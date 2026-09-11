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
exports.sosTrigger = exports.cascadeOrderExpiry = exports.requestWithdrawal = exports.completeTrip = exports.onLocationWrite = exports.acceptOrder = exports.createBooking = void 0;
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
// ── SRS §10.2.6 — 7 Cloud Functions ─────────────────────────────────────────
// 1. createBooking — passenger books a ride
var createBooking_1 = require("./createBooking");
Object.defineProperty(exports, "createBooking", { enumerable: true, get: function () { return createBooking_1.createBooking; } });
// 2. acceptOrder — driver accepts an incoming order
var acceptOrder_1 = require("./acceptOrder");
Object.defineProperty(exports, "acceptOrder", { enumerable: true, get: function () { return acceptOrder_1.acceptOrder; } });
// 3. onLocationWrite — RTDB trigger: mirrors driver GPS to passenger view
var onLocationWrite_1 = require("./onLocationWrite");
Object.defineProperty(exports, "onLocationWrite", { enumerable: true, get: function () { return onLocationWrite_1.onLocationWrite; } });
// 4. completeTrip — driver ends trip, computes final fare
var completeTrip_1 = require("./completeTrip");
Object.defineProperty(exports, "completeTrip", { enumerable: true, get: function () { return completeTrip_1.completeTrip; } });
// 5. requestWithdrawal — driver withdraws earnings
var requestWithdrawal_1 = require("./requestWithdrawal");
Object.defineProperty(exports, "requestWithdrawal", { enumerable: true, get: function () { return requestWithdrawal_1.requestWithdrawal; } });
// 6. cascadeOrderExpiry — 15s timeout → next driver
var cascadeOrderExpiry_1 = require("./cascadeOrderExpiry");
Object.defineProperty(exports, "cascadeOrderExpiry", { enumerable: true, get: function () { return cascadeOrderExpiry_1.cascadeOrderExpiry; } });
// 7. sosTrigger — emergency SOS event
var sosTrigger_1 = require("./sosTrigger");
Object.defineProperty(exports, "sosTrigger", { enumerable: true, get: function () { return sosTrigger_1.sosTrigger; } });
//# sourceMappingURL=index.js.map