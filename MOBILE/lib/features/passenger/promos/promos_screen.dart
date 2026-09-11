import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../core/providers/voucher_provider.dart';
import '../../../data/models/promo_model.dart';
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';

class PromosScreen extends ConsumerWidget {
  const PromosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs       = Theme.of(context).colorScheme;
    final promos   = ref.watch(promosProvider).value ?? const <PromoModel>[];
    ref.watch(voucherProvider); // rebuild when saved/used state changes
    final notifier = ref.read(voucherProvider.notifier);
    final saved    = notifier.savedOf(promos);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Promo & Voucher', style: AppTypography.h3),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                // ── Banner ───────────────────────────────
                const _PromoBanner(),
                const SizedBox(height: AppSpacing.s24),

                // ── Saved vouchers ────────────────────────
                if (saved.isNotEmpty) ...[
                  Text('VOUCHER TERSIMPAN',
                      style: AppTypography.label
                          .copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.s12),
                  ...saved.map((v) => Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.s12),
                        child: _VoucherCard(
                          voucher   : v,
                          isSaved   : true,
                          onSave    : () => context.push(Routes.pSearch),
                          saveLabel : 'Gunakan',
                        ),
                      )),
                  const SizedBox(height: AppSpacing.s24),
                ],

                // ── Empty state ───────────────────────────
                if (saved.isEmpty)
                  _EmptyVouchers(),

                // ── How to use ───────────────────────────
                Text('CARA PAKAI',
                    style: AppTypography.label
                        .copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.s12),
                const _HowToUse(),
                const SizedBox(height: AppSpacing.s32),
              ],
            ),
          ),
          const Divider(height: 1),
          _BottomNav(currentIndex: 2),
        ],
      ),
    );
  }
}

// ── Promo banner ──────────────────────────────────────────────────────────────

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary500, AppColors.primary600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.ink0.withOpacity(0.2),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text('SPECIAL OFFER',
                      style: AppTypography.label.copyWith(
                          color: AppColors.ink0, fontSize: 10)),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text('Hemat lebih banyak\ndengan RIHLAH',
                    style: AppTypography.h2
                        .copyWith(color: AppColors.ink0)),
                const SizedBox(height: AppSpacing.s4),
                Text('Simpan voucher sekarang\nsebelum kehabisan',
                    style: AppTypography.bodySm.copyWith(
                        color: AppColors.ink0.withOpacity(0.8))),
              ],
            ),
          ),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.ink0.withOpacity(0.15),
              borderRadius: AppRadius.lgAll,
            ),
            child: const Icon(Icons.card_giftcard_rounded,
                color: AppColors.accent500, size: 40),
          ),
        ],
      ),
    );
  }
}

