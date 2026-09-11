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
exports.requestWithdrawal = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const helpers_1 = require("./helpers");
const db = admin.firestore();
/**
 * P2 requestWithdrawal — HTTPS callable (driver-side).
 *
 * 1. Validates driver balance >= Rp 20,000
 * 2. First withdrawal of the day free; subsequent charged Rp 1,000
 * 3. Atomically debits driver balance
 * 4. Creates payout doc with status 'processing'
 * 5. STUB: auto-resolves to 'success' after 30s (real Midtrans/Xendit deferred to MVP)
 */
exports.requestWithdrawal = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    const driverId = context.auth.uid;
    const { amountIdr, destination } = data;
    if (!amountIdr || amountIdr < 20000) {
        throw new functions.https.HttpsError('invalid-argument', 'Minimum withdrawal is Rp 20.000');
    }
    if (!destination) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing destination account');
    }
    const driverRef = db.collection('users').doc(driverId);
    // Use a transaction for atomic balance debit
    const result = await db.runTransaction(async (txn) => {
        const driverDoc = await txn.get(driverRef);
        if (!driverDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Driver profile not found');
        }
        const driver = driverDoc.data();
        const balance = driver.balanceIdr || 0;
        // Check today's withdrawals for fee calculation
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const todayPayouts = await db.collection('payouts')
            .where('driverId', '==', driverId)
            .where('requestedAt', '>=', today) // JS Date works directly with Firestore
            .where('status', '!=', 'FAILED')
            .count()
            .get();
        const feeIdr = todayPayouts.data().count === 0 ? 0 : 1000;
        const netAmount = amountIdr - feeIdr;
        if (netAmount < 20000) {
            throw new functions.https.HttpsError('failed-precondition', `Net amount after fee (Rp ${feeIdr}) is below minimum (Rp 20.000)`);
        }
        if (balance < amountIdr) {
            throw new functions.https.HttpsError('failed-precondition', `Insufficient balance. Have: Rp ${balance.toLocaleString('id-ID')}, Need: Rp ${amountIdr.toLocaleString('id-ID')}`);
        }
        // Debit balance
        const newBalance = balance - amountIdr;
        txn.update(driverRef, { balanceIdr: newBalance });
        return { feeIdr, netAmount };
    });
    // Create payout record
    const payoutId = (0, helpers_1.generateId)();
    const payoutData = {
        driverId,
        amountIdr,
        feeIdr: result.feeIdr,
        destination,
        status: 'processing',
        idempotencyKey: `payout_${payoutId}`,
        requestedAt: (0, helpers_1.serverTimestamp)(),
    };
    await db.collection('payouts').doc(payoutId).set(payoutData);
    // STUB: auto-resolve after 30s (replaced by real Midtrans/Xendit in MVP)
    setTimeout(async () => {
        const success = Math.random() > 0.1; // 90% success rate
        await db.collection('payouts').doc(payoutId).update({
            status: success ? 'success' : 'failed',
            ...(success ? { paidAt: (0, helpers_1.serverTimestamp)() } : {
                failedAt: (0, helpers_1.serverTimestamp)(),
                failureReason: 'Gateway unavailable (simulated)',
            }),
        });
        // Refund on failure — in emulator, simpler direct update
        if (!success) {
            const driverDoc = await driverRef.get();
            const currentBal = driverDoc.data()?.balanceIdr || 0;
            await driverRef.update({ balanceIdr: currentBal + amountIdr });
        }
    }, 30_000);
    return {
        payoutId,
        amountIdr,
        feeIdr: result.feeIdr,
        netAmount: result.netAmount,
        status: 'processing',
    };
});
//# sourceMappingURL=requestWithdrawal.js.map