import '../../models/payout_model.dart';
import '../interfaces/ipayment_repository.dart';
import 'api_client.dart';

/// MVP-era API-backed payment repository.
///
/// Calls the NestJS Payments API instead of Firestore directly.
/// Swap this in via --dart-define=USE_API=true.
class ApiPaymentRepository implements IPaymentRepository {
  final ApiClient _api = ApiClient.instance;

  @override
  Future<String> createPayout(PayoutModel payout) async {
    final response = await _api.post('/payouts', {
      'driverId': payout.driverId,
      'amountIdr': payout.amountIdr,
      'destination': payout.destination,
    });
    return response['id'] as String? ?? '';
  }

  @override
  Future<void> updatePayoutStatus(
    String payoutId,
    PayoutStatus status, {
    bool setPaidAt = false,
  }) async {
    if (status == PayoutStatus.success) {
      await _api.patch('/payouts/$payoutId/settle', {});
    } else if (status == PayoutStatus.failed) {
      await _api.patch('/payouts/$payoutId/fail', {});
    }
  }

  @override
  Stream<List<PayoutModel>> payoutsStream({String? driverId, int limit = 200}) {
    // API-backed stream: poll every 10 seconds
    return Stream.periodic(const Duration(seconds: 10), (_) => driverId)
        .asyncMap((did) async {
          if (did == null) {
            final data = await _api.getList('/payouts?limit=$limit');
            return _parseList(data);
          }
          final data = await _api.getList('/payouts/driver/$did');
          return _parseList(data);
        });
  }

  List<PayoutModel> _parseList(List<dynamic> data) {
    return data.map((json) {
      final m = json as Map<String, dynamic>;
      return PayoutModel(
        payoutId: m['id'] as String? ?? '',
        driverId: m['driverId'] as String? ?? '',
        amountIdr: (m['amountIdr'] as num?)?.toInt() ?? 0,
        destination: m['destination'] as String? ?? '',
        status: PayoutStatus.fromString(
          (m['status'] as String?)?.toLowerCase() ?? 'processing',
        ),
      );
    }).toList();
  }
}