// ── Voucher card ──────────────────────────────────────────────────────────────

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.voucher,
    required this.isSaved,
    required this.onSave,
    required this.saveLabel,
  });

  final PromoModel   voucher;
  final bool         isSaved;
  final VoidCallback onSave;
  final String       saveLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isSaved ? AppColors.primary500 : cs.outline,
          width: isSaved ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Top ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: isSaved
                        ? AppColors.primary100
                        : cs.surfaceContainerHighest,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(Icons.local_offer_rounded,
                      color: isSaved
                          ? AppColors.primary500
                          : cs.onSurfaceVariant,
                      size: 26),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(voucher.title,
                              style: AppTypography.bodyLg.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                          if (isSaved) ...[
                            const SizedBox(width: AppSpacing.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary100,
                                borderRadius: AppRadius.pillAll,
                              ),
                              child: Text('Tersimpan',
                                  style: AppTypography.label.copyWith(
                                      color: AppColors.primary600,
                                      fontSize: 10)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(voucher.description,
                          style: AppTypography.bodySm
                              .copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.s4),
                      Text(voucher.expiryLabel,
                          style: AppTypography.bodySm.copyWith(
                              color: AppColors.danger500,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _DashedDivider(color: cs.outline),

          // ── Bottom — kode + aksi ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16, AppSpacing.s12,
                AppSpacing.s16, AppSpacing.s12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text('Kode: ',
                          style: AppTypography.bodySm
                              .copyWith(color: cs.onSurfaceVariant)),
                      Text(voucher.code,
                          style: AppTypography.mono.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary600,
                          )),
                    ],
                  ),
                ),
                // Copy
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: voucher.code));
                    Toast.show(context,
                        message: 'Kode ${voucher.code} disalin',
                        type: ToastType.success);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: AppSpacing.s8),
                    child: Icon(Icons.copy_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                // Save / Hapus
                GestureDetector(
                  onTap: onSave,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: isSaved
                          ? AppColors.danger500.withOpacity(0.08)
                          : AppColors.primary100,
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(
                        color: isSaved
                            ? AppColors.danger500.withOpacity(0.3)
                            : AppColors.primary500.withOpacity(0.3),
                      ),
                    ),
                    child: Text(saveLabel,
                        style: AppTypography.label.copyWith(
                          color: isSaved
                              ? AppColors.danger500
                              : AppColors.primary600,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ],
            ),
          ),

          // Min order
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                bottomLeft : Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Center(
              child: Text(
                'Min. order ${_fmtIdr(voucher.minOrder)}',
                style: AppTypography.bodySm
                    .copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtIdr(int v) {
    final s      = v.toString();
    final buf    = StringBuffer('Rp ');
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Empty vouchers ────────────────────────────────────────────────────────────

class _EmptyVouchers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s32),
      child: Column(
        children: [
          Icon(Icons.card_giftcard_outlined,
              size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: AppSpacing.s16),
          Text('Tidak ada voucher tersedia',
              style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: AppSpacing.s8),
          Text('Voucher baru akan muncul di sini',
              style: AppTypography.bodySm
                  .copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Dashed divider ────────────────────────────────────────────────────────────

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Container(
            width: 10, height: 20,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(10)),
              border: Border(
                top   : BorderSide(color: color),
                right : BorderSide(color: color),
                bottom: BorderSide(color: color),
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
                painter: _DashPainter(color: color)),
          ),
          Container(
            width: 10, height: 20,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(10)),
              border: Border(
                top   : BorderSide(color: color),
                left  : BorderSide(color: color),
                bottom: BorderSide(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2),
          Offset(x + 6, size.height / 2), paint);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

// ── How to use ────────────────────────────────────────────────────────────────

class _HowToUse extends StatelessWidget {
  const _HowToUse();

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final steps = [
      (Icons.search_rounded,         'Pilih tujuan',
          'Masukkan lokasi penjemputan dan tujuan'),
      (Icons.directions_car_rounded, 'Pilih layanan',
          'Pilih Mobil, Motor, atau Kurir'),
      (Icons.card_giftcard_rounded,  'Masukkan kode',
          'Tap "Tambah voucher" saat konfirmasi'),
      (Icons.check_circle_rounded,   'Hemat!',
          'Diskon langsung dipotong dari tarif'),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(steps[i].$1,
                      size: 18, color: AppColors.primary500),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$2,
                          style: AppTypography.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface)),
                      Text(steps[i].$3,
                          style: AppTypography.bodySm.copyWith(
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  List<(IconData, IconData, String)> _buildItems(BuildContext ctx) {
    final s = AppLocalizations.of(ctx);
    return [
      (Icons.home_rounded,          Icons.home_outlined,          'home'),
      (Icons.receipt_long_rounded,  Icons.receipt_long_outlined,  'activity'),
      (Icons.card_giftcard_rounded, Icons.card_giftcard_outlined, 'promos'),
      (Icons.person_rounded,        Icons.person_outline_rounded, 'profile'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(context);
    return SafeArea(
      child: SizedBox(
        height: 64,
        child: Row(
          children: List.generate(items.length, (i) {
            final (activeIcon, inactiveIcon, label) = items[i];
            final isActive = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  switch (i) {
                    case 0:
                      while (context.canPop()) context.pop();
                    case 1: context.push(Routes.pActivity);
                    case 3: context.push(Routes.pProfile);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isActive ? activeIcon : inactiveIcon,
                      size: 24,
                      color: isActive
                          ? AppColors.primary500
                          : AppColors.ink500,
                    ),
                    const SizedBox(height: 2),
                    Text(label,
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: isActive
                              ? AppColors.primary500
                              : AppColors.ink500,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
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

extension on AppSpacing {
  static const s20 = 20.0;
}