import '../../models/payout_model.dart';

/// Abstract repository for payment and payout operations.
abstract class IPaymentRepository {
  // ── Payouts (D-S6 Daily Withdrawal) ──────────────────────────────────────

  /// Create a new payout request.
  Future<String> createPayout(PayoutModel payout);

  /// Update payout status.
  Future<void> updatePayoutStatus(
    String payoutId,
    PayoutStatus status, {
    bool setPaidAt = false,
  });

  /// Stream payouts, optionally filtered by driver.
  Stream<List<PayoutModel>> payoutsStream({String? driverId, int limit = 200});
}
