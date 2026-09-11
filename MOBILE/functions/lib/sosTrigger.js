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
exports.sosTrigger = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const helpers_1 = require("./helpers");
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
exports.sosTrigger = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    const userId = context.auth.uid;
    const { tripId, lat, lng, userRole = 'passenger', userName = 'Pengguna RIHLAH', emergencyContacts = [], } = data;
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
        createdAt: (0, helpers_1.serverTimestamp)(),
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
    }
    catch (e) {
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
//# sourceMappingURL=sosTrigger.js.map