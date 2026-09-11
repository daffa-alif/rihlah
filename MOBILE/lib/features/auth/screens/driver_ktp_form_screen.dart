import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';

class DriverKtpFormScreen extends StatefulWidget {
  const DriverKtpFormScreen({super.key});

  @override
  State<DriverKtpFormScreen> createState() => _DriverKtpFormScreenState();
}

class _DriverKtpFormScreenState extends State<DriverKtpFormScreen> {
  // Field Form yang sudah diisi secara otomatis (Dummy Data)
  final _nikCtrl = TextEditingController(text: '3273012345678901');
  final _nameCtrl = TextEditingController(text: 'Rofiif Nabil Syafaqoh');
  final _birthCtrl = TextEditingController(text: 'Bandung, 17-08-2005');
  final _addressCtrl = TextEditingController(text: 'Jl. Krakatau Raya No. 12, Ciomas');

  @override
  void dispose() {
    _nikCtrl.dispose();
    _nameCtrl.dispose();
    _birthCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Konfirmasi Data KTP'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.success500.withValues(alpha: 0.1),
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: AppColors.success500),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success500),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Text(
                            'Pemindaian berhasil! Periksa kembali data di bawah ini jika ada yang keliru.',
                            style: AppTypography.bodySm.copyWith(color: AppColors.success500, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  _buildTextField('Nomor Induk Kependudukan (NIK)', _nikCtrl, TextInputType.number),
                  const SizedBox(height: AppSpacing.s16),
                  _buildTextField('Nama Lengkap (Sesuai KTP)', _nameCtrl, TextInputType.name),
                  const SizedBox(height: AppSpacing.s16),
                  _buildTextField('Tempat, Tanggal Lahir', _birthCtrl, TextInputType.text),
                  const SizedBox(height: AppSpacing.s16),
                  _buildTextField('Alamat Lengkap', _addressCtrl, TextInputType.streetAddress, maxLines: 3),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Arahkan ke layar pengenalan wajah milikmu!
                    // Sesuaikan string rutenya dengan rute Face Recognition kamu
                    context.pushNamed('dummy-face-rec');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: AppColors.ink0,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: Text(
                    'Lanjut ke Pengenalan Wajah',
                    style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, TextInputType type, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.s8),
        TextFormField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}