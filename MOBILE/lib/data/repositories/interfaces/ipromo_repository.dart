import '../../models/promo_model.dart';

/// Abstract repository for promo codes.
abstract class IPromoRepository {
  /// Stream active promo codes from Firestore.
  Stream<List<PromoModel>> getPromosStream({int limit = 200});

  /// Admin: create a new promo code.
  Future<String> createPromo(PromoModel promo);

  /// Admin: update a promo code.
  Future<void> updatePromo(String promoId, Map<String, dynamic> data);

  /// Admin: delete a promo code.
  Future<void> deletePromo(String promoId);
}
