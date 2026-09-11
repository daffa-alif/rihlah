import { Injectable } from '@nestjs/common';

export interface SosAlert {
  /** Trip ID if SOS was triggered during an active trip. */
  tripId?: string;
  /** Name of the person who triggered SOS. */
  userName: string;
  /** Phone of the person who triggered SOS. */
  userPhone: string;
  /** Role: passenger | driver. */
  userRole: string;
  /** GPS coordinates. */
  lat: number;
  lng: number;
  /** Google Maps link. */
  mapsLink: string;
}

/**
 * Twilio-based notification service for SOS alerts.
 *
 * Uses Twilio's WhatsApp Business API (primary, cheaper in Indonesia)
 * and falls back to SMS for contacts without WhatsApp.
 *
 * In development mode (no Twilio credentials), logs to console instead.
 */
@Injectable()
export class TwilioService {
  private readonly accountSid: string;
  private readonly authToken: string;
  private readonly whatsappFrom: string;
  private readonly smsFrom: string;
  private readonly enabled: boolean;

  constructor() {
    this.accountSid = process.env.TWILIO_ACCOUNT_SID || '';
    this.authToken = process.env.TWILIO_AUTH_TOKEN || '';
    this.whatsappFrom = process.env.TWILIO_WHATSAPP_NUMBER || '+14155238886';
    this.smsFrom = process.env.TWILIO_PHONE_NUMBER || '';
    this.enabled = this.accountSid !== '' && this.authToken !== '';
  }

  /**
   * Send SOS alert to emergency contacts.
   * Tries WhatsApp first (cheaper, richer), falls back to SMS.
   */
  async sendSosAlert(contacts: string[], alert: SosAlert): Promise<void> {
    const message = this.buildSosMessage(alert);

    for (const contact of contacts) {
      try {
        // Try WhatsApp first
        if (contact.startsWith('+') || contact.match(/^\d{10,15}$/)) {
          const normalizedPhone = contact.startsWith('+') ? contact : `+62${contact.replace(/^0/, '')}`;
          await this.sendWhatsApp(normalizedPhone, message);
        }
      } catch (err) {
        console.warn(`WhatsApp delivery failed for ${contact}, trying SMS:`, err);
        try {
          await this.sendSms(contact, `[RIHLAH SOS] ${alert.userName} membutuhkan bantuan di ${alert.mapsLink}`);
        } catch (smsErr) {
          console.error(`All delivery failed for ${contact}:`, smsErr);
        }
      }
    }
  }

  /** Send to the ops admin FCM topic for the admin console. */
  async notifyOps(alert: SosAlert): Promise<void> {
    // In production, this would publish to an FCM topic that the admin
    // console subscribes to. For now, log as a high-priority alert.
    console.log(`
╔═══════════════════════════════════════════════════════╗
║  🆘 SOS ALERT — ADMIN OPS                            ║
╠═══════════════════════════════════════════════════════╣
║  User:   ${alert.userName.padEnd(42)}║
║  Role:   ${alert.userRole.padEnd(42)}║
║  Trip:   ${(alert.tripId || 'N/A').padEnd(42)}║
║  Loc:    ${`${alert.lat}, ${alert.lng}`.padEnd(42)}║
║  Map:    ${alert.mapsLink.padEnd(42)}║
╚═══════════════════════════════════════════════════════╝
    `);
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  private buildSosMessage(alert: SosAlert): string {
    return [
      `🆘 *DARURAT — ${alert.userName}*`,
      '',
      `${alert.userName} (${alert.userRole === 'driver' ? 'Driver' : 'Penumpang'}) membutuhkan bantuan segera.`,
      '',
      `📍 *Lokasi:* ${alert.mapsLink}`,
      alert.tripId ? `🆔 *Perjalanan:* ${alert.tripId.substring(0, 8)}` : '',
      '',
      '_Pesan ini dikirim otomatis dari RIHLAH Safety System._',
    ]
      .filter(Boolean)
      .join('\n');
  }

  private async sendWhatsApp(to: string, message: string): Promise<void> {
    if (!this.enabled) {
      console.log(`[DEV] WhatsApp to ${to}: ${message.substring(0, 100)}...`);
      return;
    }

    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${Buffer.from(`${this.accountSid}:${this.authToken}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          From: `whatsapp:${this.whatsappFrom}`,
          To: `whatsapp:${to}`,
          Body: message,
        }).toString(),
      },
    );

    if (!response.ok) {
      throw new Error(`Twilio WhatsApp API error: ${response.status}`);
    }
  }

  private async sendSms(to: string, message: string): Promise<void> {
    if (!this.enabled || !this.smsFrom) {
      console.log(`[DEV] SMS to ${to}: ${message}`);
      return;
    }

    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${Buffer.from(`${this.accountSid}:${this.authToken}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          From: this.smsFrom,
          To: to,
          Body: message,
        }).toString(),
      },
    );

    if (!response.ok) {
      throw new Error(`Twilio SMS API error: ${response.status}`);
    }
  }
}
