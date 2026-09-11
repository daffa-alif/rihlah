import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@rihlah/database';
import { TwilioService } from '@rihlah/common/notifications/twilio.service';
import { CreateSosDto } from './dto/create-sos.dto';

@Injectable()
export class SosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly twilio: TwilioService,
  ) {}

  /**
   * Create an SOS event:
   * 1. Persist to database
   * 2. Send WhatsApp/SMS to emergency contacts
   * 3. Notify ops admin dashboard
   */
  async trigger(dto: CreateSosDto) {
    // 1. Persist SOS event
    const event = await this.prisma.sosEvent.create({
      data: {
        tripId: dto.tripId,
        byUserId: dto.byUserId,
        byUserRole: dto.byUserRole,
        byUserName: dto.byUserName,
        lat: dto.lat,
        lng: dto.lng,
        contactsNotified: dto.contacts || [],
        status: 'open',
      },
    });

    // 2. Build alert payload
    const mapsLink = `https://maps.google.com/?q=${dto.lat},${dto.lng}`;

    const alert = {
      tripId: dto.tripId,
      userName: dto.byUserName || 'Unknown',
      userPhone: '',
      userRole: dto.byUserRole,
      lat: dto.lat,
      lng: dto.lng,
      mapsLink,
    };

    // 3. Send to emergency contacts (fire-and-forget)
    const contacts = dto.contacts || [];
    if (contacts.length > 0) {
      this.twilio.sendSosAlert(contacts, alert).catch((err) => {
        console.error('SOS contact notification failed:', err);
      });
    }

    // 4. Notify ops (fire-and-forget)
    this.twilio.notifyOps(alert).catch((err) => {
      console.error('SOS ops notification failed:', err);
    });

    return event;
  }

  /** Admin: acknowledge an SOS event. */
  async acknowledge(eventId: string, adminId: string) {
    const event = await this.prisma.sosEvent.findUnique({
      where: { id: eventId },
    });
    if (!event) throw new NotFoundException('SOS event not found');

    return this.prisma.sosEvent.update({
      where: { id: eventId },
      data: { status: 'acknowledged' },
    });
  }

  /** Admin: list all SOS events. */
  async findAll(params: { status?: string; limit?: number; offset?: number }) {
    const { status, limit = 50, offset = 0 } = params;
    const where: any = {};
    if (status) where.status = status;

    const [events, total] = await Promise.all([
      this.prisma.sosEvent.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.sosEvent.count({ where }),
    ]);

    return { data: events, total, limit, offset };
  }

  /** Generate a signed upload URL for SOS audio recording (GCS). */
  async getAudioUploadUrl(eventId: string): Promise<string> {
    // In production, this generates a GCS signed URL for the driver app to
    // upload the 30-second SOS audio recording directly.
    // For now, return a placeholder.
    return `/storage/sos-audio/${eventId}.m4a`;
  }
}
