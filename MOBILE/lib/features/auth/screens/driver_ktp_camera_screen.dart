import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';

class DriverKtpCameraScreen extends StatefulWidget {
  const DriverKtpCameraScreen({super.key});

  @override
  State<DriverKtpCameraScreen> createState() => _DriverKtpCameraScreenState();
}

class _DriverKtpCameraScreenState extends State<DriverKtpCameraScreen> {
  bool _isProcessing = false;

  void _onCapture() async {
    setState(() => _isProcessing = true);

    // Simulasi waktu proses pemindaian OCR KTP
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      // PASTIKAN BARIS INI MENGARAH KE FORM KTP, BUKAN KE FACE REC!
      context.pushReplacement('/d/register/ktp-form');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink0),
        title: Text('Foto e-KTP', style: AppTypography.bodyLg.copyWith(color: AppColors.ink0)),
      ),
      body: _isProcessing
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary500),
            const SizedBox(height: 24),
            Text('Memindai data KTP...', style: AppTypography.bodyMd.copyWith(color: AppColors.ink0)),
          ],
        ),
      )
          : Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Icon(Icons.camera_alt_outlined, color: AppColors.ink0.withValues(alpha: 0.2), size: 100),
            ),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.width * 0.85 * 0.63,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary500, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Posisikan KTP di dalam kotak',
                  style: AppTypography.bodySm.copyWith(color: AppColors.ink0.withValues(alpha: 0.8)),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _onCapture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink0, width: 4),
                    color: AppColors.primary500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}