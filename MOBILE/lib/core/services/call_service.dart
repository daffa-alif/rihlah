import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallPhase { connecting, ringing, connected, ended, declined, failed }

enum CallRole { caller, callee }

const _kIceServers = {
  'iceServers': [
    // ── STUN — discovers public IP (free, no auth) ──────────────────────
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
    {'urls': 'stun:stun4.l.google.com:19302'},
    // ── TURN (primary) — Metered.ca OpenRelay free tier, 500 MB/mo ──────
    {
      'urls': [
        'turn:openrelay.metered.ca:80',
        'turn:openrelay.metered.ca:443',
        'turn:openrelay.metered.ca:443?transport=tcp',
        'turns:openrelay.metered.ca:443?transport=tcp',
      ],
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    // ── TURN (fallback) — Numb Viagenie free TURN ──────────────────────
    // Credentials refresh periodically; check https://numb.viagenie.ca
    {
      'urls': ['turn:numb.viagenie.ca'],
      'username': 'webrtc@live.com',
      'credential': 'muazkh',
    },
  ],
  // Aggressive ICE restart when direct P2P fails
  'iceTransportPolicy': 'all',
  'bundlePolicy': 'max-bundle',
  'rtcpMuxPolicy': 'require',
};

/// Max seconds to wait for a peer connection before failing the call.
const _kConnectionTimeoutSec = 30;

/// One in-app voice call attempt. Owns the WebRTC peer connection, the
/// local mic stream, and the Firestore signaling doc used to exchange the
/// SDP offer/answer and ICE candidates with the other side.
///
/// TURN relay is provided by Metered.ca OpenRelay (free tier, 500 MB/mo).
/// Upgrade to a dedicated TURN server (coturn) or a paid Metered.ca plan for
/// production scale.
class CallSession {
  CallSession._({
    required this.tripId,
    required this.callId,
    required this.role,
    required this.myUid,
    required this.otherUid,
  });

  final String tripId;
  final String callId;
  final CallRole role;
  final String myUid;
  final String otherUid;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  StreamSubscription? _docSub;
  StreamSubscription? _candidatesSub;
  Timer? _elapsedTimer;
  bool _remoteDescSet = false;

  final ValueNotifier<CallPhase> phase = ValueNotifier(CallPhase.connecting);
  final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);

  Timer? _timeoutTimer;

  /// Starts a guard timer that fails the call if it hasn't connected within
  /// [_kConnectionTimeoutSec] seconds — prevents the UI from spinning forever
  /// when TURN is down or the remote peer never answers.
  void _startConnectionTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: _kConnectionTimeoutSec), () {
      if (phase.value != CallPhase.connected) {
        phase.value = CallPhase.failed;
        _cleanupPeer();
      }
    });
  }

  DocumentReference<Map<String, dynamic>> get _callDoc => FirebaseFirestore
      .instance.collection('trips').doc(tripId).collection('calls').doc(callId);

  CollectionReference<Map<String, dynamic>> get _myCandidates => _callDoc
      .collection(role == CallRole.caller ? 'callerCandidates' : 'calleeCandidates');

  CollectionReference<Map<String, dynamic>> get _otherCandidates => _callDoc
      .collection(role == CallRole.caller ? 'calleeCandidates' : 'callerCandidates');

  /// Places a new outgoing call and immediately sends the offer.
  static Future<CallSession> startAsCaller({
    required String tripId,
    required String myUid,
    required String otherUid,
  }) async {
    final callId = FirebaseFirestore.instance
        .collection('trips').doc(tripId).collection('calls').doc().id;
    final session = CallSession._(
        tripId: tripId, callId: callId, role: CallRole.caller,
        myUid: myUid, otherUid: otherUid);
    await session._init();
    await session._sendOffer();
    return session;
  }

  /// Prepares to answer an already-ringing call. Call [acceptIncoming] once
  /// the user taps accept, or [decline] if they reject it.
  static Future<CallSession> forIncoming({
    required String tripId,
    required String callId,
    required String myUid,
    required String otherUid,
  }) async {
    final session = CallSession._(
        tripId: tripId, callId: callId, role: CallRole.callee,
        myUid: myUid, otherUid: otherUid);
    await session._init();
    return session;
  }

  Future<void> _init() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      phase.value = CallPhase.failed;
      throw Exception('Izin mikrofon ditolak');
    }

    _pc = await createPeerConnection(_kIceServers);
    _localStream =
        await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    for (final track in _localStream!.getAudioTracks()) {
      _pc!.addTrack(track, _localStream!);
    }

    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _myCandidates.add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (phase.value != CallPhase.connected) {
          _timeoutTimer?.cancel();
          phase.value = CallPhase.connected;
          _startElapsedTimer();
        }
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (phase.value != CallPhase.ended && phase.value != CallPhase.declined) {
          phase.value = CallPhase.failed;
        }
      }
    };

    _candidatesSub = _otherCandidates.snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final d = change.doc.data();
        if (d == null) continue;
        _pc!.addCandidate(RTCIceCandidate(
            d['candidate'] as String,
            d['sdpMid'] as String?,
            d['sdpMLineIndex'] as int?));
      }
    });
  }

  Future<void> _sendOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _callDoc.set({
      'callerId': myUid,
      'calleeId': otherUid,
      'status': 'ringing',
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'createdAt': FieldValue.serverTimestamp(),
    });
    phase.value = CallPhase.ringing;
    _startConnectionTimeout(); // fail if callee never answers

    _docSub = _callDoc.snapshots().listen((doc) async {
      final d = doc.data();
      if (d == null) return;
      final status = d['status'] as String?;
      if (status == 'declined') {
        phase.value = CallPhase.declined;
        await _cleanupPeer();
      } else if (status == 'ended') {
        if (phase.value != CallPhase.ended) {
          phase.value = CallPhase.ended;
          await _cleanupPeer();
        }
      } else if (status == 'accepted' && d['answer'] != null && !_remoteDescSet) {
        _remoteDescSet = true;
        phase.value = CallPhase.connecting;
        final ans = Map<String, dynamic>.from(d['answer'] as Map);
        await _pc!.setRemoteDescription(
            RTCSessionDescription(ans['sdp'] as String, ans['type'] as String));
      }
    });
  }

  Future<void> acceptIncoming() async {
    final doc = await _callDoc.get();
    final d = doc.data();
    if (d == null || d['offer'] == null) {
      phase.value = CallPhase.failed;
      throw Exception('Panggilan tidak ditemukan');
    }
    final offer = Map<String, dynamic>.from(d['offer'] as Map);
    await _pc!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'] as String, offer['type'] as String));
    _remoteDescSet = true;

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await _callDoc.update({
      'status': 'accepted',
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
    phase.value = CallPhase.connecting;
    _startConnectionTimeout(); // fail if media never connects

    _docSub = _callDoc.snapshots().listen((doc) async {
      final d = doc.data();
      if (d == null) return;
      if (d['status'] == 'ended' && phase.value != CallPhase.ended) {
        phase.value = CallPhase.ended;
        await _cleanupPeer();
      }
    });
  }

  Future<void> decline() async {
    try {
      await _callDoc.update({'status': 'declined'});
    } catch (_) {}
    phase.value = CallPhase.declined;
    await _cleanupPeer();
  }

  Future<void> hangUp() async {
    try {
      await _callDoc.update({'status': 'ended'});
    } catch (_) {}
    phase.value = CallPhase.ended;
    await _cleanupPeer();
  }

  void toggleMute() {
    if (_localStream == null) return;
    final newMuted = !isMuted.value;
    for (final t in _localStream!.getAudioTracks()) {
      t.enabled = !newMuted;
    }
    isMuted.value = newMuted;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value++;
    });
  }

  Future<void> _cleanupPeer() async {
    _timeoutTimer?.cancel();
    _elapsedTimer?.cancel();
    await _docSub?.cancel();
    await _candidatesSub?.cancel();
    for (final t in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await t.stop();
    }
    await _localStream?.dispose();
    await _pc?.close();
    await _pc?.dispose();
  }

  Future<void> dispose() async {
    await _cleanupPeer();
    phase.dispose();
    elapsedSeconds.dispose();
    isMuted.dispose();
  }
}

class CallService {
  CallService._();
  static final instance = CallService._();

  /// Emits the current ringing call addressed to [myUid] for this trip (as
  /// a map including 'callId'), or null when there isn't one. Filters only
  /// on `calleeId` server-side and checks `status` client-side, matching
  /// this project's existing no-composite-index convention.
  Stream<Map<String, dynamic>?> watchIncomingCall({
    required String tripId,
    required String myUid,
  }) {
    return FirebaseFirestore.instance
        .collection('trips').doc(tripId).collection('calls')
        .where('calleeId', isEqualTo: myUid)
        .snapshots()
        .map((snap) {
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['status'] == 'ringing') return {...d, 'callId': doc.id};
      }
      return null;
    });
  }
}
