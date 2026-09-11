import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/core.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _EWallet {
  const _EWallet({
    required this.id,
    required this.name,
    required this.color,
    this.balance,
    this.connected = false,
  });
  final String  id;
  final String  name;
  final Color   color;
  final String? balance;
  final bool    connected;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String _defaultId = 'cash';

  static const _wallets = [
    _EWallet(
      id: 'gopay', name: 'GoPay',
      color: Color(0xFF00AED6), balance: 'Rp 250.000', connected: true,
    ),
    _EWallet(id: 'ovo',    name: 'OVO',       color: Color(0xFF4C3494)),
    _EWallet(id: 'dana',   name: 'DANA',      color: Color(0xFF118EEA)),
    _EWallet(id: 'shopee', name: 'ShopeePay', color: Color(0xFFEE4D2D)),
  ];

  @override
  void initState() {
    super.initState();
    final saved = Hive.box('settings').get('default_payment') as String?;
    if (saved != null) setState(() => _defaultId = saved);
  }

  Future<void> _setDefault(String id) async {
    await Hive.box('settings').put('default_payment', id);
    if (!mounted) return;
    setState(() => _defaultId = id);
    Toast.show(context, message: 'Metode default diubah', type: ToastType.success);
  }

  void _onConnect(String name) => Toast.show(
      context, message: '$name akan tersedia segera', type: ToastType.info);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Metode Pembayaran', style: AppTypography.h3),
        elevation: 0,
        backgroundColor: cs.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          // ── Cash ──────────────────────────────────────────────────────────
          Text('Tunai',
              style: AppTypography.label.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s8),
          _MethodTile(
            icon: Icons.payments_rounded,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: AppColors.success500,
            label: 'Tunai (Cash)',
            subtitle: 'Bayar langsung ke driver di akhir perjalanan',
            isDefault: _defaultId == 'cash',
            onSetDefault: () => _setDefault('cash'),
          ),
          const SizedBox(height: AppSpacing.s24),

          // ── QRIS ──────────────────────────────────────────────────────────
          Text('QRIS',
              style: AppTypography.label.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s8),
          _MethodTile(
            icon: Icons.qr_code_scanner_rounded,
            iconBg: const Color(0xFFEDE7F6),
            iconColor: const Color(0xFF7B1FA2),
            label: 'QRIS',
            subtitle: 'Scan QR dari aplikasi e-wallet manapun',
            isDefault: _defaultId == 'qris',
            onSetDefault: () => _setDefault('qris'),
          ),
          const SizedBox(height: AppSpacing.s24),

          // ── E-Wallet ──────────────────────────────────────────────────────
          Text('E-Wallet',
              style: AppTypography.label.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s8),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _wallets.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  _WalletTile(
                    wallet: _wallets[i],
                    isDefault: _defaultId == _wallets[i].id,
                    onSetDefault: _wallets[i].connected
                        ? () => _setDefault(_wallets[i].id)
                        : null,
                    onConnect: () => _onConnect(_wallets[i].name),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),

          // ── Info card ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.primary500.withOpacity(0.06),
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.primary500.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.primary500),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    'Metode pembayaran bisa diganti tiap kali memesan di '
                    'layar konfirmasi. Pengaturan di sini hanya menetapkan '
                    'pilihan default.',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.primary600),
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

// ── Method tile (Cash / QRIS) ─────────────────────────────────────────────────

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.isDefault,
    required this.onSetDefault,
  });
  final IconData     icon;
  final Color        iconBg, iconColor;
  final String       label, subtitle;
  final bool         isDefault;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: isDefault ? null : onSetDefault,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isDefault ? AppColors.primary500 : cs.outline,
            width: isDefault ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: AppRadius.mdAll),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.bodyMd
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: AppTypography.bodySm
                          .copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (isDefault)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text('Default',
                    style: AppTypography.label.copyWith(
                        color: AppColors.ink0, fontSize: 11)),
              )
            else
              Icon(Icons.radio_button_unchecked_rounded,
                  size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Wallet tile ───────────────────────────────────────────────────────────────

class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.wallet,
    required this.isDefault,
    required this.onSetDefault,
    required this.onConnect,
  });
  final _EWallet      wallet;
  final bool          isDefault;
  final VoidCallback? onSetDefault;
  final VoidCallback  onConnect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: wallet.connected
          ? (isDefault ? null : onSetDefault)
          : onConnect,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: wallet.color,
                borderRadius: AppRadius.smAll,
              ),
              child: Center(
                child: Text(
                  wallet.name[0],
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wallet.name,
                      style: AppTypography.bodyMd
                          .copyWith(fontWeight: FontWeight.w600)),
                  if (wallet.connected && wallet.balance != null)
                    Text(wallet.balance!,
                        style: AppTypography.bodySm.copyWith(
                            color: AppColors.success500,
                            fontWeight: FontWeight.w600))
                  else if (!wallet.connected)
                    Text('Belum terhubung',
                        style: AppTypography.bodySm
                            .copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (wallet.connected && isDefault)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text('Default',
                    style: AppTypography.label.copyWith(
                        color: AppColors.ink0, fontSize: 11)),
              )
            else if (wallet.connected)
              Icon(Icons.radio_button_unchecked_rounded,
                  size: 20, color: cs.onSurfaceVariant)
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text('Hubungkan',
                    style: AppTypography.label.copyWith(
                        color: cs.onSurface, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}
