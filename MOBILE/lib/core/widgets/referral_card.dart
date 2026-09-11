// lib/core/widgets/referral_card.dart
//
// Card referral driver — tampilkan kode, share, dan status invitee.
// Embed di driver_profile_screen di bawah Vehicle Card.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../../router.dart';
import '../services/firestore_service.dart';
import '../services/referral_service.dart';
import '../core.dart';

class ReferralCard extends StatefulWidget {
  const ReferralCard({super.key});

  @override
  State<ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<ReferralCard> {
  String _code      = '';
  String _driverId  = 'driver-001';
  String _driverName = '';
  bool   _copied    = false;

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

    // Seed invitees sekali
    ReferralService.instance.seedReferralData(driverId, driverName);

    final code = ReferralService.instance
        .getOrCreateCode(driverId, driverName);

    if (!mounted) return;
    setState(() {
      _driverId   = driverId;
      _driverName = driverName;
      _code       = code;
    });
  }

  void _onCopy() {
    Clipboard.setData(ClipboardData(text: _code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2),
        () { if (mounted) setState(() => _copied = false); });
  }

  void _onShare() {
    Share.share(
      'Gabung jadi driver RIHLAH dan dapatkan penghasilan tambahan! '
      'Daftar pakai kode referral aku: *$_code* 🚗\n\n'
      'Download RIHLAH di: https://rihlah.id/driver',
      subject: 'Ajak jadi driver RIHLAH',
    );
  }

  void _onSeeAll(BuildContext context) {
    context.push(Routes.dReferral);
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final invitees = ReferralService.instance.getInvitees(_driverId);
    final bonusPaid    = ReferralService.instance
        .totalBonusPaid(_driverId);
    final bonusPending = ReferralService.instance
        .totalBonusPending(_driverId);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end  : Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────
            Row(
              children: [
                const Icon(Icons.people_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: AppSpacing.s8),
                Text('Ajak Teman Jadi Driver',
                    style: AppTypography.bodyLg.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _onSeeAll(context),
                  child: Text('Lihat semua →',
                      style: AppTypography.bodySm.copyWith(
                          color: Colors.white70)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            // ── Kode ───────────────────────────────────
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Kode referral kamu',
                            style: AppTypography.bodySm
                                .copyWith(
                                    color: Colors.white70)),
                        Text(_code,
                            style: AppTypography.mono.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2)),
                      ],
                    ),
                  ),
                  // Tombol copy
                  GestureDetector(
                    onTap: _onCopy,
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: _copied
                            ? Colors.white
                            : Colors.white.withOpacity(0.2),
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
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // ── Info bonus ─────────────────────────────
            Row(children: [
              _InfoPill(
                icon : Icons.emoji_events_rounded,
                label: 'Bonus terbayar',
                value: _fmtIdr(bonusPaid),
              ),
              const SizedBox(width: AppSpacing.s8),
              _InfoPill(
                icon : Icons.schedule_rounded,
                label: 'Menunggu',
                value: _fmtIdr(bonusPending),
              ),
              const SizedBox(width: AppSpacing.s8),
              _InfoPill(
                icon : Icons.group_rounded,
                label: 'Diundang',
                value: '${invitees.length} driver',
              ),
            ]),
            const SizedBox(height: AppSpacing.s16),

            // ── Share button ───────────────────────────
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
                  foregroundColor: const Color(0xFF16A34A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll),
                ),
              ),
            ),

            // ── Preview invitee ────────────────────────
            if (invitees.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s12),
              const Divider(
                  color: Colors.white24, height: 1),
              const SizedBox(height: AppSpacing.s12),
              Text('Status undangan terbaru',
                  style: AppTypography.bodySm.copyWith(
                      color: Colors.white70)),
              const SizedBox(height: AppSpacing.s8),
              ...invitees.take(2).map((inv) =>
                  _InviteeRow(invitee: inv, compact: true)),
            ],
          ],
        ),
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

// ── Info pill ─────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String   label, value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: AppSpacing.s6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: AppRadius.smAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 11, color: Colors.white70),
              const SizedBox(width: 3),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white70),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ── Invitee row ───────────────────────────────────────────────────────────────

class _InviteeRow extends StatelessWidget {
  const _InviteeRow({
    required this.invitee,
    this.compact = false,
  });
  final ReferralInvitee invitee;
  final bool            compact;

  Color get _statusColor => switch (invitee.status) {
    ReferralStatus.paid       => const Color(0xFF4ADE80),
    ReferralStatus.completed  => const Color(0xFFFBBF24),
    ReferralStatus.inProgress => const Color(0xFF93C5FD),
    ReferralStatus.registered => Colors.white54,
  };

