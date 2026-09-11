import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/routing_service.dart';
import '../services/geocoding_service.dart';

// ── Trip booking state ────────────────────────────────────────────────────────

enum RihlahService { car, bike, send }

class TripBookingState {
  const TripBookingState({
    this.pickupLatLng,
    this.pickupName    = 'Lokasi saat ini',
    this.dropoffLatLng,
    this.dropoffName   = '',
    this.route         = RouteResult.empty,
    this.isLoadingRoute = false,
    this.service = RihlahService.car,
    this.appliedDiscount = 0,
    this.appliedVoucherCode,
    this.paymentMethod = 'cash',
    this.note,
  });

  final LatLng?     pickupLatLng;
  final String      pickupName;
  final LatLng?     dropoffLatLng;
  final String      dropoffName;
  final RouteResult route;
  final bool        isLoadingRoute;
  final RihlahService service;
  final int         appliedDiscount;
  final String?     appliedVoucherCode;
  /// 'cash' | 'qris' | 'gopay' | 'ovo' | 'dana' | 'shopee' — chosen for this
  /// specific trip, seeded from the Hive default but overridable per-ride.
  final String      paymentMethod;
  /// Optional note for the driver (e.g. "Tunggu di depan gerbang").
  final String?     note;

  bool get hasRoute =>
      route.points.isNotEmpty && route.distanceKm > 0;

  TripBookingState copyWith({
    LatLng?     pickupLatLng,
    String?     pickupName,
    LatLng?     dropoffLatLng,
    String?     dropoffName,
    RouteResult? route,
    bool?       isLoadingRoute,
    RihlahService? service,
    int?        appliedDiscount,
    String?     appliedVoucherCode,
    String?     paymentMethod,
    String?     note,
  }) => TripBookingState(
    pickupLatLng   : pickupLatLng   ?? this.pickupLatLng,
    pickupName     : pickupName     ?? this.pickupName,
    dropoffLatLng  : dropoffLatLng  ?? this.dropoffLatLng,
    dropoffName    : dropoffName    ?? this.dropoffName,
    route          : route          ?? this.route,
    isLoadingRoute : isLoadingRoute ?? this.isLoadingRoute,
    service        : service ?? this.service,
    appliedDiscount: appliedDiscount ?? this.appliedDiscount,
    appliedVoucherCode: appliedVoucherCode ?? this.appliedVoucherCode,
    paymentMethod  : paymentMethod  ?? this.paymentMethod,
    note           : note ?? this.note,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TripBookingNotifier extends StateNotifier<TripBookingState> {
  TripBookingNotifier() : super(const TripBookingState());

  void setPickup(LatLng latLng, String name) {
    state = state.copyWith(
      pickupLatLng : latLng,
      pickupName   : name,
    );
    _refreshRoute();
  }

  void setService(RihlahService s) {
    state = state.copyWith(service: s);
  }

  void setDropoff(PlaceResult place) {
    state = state.copyWith(
      dropoffLatLng : place.latLng,
      dropoffName   : place.name,
    );
    _refreshRoute();
  }

  void setDropoffRaw(LatLng latLng, String name) {
    state = state.copyWith(
      dropoffLatLng : latLng,
      dropoffName   : name,
    );
    _refreshRoute();
  }

  void setDiscount(int discount) {
    state = state.copyWith(appliedDiscount: discount);
  }

  void setVoucher(String? code, int discount) {
    // copyWith's null-coalescing can't distinguish "clear this field" from
    // "leave it unchanged" — construct the new state directly so removing a
    // voucher (code: null) actually clears appliedVoucherCode.
    state = TripBookingState(
      pickupLatLng      : state.pickupLatLng,
      pickupName        : state.pickupName,
      dropoffLatLng     : state.dropoffLatLng,
      dropoffName       : state.dropoffName,
      route             : state.route,
      isLoadingRoute    : state.isLoadingRoute,
      service           : state.service,
      appliedDiscount   : discount,
      appliedVoucherCode: code,
      paymentMethod     : state.paymentMethod,
      note              : state.note,
    );
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setNote(String? note) {
    state = state.copyWith(note: note);
  }

  Future<void> _refreshRoute() async {
    final from = state.pickupLatLng;
    final to   = state.dropoffLatLng;
    if (from == null || to == null) return;

    state = state.copyWith(isLoadingRoute: true);
    final route = await RoutingService.instance.getRoute(from, to,
          serviceType: state.service.name);
    state = state.copyWith(route: route, isLoadingRoute: false);
  }

  void clear() => state = const TripBookingState();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final tripBookingProvider =
    StateNotifierProvider<TripBookingNotifier, TripBookingState>(
  (ref) => TripBookingNotifier(),
);