import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();
const rtdb = admin.database();

/**
 * P2 onLocationWrite — RTDB trigger.
 *
 * Fires every time a driver writes to /driver_locations/{driverId}.
 *
 * 1. Mirrors position to /active_trips/{tripId} for passenger tracking
 * 2. Recomputes ETA every 30s using Haversine (free, no Mapbox API cost)
 * 3. Cleans up stale entries when driver goes offline
 */
export const onLocationWrite = functions.database
  .ref('/driver_locations/{driverId}')
  .onWrite(async (change, context) => {
    const driverId = context.params.driverId;
    const after = change.after.val() as any;

    if (!after) {
      await cleanupDriverTrips(driverId);
      return;
    }

    const { lat, lng, tripId, heading } = after;

    if (tripId) {
      const etaKey = `eta_last_calc_${tripId}`;
      const etaSnap = await rtdb.ref(etaKey).get();
      const lastCalc = etaSnap.val() as number || 0;
      const now = Date.now();

      let etaSeconds: number | null = null;

      if (now - lastCalc >= 30_000) {
        etaSeconds = await recomputeEta(tripId, lat, lng);
        await rtdb.ref(etaKey).set(now);
      }

      await rtdb.ref(`/active_trips/${tripId}`).update({
        driverLat: lat,
        driverLng: lng,
        heading: heading || null,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
        ...(etaSeconds !== null ? { etaSeconds } : {}),
      });
    }
  });

async function cleanupDriverTrips(driverId: string) {
  const tripsSnap = await db.collection('trips')
    .where('driverId', '==', driverId)
    .where('status', 'in', ['accepted', 'arriving', 'arrived', 'inTrip'])
    .get();

  for (const doc of tripsSnap.docs) {
    await rtdb.ref(`/active_trips/${doc.id}`).remove();
    await rtdb.ref(`eta_last_calc_${doc.id}`).remove();
  }
}

async function recomputeEta(tripId: string, driverLat: number, driverLng: number): Promise<number> {
  try {
    const tripDoc = await db.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) return 0;

    const trip = tripDoc.data()!;
    const targetLat = trip.status === 'inTrip' ? trip.dropoffLat : trip.pickupLat;
    const targetLng = trip.status === 'inTrip' ? trip.dropoffLng : trip.pickupLng;

    const { haversineKm } = require('./helpers');
    const km = haversineKm(driverLat, driverLng, targetLat, targetLng);
    const etaMinutes = (km / 25) * 60;
    return Math.max(30, Math.ceil(etaMinutes * 60));
  } catch {
    return 0;
  }
}
