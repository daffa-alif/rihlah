import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/core.dart';
import '../../../router.dart';
import '../../../core/helpers/role_switcher.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rihlah/l10n/app_localizations.dart';
import 'package:rihlah/core/providers/locale_provider.dart';
import 'package:rihlah/core/providers/theme_mode_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../data/models/trip_model.dart' hide TripStatus;
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/widgets/version_tap_trigger.dart';
import '../../../data/models/user_model.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onDocs() => context.push(Routes.dProfileDocs);
  void _onLanguage() => LanguagePickerSheet.show(context);
  void _onHelp() => Toast.show(context, message: 'Pusat bantuan segera hadir', type: ToastType.info);

  void _onSwitchRole() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _SwitchSheet(
        onConfirm: () async {
          Navigator.pop(context);
          await switchRole(context, toRole: 'passenger', targetRoute: Routes.pHome);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _onSignOut() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _SignOutSheet(
        onConfirm: () async {
          final box = Hive.box('settings');
          await box.delete('authed');
          await box.delete('role');
          if (!mounted) return;
          Navigator.pop(context);
          context.go(Routes.onboarding);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'D';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final langLabel = locale.languageCode == 'en' ? 'English' : 'Bahasa Indonesia';
    final profile = ref.watch(userProfileProvider).value;

    final driverName = (profile != null && profile.name.isNotEmpty) ? profile.name : 'Driver';
    final initials = _getInitials(driverName);

    final vehicleType = profile?.vehicleType ?? 'bike';
    final vehicleIcon = vehicleType == 'bike' ? Icons.motorcycle_rounded : Icons.directions_car_rounded;
    final vehicleName = vehicleType == 'bike' ? 'Motor' : 'Mobil';
    final plate = (profile?.plate != null && profile!.plate!.isNotEmpty) ? profile.plate! : 'Belum diatur';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Header (Konsisten dengan halaman lain)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                    color: AppColors.ink0,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                ),
                child: Center(
                  child: Text(
                    'RIHLAH Driver Console',
                    style: AppTypography.h3.copyWith(
                      color: const Color(0xFF1B6B4D),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // 2. Konten Utama
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Kartu Profil
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: AppColors.ink0,
                          borderRadius: AppRadius.xlAll,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1B6B4D),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: AppTypography.h1.copyWith(color: AppColors.ink0, fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driverName, style: AppTypography.h3.copyWith(color: const Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(vehicleIcon, size: 14, color: AppColors.ink500),
                                    const SizedBox(width: 6),
                                    Text(vehicleName, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: AppRadius.pillAll,
                                  ),
                                  child: Text(plate, style: AppTypography.mono.copyWith(fontWeight: FontWeight.w700, fontSize: 11, color: const Color(0xFF0F172A))),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Kartu Rating (StreamBuilder)
                    StreamBuilder<List<TripModel>>(
                      stream: FirestoreService.instance.driverTripsStream(FirebaseAuth.instance.currentUser?.uid ?? ''),
                      builder: (context, snapshot) {
                        final allTrips = snapshot.data ?? [];

                        // Cari trip yang sudah selesai dan memiliki rating dari penumpang
                        final ratedTrips = allTrips
                            .where((t) => t.status.toString().split('.').last == 'completed' && t.passengerRating != null)
                            .toList();

                        // Hitung rata-rata rating secara dinamis
                        final dynamicRating = ratedTrips.isEmpty
                            ? 0.0
                            : ratedTrips.fold(0.0, (sum, t) => sum + (t.passengerRating ?? 0)) / ratedTrips.length;

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.ink0,
                            borderRadius: AppRadius.xlAll,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Rating', style: AppTypography.h3.copyWith(color: const Color(0xFF0F172A))),
                                  const Icon(Icons.star_outline_rounded, color: Color(0xFF22C55E), size: 28),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(dynamicRating > 0 ? dynamicRating.toStringAsFixed(1) : '0.0', style: AppTypography.h1.copyWith(fontSize: 42, color: const Color(0xFF1B6B4D))),
                                  const SizedBox(width: 4),
                                  Text('/ 5.0', style: AppTypography.bodyMd.copyWith(color: AppColors.ink500)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: AppRadius.mdAll,
                                ),
                                child: Center(
                                  child: Text('30-Day Trend', style: AppTypography.bodySm.copyWith(color: AppColors.ink400)),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Kartu Dokumen KYC & BPJS
                    GestureDetector(
                      onTap: _onDocs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: AppRadius.lgAll,
                          border: const Border(left: BorderSide(color: Color(0xFF1B6B4D), width: 6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.health_and_safety_outlined, color: Color(0xFF1B6B4D), size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Dokumen KYC dan BPJS', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: AppRadius.pillAll,
                              ),
                              child: Text('Aktif', style: AppTypography.label.copyWith(color: AppColors.ink0, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pengaturan Tambahan
                    Text('Pengaturan Lainnya', style: AppTypography.label.copyWith(color: AppColors.ink500)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.ink0,
                        borderRadius: AppRadius.lgAll,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _SettingsItem(
                            icon: Icons.language_rounded,
                            iconBg: const Color(0xFFE3F2FD),
                            iconColor: AppColors.info500,
                            label: s.profile_language,
                            trailing: Text(langLabel, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                            onTap: _onLanguage,
                          ),
                          const Divider(height: 1, indent: 56),
                          _SettingsItem(
                            icon: Icons.dark_mode_rounded,
                            iconBg: const Color(0xFF1E293B),
                            iconColor: AppColors.ink300,
                            label: s.profile_dark_mode,
                            showChevron: false,
                            trailing: Switch(
                              value: ref.watch(themeModeProvider.notifier).isDark,
                              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                              activeColor: const Color(0xFF1B6B4D),
                            ),
                            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                          ),
                          const Divider(height: 1, indent: 56),
                          _SettingsItem(
                            icon: Icons.help_outline_rounded,
                            iconBg: const Color(0xFFFFF3E0),
                            iconColor: AppColors.accent500,
                            label: s.profile_help,
                            onTap: _onHelp,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const VersionTapTrigger(),
                    const SizedBox(height: 24),

                    // Tombol Keluar (Di Paling Bawah)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _onSignOut,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text('Keluar', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger500,
                          side: const BorderSide(color: AppColors.danger500),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // 3. Bottom Nav
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.ink0,
                  border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
                ),
                child: _DriverBottomNav(
                    currentIndex: 3,
                    onTap: (i) {
                      if (i == 0) context.go(Routes.dHome);
                      if (i == 1) context.push(Routes.dEarnings);
                      if (i == 2) context.push(Routes.dHistory);
                    }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Komponen UI ──────────────────────────────────────────────────────────────

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.showChevron = true,
    required this.onTap,
  });

  final IconData icon;
  final Color    iconBg;
  final Color    iconColor;
  final String   label;
  final Widget?  trailing;
  final bool     showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: AppRadius.smAll),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(label, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500, color: const Color(0xFF0F172A))),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 4),
            ],
            if (showChevron)
              const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

// ── Sheets ────────────────────────────────────────────────────────────────────

class _SwitchSheet extends StatelessWidget {
  const _SwitchSheet({required this.onConfirm, required this.onCancel});
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Beralih ke mode penumpang?', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Kamu akan masuk sebagai penumpang. Bisa kembali ke mode driver kapan saja.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.s24),
            RihlahButton(label: 'Ya, beralih ke penumpang', onPressed: onConfirm),
            const SizedBox(height: AppSpacing.s8),
            RihlahButton(label: 'Batal', variant: RihlahButtonVariant.secondary, onPressed: onCancel),
          ],
        ),
      ),
    );
  }
}

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet({required this.onConfirm, required this.onCancel});
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Keluar dari RIHLAH?', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Kamu harus login kembali untuk mulai berkendara.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.s24),
            RihlahButton(label: 'Keluar', variant: RihlahButtonVariant.danger, onPressed: onConfirm),
            const SizedBox(height: AppSpacing.s8),
            RihlahButton(label: 'Batal', variant: RihlahButtonVariant.secondary, onPressed: onCancel),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Nav Konsisten ──────────────────────────────────────────────────────

class _DriverBottomNav extends StatelessWidget {
  const _DriverBottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Earnings'),
    (Icons.history_rounded, Icons.history_outlined, 'History'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: List.generate(_items.length, (i) {
            final (activeIcon, inactiveIcon, label) = _items[i];
            final isActive = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: isActive ? BoxDecoration(color: const Color(0xFF22C55E), borderRadius: AppRadius.pillAll) : null,
                      child: Icon(isActive ? activeIcon : inactiveIcon, size: 24, color: isActive ? AppColors.ink0 : AppColors.ink500),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: AppTypography.bodySm.copyWith(fontSize: 10, color: isActive ? const Color(0xFF22C55E) : AppColors.ink500, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Docs Screen Dipertahankan (Dipanggil dari Kartu Dokumen KYC) ──────────────

const _bpjsStatusMeta = {
  'active': ('Aktif', AppColors.success500),
  'expired': ('Kedaluwarsa', AppColors.danger500),
  'not_registered': ('Belum Terdaftar', AppColors.ink400),
};

class DriverDocsScreen extends StatefulWidget {
  const DriverDocsScreen({super.key});

  @override
  State<DriverDocsScreen> createState() => _DriverDocsScreenState();
}

class _DriverDocsScreenState extends State<DriverDocsScreen> {
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final user = uid == null ? null : await FirestoreService.instance.getUser(uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _openEditSheet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditDriverDocsSheet(uid: uid, user: _user),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u  = _user;
    final docs = [
      (
      Icons.credit_card_rounded,
      'KTP',
      u?.ktpNumberMasked?.isNotEmpty == true
          ? 'NIK •••• •••• ${u!.ktpNumberMasked}'
          : 'Belum diisi',
      ),
      (
      Icons.directions_car_rounded,
      'Kendaraan',
      u?.plate?.isNotEmpty == true
          ? '${u!.vehicleType == 'bike' ? 'Motor' : 'Mobil'} · Plat ${u.plate}'
          : 'Belum diisi',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Dokumen KYC', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: cs.onSurface),
            onPressed: _loading ? null : _openEditSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.success500.withOpacity(0.08),
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                  color: AppColors.success500.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.success500, size: 20),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    'Semua dokumen terverifikasi. Akun kamu dalam kondisi baik.',
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.success500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              children: [
                for (int i = 0; i < docs.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: AppSpacing.s16),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary100,
                            borderRadius: AppRadius.smAll,
                          ),
                          child: Icon(docs[i].$1,
                              size: 18, color: AppColors.primary500),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(docs[i].$2,
                                  style: AppTypography.bodyMd.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                              Text(docs[i].$3,
                                  style: AppTypography.bodySm
                                      .copyWith(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success500.withOpacity(0.1),
                            borderRadius: AppRadius.pillAll,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 10,
                                  color: AppColors.success500),
                              const SizedBox(width: 3),
                              Text('APPROVED',
                                  style: AppTypography.label.copyWith(
                                      color: AppColors.success500,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ── BPJS & Insurance ─────────────────────────────────────────────
          const SizedBox(height: AppSpacing.s24),
          Text(
            'Kepatuhan & Asuransi',
            style: AppTypography.label.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.s8),
          _BpjsCard(
            icon: Icons.health_and_safety_rounded,
            name: 'BPJS Ketenagakerjaan',
            statusKey: u?.bpjsKt ?? 'not_registered',
            detail: 'Perlindungan kecelakaan kerja & jaminan hari tua',
            portalUrl: 'https://www.bpjsketenagakerjaan.go.id',
          ),
          const SizedBox(height: AppSpacing.s8),
          _BpjsCard(
            icon: Icons.local_hospital_rounded,
            name: 'BPJS Kesehatan',
            statusKey: u?.bpjsKs ?? 'not_registered',
            detail: 'Jaminan kesehatan nasional (JKN)',
            portalUrl: 'https://www.bpjs-kesehatan.go.id',
          ),
          const SizedBox(height: AppSpacing.s8),
          _BpjsCard(
            icon: Icons.security_rounded,
            name: 'Asuransi Perpres 27/2026',
            statusKey: u?.bpjsInsurance ?? 'not_registered',
            detail: 'Proteksi kecelakaan mitra RIHLAH',
            portalUrl: 'https://rihlah.id/insurance',
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.info500.withOpacity(0.08),
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.info500.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    size: 16, color: AppColors.info500),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'RIHLAH mengingatkan 14 hari sebelum kartu keanggotaan habis.',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.info500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BpjsCard extends StatelessWidget {
  const _BpjsCard({
    required this.icon,
    required this.name,
    required this.statusKey,
    required this.detail,
    required this.portalUrl,
  });
  final IconData icon;
  final String   name, statusKey, detail, portalUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = _bpjsStatusMeta[statusKey] ?? _bpjsStatusMeta['not_registered']!;
    final (statusLabel, statusColor) = meta;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(icon, size: 20, color: statusColor),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600, color: cs.onSurface)),
                  Text(detail,
                      style: AppTypography.bodySm
                          .copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          statusKey == 'active'
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 10, color: statusColor),
                      const SizedBox(width: 3),
                      Text(statusLabel.toUpperCase(),
                          style: AppTypography.label.copyWith(
                              color: statusColor, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(portalUrl)),
                  child: Text('Lihat portal →',
                      style: AppTypography.bodySm.copyWith(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleTypeOption extends StatelessWidget {
  const _VehicleTypeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary100 : AppColors.ink0,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.ink300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 28,
                color: selected ? AppColors.primary500 : AppColors.ink500),
            const SizedBox(height: AppSpacing.s8),
            Text(label,
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary600 : AppColors.ink500,
                )),
          ],
        ),
      ),
    );
  }
}

class _EditDriverDocsSheet extends StatefulWidget {
  const _EditDriverDocsSheet({required this.uid, required this.user});
  final String uid;
  final UserModel? user;

  @override
  State<_EditDriverDocsSheet> createState() => _EditDriverDocsSheetState();
}

class _EditDriverDocsSheetState extends State<_EditDriverDocsSheet> {
  late final _plateCtrl = TextEditingController(text: widget.user?.plate ?? '');
  late final _ktpCtrl =
  TextEditingController(text: widget.user?.ktpNumberMasked ?? '');
  late String _vehicleType = widget.user?.vehicleType ?? 'car';
  late String _bpjsKt = widget.user?.bpjsKt ?? 'not_registered';
  late String _bpjsKs = widget.user?.bpjsKs ?? 'not_registered';
  late String _bpjsInsurance = widget.user?.bpjsInsurance ?? 'not_registered';
  bool _saving = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    _ktpCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.updateDriverProfile(
        widget.uid,
        vehicleType: _vehicleType,
        plate: _plateCtrl.text.trim(),
        ktpNumberMasked: _ktpCtrl.text.trim(),
        bpjsKt: _bpjsKt,
        bpjsKs: _bpjsKs,
        bpjsInsurance: _bpjsInsurance,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        Toast.show(context, message: 'Gagal menyimpan. Coba lagi.', type: ToastType.danger);
      }
    }
  }

  Widget _statusDropdown(String label, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
      ),
      items: const [
        DropdownMenuItem(value: 'active', child: Text('Aktif')),
        DropdownMenuItem(value: 'expired', child: Text('Kedaluwarsa')),
        DropdownMenuItem(value: 'not_registered', child: Text('Belum Terdaftar')),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Dokumen & Kendaraan', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: _VehicleTypeOption(
                      icon: Icons.directions_car_rounded,
                      label: 'Mobil',
                      selected: _vehicleType == 'car',
                      onTap: () => setState(() => _vehicleType = 'car'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: _VehicleTypeOption(
                      icon: Icons.two_wheeler_rounded,
                      label: 'Motor',
                      selected: _vehicleType == 'bike',
                      onTap: () => setState(() => _vehicleType = 'bike'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: _plateCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Plat nomor',
                  hintText: 'D 1234 ABC',
                  border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _ktpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: '4 digit terakhir NIK',
                  border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              _statusDropdown('BPJS Ketenagakerjaan', _bpjsKt, (v) => setState(() => _bpjsKt = v)),
              const SizedBox(height: AppSpacing.s12),
              _statusDropdown('BPJS Kesehatan', _bpjsKs, (v) => setState(() => _bpjsKs = v)),
              const SizedBox(height: AppSpacing.s12),
              _statusDropdown('Asuransi Perpres 27/2026', _bpjsInsurance, (v) => setState(() => _bpjsInsurance = v)),
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: AppColors.ink0,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.ink0, strokeWidth: 2.5))
                      : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}