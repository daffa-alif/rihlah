import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { serverTimestamp } from './helpers';

const db = admin.firestore();
const rtdb = admin.database();

/**
 * P2 acceptOrder — HTTPS callable.
 *
 * 1. Validates driver is authenticated
 * 2. Reads /order_offers/{driverId} to verify offer exists and is not expired
 * 3. Deletes the offer from RTDB
 * 4. Updates trip status to 'accepted' with driverId
 * 5. Sends FCM push to passenger with driver details
 */
export const acceptOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const driverId = context.auth.uid;
  const { tripId } = data;

  if (!tripId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing tripId');
  }

  // 1. Validate offer exists and isn't expired
  const offerSnap = await rtdb.ref(`/order_offers/${driverId}`).get();
  if (!offerSnap.exists()) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'No pending order offer found. The order may have expired or been accepted by another driver.',
    );
  }

  const offer = offerSnap.val();
  if (offer.tripId !== tripId) {
    throw new functions.https.HttpsError('failed-precondition', 'Offer does not match this trip');
  }

  if (Date.now() > offer.expiresAt) {
    // Clean up expired offer
    await rtdb.ref(`/order_offers/${driverId}`).remove();
    throw new functions.https.HttpsError('deadline-exceeded', 'Offer has expired');
  }

  // 2. Delete the offer (prevents double-accept)
  await rtdb.ref(`/order_offers/${driverId}`).remove();

  // 3. Update trip
  const tripRef = db.collection('trips').doc(tripId);
  const tripDoc = await tripRef.get();

  if (!tripDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Trip not found');
  }

  const trip = tripDoc.data()!;
  if (trip.status !== 'searching') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Trip is no longer available (status: ${trip.status})`,
    );
  }

  await tripRef.update({
    driverId,
    status: 'accepted',
    acceptedAt: serverTimestamp(),
  });

  // 4. Get driver details for the passenger notification
  const driverDoc = await db.collection('users').doc(driverId).get();
  const driver = driverDoc.data()!;

  // 5. Notify passenger via FCM
  // In P2, the passenger app polls tripStream; this enhances it with a push
  try {
    const passengerDoc = await db.collection('users').doc(trip.passengerId).get();
    const passenger = passengerDoc.data();
    // FCM token would be stored on user doc in production
    if (passenger?.fcmToken) {
      await admin.messaging().send({
        token: passenger.fcmToken,
        notification: {
          title: 'Driver found!',
          body: `${driver.name || 'Driver'} is on the way`,
        },
        data: {
          type: 'driver_accepted',
          tripId,
          driverId,
        },
      });
    }
  } catch (e) {
    // Non-fatal: app also polls the trip stream
    console.warn('FCM notification failed:', e);
  }

  return {
    tripId,
    status: 'accepted',
    driverName: driver.name || 'Driver RIHLAH',
    vehicleType: driver.vehicleType || 'car',
    plate: driver.plate || '',
  };
});
