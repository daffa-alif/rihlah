import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { serverTimestamp } from './helpers';

const db = admin.firestore();

/**
 * P2 sosTrigger — HTTPS callable.
 *
 * Called when passenger or driver presses the SOS button.
 *
 * 1. Validates user is authenticated and has an active trip (or not — SOS works
 *    even without an active trip)
 * 2. Creates a /sos_events doc with location and user details
 * 3. Notifies RIHLAH ops via FCM topic
 * 4. In production: sends WhatsApp/SMS to emergency contacts via Twilio
 *    (P2: logs contacts and notifies ops; real Twilio deferred to MVP)
 */
export const sosTrigger = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const userId = context.auth.uid;
  const {
    tripId,
    lat, lng,
    userRole = 'passenger',
    userName = 'Pengguna RIHLAH',
    emergencyContacts = [],
  } = data;

  if (!lat || !lng) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing location coordinates');
  }

  // 1. Create SOS event in Firestore
  const eventRef = await db.collection('sos_events').add({
    tripId: tripId || null,
    byUserId: userId,
    byUserRole: userRole,
    byUserName: userName,
    lat,
    lng,
    contactsNotified: emergencyContacts,
    status: 'open',
    createdAt: serverTimestamp(),
  });

  // 2. Notify ops dashboard via FCM topic
  try {
    await admin.messaging().send({
      topic: 'ops-alerts',
      notification: {
        title: `🆘 SOS ${userRole === 'driver' ? 'Driver' : 'Passenger'}`,
        body: `${userName} at ${lat.toFixed(4)}, ${lng.toFixed(4)}`,
      },
      data: {
        type: 'sos_alert',
        eventId: eventRef.id,
        userId,
        tripId: tripId || '',
        lat: String(lat),
        lng: String(lng),
      },
    });
  } catch (e) {
    console.warn('FCM ops alert failed:', e);
  }

  // 3. In P2, emergency contact notification is handled client-side
  //    (Flutter sos_service.dart does local notifications + WhatsApp share).
  //    In MVP, this function calls Twilio to deliver SMS/WhatsApp.

  console.log(`SOS event ${eventRef.id}: ${userName} (${userRole}) at ${lat}, ${lng}`);

  return {
    eventId: eventRef.id,
    status: 'open',
    message: 'Bantuan telah dikirim. Tim RIHLAH akan segera menghubungi.',
  };
});
