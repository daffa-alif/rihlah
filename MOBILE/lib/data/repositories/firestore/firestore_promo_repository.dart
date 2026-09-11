import '../../../core/services/firestore_service.dart';
import '../../models/promo_model.dart';
import '../interfaces/ipromo_repository.dart';

class FirestorePromoRepository implements IPromoRepository {
  final FirestoreService _svc = FirestoreService.instance;

  @override
  Stream<List<PromoModel>> getPromosStream({int limit = 200}) =>
      _svc.getPromosStream(limit: limit);

  @override
  Future<String> createPromo(PromoModel promo) => _svc.createPromo(promo);

  @override
  Future<void> updatePromo(String promoId, Map<String, dynamic> data) =>
      _svc.updatePromo(promoId, data);

  @override
  Future<void> deletePromo(String promoId) => _svc.deletePromo(promoId);
}
