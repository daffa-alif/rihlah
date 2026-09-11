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
exports.calculateFare = calculateFare;
exports.maxKm = maxKm;
exports.isInsideServiceArea = isInsideServiceArea;
exports.findNearbyDrivers = findNearbyDrivers;
exports.haversineKm = haversineKm;
exports.serverTimestamp = serverTimestamp;
exports.generateId = generateId;
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
const rtdb = admin.database();
// ── Fare Calculator (mirrors Flutter FareCalculator + NestJS FareCalculatorService) ─
const FARE = {
    car: { base: 5000, perKm: 3000, perMin: 300, maxKm: 50 },
    bike: { base: 3000, perKm: 2000, perMin: 200, maxKm: 25 },
    send: { base: 4000, perKm: 2500, perMin: 250, maxKm: 30 },
};
const GOJEK_CAR = { base: 9000, perKm: 4000, perMin: 450 };
const GOJEK_BIKE = { base: 6000, perKm: 2500, perMin: 300 };
const PLATFORM_FEE = 0.05;
function calculateFare(distanceKm, durationMin, service) {
    const svc = FARE[service];
    const baseFare = Math.round(svc.base + distanceKm * svc.perKm + durationMin * svc.perMin);
    const totalFare = roundTo100(baseFare);
    const platformFee = Math.round(totalFare * PLATFORM_FEE);
    const driverEarns = totalFare - platformFee;
    const gojekSvc = service === 'bike' ? GOJEK_BIKE : GOJEK_CAR;
    const gojekEstimate = roundTo100(Math.round(gojekSvc.base + distanceKm * gojekSvc.perKm + durationMin * gojekSvc.perMin));
    const indriveEstimate = roundTo100(Math.round(gojekEstimate * 0.9));
    return { baseFare, totalFare, platformFee, driverEarns, gojekEstimate, indriveEstimate, durationMin };
}
function maxKm(service) {
    return FARE[service]?.maxKm ?? 50;
}
function roundTo100(v) {
    return Math.round(v / 100) * 100;
}
// ── Service Area Validation ─────────────────────────────────────────────────────
async function isInsideServiceArea(lat, lng) {
    const areas = await db.collection('service_areas')
        .where('active', '==', true)
        .get();
    for (const doc of areas.docs) {
        const geojson = doc.data().geojson;
        if (geojson && pointInPolygon(lat, lng, geojson))
            return true;
    }
    return false;
}
function pointInPolygon(lat, lng, geojson) {
    // GeoJSON coordinates are [longitude, latitude] pairs.
    // Firestore stores them as nested maps: { arrayValue: { values: [...] } }
    // or as plain JS arrays depending on how they were written.
    const coords = extractCoords(geojson);
    if (!coords || coords.length < 3)
        return false;
    let inside = false;
    for (let i = 0, j = coords.length - 1; i < coords.length; j = i++) {
        const xi = coords[i][0]; // longitude
        const yi = coords[i][1]; // latitude
        const xj = coords[j][0]; // longitude
        const yj = coords[j][1]; // latitude
        const intersect = ((yi > lat) !== (yj > lat)) &&
            (lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi);
        if (intersect)
            inside = !inside;
    }
    return inside;
}
/** Extract coordinates from GeoJSON, handling both plain JS and Firestore map formats. */
function extractCoords(geojson) {
    // Plain JS object (from direct Firestore write)
    if (Array.isArray(geojson?.coordinates?.[0])) {
        return geojson.coordinates[0];
    }
    // Firestore mapValue format (from REST API write)
    try {
        const outer = geojson?.coordinates?.arrayValue?.values ?? geojson?.coordinates;
        if (Array.isArray(outer)) {
            const ring = outer[0]?.arrayValue?.values ?? outer[0];
            if (Array.isArray(ring)) {
                return ring.map((v) => {
                    const arr = v?.arrayValue?.values ?? v;
                    if (Array.isArray(arr)) {
                        return arr.map((n) => Number(n?.doubleValue ?? n?.integerValue ?? n ?? 0));
                    }
                    return [0, 0];
                });
            }
        }
    }
    catch (_) { /* fall through */ }
    return null;
}
/**
 * Find online drivers within radius (km).  Uses RTDB presence + Firestore driver
 * data to score candidates.  Radius expansion is handled by the caller.
 */
