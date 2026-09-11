import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { calculateFare, serverTimestamp } from './helpers';

const db = admin.firestore();

/**
 * P2 completeTrip — HTTPS callable (driver-side, idempotent).
 *
 * 1. Validates trip status is 'inTrip'
 * 2. Computes final fare from actual distance and duration
 * 3. Updates driver balance and trip count
 * 4. Sets trip status to 'completed'
 * 5. Sends FCM pushes to both passenger and driver
 */
export const completeTrip = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const driverId = context.auth.uid;
  const { tripId } = data;

  if (!tripId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing tripId');
  }

  const tripRef = db.collection('trips').doc(tripId);
  const tripDoc = await tripRef.get();

  if (!tripDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Trip not found');
  }

  const trip = tripDoc.data()!;

  // Idempotency: if already completed, return success
  if (trip.status === 'completed') {
    return { tripId, status: 'completed', alreadyCompleted: true };
  }

  // Validate
  if (trip.status !== 'inTrip') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Cannot complete trip in status: ${trip.status}`,
    );
  }

  if (trip.driverId !== driverId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You are not the assigned driver for this trip',
    );
  }

  // Recompute fare from actual values
  const fare = calculateFare(
    trip.distanceKm || 0,
    trip.durationMin || 0,
    trip.serviceType as any,
  );

  // Update trip
  const completedAt = serverTimestamp();
  await tripRef.update({
    status: 'completed',
    totalFare: fare.totalFare,
    platformFee: fare.platformFee,
    driverEarns: fare.driverEarns,
    completedAt,
  });

  // Update driver balance and trip count atomically (best-effort in P2)
  const driverRef = db.collection('users').doc(driverId);
  await db.runTransaction(async (txn) => {
    const driverDoc = await txn.get(driverRef);
    if (!driverDoc.exists) return;

    const driver = driverDoc.data()!;
    const newBalance = (driver.balanceIdr || 0) + fare.driverEarns;
    const newTrips = (driver.totalTrips || 0) + 1;

    txn.update(driverRef, {
      balanceIdr: newBalance,
      totalTrips: newTrips,
    });
  });

  // FCM pushes (best-effort)
  try {
    const passengerDoc = await db.collection('users').doc(trip.passengerId).get();
    const driverDoc = await db.collection('users').doc(driverId).get();

    const tokens: string[] = [];
    if (passengerDoc.data()?.fcmToken) tokens.push(passengerDoc.data()!.fcmToken);
    if (driverDoc.data()?.fcmToken) tokens.push(driverDoc.data()!.fcmToken);

    for (const token of tokens) {
      await admin.messaging().send({
        token,
        notification: {
          title: 'Trip complete',
          body: `Total: Rp ${fare.totalFare.toLocaleString('id-ID')}`,
        },
        data: { type: 'trip_completed', tripId },
      }).catch(() => {}); // non-fatal
    }
  } catch (_) { /* non-fatal */ }

  return {
    tripId,
    status: 'completed',
    fare: {
      total: fare.totalFare,
      platformFee: fare.platformFee,
      driverEarns: fare.driverEarns,
    },
  };
});
