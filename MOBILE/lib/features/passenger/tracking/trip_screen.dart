import 'dart:async';
import 'dart:math' show pi;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/core.dart';
import '../../../core/providers/trip_booking_provider.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/call_screen.dart';
import '../../../core/widgets/trip_chat_sheet.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/trip_model.dart' hide TripStatus;
import '../../../core/services/routing_service.dart';
import '../../../core/utils/fare_calculator.dart';
import '../../../core/utils/gps_fix_filter.dart';
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const _kDistance = Distance();
const _pickupFallback  = LatLng(-6.8750, 107.6175);
const _dropoffFallback = LatLng(-6.9200, 107.6070);

LatLng _driverStartNear(LatLng pickup) =>
    LatLng(pickup.latitude - 0.006, pickup.longitude + 0.005);

enum _TripState { loading, accepted, arriving, arrived, inTrip }

class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  bool _userPanned = false;

  List<LatLng> _approachPath = [];
  List<LatLng> _routePath    = [];

  _TripState _state               = _TripState.loading;
  int        _etaSeconds          = 180;
  int        _arrivedGraceSeconds = 300;
  int        _subtitleIndex       = 0;

  late final ValueNotifier<LatLng> _driverPosNotifier;
  late final ValueNotifier<double> _driverHeadingNotifier;

  late AnimationController _approachCtrl;
  late AnimationController _inTripCtrl;

  Timer? _arrivedGraceTimer;
  Timer? _subtitleTimer;
  Timer? _gpsPollTimer;
  Timer? _tripPollTimer;

  AnimationController? _gpsSmooth;
  LatLng _gpsSmoothFrom = _pickupFallback;
  LatLng _gpsSmoothTo   = _pickupFallback;
  double _smoothHeadingTo = 0.0;

  bool _usingRealGps     = false;
  bool _connectionLost   = false;
  DateTime? _lastSmoothFixAt;
  final _gpsFilter = GpsFixFilter();

  bool  _approachRouteIsReal    = false;
  bool  _isRecalculatingApproach = false;
  Timer? _approachRecalcCooldown;

  bool  _isRecalculatingRoute = false;
  Timer? _routeRecalcCooldown;

  StreamSubscription? _firestoreTripSub;
  StreamSubscription? _rtdbGpsSub;
  String? _driverId;

  TripModel? _realTrip;
  String     _driverName  = 'Budi Santoso';
  String     _vehiclePlate = 'B 1234 XYZ';
  String     _vehicleDesc  = 'Honda Vario • Hitam';

  StreamSubscription<List<ChatMessage>>? _chatNotifySub;
  int  _lastMsgCount = -1;
  bool _chatOpen     = false;

  StreamSubscription<Map<String, dynamic>?>? _incomingCallSub;
  String? _handledCallId;

  @override
  void initState() {
    super.initState();
    final trip   = ref.read(tripBookingProvider);
    final pickup = trip.pickupLatLng ?? _pickupFallback;

    _driverPosNotifier = ValueNotifier<LatLng>(_driverStartNear(pickup));
    _driverHeadingNotifier = ValueNotifier<double>(0.0);

    _startSubtitleRotation();
    _startGpsPoll();
    _startFirebaseListeners();
    _startChatNotifyListener();
    _startIncomingCallListener();
    _loadRoutes();
  }

  void _startIncomingCallListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _incomingCallSub = CallService.instance
        .watchIncomingCall(tripId: widget.tripId, myUid: uid)
        .listen((call) async {
      if (!mounted || call == null) return;
      final callId = call['callId'] as String;
      if (_handledCallId == callId) return;
      _handledCallId = callId;

      final callerId = call['callerId'] as String;
      await NotificationService.instance.showIncomingCall(
        tripId    : widget.tripId,
        callerName: _driverName,
      );

      final session = await CallSession.forIncoming(
        tripId  : widget.tripId,
        callId  : callId,
        myUid   : uid,
        otherUid: callerId,
      );
      if (!mounted) return;
      await NotificationService.instance.cancelIncomingCall(widget.tripId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          session   : session,
          otherName : _driverName,
          isIncoming: true,
        ),
      ));
    }, onError: (_) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _startIncomingCallListener();
      });
    });
  }

  void _startChatNotifyListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _chatNotifySub = FirestoreService.instance
        .tripMessagesStream(widget.tripId)
        .listen((messages) {
      if (!mounted) return;
      if (_lastMsgCount == -1) {
        _lastMsgCount = messages.length;
        return;
      }
      if (messages.length > _lastMsgCount) {
        final fresh = messages.sublist(_lastMsgCount);
        _lastMsgCount = messages.length;
        if (_chatOpen) return;
        for (final m in fresh) {
          if (m.senderId == uid) continue;
          NotificationService.instance.showNewMessage(
            tripId    : widget.tripId,
            senderName: _driverName,
            text      : m.text,
          );
        }
      } else {
        _lastMsgCount = messages.length;
      }
    }, onError: (_) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _startChatNotifyListener();
      });
    });
  }

  Future<void> _loadRoutes() async {
    final booking = ref.read(tripBookingProvider);
    LatLng pickup  = booking.pickupLatLng  ?? _pickupFallback;
    LatLng dropoff = booking.dropoffLatLng ?? _dropoffFallback;

    if (booking.pickupLatLng == null || booking.dropoffLatLng == null) {
      final ft = await FirestoreService.instance.getTrip(widget.tripId);
      if (ft != null) {
        pickup  = LatLng(ft.pickupLat,  ft.pickupLng);
        dropoff = LatLng(ft.dropoffLat, ft.dropoffLng);
        if (mounted) setState(() => _realTrip = ft);
      }
    }

    final driverStart = _driverStartNear(pickup);
    final approachResult = await RoutingService.instance.getRoute(driverStart, pickup, serviceType: booking.service.name);

    List<LatLng> tripPoints = booking.route.points;
    if (tripPoints.length < 2) {
      final tripResult = await RoutingService.instance.getRoute(pickup, dropoff, serviceType: booking.service.name);
      tripPoints = tripResult.points;
    }

    _approachPath = approachResult.points.length >= 2 ? approachResult.points : _straightPath(driverStart, pickup, 8);
    _routePath = tripPoints.length >= 2 ? tripPoints : _straightPath(pickup, dropoff, 8);

    if (!mounted) return;
    _driverPosNotifier.value = _approachPath.first;
    _initApproachAnimation();
    _initInTripAnimation();
    setState(() => _state = _TripState.accepted);
  }

  List<LatLng> _straightPath(LatLng a, LatLng b, int steps) =>
      List.generate(steps, (i) {
        final t = i / (steps - 1);
        return LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
      });

  Duration get _approachSegMs => const Duration(milliseconds: 2500);
  Duration get _inTripSegMs => const Duration(milliseconds: 3500);

  void _initApproachAnimation() {
    _approachCtrl = AnimationController(vsync: this, duration: _approachSegMs);
  }

  void _initInTripAnimation() {
    _inTripCtrl = AnimationController(vsync: this, duration: _inTripSegMs);
  }

  void _startFirebaseListeners() {
    _subscribeTripStream();
    _startTripPoll();
  }

  void _subscribeTripStream() {
    _firestoreTripSub?.cancel();
    _firestoreTripSub = FirestoreService.instance.tripStream(widget.tripId).listen(
      _handleTripUpdate,
      onError: (_) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _subscribeTripStream();
        });
      },
    );
  }

  void _startTripPoll() {
    _tripPollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!mounted) return;
      final trip = await FirestoreService.instance.getTrip(widget.tripId);
      if (trip != null && mounted) _handleTripUpdate(trip);
    });
  }

  void _handleTripUpdate(TripModel? trip) {
    if (!mounted || trip == null) return;
    setState(() => _realTrip = trip);

    if (trip.driverId != null && _driverId == null) {
      _driverId = trip.driverId;
      _startRtdbGpsListener(_driverId!);
      _loadDriverInfo(_driverId!);
    }

    if (trip.status.name == 'completed') {
      _cleanupTimers();
      if (mounted) context.go(Routes.pTripComplete(widget.tripId));
      return;
    }

    if (trip.status.name == 'arrived' && _state != _TripState.arrived && _state != _TripState.inTrip) {
      try { _approachCtrl.stop(); } catch (_) {}
      setState(() { _state = _TripState.arrived; _etaSeconds = 0; });
      _startArrivedGrace();
      return;
    }

    if (trip.status.name == 'inTrip' && _state != _TripState.inTrip) {
      _startInTrip();
      return;
    }
  }

  Future<void> _loadDriverInfo(String driverId) async {
    final user = await FirestoreService.instance.getUser(driverId);
    if (mounted && user != null && user.name.isNotEmpty && user.name != 'Pengguna RIHLAH') {
      setState(() {
        _driverName = user.name;
        // Perbaikan null safety di sini:
        if (user.plate != null && user.plate!.isNotEmpty) {
          _vehiclePlate = user.plate!;
        }
      });
    }
  }

  void _startRtdbGpsListener(String driverId) {
    _rtdbGpsSub?.cancel();
    _rtdbGpsSub = FirestoreService.instance.driverLocationStream(driverId).listen(
          (data) {
        if (!mounted || data == null) return;
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        final ts  = (data['updatedAt'] as num?)?.toInt() ?? 0;
        final heading = (data['headingDeg'] as num?)?.toDouble();

        if (lat == null || lng == null) return;

        final ageSeconds = ts > 0 ? (DateTime.now().millisecondsSinceEpoch - ts) / 1000 : 0.0;
        if (ageSeconds > 60) {
          if (!_connectionLost) setState(() => _connectionLost = true);
          return;
        }
        if (_connectionLost) setState(() => _connectionLost = false);

        _handleRealGpsFix(LatLng(lat, lng), (heading ?? 0.0) * (pi / 180));
      },
      onError: (_) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _driverId != null) _startRtdbGpsListener(driverId);
        });
      },
    );
  }

  void _startGpsPoll() {
    _gpsPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      String? driverId = _driverId;
      if (driverId == null) {
        try {
          final trip = await FirestoreService.instance.getTrip(widget.tripId);
          if (trip?.driverId != null) {
            driverId = trip!.driverId;
            if (mounted) {
              _driverId = driverId;
              _startRtdbGpsListener(driverId!);
              _loadDriverInfo(driverId!);
            }
          }
        } catch (_) {}
      }
      if (driverId == null) return;

      try {
        final data = await FirestoreService.instance.getDriverLocation(driverId);
        if (!mounted || data == null) return;
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        final heading = (data['headingDeg'] as num?)?.toDouble();

        if (lat == null || lng == null) return;
        _handleRealGpsFix(LatLng(lat, lng), (heading ?? 0.0) * (pi / 180));
      } catch (_) {}
    });
  }

  void _handleRealGpsFix(LatLng rawPos, double headingRad) {
    final accepted = _gpsFilter.filter(rawPos);
    if (accepted == null) return;

    if (!_usingRealGps) {
      setState(() => _usingRealGps = true);
      try { _approachCtrl.stop(); } catch (_) {}
      try { _inTripCtrl.stop(); } catch (_) {}

      _driverPosNotifier.value = rawPos;
      _driverHeadingNotifier.value = headingRad;
      _centerMap(rawPos);
      _recalcEta();
      return;
    }

    _smoothDriverMoveTo(_snapDriverToRoute(rawPos), headingRad);
    _recalcEta();
  }

  void _recalcEta() {
    final path = _state == _TripState.inTrip ? _routePath : _approachPath;
    if (path.length < 2) return;

    final gpsPos = _driverPosNotifier.value;
    int closestIdx = 0;
    double minDist = double.infinity;

    for (int i = 0; i < path.length; i++) {
      final d = _kDistance.as(LengthUnit.Meter, gpsPos, path[i]);
      if (d < minDist) { minDist = d; closestIdx = i; }
    }

    double remainingMeters = 0;
    for (int i = closestIdx; i < path.length - 1; i++) {
      remainingMeters += _kDistance.as(LengthUnit.Meter, path[i], path[i + 1]);
    }

    const speedMs = 25.0 * 1000 / 3600;
    final seconds = (remainingMeters / speedMs).round();

    if (mounted) {
      setState(() => _etaSeconds = seconds.clamp(0, 9999));
    }
  }

  void _startSubtitleRotation() {
    _subtitleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _subtitleIndex = (_subtitleIndex + 1) % 3);
    });
  }

  @override
  void dispose() {
    _cleanupTimers();
    super.dispose();
  }

  void _cleanupTimers() {
    _gpsSmooth?.dispose();
    try { _approachCtrl.dispose(); } catch (_) {}
    try { _inTripCtrl.dispose(); } catch (_) {}
    _driverPosNotifier.dispose();
    _driverHeadingNotifier.dispose();
    _arrivedGraceTimer?.cancel();
    _subtitleTimer?.cancel();
    _gpsPollTimer?.cancel();
    _tripPollTimer?.cancel();
    _approachRecalcCooldown?.cancel();
    _routeRecalcCooldown?.cancel();
    _firestoreTripSub?.cancel();
    _rtdbGpsSub?.cancel();
    _chatNotifySub?.cancel();
    _incomingCallSub?.cancel();
  }

  void _startArrivedGrace() {
    _arrivedGraceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _arrivedGraceSeconds--);
    });
  }

  void _startInTrip() {
    _arrivedGraceTimer?.cancel();
    _approachCtrl.stop();
    setState(() => _state = _TripState.inTrip);
  }

  void _smoothDriverMoveTo(LatLng target, double newHeading) {
    final now = DateTime.now();
    final elapsedMs = _lastSmoothFixAt == null ? 800 : now.difference(_lastSmoothFixAt!).inMilliseconds.clamp(400, 3000);
    _lastSmoothFixAt = now;

    _gpsSmooth ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(() {
        if (!mounted) return;
        final t = _gpsSmooth!.value;
        _driverPosNotifier.value = LatLng(
          _gpsSmoothFrom.latitude + (_gpsSmoothTo.latitude - _gpsSmoothFrom.latitude) * t,
          _gpsSmoothFrom.longitude + (_gpsSmoothTo.longitude - _gpsSmoothFrom.longitude) * t,
        );

        double currentHeading = _driverHeadingNotifier.value;
        double targetHeading = _smoothHeadingTo;
        double diff = targetHeading - currentHeading;

        if (diff > pi) currentHeading += 2 * pi;
        else if (diff < -pi) currentHeading -= 2 * pi;

        _driverHeadingNotifier.value = currentHeading + (targetHeading - currentHeading) * t;
        _centerMap(_driverPosNotifier.value);
      });

    _gpsSmoothFrom = _driverPosNotifier.value;
    _gpsSmoothTo   = target;
    _smoothHeadingTo = newHeading;

    _gpsSmooth!..duration = Duration(milliseconds: elapsedMs)..forward(from: 0);
  }

  LatLng _snapDriverToRoute(LatLng gps) {
    final path = _state == _TripState.inTrip ? _routePath : _approachPath;
    if (path.length < 2) return gps;
    double minDist = double.infinity;
    LatLng bestPt = gps;
    for (int i = 0; i < path.length - 1; i++) {
      final pt = _closestDriverPointOnSeg(gps, path[i], path[i + 1]);
      final d  = _kDistance.as(LengthUnit.Meter, gps, pt);
      if (d < minDist) { minDist = d; bestPt = pt; }
    }
    return minDist <= 80 ? bestPt : gps;
  }

  LatLng _closestDriverPointOnSeg(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return a;
    final t  = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / lenSq;
    final tc = t.clamp(0.0, 1.0);
    return LatLng(a.latitude + tc * dy, a.longitude + tc * dx);
  }

  void _centerMap(LatLng pos) {
    if (_userPanned) return;
    try { _mapController.move(pos, 16); } catch (_) {}
  }

  void _recenter() {
    setState(() => _userPanned = false);
    try { _mapController.move(_driverPosNotifier.value, 16); } catch (_) {}
  }

  Future<void> _onCall() async {
    final driverId = _driverId;
    final myUid    = FirebaseAuth.instance.currentUser?.uid;
    if (driverId == null || myUid == null) {
      Toast.show(context, message: 'Driver belum tersedia', type: ToastType.warning);
      return;
    }
    try {
      final session = await CallSession.startAsCaller(tripId: widget.tripId, myUid: myUid, otherUid: driverId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(session: session, otherName: _driverName, isIncoming: false),
      ));
    } catch (e) {
      if (mounted) Toast.show(context, message: 'Tidak bisa memulai panggilan: $e', type: ToastType.warning);
    }
  }

  void _onChat() {
    _chatOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => TripChatSheet(tripId: widget.tripId, otherName: _driverName),
    ).then((_) => _chatOpen = false);
  }

  void _onSos() {
    HapticFeedback.heavyImpact();
    context.push(Routes.pSos);
  }

  void _onShareTrip() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ShareTripSheet(tripId: widget.tripId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip    = ref.watch(tripBookingProvider);
    final pickup  = trip.pickupLatLng  ?? _pickupFallback;
    final dropoff = trip.dropoffLatLng ?? _dropoffFallback;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(child: _buildMap(pickup: pickup, dropoff: dropoff)),
          ),

          if (_state == _TripState.loading)
            Positioned.fill(
              child: Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: AppColors.primary500))),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12.0,
            left: 16.0,
            child: _TopIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => context.go(Routes.pHome),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12.0,
            right: 16.0,
            child: GestureDetector(
              onTap: _onShareTrip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ink0,
                  borderRadius: AppRadius.pillAll,
                  boxShadow: AppElevation.floating,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.share_rounded, color: AppColors.success500, size: 18),
                    const SizedBox(width: 8),
                    Text('Share trip', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                  ],
                ),
              ),
            ),
          ),

          if (_userPanned)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16.0,
              child: _MapButton(
                onTap: _recenter,
                child: const Icon(Icons.my_location_rounded, color: AppColors.primary500, size: 20),
              ),
            ),

          if (_state == _TripState.arrived)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8.0,
              left: 64.0, right: 64.0,
              child: _ArrivedBanner(graceSeconds: _arrivedGraceSeconds),
            ),

          if (_connectionLost)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8.0,
              left: 64.0, right: 64.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(color: AppColors.danger500, borderRadius: AppRadius.pillAll, boxShadow: AppElevation.floating),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.signal_wifi_off_rounded, color: AppColors.ink0, size: 14),
                    const SizedBox(width: 8.0),
                    Text('Koneksi terputus — menunggu sinyal', style: AppTypography.bodySm.copyWith(color: AppColors.ink0, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          if (_state != _TripState.loading)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomPanelModern(
                state: _state,
                etaSeconds: _etaSeconds,
                driverName: _driverName,
                vehicleDesc: _vehicleDesc,
                vehiclePlate: _vehiclePlate,
                onCall: _onCall,
                onChat: _onChat,
                onSos: _onSos,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap({required LatLng pickup, required LatLng dropoff}) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _driverPosNotifier.value,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && !_userPanned) setState(() => _userPanned = true);
        },
      ),
      children: [
        RihlahCachedTileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.rihlah',
          tileBuilder: _tintTile,
        ),
        if (_approachPath.length >= 2 || _routePath.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: _state == _TripState.inTrip ? _routePath : _approachPath,
              strokeWidth: 4,
              color: AppColors.primary500.withValues(alpha: 0.6),
            ),
          ]),
        MarkerLayer(markers: [
          if (_state != _TripState.inTrip && _state != _TripState.loading)
            Marker(
              point: pickup, width: 32, height: 32,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.danger500, border: Border.all(color: AppColors.ink0, width: 3), boxShadow: AppElevation.card),
                child: const Icon(Icons.location_on_rounded, color: AppColors.ink0, size: 16),
              ),
            ),
          if (_state == _TripState.inTrip)
            Marker(
              point: dropoff, width: 32, height: 38,
              child: Column(children: [
                Container(width: 28, height: 28, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger500), child: const Icon(Icons.location_on_rounded, color: AppColors.ink0, size: 16)),
                Container(width: 2, height: 8, color: AppColors.danger500),
              ]),
            ),
        ]),
        ValueListenableBuilder<LatLng>(
          valueListenable: _driverPosNotifier,
          builder: (_, pos, __) => MarkerLayer(markers: [
            Marker(
              point: pos, width: 50, height: 50,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success500, border: Border.all(color: AppColors.ink0, width: 3), boxShadow: AppElevation.floating),
                child: const Icon(Icons.motorcycle_rounded, color: AppColors.ink0, size: 24),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _BottomPanelModern extends StatelessWidget {
  const _BottomPanelModern({
    required this.state,
    required this.etaSeconds,
    required this.driverName,
    required this.vehicleDesc,
    required this.vehiclePlate,
    required this.onCall,
    required this.onChat,
    required this.onSos,
  });

  final _TripState   state;
  final int          etaSeconds;
  final String       driverName;
  final String       vehicleDesc;
  final String       vehiclePlate;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final minutes = (etaSeconds / 60).ceil();
    final etaText = state == _TripState.arrived ? 'Driver sudah tiba di lokasi' : 'Tiba dalam $minutes Menit';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink0,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.ink300, borderRadius: AppRadius.pillAll)),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Driver sedang menuju lokasi Anda', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.success500, borderRadius: AppRadius.pillAll),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink0)),
                        const SizedBox(width: 4),
                        Text('Live', style: AppTypography.label.copyWith(color: AppColors.ink0, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(etaText, style: AppTypography.h2.copyWith(color: AppColors.success500, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16.0),
              const Divider(height: 1, color: Color(0xFFF1F3F5)),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: const DecorationImage(image: NetworkImage('https://i.pravatar.cc/150?img=11'), fit: BoxFit.cover),
                      border: Border.all(color: AppColors.ink300),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driverName, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                        const SizedBox(height: 2),
                        Text(vehicleDesc, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: AppRadius.smAll),
                          child: Text(vehiclePlate, style: AppTypography.label.copyWith(color: AppColors.info500, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFFF9E6), borderRadius: AppRadius.pillAll),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 16),
                        const SizedBox(width: 4),
                        Text('4.9', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      onPressed: onChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F3F5),
                        foregroundColor: AppColors.ink900,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.success500, size: 20),
                      label: Text('Chat', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: onCall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F3F5),
                        foregroundColor: AppColors.ink900,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      icon: const Icon(Icons.phone_rounded, color: AppColors.success500, size: 20),
                      label: Text('Telepon', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: onSos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFEBEE),
                        foregroundColor: AppColors.danger500,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      child: Text('SOS', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w800, color: AppColors.danger500)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: AppColors.ink0, shape: BoxShape.circle, boxShadow: AppElevation.floating),
        child: Icon(icon, color: AppColors.ink900, size: 22),
      ),
    );
  }
}

