import '../../../core/services/firestore_service.dart';
import '../../models/payout_model.dart';
import '../interfaces/ipayout_repository.dart';

class FirestorePayoutRepository implements IPayoutRepository {
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
