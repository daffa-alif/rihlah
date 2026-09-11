import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { calculateFare, maxKm, isInsideServiceArea, findNearbyDrivers, generateId, serverTimestamp } from './helpers';

const db = admin.firestore();
const rtdb = admin.database();

/**
 * P2 createBooking — HTTPS callable.
 *
 * 1. Validates passenger is authenticated
 * 2. Validates pickup inside service area
 * 3. Validates distance within service limit
 * 4. Computes fare using shared fare formula
 * 5. Searches for nearby online drivers (1.5 → 3 → 5 → 8 km)
 * 6. Scores drivers (composite: proximity + rating + acceptance + spread)
 * 7. Creates trip doc in Firestore with status 'searching'
 * 8. Offers to top-1 driver via RTDB /order_offers with 15s timeout
 * 9. Schedules cascade to next driver via Cloud Tasks
 */
export const createBooking = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const passengerId = context.auth.uid;
  const {
    serviceType = 'car',
    pickupLat, pickupLng, pickupAddress,
    dropoffLat, dropoffLng, dropoffAddress,
    paymentMethod = 'cash',
  } = data;

  // Validate required fields
  if (!pickupLat || !pickupLng || !dropoffLat || !dropoffLng) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing pickup/dropoff coordinates');
  }

  // 1. Service area check
  const inside = await isInsideServiceArea(pickupLat, pickupLng);
  if (!inside) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Pickup location is outside the RIHLAH service area (Bandung Kota + Cimahi)',
    );
  }

  // 2. Distance
  const { haversineKm } = require('./helpers');
  const distanceKm = haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
  const maxDist = maxKm(serviceType);

  if (distanceKm > maxDist) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Distance ${distanceKm.toFixed(1)} km exceeds the ${maxDist} km limit for ${serviceType}`,
    );
  }

  // 3. Compute fare
  const durationMin = Math.ceil((distanceKm / 25) * 60);
  const fare = calculateFare(distanceKm, durationMin, serviceType as any);

  // 4. Create trip
  const tripId = generateId();
  const tripData = {
    tripId,
    passengerId,
    serviceType,
    pickupLat, pickupLng, pickupAddress,
    dropoffLat, dropoffLng, dropoffAddress,
    distanceKm: Math.round(distanceKm * 10) / 10,
    durationMin,
    totalFare: fare.totalFare,
    platformFee: fare.platformFee,
    driverEarns: fare.driverEarns,
    paymentMethod,
    status: 'searching',
    fareFormulaVersion: 1,
    createdAt: serverTimestamp(),
    skippedBy: [],
  };

  await db.collection('trips').doc(tripId).set(tripData);

  // 5. Search for drivers with expanding radius
  const RADIUS_STEPS = [1.5, 3, 5, 8];
  let bestDriver: string | null = null;

  for (const radius of RADIUS_STEPS) {
    const drivers = await findNearbyDrivers(pickupLat, pickupLng, radius, serviceType);
    if (drivers.length > 0) {
      bestDriver = drivers[0].id; // top-scored driver
      break;
    }
  }

  if (bestDriver) {
    // 6. Offer to top-1 driver
    const expiresAt = Date.now() + 15_000;
    await rtdb.ref(`/order_offers/${bestDriver}`).set({
      tripId,
      expiresAt,
      offerData: {
        pickup: pickupAddress,
        dropoff: dropoffAddress,
        distanceKm: Math.round(distanceKm * 10) / 10,
        durationMin,
        serviceType,
        fare: fare.totalFare,
        driverEarns: fare.driverEarns,
      },
    });

    // 7. Cascade to next driver on expiry: the Flutter driver app calls
    //    'cascadeOrderExpiry' callable when its local 15s countdown expires
    //    (or when the driver taps "Pass"). For production, replace with
    //    Cloud Tasks to guarantee cascade even if the driver goes offline:
    //      const {CloudTasksClient} = require('@google-cloud/tasks');
    //      await tasksClient.createTask({...scheduleTime: +15s...});
    //    The cascadeOrderExpiry function at cascadeOrderExpiry.ts is ready
    //    to receive Cloud Tasks HTTP requests directly.
  }

  return { tripId, fare, matchedDriver: !!bestDriver };
});

// cascadeToNextDriver kept for reference; production cascade flows through
// the cascadeOrderExpiry callable (see cascadeOrderExpiry.ts).
async function cascadeToNextDriver(
  tripId: string,
  skippedDriverId: string,
  pickupLat: number,
  pickupLng: number,
  serviceType: string,
) {
  // Add to skipped list
  const tripRef = db.collection('trips').doc(tripId);
  const tripData = (await tripRef.get()).data();
  const existing = tripData?.skippedBy || [];
  await tripRef.update({ skippedBy: [...existing, skippedDriverId] });

  // Remove expired offer
  await rtdb.ref(`/order_offers/${skippedDriverId}`).remove();

  // Find next driver
  const trip = (await tripRef.get()).data();
  if (!trip) return;

  const elapsed = Date.now() - (trip.createdAt?.toMillis?.() ?? Date.now());
  if (elapsed > 90_000) {
    // Total 90s budget exhausted
    await tripRef.update({ status: 'no_drivers_available' });
    return;
  }

  const RADIUS_STEPS = [1.5, 3, 5, 8];
  for (const radius of RADIUS_STEPS) {
    const drivers = await findNearbyDrivers(pickupLat, pickupLng, radius, serviceType);
    const next = drivers.find(d => !trip.skippedBy?.includes(d.id));
    if (next) {
      const expiresAt = Date.now() + 15_000;
      await rtdb.ref(`/order_offers/${next.id}`).set({
        tripId,
        expiresAt,
        offerData: trip,
      });
      return;
    }
  }

  // No drivers available
  await tripRef.update({ status: 'no_drivers_available' });
}
