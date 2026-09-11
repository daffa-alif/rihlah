import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../router.dart';

class DriverRequirementsScreen extends StatefulWidget {
  const DriverRequirementsScreen({super.key});

  @override
  State<DriverRequirementsScreen> createState() => _DriverRequirementsScreenState();
}

class _DriverRequirementsScreenState extends State<DriverRequirementsScreen> {
  bool _isAgreed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Pendaftaran Driver'),
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
                  Text(
                    'Siapkan Dokumen Berikut',
                    style: AppTypography.h2.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Pastikan kamu memiliki dokumen asli dan masih berlaku untuk memperlancar proses verifikasi.',
                    style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  // List Persyaratan
                  _RequirementItem(
                    icon: Icons.badge_rounded,
                    title: 'e-KTP Asli',
                    subtitle: 'Wajib KTP elektronik asli, bukan fotokopi atau resi.',
                  ),
                  _RequirementItem(
                    icon: Icons.card_membership_rounded,
                    title: 'SIM C / SIM A Aktif',
                    subtitle: 'Sesuai dengan jenis layanan yang didaftarkan.',
                  ),
                  _RequirementItem(
                    icon: Icons.description_rounded,
                    title: 'STNK Kendaraan',
                    subtitle: 'Pajak kendaraan dalam keadaan hidup/aktif.',
                  ),
                  _RequirementItem(
                    icon: Icons.gpp_good_rounded,
                    title: 'SKCK Aktif',
                    subtitle: 'Surat Keterangan Catatan Kepolisian yang masih berlaku.',
                  ),

                  const SizedBox(height: AppSpacing.s24),
                  const Divider(),
                  const SizedBox(height: AppSpacing.s16),

                  Text(
                    'Informasi Penting',
                    style: AppTypography.h3.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Data kamu akan dienkripsi dan disimpan dengan aman sesuai dengan kebijakan privasi RIHLAH. Kami tidak akan menyalahgunakan data pribadi kamu.',
                    style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // Persetujuan & Tombol Lanjut
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: AppElevation.floating,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: _isAgreed,
                    onChanged: (val) => setState(() => _isAgreed = val ?? false),
                    title: Text(
                      'Saya menyetujui Syarat & Ketentuan serta Kebijakan Privasi RIHLAH',
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary500,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isAgreed
                          ? () => context.push('/d/register/ktp-cam') // Rute ke kamera
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: AppColors.ink0,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      child: Text(
                        'Mulai Foto e-KTP',
                        style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  const _RequirementItem({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary500.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary500, size: 24),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}