class _ArrivedBanner extends StatelessWidget {
  const _ArrivedBanner({required this.graceSeconds});
  final int graceSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(color: AppColors.success500, borderRadius: AppRadius.pillAll, boxShadow: AppElevation.floating),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.ink0, size: 18),
          const SizedBox(width: 8.0),
          Text('Driver sudah tiba di titik penjemputan', style: AppTypography.bodySm.copyWith(color: AppColors.ink0, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ShareTripSheet extends StatelessWidget {
  const _ShareTripSheet({required this.tripId});
  final String tripId;
  String get _url => 'rihlah://${Routes.track(tripId)}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.ink300, borderRadius: AppRadius.pillAll))),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.success500.withValues(alpha: 0.1), borderRadius: AppRadius.mdAll),
                  child: const Icon(Icons.share_location_rounded, size: 20, color: AppColors.success500),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bagikan Perjalanan', style: AppTypography.h2),
                      Text('Link lokasi real-time untuk keluarga', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: AppRadius.lgAll, border: Border.all(color: AppColors.ink300)),
              child: Row(
                children: [
                  Expanded(child: Text(_url, style: AppTypography.bodySm.copyWith(color: AppColors.primary500, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8.0),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _url));
                      Toast.show(context, message: 'Link disalin!', type: ToastType.success);
                    },
                    child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final msg = Uri.encodeComponent('Hei! Pantau perjalanan RIHLAH-ku secara live:\n$_url');
                  final uri = Uri.parse('https://wa.me/?text=$msg');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
                ),
                icon: const Icon(Icons.chat_rounded, color: AppColors.ink0, size: 18),
                label: Text('Bagikan via WhatsApp', style: AppTypography.bodyMd.copyWith(color: AppColors.ink0, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12.0),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _url));
                  Navigator.pop(context);
                  Toast.show(context, message: 'Link perjalanan disalin!', type: ToastType.success);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: const Text('Salin Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _tintTile(BuildContext ctx, Widget tile, TileImage ti) => ColorFiltered(
  colorFilter: const ColorFilter.matrix([
    0.85, 0.02, 0.02, 0, 5,
    0.00, 0.90, 0.02, 0, 5,
    0.00, 0.04, 0.78, 0, 8,
    0.00, 0.00, 0.00, 1, 0,
  ]),
  child: tile,
);

class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget       child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.ink0, shape: BoxShape.circle, boxShadow: AppElevation.card),
        child: Center(child: child),
      ),
    );
  }
}