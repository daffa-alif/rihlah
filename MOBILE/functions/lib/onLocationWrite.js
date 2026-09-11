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
exports.onLocationWrite = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
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
exports.onLocationWrite = functions.database
    .ref('/driver_locations/{driverId}')
    .onWrite(async (change, context) => {
    const driverId = context.params.driverId;
    const after = change.after.val();
    if (!after) {
        await cleanupDriverTrips(driverId);
        return;
    }
    const { lat, lng, tripId, heading } = after;
    if (tripId) {
        const etaKey = `eta_last_calc_${tripId}`;
        const etaSnap = await rtdb.ref(etaKey).get();
        const lastCalc = etaSnap.val() || 0;
        const now = Date.now();
        let etaSeconds = null;
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
async function cleanupDriverTrips(driverId) {
    const tripsSnap = await db.collection('trips')
        .where('driverId', '==', driverId)
        .where('status', 'in', ['accepted', 'arriving', 'arrived', 'inTrip'])
        .get();
    for (const doc of tripsSnap.docs) {
        await rtdb.ref(`/active_trips/${doc.id}`).remove();
        await rtdb.ref(`eta_last_calc_${doc.id}`).remove();
    }
}
async function recomputeEta(tripId, driverLat, driverLng) {
    try {
        const tripDoc = await db.collection('trips').doc(tripId).get();
        if (!tripDoc.exists)
            return 0;
        const trip = tripDoc.data();
        const targetLat = trip.status === 'inTrip' ? trip.dropoffLat : trip.pickupLat;
        const targetLng = trip.status === 'inTrip' ? trip.dropoffLng : trip.pickupLng;
        const { haversineKm } = require('./helpers');
        const km = haversineKm(driverLat, driverLng, targetLat, targetLng);
        const etaMinutes = (km / 25) * 60;
        return Math.max(30, Math.ceil(etaMinutes * 60));
    }
    catch {
        return 0;
    }
}
//# sourceMappingURL=onLocationWrite.js.map