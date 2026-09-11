import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { generateId, serverTimestamp } from './helpers';

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
export const requestWithdrawal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const driverId = context.auth.uid;
  const { amountIdr, destination } = data;

  if (!amountIdr || amountIdr < 20000) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Minimum withdrawal is Rp 20.000',
    );
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

    const driver = driverDoc.data()!;
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
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Net amount after fee (Rp ${feeIdr}) is below minimum (Rp 20.000)`,
      );
    }

    if (balance < amountIdr) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient balance. Have: Rp ${balance.toLocaleString('id-ID')}, Need: Rp ${amountIdr.toLocaleString('id-ID')}`,
      );
    }

    // Debit balance
    const newBalance = balance - amountIdr;
    txn.update(driverRef, { balanceIdr: newBalance });

    return { feeIdr, netAmount };
  });

  // Create payout record
  const payoutId = generateId();
  const payoutData = {
    driverId,
    amountIdr,
    feeIdr: result.feeIdr,
    destination,
    status: 'processing',
    idempotencyKey: `payout_${payoutId}`,
    requestedAt: serverTimestamp(),
  };

  await db.collection('payouts').doc(payoutId).set(payoutData);

  // STUB: auto-resolve after 30s (replaced by real Midtrans/Xendit in MVP)
  setTimeout(async () => {
    const success = Math.random() > 0.1; // 90% success rate
    await db.collection('payouts').doc(payoutId).update({
      status: success ? 'success' : 'failed',
      ...(success ? { paidAt: serverTimestamp() } : {
        failedAt: serverTimestamp(),
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
