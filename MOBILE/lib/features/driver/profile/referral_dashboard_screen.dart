// lib/features/driver/profile/referral_dashboard_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/core.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/referral_service.dart';

class ReferralDashboardScreen extends StatefulWidget {
  const ReferralDashboardScreen({super.key});
  @override
  State<ReferralDashboardScreen> createState() =>
      _ReferralDashboardScreenState();
}

class _ReferralDashboardScreenState
    extends State<ReferralDashboardScreen> {
  String            _driverId   = 'driver-001';
  String            _driverName = '';
  String            _code       = '';
  bool              _copied     = false;
  UsedReferralInfo? _usedCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final driverId = FirebaseAuth.instance.currentUser?.uid;
    if (driverId == null) return;
    final profile = await FirestoreService.instance.getUser(driverId);
    final driverName = (profile != null && profile.name.isNotEmpty)
        ? profile.name : 'Driver';

    ReferralService.instance.seedReferralData(driverId, driverName);

    if (!mounted) return;
    setState(() {
      _driverId   = driverId;
      _driverName = driverName;
      _code       = ReferralService.instance
          .getOrCreateCode(driverId, driverName);
      _usedCode   = ReferralService.instance.getUsedCode(driverId);
    });
  }

  void _onCopy() {
    Clipboard.setData(ClipboardData(text: _code));
    setState(() => _copied = true);
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(seconds: 2),
        () { if (mounted) setState(() => _copied = false); });
  }

  void _onShare() {
    Share.share(
      'Gabung jadi driver RIHLAH dan langsung dapat bonus trip! 🎉\n\n'
      'Daftar pakai kode referral aku: *$_code*\n\n'
      '• Selesaikan 20 perjalanan pertama\n'
      '• Kamu dapat Rp 15.000 bonus\n'
      '• Aku juga dapat Rp 25.000 bonus\n\n'
      'Download RIHLAH: https://rihlah.id/driver',
    );
  }

  void _onEnterCode() {
    if (_usedCode != null) {
      Toast.show(context,
          message: 'Kamu sudah menggunakan kode: ${_usedCode!.code}',
          type: ToastType.info);
      return;
    }
    _showEnterCodeSheet();
  }

  void _showEnterCodeSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: AppSpacing.s24, right: AppSpacing.s24,
          top: AppSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: AppRadius.pillAll),
            )),
            const SizedBox(height: AppSpacing.s16),
            Text('Masukkan Kode Referral',
                style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Masukkan kode dari driver yang mengundang kamu. '
              'Selesaikan 20 trip pertama dan dapatkan Rp 15.000!',
              style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context)
                      .colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.s24),
            TextField(
              controller: ctrl,
              autofocus : true,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.mono.copyWith(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  letterSpacing: 2),
              decoration: const InputDecoration(
                  hintText: 'IWN4829',
                  prefixIcon: Icon(Icons.confirmation_number_rounded)),
            ),
            const SizedBox(height: AppSpacing.s24),
            RihlahButton(
              label: 'Gunakan Kode',
              onPressed: () {
                final code = ctrl.text.trim().toUpperCase();
                if (code.isEmpty) return;
                Navigator.pop(context);
                _applyCode(code);
              },
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }

  void _applyCode(String code) {
    final error = ReferralService.instance.useCode(
      driverId        : _driverId,
      driverName      : _driverName,
      code            : code,
      allDriversJson  : '',
    );

    if (error != null) {
      Toast.show(context, message: error, type: ToastType.warning);
    } else {
      setState(() =>
        _usedCode = ReferralService.instance.getUsedCode(_driverId));
      Toast.show(context,
          message: 'Kode berhasil digunakan! Selesaikan 20 trip untuk bonus.',
          type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final invitees = ReferralService.instance.getInvitees(_driverId);
    final bonusPaid    = ReferralService.instance.totalBonusPaid(_driverId);
    final bonusPending = ReferralService.instance
        .totalBonusPending(_driverId);
    final totalBonus   = ReferralService.instance
        .totalBonusEarned(_driverId);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Program Referral', style: AppTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          // ── Hero card kode ──────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.s20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                begin: Alignment.topLeft,
                end  : Alignment.bottomRight,
              ),
              borderRadius: AppRadius.lgAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Text('Kode Referral Kamu',
                      style: AppTypography.bodyLg.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: AppSpacing.s16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(_code,
                          style: AppTypography.mono.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 3)),
                    ),
                    GestureDetector(
                      onTap: _onCopy,
                      child: AnimatedContainer(
                        duration: const Duration(
                            milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s8),
                        decoration: BoxDecoration(
                          color: _copied
                              ? Colors.white
                              : Colors.white
                                  .withOpacity(0.2),
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              size: 14,
                              color: _copied
                                  ? const Color(0xFF16A34A)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _copied ? 'Tersalin!' : 'Salin',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _copied
                                    ? const Color(0xFF16A34A)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.s12),
                // Info singkat
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    _WhitePill('👤 Kamu dapat Rp 25rb/driver'),
                    _WhitePill('🎁 Mereka dapat Rp 15rb'),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _onShare,
                    icon: const Text('💬',
                        style: TextStyle(fontSize: 14)),
                    label: const Text('Bagikan via WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor:
                          const Color(0xFF16A34A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdAll),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // ── Bonus summary ───────────────────────────
          Row(children: [
            _BonusCard(
              icon : Icons.emoji_events_rounded,
              color: AppColors.primary500,
              label: 'Total Bonus',
              value: _fmtIdr(totalBonus),
            ),
            const SizedBox(width: AppSpacing.s8),
            _BonusCard(
              icon : Icons.check_circle_rounded,
              color: AppColors.success500,
              label: 'Terbayar',
              value: _fmtIdr(bonusPaid),
            ),
            const SizedBox(width: AppSpacing.s8),
            _BonusCard(
              icon : Icons.schedule_rounded,
              color: AppColors.accent500,
              label: 'Pending',
              value: _fmtIdr(bonusPending),
            ),
          ]),
          const SizedBox(height: AppSpacing.s16),

          // ── Kode yang dipakai driver ini ────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: cs.outline),
            ),
            child: _usedCode != null
                ? Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('Kode yang Kamu Gunakan',
                          style: AppTypography.label.copyWith(
                              color: cs.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.s8),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s8),
                          decoration: BoxDecoration(
                            color: AppColors.primary100,
                            borderRadius: AppRadius.mdAll,
                          ),
                          child: Text(_usedCode!.code,
                              style: AppTypography.mono
                                  .copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary600,
                                      letterSpacing: 2)),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('dari ${_usedCode!.referrerName}',
                                  style: AppTypography.bodyMd
                                      .copyWith(
                                          fontWeight:
                                              FontWeight.w600)),
                              Text(
                                _usedCode!.bonusReceived
                                    ? '✓ Bonus Rp 15.000 diterima'
                                    : 'Selesaikan 20 trip untuk bonus',
                                style: AppTypography.bodySm
                                    .copyWith(
                                        color: _usedCode!
                                                .bonusReceived
                                            ? AppColors.success500
                                            : cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ],
                  )
                : InkWell(
                    onTap: _onEnterCode,
                    borderRadius: AppRadius.lgAll,
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary100,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: const Icon(
                            Icons.confirmation_number_rounded,
                            color: AppColors.primary500),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Punya kode referral?',
                                style: AppTypography.bodyMd
                                    .copyWith(
                                        fontWeight:
                                            FontWeight.w700)),
                            Text(
                              'Masukkan kode dari driver lain '
                              'dan dapatkan Rp 15.000',
                              style: AppTypography.bodySm
                                  .copyWith(
                                      color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant),
                    ]),
                  ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // ── Daftar invitee ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Driver yang Diundang',
                  style: AppTypography.h3),
              Text('${invitees.length} driver',
                  style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          if (invitees.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s24),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: AppRadius.lgAll,
              ),
              child: Column(
                children: [
                  const Text('👥',
                      style: TextStyle(fontSize: 36)),
                  const SizedBox(height: AppSpacing.s8),
                  Text('Belum ada yang menggunakan kodemu',
                      style: AppTypography.bodyMd
                          .copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Bagikan kode di atas ke teman driver kamu',
                    style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < invitees.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 72),
                    _InviteeDetailTile(invitee: invitees[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.s16),

          // ── Cara kerja ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: AppRadius.lgAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cara Kerja Referral',
                    style: AppTypography.h3),
                const SizedBox(height: AppSpacing.s12),
                ...[
                  ('1', 'Bagikan kode unikmu ke calon driver'),
                  ('2', 'Mereka daftar dan masukkan kodemu'),
                  ('3', 'Mereka selesaikan 20 perjalanan pertama'),
                  ('4', 'Kamu dapat Rp 25.000, mereka dapat Rp 15.000'),
                ].map((item) => Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppSpacing.s8),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(item.$1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(item.$2,
                            style: AppTypography.bodyMd),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s32),
        ],
      ),
    );
  }

  String _fmtIdr(int v) {
    if (v == 0) return 'Rp 0';
    if (v >= 1000000) {
      return 'Rp ${(v / 1000000).toStringAsFixed(1)}jt';
    }
    if (v >= 1000) return 'Rp ${(v / 1000).round()}k';
    return 'Rp $v';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _WhitePill extends StatelessWidget {
  const _WhitePill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: AppRadius.pillAll,
    ),
    child: Text(label,
        style: const TextStyle(
            color: Colors.white, fontSize: 11)),
  );
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color    color;
  final String   label, value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: AppTypography.bodySm
                    .copyWith(color: cs.onSurfaceVariant)),
            Text(value,
                style: AppTypography.mono.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _InviteeDetailTile extends StatelessWidget {
  const _InviteeDetailTile({required this.invitee});
  final ReferralInvitee invitee;

  Color _statusColor(BuildContext ctx) => switch (invitee.status) {
    ReferralStatus.paid       => AppColors.success500,
    ReferralStatus.completed  => AppColors.accent500,
    ReferralStatus.inProgress => AppColors.primary500,
    ReferralStatus.registered =>
        Theme.of(ctx).colorScheme.onSurfaceVariant,
  };

  String get _statusText => switch (invitee.status) {
    ReferralStatus.paid       => '✓ Bonus Rp 25rb dibayar',
    ReferralStatus.completed  => '⏳ Selesai — menunggu bonus',
    ReferralStatus.inProgress =>
        '${invitee.tripsCompleted}/$kMilestoneTrips perjalanan',
    ReferralStatus.registered => 'Baru terdaftar',
  };

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final joinStr = '${invitee.joinDate.day.toString().padLeft(2,'0')}/'
        '${invitee.joinDate.month.toString().padLeft(2,'0')}/'
        '${invitee.joinDate.year}';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                invitee.name.isNotEmpty
                    ? invitee.name[0].toUpperCase() : 'D',
                style: AppTypography.h3.copyWith(
                    color: AppColors.primary600),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invitee.name,
                    style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w700)),
                Text('Bergabung $joinStr',
                    style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                if (invitee.status ==
                    ReferralStatus.inProgress) ...[
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_statusText,
                          style: AppTypography.bodySm),
                      Text(
                          '${(invitee.progressPct * 100).round()}%',
                          style: AppTypography.bodySm.copyWith(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(
                      value: invitee.progressPct,
                      minHeight: 6,
                      backgroundColor:
                          cs.surfaceContainerHighest,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(
                              AppColors.primary500),
                    ),
                  ),
                ] else
                  Text(_statusText,
                      style: AppTypography.bodySm.copyWith(
                          color: _statusColor(context),
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}