import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class FaceRecDummyScreen extends StatefulWidget {
  const FaceRecDummyScreen({super.key});

  @override
  State<FaceRecDummyScreen> createState() => _FaceRecDummyScreenState();
}

class _FaceRecDummyScreenState extends State<FaceRecDummyScreen> {
  int _stepIndex = 0;
  bool _isScanning = false;

  // Daftar urutan instruksi liveness detection
  final List<String> _instructions = [
    "Posisikan wajah Anda di dalam bingkai",
    "Tengok ke kiri",
    "Tengok ke kanan",
    "Tengok ke atas",
    "Tengok ke bawah",
    "Berikan senyuman terbaik Anda 😃",
    "Kedipkan mata 😉",
    "Verifikasi Berhasil!"
  ];

  void _startLivenessTest() async {
    setState(() {
      _isScanning = true;
      _stepIndex = 0;
    });

    // Melakukan perulangan (loop) untuk mengganti teks setiap 2 detik
    for (int i = 0; i < _instructions.length; i++) {
      if (!mounted) return;

      setState(() {
        _stepIndex = i;
      });

      // Jeda waktu sebelum lanjut ke instruksi berikutnya
      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted) return;

    // Setelah semua urutan selesai, arahkan ke beranda Driver
    context.goNamed('d-home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Tema gelap khas layar kamera pemindai
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Liveness Detection', style: TextStyle(fontSize: 18)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Teks Instruksi Dinamis
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              // AnimatedSwitcher memberikan efek transisi halus saat teks berubah
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _instructions[_stepIndex],
                  key: ValueKey<int>(_stepIndex),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // 2. Viewfinder Kamera (Bentuk Oval)
            Center(
              child: Container(
                width: 280,
                height: 380,
                decoration: BoxDecoration(
                  // Area ini nantinya bisa diganti dengan widget CameraPreview()
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(150), // Membuatnya oval
                  border: Border.all(
                    color: _isScanning ? Colors.greenAccent : Colors.white38,
                    width: 4,
                  ),
                  boxShadow: [
                    if (_isScanning)
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isScanning)
                      const Icon(
                        Icons.face_retouching_natural,
                        size: 100,
                        color: Colors.white24,
                      ),
                    if (_isScanning)
                    // Efek visual seolah sedang memindai wajah
                      const CircularProgressIndicator(
                        color: Colors.greenAccent,
                        strokeWidth: 3,
                      ),
                  ],
                ),
              ),
            ),

            // 3. Tombol Aksi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _startLivenessTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isScanning ? 'Menganalisis Wajah...' : 'Mulai Kamera',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}