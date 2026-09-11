import '../../models/payout_model.dart';
import '../interfaces/ipayout_repository.dart';
import 'api_client.dart';

/// MVP-era API-backed payout repository.
///
/// Calls the NestJS Payouts API instead of Firestore directly.
class ApiPayoutRepository implements IPayoutRepository {
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
    return Stream.periodic(const Duration(seconds: 10), (_) => driverId)
        .asyncMap((did) async {
          try {
            final path = did != null
                ? '/payouts/driver/$did'
                : '/payouts?limit=$limit';
            final data = await _api.getList(path);
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
          } catch (e) {
            // Silently fail — the UI shows the last known state
            return <PayoutModel>[];
          }
        });
  }
}