async function findNearbyDrivers(pickupLat, pickupLng, radiusKm, serviceType) {
    const locSnap = await rtdb.ref('driver_locations').get();
    if (!locSnap.exists())
        return [];
    const drivers = [];
    const driverLocs = locSnap.val();
    const driverIds = Object.keys(driverLocs);
    for (const driverId of driverIds) {
        const loc = driverLocs[driverId];
        if (!loc || !loc.lat || !loc.lng)
            continue;
        const dist = haversineKm(pickupLat, pickupLng, loc.lat, loc.lng);
        if (dist > radiusKm)
            continue;
        // Get driver profile from Firestore
        const driverDoc = await db.collection('users').doc(driverId).get();
        if (!driverDoc.exists)
            continue;
        const driver = driverDoc.data();
        if (driver.accountStatus !== 'active')
            continue;
        // Vehicle type filter: bike drivers only get bike orders, car gets car+sends
        const vehicleType = driver.vehicleType || 'bike';
        if (serviceType === 'car' && vehicleType !== 'car')
            continue;
        if (serviceType === 'bike' && vehicleType !== 'bike')
            continue;
        // Count trips today for spread scoring
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tripsSnap = await db.collection('trips')
            .where('driverId', '==', driverId)
            .where('status', '==', 'completed')
            .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(today))
            .count()
            .get();
        drivers.push({
            id: driverId,
            distanceKm: dist,
            ratingAvg: driver.ratingAvg || 0,
            acceptanceRate: driver.acceptanceRate || 0,
            tripsToday: tripsSnap.data().count,
        });
    }
    // Sort by composite score
    return scoreDrivers(drivers);
}
function scoreDrivers(drivers) {
    if (drivers.length <= 1)
        return drivers;
    const maxDist = Math.max(...drivers.map(d => d.distanceKm), 1);
    const maxTrips = Math.max(...drivers.map(d => d.tripsToday), 1);
    const scored = drivers.map(d => {
        const proximity = 1 - d.distanceKm / maxDist;
        const rating = d.ratingAvg / 5;
        const acceptance = Math.max(0, Math.min(1, d.acceptanceRate));
        const spread = 1 - d.tripsToday / maxTrips;
        const score = 0.40 * proximity + 0.25 * rating + 0.20 * acceptance + 0.15 * spread;
        return { ...d, distanceKm: score }; // reuse distanceKm field for score (sorted by it)
    });
    scored.sort((a, b) => b.distanceKm - a.distanceKm); // highest score first
    return scored;
}
// ── Haversine ────────────────────────────────────────────────────────────────────
function haversineKm(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
function toRad(deg) { return (deg * Math.PI) / 180; }
// ── Timestamp ────────────────────────────────────────────────────────────────────
/** Safe server timestamp — works in both emulator and production. */
function serverTimestamp() {
    try {
        if (admin.firestore?.FieldValue?.serverTimestamp) {
            return admin.firestore.FieldValue.serverTimestamp();
        }
    }
    catch (_) { /* fall through */ }
    try {
        if (admin.firestore?.Timestamp?.now) {
            return admin.firestore.Timestamp.now();
        }
    }
    catch (_) { /* fall through */ }
    // Ultimate fallback: plain JS Date
    return new Date();
}
// ── ID Generation ────────────────────────────────────────────────────────────────
function generateId() {
    return db.collection('_').doc().id; // Firestore auto-ID
}
//# sourceMappingURL=helpers.js.map