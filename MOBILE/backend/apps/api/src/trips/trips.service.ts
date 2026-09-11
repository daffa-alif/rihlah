import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '@rihlah/database';
import { FareCalculatorService } from '@rihlah/common';
import { CreateTripDto, RateTripDto } from './dto/create-trip.dto';

const VALID_TRANSITIONS: Record<string, string[]> = {
  searching: ['accepted', 'cancelled'],
  accepted: ['arriving', 'cancelled'],
  arriving: ['arrived', 'cancelled'],
  arrived: ['inTrip', 'cancelled'],
  inTrip: ['completed', 'cancelled'],
  completed: [], // terminal
  cancelled: [], // terminal
};

@Injectable()
export class TripsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fareCalculator: FareCalculatorService,
  ) {}

  // ── Create Booking ──────────────────────────────────────────────────────────

  async create(dto: CreateTripDto) {
    // 1. Validate service area — pickup must be inside an active polygon
    const inside = await this.isInsideServiceArea(dto.pickupLat, dto.pickupLng);
    if (!inside) {
      throw new BadRequestException(
        'Pickup location is outside the RIHLAH service area',
      );
    }

    // 2. Check distance limit for service type
    const distanceKm = dto.distanceM / 1000;
    if (!this.fareCalculator.isWithinLimit(dto.serviceType as any, distanceKm)) {
      throw new BadRequestException(
        `Distance ${distanceKm.toFixed(1)} km exceeds the limit for ${dto.serviceType}`,
      );
    }

    // 3. Calculate fare
    const fare = await this.fareCalculator.calculate({
      distanceKm,
      durationMin: Math.ceil(dto.durationS / 60),
      service: dto.serviceType as any,
    });

    // 4. Create the trip
    const trip = await this.prisma.trip.create({
      data: {
        passengerId: dto.passengerId,
        serviceType: dto.serviceType,
        pickupLat: dto.pickupLat,
        pickupLng: dto.pickupLng,
        pickupAddress: dto.pickupAddress,
        dropoffLat: dto.dropoffLat,
        dropoffLng: dto.dropoffLng,
        dropoffAddress: dto.dropoffAddress,
        distanceM: dto.distanceM,
        durationS: dto.durationS,
        fareIdr: fare.totalFareIdr,
        driverShareIdr: fare.driverEarnsIdr,
        platformFeeIdr: fare.platformFeeIdr,
        paymentMethod: dto.paymentMethod || 'cash',
        status: 'searching',
        fareFormulaVersion: 1,
        appliedVoucherCode: dto.appliedVoucherCode,
        appliedDiscountIdr: dto.appliedDiscountIdr || 0,
      },
    });

    // 5. Trigger matching (async — the matching worker handles dispatch)
    // In MVP, this publishes to Redis; for now we just return the trip and
    // the driver app polls `pendingTripsStream`.

    return { ...trip, fare };
  }

  // ── Trip Lifecycle ──────────────────────────────────────────────────────────

  async findById(tripId: string) {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    return trip;
  }

  async accept(tripId: string, driverId: string) {
    const trip = await this.findById(tripId);
    this.validateTransition(trip.status, 'accepted');

    // Validate driver exists and is online
    const driver = await this.prisma.driver.findUnique({
      where: { userId: driverId },
    });
    if (!driver) throw new NotFoundException('Driver not found');

    return this.prisma.trip.update({
      where: { id: tripId },
      data: {
        driverId,
        status: 'accepted',
        acceptedAt: new Date(),
      },
    });
  }

  async decline(tripId: string, driverId: string) {
    const trip = await this.findById(tripId);
    if (trip.status !== 'searching') {
      throw new BadRequestException('Trip is no longer available');
    }

    // Add driver to skippedByIds so they aren't offered this trip again
    return this.prisma.trip.update({
      where: { id: tripId },
      data: {
        skippedByIds: { push: driverId },
      },
    });
  }

  async setArriving(tripId: string, driverId: string) {
    const trip = await this.findById(tripId);
    this.validateDriver(trip, driverId);
    this.validateTransition(trip.status, 'arriving');

    return this.prisma.trip.update({
      where: { id: tripId },
      data: { status: 'arriving' },
    });
  }

  async setArrived(tripId: string, driverId: string) {
    const trip = await this.findById(tripId);
    this.validateDriver(trip, driverId);
    this.validateTransition(trip.status, 'arrived');

    return this.prisma.trip.update({
      where: { id: tripId },
      data: { status: 'arrived' },
    });
  }

  async startTrip(tripId: string, driverId: string) {
    const trip = await this.findById(tripId);
    this.validateDriver(trip, driverId);
    this.validateTransition(trip.status, 'inTrip');

    return this.prisma.trip.update({
      where: { id: tripId },
      data: { status: 'inTrip' },
    });
  }

  async complete(tripId: string, driverId: string) {
    const trip = await this.findById(tripId);
    this.validateDriver(trip, driverId);
    this.validateTransition(trip.status, 'completed');

    // Recompute final fare based on actual distance/duration
    const fare = await this.fareCalculator.calculate({
      distanceKm: trip.distanceM / 1000,
      durationMin: Math.ceil(trip.durationS / 60),
      service: trip.serviceType as any,
    });

    const completed = await this.prisma.trip.update({
      where: { id: tripId },
      data: {
        status: 'completed',
        fareIdr: fare.totalFareIdr,
        driverShareIdr: fare.driverEarnsIdr,
        platformFeeIdr: fare.platformFeeIdr,
        completedAt: new Date(),
      },
    });

    // Update driver balance and trip count
    await this.prisma.driver.update({
      where: { userId: driverId },
      data: {
        balanceIdr: { increment: fare.driverEarnsIdr },
        totalTrips: { increment: 1 },
      },
    });

    return { ...completed, fare };
  }

  async cancel(tripId: string, cancelledBy: string) {
    const trip = await this.findById(tripId);
    if (trip.status === 'completed' || trip.status === 'cancelled') {
      throw new BadRequestException('Trip is already final');
    }

    return this.prisma.trip.update({
      where: { id: tripId },
      data: {
        status: 'cancelled',
        cancelledAt: new Date(),
      },
    });
  }

  async rate(tripId: string, userId: string, dto: RateTripDto) {
    const trip = await this.findById(tripId);
    if (trip.status !== 'completed') {
      throw new BadRequestException('Can only rate completed trips');
    }
    if (trip.passengerId !== userId) {
      throw new ForbiddenException('Only the passenger can rate the trip');
    }

    // Check 7-day window
    const completedAt = trip.completedAt;
    if (completedAt) {
      const daysSinceCompletion =
        (Date.now() - completedAt.getTime()) / (1000 * 60 * 60 * 24);
      if (daysSinceCompletion > 7) {
        throw new BadRequestException(
          'Rating window has expired (7 days after trip completion)',
        );
      }
    }

    // Create rating record
    const rating = await this.prisma.rating.create({
      data: {
        tripId,
        byUserId: userId,
        targetUserId: trip.driverId!,
        stars: dto.stars,
        tags: dto.tags || [],
        comment: dto.comment,
      },
    });

    // Update trip
    await this.prisma.trip.update({
      where: { id: tripId },
      data: {
        passengerRating: dto.stars,
        passengerTip: dto.tip || 0,
        passengerReview: dto.comment,
      },
    });

    // Recompute driver rating average
    await this.recomputeDriverRating(trip.driverId!);

    return rating;
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  async findPending(
    serviceType: string,
    driverId: string,
    limit = 20,
  ) {
    const cutoff = new Date(Date.now() - 15 * 60 * 1000); // 15 min ago

    return this.prisma.trip.findMany({
      where: {
        status: 'searching',
        OR: [
          { serviceType },
          { serviceType: 'send' }, // 'send' orders visible to both car and bike
        ],
        createdAt: { gte: cutoff },
        NOT: { skippedByIds: { has: driverId } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async findByPassenger(passengerId: string, limit = 50) {
    return this.prisma.trip.findMany({
      where: { passengerId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async findByDriver(driverId: string, limit = 50) {
    return this.prisma.trip.findMany({
      where: { driverId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async findAll(params: {
    status?: string;
    limit?: number;
    offset?: number;
  }) {
    const { status, limit = 50, offset = 0 } = params;
    const where: any = {};
    if (status) where.status = status;

    const [trips, total] = await Promise.all([
      this.prisma.trip.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.trip.count({ where }),
    ]);

    return { data: trips, total, limit, offset };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  private validateTransition(current: string, target: string) {
    const allowed = VALID_TRANSITIONS[current];
    if (!allowed || !allowed.includes(target)) {
      throw new BadRequestException(
        `Cannot transition from '${current}' to '${target}'`,
      );
    }
  }

  private validateDriver(trip: any, driverId: string) {
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not assigned to this trip');
    }
  }

  private async isInsideServiceArea(
    lat: number,
    lng: number,
  ): Promise<boolean> {
    const result: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT 1
       FROM "service_areas"
       WHERE active = true
         AND ST_Within(
           ST_SetSRID(ST_MakePoint($1, $2), 4326),
           ST_GeomFromGeoJSON(geojson::text)
         )
       LIMIT 1`,
      lng,
      lat,
    );
    return result.length > 0;
  }

  private async recomputeDriverRating(driverId: string) {
    const result: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT AVG(stars::float) as avg_rating, COUNT(*) as count
       FROM "ratings"
       WHERE "targetUserId" = $1`,
      driverId,
    );

    if (result.length > 0 && result[0].avg_rating !== null) {
      await this.prisma.driver.update({
        where: { userId: driverId },
        data: {
          ratingAvg: Math.round(result[0].avg_rating * 100) / 100,
          ratingCount: Number(result[0].count),
        },
      });
    }
  }
}
