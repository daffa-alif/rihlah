import * as admin from 'firebase-admin';

admin.initializeApp();

// ── SRS §10.2.6 — 7 Cloud Functions ─────────────────────────────────────────

// 1. createBooking — passenger books a ride
export { createBooking } from './createBooking';

// 2. acceptOrder — driver accepts an incoming order
export { acceptOrder } from './acceptOrder';

// 3. onLocationWrite — RTDB trigger: mirrors driver GPS to passenger view
export { onLocationWrite } from './onLocationWrite';

// 4. completeTrip — driver ends trip, computes final fare
export { completeTrip } from './completeTrip';

// 5. requestWithdrawal — driver withdraws earnings
export { requestWithdrawal } from './requestWithdrawal';

// 6. cascadeOrderExpiry — 15s timeout → next driver
export { cascadeOrderExpiry } from './cascadeOrderExpiry';

// 7. sosTrigger — emergency SOS event
export { sosTrigger } from './sosTrigger';
