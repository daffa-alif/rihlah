import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '@rihlah/database';
import { EncryptionService } from '@rihlah/common';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly encryption: EncryptionService,
  ) {}

  // ── Create / Get / Update ───────────────────────────────────────────────────

  async create(dto: CreateUserDto) {
    const existing = await this.prisma.user.findUnique({
      where: { firebaseUid: dto.firebaseUid },
    });
    if (existing) return this.toSafeUser(existing);

    const user = await this.prisma.user.create({
      data: {
        firebaseUid: dto.firebaseUid,
        phoneEnc: this.encryption.encrypt(dto.phone),
        nameEnc: this.encryption.encrypt(dto.name || 'Pengguna RIHLAH'),
        role: dto.role || 'passenger',
      },
    });

    // Create role-specific profile
    if (user.role === 'driver') {
      await this.prisma.driver.create({
        data: { userId: user.id },
      });
    } else if (user.role === 'passenger') {
      await this.prisma.passenger.create({
        data: { userId: user.id },
      });
    }

    return this.toSafeUser(user);
  }

  async findById(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: { driver: true, passenger: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return this.toSafeUser(user);
  }

  async findByFirebaseUid(firebaseUid: string) {
    const user = await this.prisma.user.findUnique({
      where: { firebaseUid },
      include: { driver: true, passenger: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return this.toSafeUser(user);
  }

  async update(id: string, dto: UpdateUserDto) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');

    const data: any = {};
    if (dto.name) data.nameEnc = this.encryption.encrypt(dto.name);
    if (dto.accountStatus) data.accountStatus = dto.accountStatus;

    const updated = await this.prisma.user.update({
      where: { id },
      data,
    });

    // Update driver KYC fields if provided
    if (dto.vehicleType || dto.plate || dto.ktpNumber || dto.bpjsKt) {
      const driverData: any = {};
      if (dto.vehicleType) driverData.vehicleType = dto.vehicleType;
      if (dto.plate) driverData.plate = dto.plate;
      if (dto.ktpNumber) {
        driverData.ktpNumberEnc = this.encryption.encrypt(dto.ktpNumber);
      }
      if (dto.bpjsKt) driverData.bpjsKt = dto.bpjsKt;
      if (dto.bpjsKs) driverData.bpjsKs = dto.bpjsKs;
      if (dto.bpjsInsurance) driverData.bpjsInsurance = dto.bpjsInsurance;

      await this.prisma.driver.upsert({
        where: { userId: id },
        create: { userId: id, ...driverData },
        update: driverData,
      });
    }

    return this.toSafeUser(updated);
  }

  async setRole(id: string, role: string) {
    await this.findById(id); // throws if not found
    return this.prisma.user.update({
      where: { id },
      data: { role },
    });
  }

  async setAccountStatus(id: string, status: string) {
    await this.findById(id);
    return this.prisma.user.update({
      where: { id },
      data: { accountStatus: status },
    });
  }

  // ── List / Search ──────────────────────────────────────────────────────────

  async findAll(params: { role?: string; limit?: number; offset?: number }) {
    const { role, limit = 50, offset = 0 } = params;
    const where: any = {};
    if (role) where.role = role;

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { driver: true },
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      data: users.map((u) => this.toSafeUser(u)),
      total,
      limit,
      offset,
    };
  }

  // ── Driver helpers ─────────────────────────────────────────────────────────

  async setDriverOnline(driverId: string, online: boolean) {
    const driver = await this.prisma.driver.findUnique({
      where: { userId: driverId },
    });
    if (!driver) throw new NotFoundException('Driver profile not found');

    return this.prisma.driver.update({
      where: { userId: driverId },
      data: {
        online,
        onlineAt: online ? new Date() : null,
      },
    });
  }

  async updateDriverLocation(
    driverId: string,
    lat: number,
    lng: number,
  ) {
    return this.prisma.$executeRawUnsafe(
      `UPDATE drivers
       SET "lastLat" = $1, "lastLng" = $2,
           location = ST_SetSRID(ST_MakePoint($3, $4), 4326),
           "updatedAt" = NOW()
       WHERE "userId" = $5`,
      lat, lng, lng, lat, driverId,
    );
  }

  async getNearbyDrivers(
    lat: number,
    lng: number,
    radiusMeters: number,
    vehicleType?: string,
  ) {
    const typeFilter = vehicleType
      ? `AND d."vehicleType" = '${vehicleType}'`
      : '';

    const result: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT
         d."userId" as id,
         d."ratingAvg" as "ratingAvg",
         d."acceptanceRate" as "acceptanceRate",
         d."totalTrips" as "totalTrips",
         d."vehicleType" as "vehicleType",
         ST_Distance(
           d.location::geography,
           ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography
         ) / 1000 AS "distanceKm"
       FROM drivers d
       WHERE d.online = true
         AND d."accountStatus" = 'active'
         ${typeFilter}
         AND ST_DWithin(
           d.location::geography,
           ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography,
           $4
         )
       ORDER BY "distanceKm"`,
      lat, lng, lng, radiusMeters,
    );

    return result;
  }

  // ── Decrypt PII for safe return ────────────────────────────────────────────

  private toSafeUser(user: any) {
    return {
      ...user,
      phone: this.decryptSafe(user.phoneEnc),
      name: this.decryptSafe(user.nameEnc),
      // Never return encrypted fields in the response
      phoneEnc: undefined,
      nameEnc: undefined,
      driver: user.driver
        ? {
            ...user.driver,
            ktpNumberEnc: undefined, // never return KTP in API response
          }
        : undefined,
    };
  }

  private decryptSafe(encrypted: string | null): string {
    if (!encrypted) return '';
    try {
      return this.encryption.decrypt(encrypted);
    } catch {
      return '[decryption error]';
    }
  }
}
