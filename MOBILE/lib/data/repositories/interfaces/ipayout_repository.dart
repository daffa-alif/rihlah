import '../../models/payout_model.dart';

/// Abstract repository for payout (driver withdrawal) operations.
/// Kept separate from IPaymentRepository for single-responsibility clarity.
abstract class IPayoutRepository {
  /// Create a new payout request.
  Future<String> createPayout(PayoutModel payout);

  /// Update payout status (called by driver app simulation or admin console).
  Future<void> updatePayoutStatus(
    String payoutId,
    PayoutStatus status, {
    bool setPaidAt = false,
  });

  /// Stream payouts, optionally filtered by driver.
  Stream<List<PayoutModel>> payoutsStream({String? driverId, int limit = 200});
}
