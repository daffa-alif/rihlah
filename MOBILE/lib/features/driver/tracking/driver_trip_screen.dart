import 'dart:async';
import 'dart:math' show pi;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/core.dart';
import '../../../core/utils/gps_fix_filter.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/services/voice_guidance_service.dart';
import '../../../core/widgets/call_screen.dart';
import '../../../core/widgets/trip_chat_sheet.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/trip_model.dart' hide TripStatus;
import '../../../router.dart';
import '../../../core/widgets/sos_button.dart';

// ignore_for_file: depend_on_referenced_packages
const _kDistance = Distance();

enum _DriverTripState { loading, toPickup, waitingPassenger, inTrip }

class DriverTripScreen extends StatefulWidget {
  const DriverTripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen>
    with TickerProviderStateMixin {

  final _mapController = MapController();
  bool _userPanned     = false;
  _DriverTripState _state = _DriverTripState.loading;

  // Real Firestore trip
  TripModel? _trip;

  String get _passengerName => _trip?.passengerName ?? 'Penumpang';
  String get _pickupLabel   => _trip?.pickupAddress  ?? 'Penjemputan';
  String get _dropoffLabel  => _trip?.dropoffAddress ?? 'Tujuan';

  // Routes from OSRM
  List<LatLng>    _toPickupPath   = [];
  List<LatLng>    _toDropoffPath  = [];
  List<RouteStep> _approachSteps  = [];
  List<RouteStep> _tripSteps      = [];
  double          _approachDistKm = 0;

  // Mapping: indeks titik path → indeks step OSRM
  List<int> _approachStepThresholds = [];
  List<int> _tripStepThresholds     = [];

  // Pickup / dropoff LatLng
  late LatLng _pickupLatLng;
  late LatLng _dropoffLatLng;

  bool _approaching = false;
  bool _nearDropoff = false;

  // Smooth GPS interpolation
  late AnimationController _smoothCtrl;
  LatLng _smoothFrom = const LatLng(-6.8750, 107.6175);
  LatLng _smoothTo   = const LatLng(-6.8750, 107.6175);
  DateTime? _lastSmoothFixAt;

  // Notifiers untuk posisi dan rotasi mobil
  final _driverPosNotifier = ValueNotifier<LatLng>(const LatLng(-6.8750, 107.6175));
  final _driverHeadingNotifier = ValueNotifier<double>(0.0);

  // ETA
  int    _etaSeconds = 0;
  Timer? _etaTimer;
  Timer? _instructionTimer;
  int    _instructionIdx = 0;

  // GPS stream
  StreamSubscription<Position>? _gpsSub;
  final _gpsFilter = GpsFixFilter();
  DateTime? _lastLocationWriteAt;
  StreamSubscription<TripModel?>? _tripCancelSub;

  // Route deviation detection (Diturunkan dari 50.0 ke 35.0 agar lebih responsif)
  static const _deviationThresholdM = 35.0; // meter
  bool  _isRecalculating = false;
  Timer? _recalcCooldown;

  // ── Chat notifications ────────────────────────────────────────────────────
  StreamSubscription<List<ChatMessage>>? _chatNotifySub;
  int  _lastMsgCount = -1;
  bool _chatOpen     = false;

  // ── Incoming calls ────────────────────────────────────────────────────────
  StreamSubscription<Map<String, dynamic>?>? _incomingCallSub;
  String? _handledCallId;

  @override
  void initState() {
    super.initState();
    _smoothCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _smoothCtrl.addListener(() {
      if (!mounted) return;
      final t = _smoothCtrl.value;
      _driverPosNotifier.value = LatLng(
        _smoothFrom.latitude  + (_smoothTo.latitude  - _smoothFrom.latitude)  * t,
        _smoothFrom.longitude + (_smoothTo.longitude - _smoothFrom.longitude) * t,
      );
      _centerMap(_driverPosNotifier.value);
    });
    _loadRoutes();
    _startGpsStream();
    _watchCancellation();
    _startChatNotifyListener();
    _startIncomingCallListener();
    VoiceGuidanceService.instance.init();
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
          tripId: widget.tripId, callerName: _passengerName);

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
          otherName : _passengerName,
          isIncoming: true,
        ),
      ));
    }, onError: (e) {
      debugPrint('Incoming call listener error: $e');
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
            senderName: _passengerName,
            text      : m.text,
          );
        }
      } else {
        _lastMsgCount = messages.length;
      }
    }, onError: (e) {
      debugPrint('Chat notify listener error: $e');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _startChatNotifyListener();
      });
    });
  }

  void _watchCancellation() {
    _tripCancelSub =
        FirestoreService.instance.tripStream(widget.tripId).listen((trip) {
          if (!mounted || trip == null) return;
          if (trip.status.name == 'cancelled') {
            _tripCancelSub?.cancel();
            Hive.box('settings').delete('driver_location');
            Toast.show(context,
                message: 'Penumpang membatalkan perjalanan',
                type: ToastType.warning);
            context.go(Routes.dHome);
          }
        });
  }

  void _assignLatLng() {
    if (_trip != null) {
      _pickupLatLng  = LatLng(_trip!.pickupLat,  _trip!.pickupLng);
      _dropoffLatLng = LatLng(_trip!.dropoffLat, _trip!.dropoffLng);
    } else {
      _pickupLatLng  = const LatLng(-6.8750, 107.6175);
      _dropoffLatLng = const LatLng(-6.9200, 107.6070);
      if (mounted) {
        Toast.show(context,
            message: 'Gagal memuat data trip. Menampilkan perkiraan.',
            type: ToastType.warning);
      }
    }
  }

  Future<void> _loadRoutes() async {
    try {
      _trip = await FirestoreService.instance.getTrip(widget.tripId);
    } catch (_) {}
    if (!mounted) return;
    _assignLatLng();

    final gpsPos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;

    _driverPosNotifier.value = gpsPos;

    final approach = await RoutingService.instance
        .getRoute(gpsPos, _pickupLatLng, serviceType: _trip?.serviceType);
    final trip = await RoutingService.instance
        .getRoute(_pickupLatLng, _dropoffLatLng,
        serviceType: _trip?.serviceType);

    if (!mounted) return;

    _toPickupPath = approach.points.length >= 2
        ? _densify(approach.points, intervalMeters: 15)
        : _densify(_fallbackPath(gpsPos, _pickupLatLng, 20), intervalMeters: 15);
    _toDropoffPath = trip.points.length >= 2
        ? _densify(trip.points, intervalMeters: 15)
        : _densify(_fallbackPath(_pickupLatLng, _dropoffLatLng, 20), intervalMeters: 15);

    _approachDistKm = approach.distanceKm > 0
        ? approach.distanceKm
        : _fallbackDistKm(gpsPos, _pickupLatLng);
    _approachSteps = approach.steps;
    _tripSteps     = trip.steps;

    _approachStepThresholds = _buildStepThresholds(_toPickupPath, _approachSteps);
    _tripStepThresholds     = _buildStepThresholds(_toDropoffPath, _tripSteps);

    setState(() {
      _state      = _DriverTripState.toPickup;
      _approaching = true;
    });

    _startEtaTimer();

    try { _mapController.move(gpsPos, 16); } catch (_) {}
  }

  List<LatLng> _densify(List<LatLng> path,
      {double intervalMeters = 15}) {
    if (path.length < 2) return path;
    final result = <LatLng>[path.first];
    for (int i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      final dist = _kDistance.as(LengthUnit.Meter, a, b);
      if (dist <= intervalMeters) {
        result.add(b);
        continue;
      }
      final steps = (dist / intervalMeters).ceil();
      for (int s = 1; s <= steps; s++) {
        final t = s / steps;
        result.add(LatLng(
          a.latitude  + (b.latitude  - a.latitude)  * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    return result;
  }

  List<LatLng> _fallbackPath(LatLng a, LatLng b, [int steps = 20]) =>
      List.generate(steps, (i) {
        final t = i / (steps - 1);
        return LatLng(
          a.latitude  + (b.latitude  - a.latitude)  * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      });

  List<int> _buildStepThresholds(
      List<LatLng> path, List<RouteStep> steps) {
    if (steps.isEmpty || path.length < 2) return [];

    final cumDist = <double>[0];
    for (int i = 1; i < path.length; i++) {
      cumDist.add(cumDist.last +
          _kDistance.as(LengthUnit.Meter, path[i - 1], path[i]));
    }
    final totalDist = cumDist.last;
    if (totalDist == 0) return [];

    double parseStepDist(String s) {
      final lower = s.toLowerCase().trim();
      if (lower.contains('km')) {
        return (double.tryParse(
            lower.replaceAll('km', '').trim()) ??
            0) *
            1000;
      }
      return double.tryParse(lower.replaceAll('m', '').trim()) ?? 0;
    }

    double cumStep = 0;
    final thresholds = <int>[];
    for (final step in steps) {
      final targetDist = cumStep;
      int closestIdx = 0;
      double minDiff = double.infinity;
      for (int i = 0; i < cumDist.length; i++) {
        final diff = (cumDist[i] - targetDist).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestIdx = i;
        }
      }
      thresholds.add(closestIdx);
      cumStep += parseStepDist(step.distance);
    }
    return thresholds;
  }

  double _fallbackDistKm(LatLng a, LatLng b) =>
      double.parse(_kDistance
          .as(LengthUnit.Kilometer, a, b)
          .toStringAsFixed(1));

  void _startGpsStream() {
    _gpsSub = LocationService.instance.rawPositionStream().listen((raw) {
      final pos = LatLng(raw.latitude, raw.longitude);
      final heading = raw.heading >= 0 ? raw.heading : 0.0;

      _driverHeadingNotifier.value = heading * (pi / 180);

      Hive.box('settings').put('driver_location', {
        'lat': pos.latitude,
        'lon': pos.longitude,
        'ts' : DateTime.now().millisecondsSinceEpoch,
      });

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final now = DateTime.now();

      final interval = PowerModeService.instance.isPowerSaveMode.value ? 10000 : 2500;
      final dueForWrite = _lastLocationWriteAt == null ||
          now.difference(_lastLocationWriteAt!) >= Duration(milliseconds: interval);

      if (uid != null && dueForWrite) {
        _lastLocationWriteAt = now;
        FirestoreService.instance.updateDriverLocation(
          driverId  : uid,
          lat       : pos.latitude,
          lng       : pos.longitude,
          tripId    : widget.tripId,
          headingDeg: heading,
        );
      }

      final displayPos = (_state == _DriverTripState.toPickup ||
          _state == _DriverTripState.inTrip)
          ? _snapToRoute(pos) : pos;
      _smoothMoveTo(displayPos);

      if (_state == _DriverTripState.toPickup ||
          _state == _DriverTripState.inTrip) {
        _updateInstructionByGps(pos);
        _checkProximity(pos);
        _checkDeviation(pos);
      }
    });
  }

  // ── Route deviation detection ─────────────────────────────────────────────

  void _checkDeviation(LatLng gpsPos) {
    if (_isRecalculating || _recalcCooldown != null) return;

    final path = _state == _DriverTripState.inTrip
        ? _toDropoffPath : _toPickupPath;
    if (path.length < 2) return;

    double minDist = double.infinity;
    for (final pt in path) {
      final d = _kDistance.as(LengthUnit.Meter, gpsPos, pt);
      if (d < minDist) minDist = d;
      if (d < _deviationThresholdM) return;
    }

    if (minDist > _deviationThresholdM) {
      debugPrint('=== Deviation detected: ${minDist.toStringAsFixed(0)}m '
          '— recalculating route');
      _recalculateRoute(gpsPos);
    }
  }

  Future<void> _recalculateRoute(LatLng currentPos) async {
    if (_isRecalculating) return;
    setState(() => _isRecalculating = true);

    // Dipercepat cooldown-nya menjadi 10 detik
    _recalcCooldown = Timer(const Duration(seconds: 10), () {
      _recalcCooldown = null;
    });

    try {
      final destination = _state == _DriverTripState.inTrip
          ? _dropoffLatLng : _pickupLatLng;

      final result = await RoutingService.instance
          .getRoute(currentPos, destination,
          serviceType: _trip?.serviceType);

      if (!mounted) return;
      if (result.points.length < 2) return;

      final newPath  = _densify(result.points, intervalMeters: 15);
      final newSteps = result.steps;

      setState(() {
        if (_state == _DriverTripState.inTrip) {
          _toDropoffPath  = newPath;
          _tripSteps      = newSteps;
          _tripStepThresholds = _buildStepThresholds(newPath, newSteps);
        } else {
          _toPickupPath   = newPath;
          _approachSteps  = newSteps;
          _approachDistKm = result.distanceKm;
          _approachStepThresholds = _buildStepThresholds(newPath, newSteps);
        }
        _instructionIdx  = 0;
        _isRecalculating = false;
      });

      _recalcEta();
      Toast.show(context,
          message: 'Rute diperbarui',
          type: ToastType.info);
    } catch (e) {
      if (mounted) setState(() => _isRecalculating = false);
      debugPrint('=== Recalc failed: $e');
    }
  }

  // ── GPS-driven helpers ────────────────────────────────────────────────────

  void _updateInstructionByGps(LatLng gpsPos) {
    final path = _state == _DriverTripState.inTrip
        ? _toDropoffPath : _toPickupPath;
    if (path.isEmpty) return;
    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < path.length; i++) {
      final d = _kDistance.as(LengthUnit.Meter, gpsPos, path[i]);
      if (d < minDist) { minDist = d; closestIdx = i; }
    }
    _updateInstruction(closestIdx);
  }

  void _checkProximity(LatLng gpsPos) {
    if (_state == _DriverTripState.inTrip && !_nearDropoff) {
      final d = _kDistance.as(LengthUnit.Meter, gpsPos, _dropoffLatLng);
      if (d < 500) setState(() => _nearDropoff = true);
    }
  }

  void _handleCompleteButton() {
    final gpsPos = _driverPosNotifier.value;
    final distanceM = _kDistance.as(LengthUnit.Meter, gpsPos, _dropoffLatLng);

    if (distanceM > 500) {
      _showEarlyDropoffDialog();
    } else {
      _completeTrip();
    }
  }

  void _showEarlyDropoffDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selesaikan perjalanan di sini?', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Posisi kamu saat ini masih berjarak cukup jauh dari titik tujuan di peta. Pastikan penumpang sudah benar-benar turun.',
                style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              RihlahButton(
                label: 'Ya, Penumpang Sudah Turun',
                variant: RihlahButtonVariant.primary,
                onPressed: () {
                  Navigator.pop(context);
                  _completeTrip();
                },
              ),
              const SizedBox(height: AppSpacing.s8),
              RihlahButton(
                label: 'Lanjutkan Mengemudi',
                variant: RihlahButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeTrip() async {
    try {
      await FirestoreService.instance.completeTrip(widget.tripId);
    } catch (e) {
      if (mounted) {
        Toast.show(context,
            message: 'Gagal menyelesaikan trip. Coba lagi.',
            type: ToastType.danger);
      }
      return;
    }
    if (!mounted) return;
    context.go(Routes.dTripComplete(widget.tripId));
  }

  void _updateInstruction(int pathIndex) {
    final thresholds = _state == _DriverTripState.inTrip
        ? _tripStepThresholds : _approachStepThresholds;
    if (thresholds.isEmpty) return;

    int newIdx = 0;
    for (int i = 0; i < thresholds.length; i++) {
      if (pathIndex >= thresholds[i]) {
        newIdx = i;
      } else {
        break;
      }
    }

    if (newIdx != _instructionIdx) {
      setState(() => _instructionIdx = newIdx);

      final steps = _state == _DriverTripState.inTrip
          ? _tripSteps : _approachSteps;
      if (steps.isNotEmpty) {
        final step = steps[newIdx.clamp(0, steps.length - 1)];
        VoiceGuidanceService.instance.speakInstruction(
            '${step.distance}, ${step.instruction}');
      }
    }
  }

  void _startEtaTimer() {
    _recalcEta();
    _etaTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _recalcEta();
    });
  }

  double _remainingKm = 0;

  void _recalcEta() {
    final path = _state == _DriverTripState.inTrip
        ? _toDropoffPath : _toPickupPath;

    if (path.length < 2) {
      if (mounted) setState(() { _etaSeconds = 0; _remainingKm = 0; });
      return;
    }

    final gpsPos = _driverPosNotifier.value;
    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < path.length; i++) {
      final d = _kDistance.as(LengthUnit.Meter, gpsPos, path[i]);
      if (d < minDist) { minDist = d; closestIdx = i; }
    }

    double remainingMeters = 0;
    for (int i = closestIdx; i < path.length - 1; i++) {
      remainingMeters += _kDistance.as(
          LengthUnit.Meter, path[i], path[i + 1]);
    }

    const speedMs = 25.0 * 1000 / 3600;
    final seconds = (remainingMeters / speedMs).round();

    if (mounted) setState(() {
      _etaSeconds   = seconds.clamp(0, 9999);
      _remainingKm  = double.parse(
          (remainingMeters / 1000).toStringAsFixed(1));
    });
  }

  // ── GPS smoothing + route snapping ──────────────────────────────────────────

  void _smoothMoveTo(LatLng target) {
    final now = DateTime.now();
    final elapsedMs = _lastSmoothFixAt == null
        ? 800
        : now.difference(_lastSmoothFixAt!).inMilliseconds.clamp(400, 3000);
    _lastSmoothFixAt = now;

    _smoothFrom = _driverPosNotifier.value;
    _smoothTo   = target;
    _smoothCtrl
      ..duration = Duration(milliseconds: elapsedMs)
      ..forward(from: 0);
  }

  LatLng _snapToRoute(LatLng gps) {
    final path = _state == _DriverTripState.inTrip ? _toDropoffPath : _toPickupPath;
    if (path.length < 2) return gps;
    double minDist = double.infinity;
    LatLng bestPt = gps;
    for (int i = 0; i < path.length - 1; i++) {
      final pt = _closestPointOnSegment(gps, path[i], path[i + 1]);
      final d  = _kDistance.as(LengthUnit.Meter, gps, pt);
      if (d < minDist) { minDist = d; bestPt = pt; }
    }
    return minDist <= _deviationThresholdM ? bestPt : gps;
  }

  LatLng _closestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude  - a.latitude;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return a;
    final t  = ((p.longitude - a.longitude) * dx +
        (p.latitude  - a.latitude)  * dy) / lenSq;
    final tc = t.clamp(0.0, 1.0);
    return LatLng(a.latitude + tc * dy, a.longitude + tc * dx);
  }

  void _centerMap(LatLng pos) {
    // Jika driver sedang menggeser layar manual (melihat-lihat map),
    // kamera JANGAN ditarik paksa. Biarkan mereka mengeksplor.
    if (_userPanned) return;

    double idealZoom = 16.0; // Zoom standar

    try {
      // Hanya hitung auto-zoom jika driver sedang menuju penjemputan atau tujuan
      if (_state == _DriverTripState.toPickup || _state == _DriverTripState.inTrip) {
        final target = _state == _DriverTripState.inTrip ? _dropoffLatLng : _pickupLatLng;

        // Hitung jarak driver ke titik tujuan dalam satuan Meter
        final distM = _kDistance.as(LengthUnit.Meter, pos, target);

        // ── FORMULA CINEMATIC AUTO-ZOOM ──
        // Jika jarak dekat (0m) -> Zoom 18.0 (Sangat Detail)
        // Jika jarak menengah (1.5km) -> Zoom 17.0
        // Jika jarak jauh (> 6.7km) -> Zoom 13.5 (Tampilan Luas/Zoom Out maksimal)
        idealZoom = 18.0 - (distM / 1500).clamp(0.0, 4.5);
      }

      // Gerakkan kamera secara real-time mengikuti posisi mobil dengan zoom yang dinamis
      _mapController.move(pos, idealZoom);
    } catch (_) {}
  }

  void _recenter() {
    setState(() => _userPanned = false);
    try { _mapController.move(_driverPosNotifier.value, 16); }
    catch (_) {}
  }

  @override
  void dispose() {
    _smoothCtrl.dispose();
    _driverPosNotifier.dispose();
    _driverHeadingNotifier.dispose();
    _instructionTimer?.cancel();
    _etaTimer?.cancel();
    _gpsSub?.cancel();
    _tripCancelSub?.cancel();
    _chatNotifySub?.cancel();
    _incomingCallSub?.cancel();
    _recalcCooldown?.cancel();
    VoiceGuidanceService.instance.stop();
    Hive.box('settings').delete('driver_location');
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onArrived() {
    HapticFeedback.mediumImpact();
    setState(() {
      _state = _DriverTripState.waitingPassenger;
      _instructionIdx = 0;
    });
    FirestoreService.instance.setTripArrived(widget.tripId).catchError((e) {
      debugPrint('setTripArrived failed: $e');
    });
    Toast.show(context,
        message: 'Penumpang sedang menuju ke kamu',
        type: ToastType.info);
    VoiceGuidanceService.instance.speak(
        'Kamu telah tiba di titik penjemputan. '
            'Penumpang sedang menuju ke kamu.');
  }

  void _onStartTrip() {
    HapticFeedback.mediumImpact();
    setState(() {
      _state          = _DriverTripState.inTrip;
      _instructionIdx = 0;
      _userPanned     = false;
    });
    FirestoreService.instance.setTripInTrip(widget.tripId).catchError((e) {
      debugPrint('setTripInTrip failed: $e');
    });
    _updateInstructionByGps(_driverPosNotifier.value);
    _recalcEta();
    VoiceGuidanceService.instance.speak('Perjalanan dimulai. Menuju tujuan.');
    try { _mapController.move(_driverPosNotifier.value, 16); } catch (_) {}
  }

  void _onChat() {
    _chatOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl))),
      builder: (_) => TripChatSheet(
        tripId   : widget.tripId,
        otherName: _passengerName,
      ),
    ).then((_) => _chatOpen = false);
  }

  Future<void> _onCall() async {
    final passengerId = _trip?.passengerId;
    final myUid       = FirebaseAuth.instance.currentUser?.uid;
    if (passengerId == null || passengerId.isEmpty || myUid == null) {
      Toast.show(context,
          message: 'Penumpang belum tersedia', type: ToastType.warning);
      return;
    }
    try {
      final session = await CallSession.startAsCaller(
        tripId  : widget.tripId,
        myUid   : myUid,
        otherUid: passengerId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          session   : session,
          otherName : _passengerName,
          isIncoming: false,
        ),
      ));
    } catch (e) {
      if (mounted) {
        Toast.show(context,
            message: 'Tidak bisa memulai panggilan: $e',
            type: ToastType.warning);
      }
    }
  }

  void _onCancelPickup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Batalkan penjemputan?',
                  style: AppTypography.h2),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Batalkan sekarang mungkin mempengaruhi rating kamu.',
                style: AppTypography.bodyMd
                    .copyWith(color: Theme.of(context)
                    .colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.s24),
              RihlahButton(
                label: 'Ya, batalkan',
                variant: RihlahButtonVariant.danger,
                onPressed: () {
                  _etaTimer?.cancel();
                  _tripCancelSub?.cancel();
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    FirestoreService.instance.clearDriverLocation(uid);
                  }
                  FirestoreService.instance.cancelTrip(
                    widget.tripId,
                    cancelledBy: 'driver',
                  );
                  Hive.box('settings').delete('driver_location');
                  Navigator.pop(context);
                  context.go(Routes.dHome);
                  Toast.show(context,
                      message: 'Penjemputan dibatalkan',
                      type: ToastType.warning);
                },
              ),
              const SizedBox(height: AppSpacing.s8),
              RihlahButton(
                label: 'Lanjutkan',
                variant: RihlahButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  (String, String) get _currentInstruction {
    final steps = _state == _DriverTripState.inTrip
        ? _tripSteps : _approachSteps;
    if (steps.isEmpty) {
      return _state == _DriverTripState.inTrip
          ? ('Menuju tujuan', _dropoffLabel)
          : ('Menuju penjemputan', _pickupLabel);
    }
    final step = steps[_instructionIdx.clamp(0, steps.length - 1)];
    return (step.distance, step.instruction);
  }

  String get _etaLabel {
    if (_etaSeconds <= 0) return 'Tiba';
    final h = _etaSeconds ~/ 3600;
    final m = (_etaSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}j ${m}m';
    if (m > 0) return '${m}m';
    return '< 1 menit';
  }

  String get _distLabel => '${_remainingKm.toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    if (_state == _DriverTripState.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(
            color: AppColors.primary500)),
      );
    }

    final (instrDist, instrLabel) = _currentInstruction;

    return Scaffold(
      backgroundColor: AppColors.ink0,
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────
          Positioned.fill(
            child: RepaintBoundary(child: _buildMap()),
          ),

          // ── Turn ribbon ───────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.s8,
            left: AppSpacing.s16,
            right: _userPanned ? 64 : AppSpacing.s16,
            child: _TurnRibbon(
                distance: instrDist, instruction: instrLabel),
          ),

          // ── Recalculating indicator ───────────────────
          if (_isRecalculating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: AppSpacing.s16,
              right: AppSpacing.s16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.info500,
                  borderRadius: AppRadius.pillAll,
                  boxShadow: AppElevation.card,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: AppColors.ink0,
                          strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text('Menghitung ulang rute…',
                        style: AppTypography.bodySm.copyWith(
                            color: AppColors.ink0,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          // ── SOS button ───────────────────────────────
          Positioned(
            left: AppSpacing.s16,
            bottom: 180,
            child: DriverSosButton(
              tripId: widget.tripId,
              mini  : true,
            ),
          ),

          // ── Recenter button ───────────────────────────
          if (_userPanned)
            Positioned(
              top: MediaQuery.of(context).padding.top + AppSpacing.s8,
              right: AppSpacing.s16,
              child: _MapBtn(
                onTap: _recenter,
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.primary500, size: 20),
              ),
            ),

          // ── Bottom panel ──────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(
              state          : _state,
              passengerName  : _passengerName,
              passengerRating: _trip?.passengerRating?.toDouble(),
              pickupLabel    : _pickupLabel,
              pickupSub      : '',
              dropoffLabel   : _dropoffLabel,
              dropoffSub     : '',
              etaLabel       : _etaLabel,
              distLabel      : _distLabel,
              approaching    : _approaching,
              nearDropoff    : _nearDropoff,
              onArrived      : _onArrived,
              onStartTrip    : _onStartTrip,
              onComplete     : _handleCompleteButton,
              onCancel       : _onCancelPickup,
              onChat         : _onChat,
              onCall         : _onCall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _driverPosNotifier.value,
        initialZoom: 16,
        interactionOptions:
        const InteractionOptions(flags: InteractiveFlag.all),
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && !_userPanned) {
            setState(() => _userPanned = true);
          }
        },
      ),
      children: [
        RihlahCachedTileLayer(
          urlTemplate:
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.rihlah',
          tileBuilder: _tintTile,
        ),
        if (_toPickupPath.isNotEmpty || _toDropoffPath.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
              points: _state == _DriverTripState.inTrip
                  ? _toDropoffPath : _toPickupPath,
              strokeWidth: 4,
              color: AppColors.primary500.withOpacity(0.5),
            ),
          ]),
        MarkerLayer(markers: [
          Marker(
            point: _state == _DriverTripState.inTrip
                ? _dropoffLatLng : _pickupLatLng,
            width: 32, height: 38,
            child: Column(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _state == _DriverTripState.inTrip
                      ? AppColors.danger500 : AppColors.primary500,
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: AppColors.ink0, size: 16),
              ),
              Container(
                  width: 2, height: 8,
                  color: _state == _DriverTripState.inTrip
                      ? AppColors.danger500 : AppColors.primary500),
            ]),
          ),
        ]),
        ValueListenableBuilder<LatLng>(
          valueListenable: _driverPosNotifier,
          builder: (_, pos, __) => MarkerLayer(markers: [
            Marker(
              point: pos,
              width: 44, height: 44,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary500,
                  border: Border.all(
                      color: AppColors.ink0, width: 3),
                  boxShadow: AppElevation.floating,
                ),
                child: ValueListenableBuilder<double>(
                  valueListenable: _driverHeadingNotifier,
                  builder: (_, headingRad, __) => Transform.rotate(
                    angle: headingRad,
                    child: const Icon(
                        Icons.directions_car_rounded,
                        color: AppColors.ink0,
                        size: 20
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Turn ribbon ───────────────────────────────────────────────────────────────

class _TurnRibbon extends StatelessWidget {
  const _TurnRibbon(
      {required this.distance, required this.instruction});
  final String distance, instruction;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(instruction),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.ink900,
          borderRadius: AppRadius.lgAll,
          boxShadow: AppElevation.floating,
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary500,
                borderRadius: AppRadius.smAll,
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: AppColors.ink0, size: 20),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(distance,
                      style: AppTypography.bodySm.copyWith(
                          color: AppColors.ink0.withOpacity(0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(instruction,
                      style: AppTypography.bodyLg.copyWith(
                          color: AppColors.ink0,
                          fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.state,
    required this.passengerName,
    required this.passengerRating,
    required this.pickupLabel,
    required this.pickupSub,
    required this.dropoffLabel,
    required this.dropoffSub,
    required this.etaLabel,
    required this.distLabel,
    required this.approaching,
    required this.nearDropoff,
    required this.onArrived,
    required this.onStartTrip,
    required this.onComplete,
    required this.onCancel,
    required this.onChat,
    required this.onCall,
  });

  final _DriverTripState state;
  final String           passengerName;
  final double?          passengerRating;
  final String           pickupLabel;
  final String           pickupSub;
  final String           dropoffLabel;
  final String           dropoffSub;
  final String           etaLabel;
  final String           distLabel;
  final bool             approaching;
  final bool             nearDropoff;
  final VoidCallback     onArrived;
  final VoidCallback     onStartTrip;
  final VoidCallback     onComplete;
  final VoidCallback     onCancel;
  final VoidCallback     onChat;
  final VoidCallback     onCall;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
        boxShadow: AppElevation.floating,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16, AppSpacing.s16,
              AppSpacing.s16, AppSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: AppRadius.pillAll),
              ),
              const SizedBox(height: AppSpacing.s16),

              // ETA row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state == _DriverTripState.toPickup
                              ? 'Menuju penjemputan'
                              : state == _DriverTripState.waitingPassenger
                              ? 'Menunggu penumpang'
                              : 'Menuju tujuan',
                          style: AppTypography.bodySm
                              .copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          state == _DriverTripState.waitingPassenger
                              ? 'Penumpang sedang menuju kamu'
                              : '$etaLabel  ·  $distLabel',
                          style: AppTypography.h2
                              .copyWith(color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  StatusPill(
                    status: state == _DriverTripState.inTrip
                        ? TripStatus.inTrip : TripStatus.accepted,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Pickup location card (pre-trip only)
              if (state != _DriverTripState.inTrip) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          state == _DriverTripState.waitingPassenger
                              ? 'TUJUAN' : 'PICKUP',
                          style: AppTypography.label
                              .copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        state == _DriverTripState.waitingPassenger
                            ? dropoffLabel : pickupLabel,
                        style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        state == _DriverTripState.waitingPassenger
                            ? dropoffSub : pickupSub,
                        style: AppTypography.bodySm
                            .copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],

              // Passenger card
              _PassengerCard(
                name  : passengerName,
                rating: passengerRating,
                onChat: onChat,
                onCall: onCall,
              ),
              const SizedBox(height: AppSpacing.s16),

              // CTA
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: state == _DriverTripState.toPickup
                    ? Row(
                  key: const ValueKey('pickup-cta'),
                  children: [
                    // Batalkan (hanya saat toPickup)
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                            AppColors.danger500,
                            side: const BorderSide(
                                color: AppColors.danger500),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                AppRadius.mdAll),
                          ),
                          child: Text('Batal',
                              style: AppTypography.bodyLg
                                  .copyWith(
                                fontWeight:
                                FontWeight.w600,
                                color:
                                AppColors.danger500,
                              )),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    // Sudah tiba
                    Expanded(
                      flex: 3,
                      child: _ArrivedButton(
                        enabled: approaching,
                        onTap  : onArrived,
                      ),
                    ),
                  ],
                )
                    : state == _DriverTripState.waitingPassenger
                    ? _StartTripButton(
                  key: const ValueKey('start'),
                  onTap: onStartTrip,
                )
                    : _CompleteButton(
                  key: const ValueKey('complete'),
                  onTap: onComplete, // Tombol selalu muncul saat inTrip
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Passenger card ────────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({
    required this.name,
    required this.rating,
    required this.onChat,
    required this.onCall,
  });
  final String       name;
  final double?      rating;
  final VoidCallback onChat;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0] : 'P';

    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.accent500),
          child: Center(
            child: Text(initial,
                style: const TextStyle(
                    color: AppColors.ink0,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: AppTypography.bodyLg
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                const Icon(Icons.star_rounded,
                    size: 14, color: AppColors.accent500),
                Text(
                  rating != null
                      ? ' ${rating!.toStringAsFixed(1)}'
                      : ' —',
                  style: AppTypography.bodySm
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ]),
            ],
          ),
        ),
        _CircleButton(
          icon     : Icons.phone_rounded,
          color    : AppColors.success500.withOpacity(0.12),
          iconColor: AppColors.success500,
          onTap    : onCall,
        ),
        const SizedBox(width: AppSpacing.s8),
        _CircleButton(
          icon     : Icons.chat_bubble_outline_rounded,
          color    : AppColors.info500.withOpacity(0.12),
          iconColor: AppColors.info500,
          onTap    : onChat,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });
  final IconData     icon;
  final Color        color, iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

// ── CTAs ──────────────────────────────────────────────────────────────────────

class _ArrivedButton extends StatelessWidget {
  const _ArrivedButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary500,
            disabledBackgroundColor: AppColors.primary500,
            foregroundColor: AppColors.ink0,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: AppRadius.mdAll),
          ),
          child: Text('Sudah tiba',
              style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink0)),
        ),
      ),
    );
  }
}

class _StartTripButton extends StatelessWidget {
  const _StartTripButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success500,
          foregroundColor: AppColors.ink0,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll),
        ),
        child: Text('Mulai perjalanan',
            style: AppTypography.bodyLg.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink0)),
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success500,
          foregroundColor: AppColors.ink0,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll),
        ),
        child: Text('Selesai / Antar',
            style: AppTypography.bodyLg.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink0)),
      ),
    );
  }
}

// ── Map helpers ───────────────────────────────────────────────────────────────

Widget _tintTile(BuildContext ctx, Widget tile, TileImage ti) =>
    ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.85, 0.02, 0.02, 0, 5,
        0.00, 0.90, 0.02, 0, 5,
        0.00, 0.04, 0.78, 0, 8,
        0.00, 0.00, 0.00, 1, 0,
      ]),
      child: tile,
    );

class _MapBtn extends StatelessWidget {
  const _MapBtn({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget       child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: AppElevation.card,
        ),
        child: Center(child: child),
      ),
    );
  }
}