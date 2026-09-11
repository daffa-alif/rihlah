// lib/core/services/voice_guidance_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';

class VoiceGuidanceService {
  VoiceGuidanceService._();
  static final instance = VoiceGuidanceService._();

  final _tts     = FlutterTts();
  bool  _ready   = false;
  bool  _enabled = true;

  // Penanda untuk mengetahui apakah TTS menggunakan logat Indonesia
  bool _isIndonesian = false;

  static const _hiveKey = 'voice_guidance_enabled';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_ready) return;

    final box = Hive.box('settings');
    _enabled  = box.get(_hiveKey, defaultValue: true) as bool;

    // Prefer Google TTS engine (lebih natural untuk id-ID)
    try {
      await _tts.setEngine('com.google.android.tts');
    } catch (_) {
      // Engine lain jika Google TTS tidak ada
    }

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.45); // sedikit lebih lambat agar jelas
    await _tts.setPitch(1.0);

    // Cek dulu bahasa yang tersedia sebelum set
    final langs = await _tts.getLanguages as List? ?? [];
    final langStrs = langs.map((l) => l.toString().toLowerCase()).toList();

    // Coba id-ID → id → in-ID → fallback en-US
    if (langStrs.any((l) => l == 'id-id')) {
      await _tts.setLanguage('id-ID');
      _isIndonesian = true;
      debugPrint('=== TTS: menggunakan id-ID');
    } else if (langStrs.any((l) => l.startsWith('id'))) {
      final idLang = langs.firstWhere(
              (l) => l.toString().toLowerCase().startsWith('id'));
      await _tts.setLanguage(idLang.toString());
      _isIndonesian = true;
      debugPrint('=== TTS: menggunakan $idLang');
    } else if (langStrs.any((l) => l.startsWith('in'))) {
      final inLang = langs.firstWhere(
              (l) => l.toString().toLowerCase().startsWith('in'));
      await _tts.setLanguage(inLang.toString());
      _isIndonesian = true;
      debugPrint('=== TTS: menggunakan $inLang');
    } else {
      await _tts.setLanguage('en-US');
      _isIndonesian = false;
      debugPrint('=== TTS: id-ID tidak tersedia, fallback en-US');
    }

    _ready = true;
  }

  // ── Toggle ────────────────────────────────────────────────────────────────

  bool get isEnabled => _enabled;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    Hive.box('settings').put(_hiveKey, value);
    if (!value) {
      await _tts.stop();
    } else {
      // Re-init jika belum ready
      if (!_ready) await init();
    }
  }

  Future<void> toggle() => setEnabled(!_enabled);

  // ── Translation (Kamus Terjemahan OSRM) ───────────────────────────────────

  /// Menerjemahkan teks bahasa Inggris dari OSRM ke Bahasa Indonesia
  String _translateInstruction(String text) {
    String translated = text.toLowerCase();

    final map = {
      'turn left': 'belok kiri',
      'turn right': 'belok kanan',
      'turn slight left': 'belok sedikit ke kiri',
      'turn slight right': 'belok sedikit ke kanan',
      'turn sharp left': 'belok tajam ke kiri',
      'turn sharp right': 'belok tajam ke kanan',
      'continue straight': 'terus lurus',
      'continue': 'terus lurus',
      'head': 'menuju',
      'north': 'utara',
      'south': 'selatan',
      'east': 'timur',
      'west': 'barat',
      'make a u-turn': 'putar balik',
      'roundabout': 'bundaran',
      'exit': 'jalan keluar',
      'arrive': 'anda telah tiba',
      'destination': 'tujuan',
      'meters': 'meter',
      'kilometers': 'kilometer',
      'km': 'kilometer',
      'm': 'meter',
      'in': 'dalam',
    };

    map.forEach((eng, ind) {
      translated = translated.replaceAll(eng, ind);
    });

    return translated;
  }

  // ── Speak ─────────────────────────────────────────────────────────────────

  Future<void> speak(String text) async {
    if (!_enabled) return;
    if (!_ready) await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Instruksi navigasi — diterjemahkan terlebih dahulu jika TTS menggunakan logat Indonesia.
  Future<void> speakInstruction(String instruction) {
    String finalSpeech = instruction;

    // Syarat MVP Audit D-S3 dipenuhi di sini
    if (_isIndonesian) {
      finalSpeech = _translateInstruction(instruction);
    }

    return speak(finalSpeech);
  }

  /// Pengumuman penting — prefix "Perhatian".
  Future<void> speakAlert(String message) =>
      speak('Perhatian. $message');

  Future<void> stop() => _tts.stop();

  void dispose() {
    _tts.stop();
  }
}