  String get _statusLabel => switch (invitee.status) {
    ReferralStatus.paid       => 'Bonus dibayar ✓',
    ReferralStatus.completed  => 'Selesai — menunggu bonus',
    ReferralStatus.inProgress =>
        '${invitee.tripsCompleted}/20 perjalanan',
    ReferralStatus.registered => 'Baru terdaftar',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                invitee.name.isNotEmpty
                    ? invitee.name[0].toUpperCase()
                    : 'D',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invitee.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text(_statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 11)),
              ],
            ),
          ),
          // Progress mini bar (hanya inProgress)
          if (invitee.status == ReferralStatus.inProgress)
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(invitee.progressPct * 100).round()}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(
                      value: invitee.progressPct,
                      minHeight: 4,
                      backgroundColor:
                          Colors.white.withOpacity(0.2),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(
                              Color(0xFF93C5FD)),
                    ),
                  ),
                ],
              ),
            ),
          if (invitee.status == ReferralStatus.paid)
            const Icon(Icons.check_circle_rounded,
                size: 18, color: Color(0xFF4ADE80)),
        ],
      ),
    );
  }
}

// ── Invitee full sheet ────────────────────────────────────────────────────────

class _InviteeSheet extends StatelessWidget {
  const _InviteeSheet({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final invitees = ReferralService.instance.getInvitees(driverId);
    final paid     = ReferralService.instance.totalBonusPaid(driverId);
    final pending  = ReferralService.instance
        .totalBonusPending(driverId);

    return DraggableScrollableSheet(
      initialChildSize : 0.7,
      minChildSize     : 0.4,
      maxChildSize     : 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s12),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: AppRadius.pillAll),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s24),
            child: Row(
              children: [
                Text('Driver yang Diundang',
                    style: AppTypography.h2),
                const Spacer(),
                Text('${invitees.length} orang',
                    style: AppTypography.bodySm
                        .copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Summary strip
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s24),
            child: Row(children: [
              _SummaryBox(
                label: 'Total Bonus',
                value: _fmtIdr(paid + pending),
                color: AppColors.primary500,
              ),
              const SizedBox(width: AppSpacing.s8),
              _SummaryBox(
                label: 'Terbayar',
                value: _fmtIdr(paid),
                color: AppColors.success500,
              ),
              const SizedBox(width: AppSpacing.s8),
              _SummaryBox(
                label: 'Pending',
                value: _fmtIdr(pending),
                color: AppColors.accent500,
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1),

          // List
          Expanded(
            child: invitees.isEmpty
                ? Center(
                    child: Text('Belum ada driver yang diundang',
                        style: AppTypography.bodyMd.copyWith(
                            color: cs.onSurfaceVariant)),
                  )
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.all(
                        AppSpacing.s16),
                    itemCount: invitees.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _InviteeDetail(invitee: invitees[i]),
                  ),
          ),
        ],
      ),
    );
  }

  String _fmtIdr(int v) {
    if (v == 0) return 'Rp 0';
    if (v >= 1000) return 'Rp ${(v / 1000).round()}k';
    return 'Rp $v';
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: AppRadius.mdAll,
          border: Border.all(
              color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant)),
            Text(value,
                style: AppTypography.mono.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _InviteeDetail extends StatelessWidget {
  const _InviteeDetail({required this.invitee});
  final ReferralInvitee invitee;

  Color _statusColor(BuildContext context) =>
      switch (invitee.status) {
    ReferralStatus.paid       => AppColors.success500,
    ReferralStatus.completed  => AppColors.accent500,
    ReferralStatus.inProgress => AppColors.primary500,
    ReferralStatus.registered =>
        Theme.of(context).colorScheme.onSurfaceVariant,
  };

  String get _statusLabel => switch (invitee.status) {
    ReferralStatus.paid       => '✓ Bonus Rp 25k dibayar',
    ReferralStatus.completed  => '⏳ Menunggu pembayaran bonus',
    ReferralStatus.inProgress =>
        '${invitee.tripsCompleted}/20 perjalanan',
    ReferralStatus.registered => 'Baru terdaftar',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final joinStr =
        '${invitee.joinDate.day.toString().padLeft(2,'0')}/'
        '${invitee.joinDate.month.toString().padLeft(2,'0')}/'
        '${invitee.joinDate.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s12),
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
                // Progress bar
                if (invitee.status ==
                    ReferralStatus.inProgress) ...[
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${invitee.tripsCompleted}/20 trip',
                          style: AppTypography.bodySm),
                      Text(
                          '${(invitee.progressPct * 100).round()}%',
                          style: AppTypography.bodySm.copyWith(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.w600)),
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
                  Text(_statusLabel,
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