import '../../../core/services/firestore_service.dart';
import '../../models/payout_model.dart';
import '../interfaces/ipayment_repository.dart';

/// P2-era Firestore implementation. Delegates to FirestoreService.
/// Will be replaced by ApiPaymentRepository when the backend is ready.
class FirestorePaymentRepository implements IPaymentRepository {
  final FirestoreService _svc = FirestoreService.instance;

  @override
  Future<String> createPayout(PayoutModel payout) => _svc.createPayout(payout);

  @override
  Future<void> updatePayoutStatus(
    String payoutId,
    PayoutStatus status, {
    bool setPaidAt = false,
  }) => _svc.updatePayoutStatus(payoutId, status, setPaidAt: setPaidAt);

  @override
  Stream<List<PayoutModel>> payoutsStream({String? driverId, int limit = 200}) =>
      _svc.payoutsStream(driverId: driverId, limit: limit);
}
