import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import '../../data/models/chat_message.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/payout_model.dart';
import '../../data/models/promo_model.dart';
import '../../data/models/saved_address.dart';
import '../../data/models/sos_event_model.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;
  final _rtdb = FirebaseDatabase.instance;

  // ── Users ─────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Restore the user's Firestore name from Firebase Auth if it was
  /// overwritten to the default by the old bug. Safe to call on every
  /// app start — only writes when correction is needed.
  Future<void> healUserName(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return;
      final currentName = doc.data()?['name'] as String?;
      if (currentName != null && currentName != 'Pengguna RIHLAH') return;
      final authName = FirebaseAuth.instance.currentUser?.displayName;
      if (authName != null && authName.isNotEmpty && authName != 'Pengguna RIHLAH') {
        await _users.doc(uid).update({'name': authName});
      }
    } catch (_) {
      // Non-fatal — name sync can be retried later
    }
  }

  Future<void> createUserProfile({
    required String uid,
    required String phone,
    String name = 'Pengguna RIHLAH',
    String role = '',
  }) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) {
      await healUserName(uid);
      return;
    }

    final data = <String, dynamic>{
      'uid': uid,
      'phone': phone,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (role.isNotEmpty) data['role'] = role;
    await _users.doc(uid).set(data);
  }

  Future<void> setUserRole(String uid, String role) async {
    await _users.doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserName(String uid, String name) async {
    await _users.doc(uid).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> userStream(String uid) => _users.doc(uid).snapshots().map(
      (doc) => doc.exists ? UserModel.fromFirestore(doc) : null);

  /// Driver KYC/vehicle/BPJS fields (D-A2) — merged onto the shared
  /// `users/{uid}` doc so it stays consistent with the rest of the profile.
  Future<void> updateDriverProfile(
    String uid, {
    String? vehicleType,
    String? plate,
    String? ktpNumberMasked,
    String? bpjsKt,
    String? bpjsKs,
    String? bpjsInsurance,
  }) async {
    await _users.doc(uid).set({
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (plate != null) 'plate': plate,
      if (ktpNumberMasked != null) 'ktpNumberMasked': ktpNumberMasked,
      if (bpjsKt != null) 'bpjsKt': bpjsKt,
      if (bpjsKs != null) 'bpjsKs': bpjsKs,
      if (bpjsInsurance != null) 'bpjsInsurance': bpjsInsurance,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setAccountStatus(String uid, String status) async {
    await _users.doc(uid).update({
      'accountStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin console — list users by role, most-recent first. Bounded to
  /// [limit] and unindexed (single-field `role` filter only) so it works
  /// without any Firebase Console composite-index setup, same pattern as
  /// [pendingTripsStream].
  Stream<List<UserModel>> usersStream({String? role, int limit = 200}) {
    Query<Map<String, dynamic>> q = _users;
    if (role != null) q = q.where('role', isEqualTo: role);
    return q.limit(limit).snapshots().map(
        (snap) => snap.docs.map(UserModel.fromFirestore).toList());
  }

  // ── Saved addresses (subcollection of users/{uid}) ──────────────────────

  CollectionReference<Map<String, dynamic>> _addresses(String uid) =>
      _users.doc(uid).collection('addresses');

  Stream<List<SavedAddress>> addressesStream(String uid) =>
      _addresses(uid).snapshots().map((snap) => snap.docs
          .map((doc) => SavedAddress.fromMap(doc.data()))
          .toList());

  Future<void> addAddress(String uid, SavedAddress address) async {
    await _addresses(uid).doc(address.id).set(address.toMap());
  }

  Future<void> updateAddress(String uid, SavedAddress address) async {
    await _addresses(uid).doc(address.id).set(address.toMap());
  }

  Future<void> removeAddress(String uid, String addressId) async {
    await _addresses(uid).doc(addressId).delete();
  }

  // ── Trips ─────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _trips =>
      _db.collection('trips');

  Future<String> createTrip(Map<String, dynamic> data) async {
    final ref = await _trips.add(data);
    return ref.id;
  }

  Stream<TripModel?> tripStream(String tripId) =>
      _trips.doc(tripId).snapshots().map((doc) {
        if (!doc.exists) return null;
        return TripModel.fromFirestore(doc);
      });

  Future<TripModel?> getTrip(String tripId) async {
    final doc = await _trips.doc(tripId).get();
    if (!doc.exists) return null;
    return TripModel.fromFirestore(doc);
  }

  // Driver picks up a searching trip
  Future<void> acceptTrip({
    required String tripId,
    required String driverId,
  }) async {
    await _trips.doc(tripId).update({
      'driverId': driverId,
      'status': TripStatus.accepted.name,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTripStatus(String tripId, TripStatus status) async {
    await _trips.doc(tripId).update({'status': status.name});
  }

  Future<void> setTripArrived(String tripId) async =>
      _trips.doc(tripId).update({'status': 'arrived'});

  Future<void> setTripInTrip(String tripId) async =>
      _trips.doc(tripId).update({'status': 'inTrip'});

  Future<void> cancelTrip(String tripId, {
    String? cancelledBy,
    int? cancellationFee,
  }) async {
    final data = <String, dynamic>{
      'status': TripStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    };
    if (cancelledBy != null) data['cancelledBy'] = cancelledBy;
    if (cancellationFee != null) data['cancellationFee'] = cancellationFee;
    await _trips.doc(tripId).update(data);
  }

  /// Complete a trip — updates trip status, then driver balance.
  /// Idempotent: if the trip is already completed the balance is NOT credited
  /// again, preventing double-payment when both driver and passenger call this.
  Future<void> completeTrip(String tripId) async {
    final tripRef = _trips.doc(tripId);

    // 1. Read current trip to get driverId, earnings, and current status
    final tripSnap = await tripRef.get();
    if (!tripSnap.exists) return;
    final trip = tripSnap.data()!;

    // Guard: if the trip is already completed, don't credit the driver again.
    // Only the first caller (normally the driver) triggers the balance update.
    final currentStatus = trip['status'] as String?;
    if (currentStatus == TripStatus.completed.name) return;

    final driverId = trip['driverId'] as String?;
    final driverEarns = (trip['driverEarns'] as num?)?.toInt() ?? 0;

    // 2. Update trip status
    await tripRef.update({
      'status': TripStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
    });

    // 3. Atomically increment driver balance + trip count (if driver assigned)
    if (driverId != null) {
      final driverRef = _users.doc(driverId);
      await driverRef.update({
        'balanceIdr': FieldValue.increment(driverEarns),
        'totalTrips': FieldValue.increment(1),
      });
    }
  }

  // Driver declines an offer without changing its status, so other drivers
  // can still be offered it. `pendingTripsStream` excludes it for this
  // driver going forward, so they don't get re-served the same trip.
  Future<void> skipTrip(String tripId, String driverId) async {
    await _trips.doc(tripId).update({
      'skippedBy': FieldValue.arrayUnion([driverId]),
    });
  }

  Future<void> rateTrip({
    required String tripId,
    required int rating,
    required int tip,
    required String review,
  }) async {
    await _trips.doc(tripId).update({
      'passengerRating': rating,
      'passengerTip': tip,
      'passengerReview': review,
    });
    // Recompute the driver's average rating from all completed trips
    final trip = await _trips.doc(tripId).get();
    final driverId = trip.data()?['driverId'] as String?;
    if (driverId != null) await _updateDriverRatingAvg(driverId);
  }

  /// Queries all completed trips for [driverId], computes the average
  /// passenger rating, and writes it to `users/{driverId}.ratingAvg`.
  Future<void> _updateDriverRatingAvg(String driverId) async {
    final snap = await _trips
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .where('passengerRating', isGreaterThan: 0)
        .limit(200)
        .get();
    if (snap.docs.isEmpty) return;
    double sum = 0;
    int count = 0;
    for (final doc in snap.docs) {
      final r = (doc.data()['passengerRating'] as num?)?.toInt();
      if (r != null && r > 0) {
        sum += r;
        count++;
      }
    }
    if (count == 0) return;
    final avg = (sum / count * 100).round() / 100; // 2 decimal places
    await _users.doc(driverId).update({'ratingAvg': avg});
  }

  /// Returns driver IDs that this passenger previously rated 1 star.
  /// SRS P-S6: "Passenger cannot book the same driver again if they last
  /// rated 1 star (auto-prefer different driver)."
  Future<List<String>> getOneStarDriverIds(String passengerId) async {
    final snap = await _trips
        .where('passengerId', isEqualTo: passengerId)
        .where('passengerRating', isEqualTo: 1)
        .where('status', isEqualTo: 'completed')
        .limit(50)
        .get();
    final driverIds = <String>{};
    for (final doc in snap.docs) {
      final d = doc.data()['driverId'] as String?;
      if (d != null) driverIds.add(d);
    }
    return driverIds.toList();
  }

  // Query for pending trips a driver can accept.
  // Only filters on `status` in Firestore (uses the auto-created single-field
  // index — no composite index required). serviceType is filtered client-side
  // so this works out of the box without any Firebase Console index setup.
  //
  // 'car' orders only go to car drivers, 'bike' orders only go to bike
  // drivers — but 'send' (package delivery) orders go to BOTH, since either
  // vehicle can carry a package.
  Stream<List<TripModel>> pendingTripsStream(
    String serviceType, {
    required String driverId,
  }) {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(minutes: 15)),
    );
    return _trips
        .where('status', isEqualTo: TripStatus.searching.name)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map(TripModel.fromFirestore)
            .where((t) => t.serviceType == serviceType || t.serviceType == 'send')
            .where((t) =>
                t.createdAt == null || t.createdAt!.compareTo(cutoff) >= 0)
            .where((t) => !t.skippedBy.contains(driverId))
            .toList()
            ..sort((a, b) {
              // null createdAt = just created; treat as newest so it sorts first
              final aTs = a.createdAt?.seconds ?? 9999999999;
              final bTs = b.createdAt?.seconds ?? 9999999999;
              return bTs.compareTo(aTs);
            }));
  }

  /// Admin console — a single driver's trip history, most-recent first.
  /// Single-field `driverId` filter only (sorted client-side) so this works
  /// without a Firebase Console composite-index setup.
  Stream<List<TripModel>> driverTripsStream(String driverId, {int limit = 200}) {
    return _trips
        .where('driverId', isEqualTo: driverId)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final trips = snap.docs.map(TripModel.fromFirestore).toList();
      trips.sort((a, b) {
        final aTs = a.createdAt?.seconds ?? 0;
        final bTs = b.createdAt?.seconds ?? 0;
        return bTs.compareTo(aTs);
      });
      return trips;
    });
  }

  /// A single passenger's trip history, most-recent first. Same unindexed
  /// pattern as [driverTripsStream] — single-field filter, sorted client-side.
  Stream<List<TripModel>> passengerTripsStream(String passengerId,
      {int limit = 200}) {
    return _trips
        .where('passengerId', isEqualTo: passengerId)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final trips = snap.docs.map(TripModel.fromFirestore).toList();
      trips.sort((a, b) {
        final aTs = a.createdAt?.seconds ?? 0;
        final bTs = b.createdAt?.seconds ?? 0;
        return bTs.compareTo(aTs);
      });
      return trips;
    });
  }

  /// Admin console — most-recent trips, optionally filtered by status.
  /// Bounded + single-field filter, same unindexed pattern as
  /// [pendingTripsStream] / [usersStream].
  Stream<List<TripModel>> allTripsStream({TripStatus? status, int limit = 200}) {
    // `status` is filtered client-side rather than chained onto the
    // `.orderBy('createdAt')` query — an equality filter combined with an
    // orderBy on a different field needs a composite index, which this
    // app avoids requiring (same reasoning as pendingTripsStream).
    return _trips
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final trips = snap.docs.map(TripModel.fromFirestore).toList();
      return status == null
          ? trips
          : trips.where((t) => t.status == status).toList();
    });
  }

  // ── Trip chat ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _tripMessages(String tripId) =>
      _trips.doc(tripId).collection('messages');

  Stream<List<ChatMessage>> tripMessagesStream(String tripId) =>
      _tripMessages(tripId)
          .snapshots()
          .map((snap) {
            final msgs = snap.docs.map(ChatMessage.fromFirestore).toList();
            // Client-side sort (no composite index required — follows the
            // same unindexed pattern as pendingTripsStream / allTripsStream).
            msgs.sort((a, b) {
              final aTs = a.sentAt?.seconds ?? 0;
              final bTs = b.sentAt?.seconds ?? 0;
              return aTs.compareTo(bTs);
            });
            return msgs;
          });

  Future<void> sendTripMessage({
    required String tripId,
    required String senderId,
    required String text,
  }) async {
    await _tripMessages(tripId).add({
      'senderId': senderId,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Driver GPS via Realtime Database ─────────────────────────────────────

  DatabaseReference _driverLocRef(String driverId) =>
      _rtdb.ref('driver_locations/$driverId');

  Future<void> updateDriverLocation({
    required String driverId,
    required double lat,
    required double lng,
    String? tripId,
    double? headingDeg,
  }) async {
    await _driverLocRef(driverId).set({
      'lat': lat,
      'lng': lng,
      if (tripId != null) 'tripId': tripId,
      if (headingDeg != null) 'heading': headingDeg,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Stream<Map<String, dynamic>?> driverLocationStream(String driverId) =>
      _driverLocRef(driverId).onValue.map((event) {
        final data = event.snapshot.value;
        if (data == null) return null;
        return Map<String, dynamic>.from(data as Map);
      });

  Future<Map<String, dynamic>?> getDriverLocation(String driverId) async {
    final snap = await _driverLocRef(driverId).get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<void> clearDriverLocation(String driverId) async {
    await _driverLocRef(driverId).remove();
  }

  /// Admin dashboard KPI — count of drivers currently broadcasting a
  /// position (i.e. online right now), read once from RTDB presence data.
  Future<int> onlineDriversCount() async {
    final snap = await _rtdb.ref('driver_locations').get();
    if (!snap.exists || snap.value == null) return 0;
    return Map<String, dynamic>.from(snap.value as Map).length;
  }

  // ── Payouts (D-S6 Daily Withdrawal) ──────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _payouts =>
      _db.collection('payouts');

  Future<String> createPayout(PayoutModel payout) async {
    final ref = await _payouts.add(payout.toMap());
    return ref.id;
  }

  Future<void> updatePayoutStatus(
    String payoutId,
    PayoutStatus status, {
    bool setPaidAt = false,
  }) async {
    await _payouts.doc(payoutId).update({
      'status': status.name,
      if (setPaidAt) 'paidAt': FieldValue.serverTimestamp(),
    });
  }

  /// `driverId` is filtered client-side (see [allTripsStream] for why) so
  /// this never needs a composite index.
  Stream<List<PayoutModel>> payoutsStream({String? driverId, int limit = 200}) {
    return _payouts
        .orderBy('requestedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final payouts = snap.docs.map(PayoutModel.fromFirestore).toList();
      return driverId == null
          ? payouts
          : payouts.where((p) => p.driverId == driverId).toList();
    });
  }

  // ── SOS events (P-S7 / D-S8) ─────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _sosEvents =>
      _db.collection('sos_events');

  Future<String> createSosEvent(SosEventModel event) async {
    final ref = await _sosEvents.add(event.toMap());
    return ref.id;
  }

  Future<void> updateSosEventStatus(String eventId, String status) async {
    await _sosEvents.doc(eventId).update({'status': status});
  }

  Stream<List<SosEventModel>> sosEventsStream({int limit = 200}) =>
      _sosEvents
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(SosEventModel.fromFirestore).toList());

  // ── Promos ────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _promos =>
      _db.collection('promos');

  /// Bounded + client-sorted, same unindexed pattern as [allTripsStream].
  Stream<List<PromoModel>> getPromosStream({int limit = 200}) {
    return _promos
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(PromoModel.fromFirestore).toList());
  }

  Future<String> createPromo(PromoModel promo) async {
    final ref = await _promos.add(promo.toMap());
    return ref.id;
  }

  Future<void> updatePromo(String promoId, Map<String, dynamic> data) async {
    await _promos.doc(promoId).update(data);
  }

  Future<void> deletePromo(String promoId) async {
    await _promos.doc(promoId).delete();
  }

  // ── Helper: current user's UID ────────────────────────────────────────────

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  // --- FUNGSI BARU UNTUK SOS MVP ---
  Future<void> reportSosEvent({
    required String userId,
    required String role,
    String? tripId,
    double? lat,
    double? lng,
  }) async {
    try {
      // Pastikan kamu sudah meng-import 'package:cloud_firestore/cloud_firestore.dart'; di bagian atas file
      final db = FirebaseFirestore.instance;

      await db.collection('sos_events').add({
        'userId': userId,
        'role': role,
        'tripId': tripId,
        // Menyimpan koordinat menggunakan tipe data GeoPoint bawaan Firebase
        'location': (lat != null && lng != null) ? GeoPoint(lat, lng) : null,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active', // Status 'active' agar langsung muncul di dasbor Admin
      });
    } catch (e) {
      // Melempar error ke UI agar bisa ditangkap oleh blok catch di sos_screen.dart
      throw Exception('Gagal menulis data SOS ke server: $e');
    }
  }
}
