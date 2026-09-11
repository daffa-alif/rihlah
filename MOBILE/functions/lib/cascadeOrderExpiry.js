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
exports.cascadeOrderExpiry = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
const rtdb = admin.database();
/**
 * P2 cascadeOrderExpiry — HTTPS callable (called by client when 15s offer expires).
 *
 * In production MVP, this is triggered by Cloud Tasks. In P2, the Flutter
 * driver app calls this after its local 15s countdown expires without action.
 *
 * 1. Validates the offer is still in /order_offers and expired
 * 2. Removes the expired offer
 * 3. Adds driver to trip's skippedBy
 * 4. Finds next eligible driver and offers to them
 * 5. If no more drivers within 8 km after 90s total, marks trip 'no_drivers_available'
 */
exports.cascadeOrderExpiry = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    const driverId = context.auth.uid;
    const { tripId } = data;
    if (!tripId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing tripId');
    }
    // 1. Verify offer exists for this driver and is expired
    const offerSnap = await rtdb.ref(`/order_offers/${driverId}`).get();
    if (!offerSnap.exists())
        return { cascaded: false, reason: 'no_offer' };
    const offer = offerSnap.val();
    if (offer.tripId !== tripId)
        return { cascaded: false, reason: 'trip_mismatch' };
    // Remove the offer
    await rtdb.ref(`/order_offers/${driverId}`).remove();
    // 2. Check trip still exists and is searching
    const tripRef = db.collection('trips').doc(tripId);
    const tripDoc = await tripRef.get();
    if (!tripDoc.exists)
        return { cascaded: false, reason: 'trip_not_found' };
    const trip = tripDoc.data();
    if (trip.status !== 'searching')
        return { cascaded: false, reason: 'trip_no_longer_searching' };
    // 3. Add to skipped list
    await tripRef.update({
        skippedBy: admin.firestore.FieldValue.arrayUnion(driverId),
    });
    // 4. Check total budget (90s)
    const createdAt = trip.createdAt?.toMillis?.() ?? Date.now();
    const elapsed = Date.now() - createdAt;
    if (elapsed > 90_000) {
        await tripRef.update({ status: 'no_drivers_available' });
        return { cascaded: false, reason: 'budget_exhausted' };
    }
    // 5. Find next driver
    const { findNearbyDrivers } = require('./helpers');
    const RADIUS_STEPS = [1.5, 3, 5, 8];
    for (const radius of RADIUS_STEPS) {
        const drivers = await findNearbyDrivers(trip.pickupLat, trip.pickupLng, radius, trip.serviceType);
        const next = drivers.find((d) => d.id !== driverId && !(trip.skippedBy || []).includes(d.id));
        if (next) {
            const expiresAt = Date.now() + 15_000;
            await rtdb.ref(`/order_offers/${next.id}`).set({
                tripId,
                expiresAt,
                offerData: {
                    pickup: trip.pickupAddress,
                    dropoff: trip.dropoffAddress,
                    distanceKm: trip.distanceKm,
                    durationMin: trip.durationMin,
                    serviceType: trip.serviceType,
                    fare: trip.totalFare,
                    driverEarns: trip.driverEarns,
                },
            });
            return { cascaded: true, nextDriverId: next.id, distanceKm: next.distanceKm };
        }
    }
    // 6. Exhausted all drivers at max radius
    await tripRef.update({ status: 'no_drivers_available' });
    return { cascaded: false, reason: 'all_drivers_exhausted' };
});
//# sourceMappingURL=cascadeOrderExpiry.js.map