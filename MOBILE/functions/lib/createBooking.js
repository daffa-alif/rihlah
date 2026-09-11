"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.createBooking = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const helpers_1 = require("./helpers");
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
exports.createBooking = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    const passengerId = context.auth.uid;
    const { serviceType = 'car', pickupLat, pickupLng, pickupAddress, dropoffLat, dropoffLng, dropoffAddress, paymentMethod = 'cash', } = data;
    // Validate required fields
    if (!pickupLat || !pickupLng || !dropoffLat || !dropoffLng) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing pickup/dropoff coordinates');
    }
    // 1. Service area check
    const inside = await (0, helpers_1.isInsideServiceArea)(pickupLat, pickupLng);
    if (!inside) {
        throw new functions.https.HttpsError('failed-precondition', 'Pickup location is outside the RIHLAH service area (Bandung Kota + Cimahi)');
    }
    // 2. Distance
    const { haversineKm } = require('./helpers');
    const distanceKm = haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
    const maxDist = (0, helpers_1.maxKm)(serviceType);
    if (distanceKm > maxDist) {
        throw new functions.https.HttpsError('failed-precondition', `Distance ${distanceKm.toFixed(1)} km exceeds the ${maxDist} km limit for ${serviceType}`);
    }
    // 3. Compute fare
    const durationMin = Math.ceil((distanceKm / 25) * 60);
    const fare = (0, helpers_1.calculateFare)(distanceKm, durationMin, serviceType);
    // 4. Create trip
    const tripId = (0, helpers_1.generateId)();
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
        createdAt: (0, helpers_1.serverTimestamp)(),
        skippedBy: [],
    };
    await db.collection('trips').doc(tripId).set(tripData);
    // 5. Search for drivers with expanding radius
    const RADIUS_STEPS = [1.5, 3, 5, 8];
    let bestDriver = null;
    for (const radius of RADIUS_STEPS) {
        const drivers = await (0, helpers_1.findNearbyDrivers)(pickupLat, pickupLng, radius, serviceType);
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
        // 7. Schedule cascade expiry (simulated via setTimeout in P2;
        //    production uses Cloud Tasks)
        setTimeout(async () => {
            const offer = await rtdb.ref(`/order_offers/${bestDriver}`).get();
            if (offer.exists()) {
                const offerData = offer.val();
                if (offerData.tripId === tripId && Date.now() > offerData.expiresAt) {
                    await cascadeToNextDriver(tripId, bestDriver, pickupLat, pickupLng, serviceType);
                }
            }
        }, 15_500);
    }
    return { tripId, fare, matchedDriver: !!bestDriver };
});
async function cascadeToNextDriver(tripId, skippedDriverId, pickupLat, pickupLng, serviceType) {
    // Add to skipped list
    const tripRef = db.collection('trips').doc(tripId);
    const tripData = (await tripRef.get()).data();
    const existing = tripData?.skippedBy || [];
    await tripRef.update({ skippedBy: [...existing, skippedDriverId] });
    // Remove expired offer
    await rtdb.ref(`/order_offers/${skippedDriverId}`).remove();
    // Find next driver
    const trip = (await tripRef.get()).data();
    if (!trip)
        return;
    const elapsed = Date.now() - (trip.createdAt?.toMillis?.() ?? Date.now());
    if (elapsed > 90_000) {
        // Total 90s budget exhausted
        await tripRef.update({ status: 'no_drivers_available' });
        return;
    }
    const RADIUS_STEPS = [1.5, 3, 5, 8];
    for (const radius of RADIUS_STEPS) {
        const drivers = await (0, helpers_1.findNearbyDrivers)(pickupLat, pickupLng, radius, serviceType);
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
//# sourceMappingURL=createBooking.js.map