import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core.dart';
import '../../../data/mock/seed_data.dart';

// ── Dev settings model ────────────────────────────────────────────────────────

class DevSettings {
  const DevSettings({
    this.autoAcceptOffers  = false,
    this.surgePricing      = false,
    this.slowNetwork       = false,
    this.geoSpeed          = 1.0,
    this.persona           = DevPersona.aisha,
  });

  final bool       autoAcceptOffers;
  final bool       surgePricing;
  final bool       slowNetwork;
  final double     geoSpeed;
  final DevPersona persona;

  DevSettings copyWith({
    bool?       autoAcceptOffers,
    bool?       surgePricing,
    bool?       slowNetwork,
    double?     geoSpeed,
    DevPersona? persona,
  }) => DevSettings(
    autoAcceptOffers : autoAcceptOffers ?? this.autoAcceptOffers,
    surgePricing     : surgePricing     ?? this.surgePricing,
    slowNetwork      : slowNetwork      ?? this.slowNetwork,
    geoSpeed         : geoSpeed         ?? this.geoSpeed,
    persona          : persona          ?? this.persona,
  );
}

enum DevPersona {
  aisha('Aisha Putri',   '+62 812-3456-7890', 'A', AppColors.accent500),
  budi ('Budi Santoso',  '+62 811-2222-3333', 'B', AppColors.info500),
  citra('Citra Dewi',    '+62 813-4444-5555', 'C', AppColors.success500);

  const DevPersona(this.name, this.phone, this.initial, this.color);
  final String name;
  final String phone;
  final String initial;
  final Color  color;
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

final devSettingsProvider =
    StateNotifierProvider<DevSettingsNotifier, DevSettings>((ref) {
  return DevSettingsNotifier();
});

class DevSettingsNotifier extends StateNotifier<DevSettings> {
  DevSettingsNotifier() : super(_load());

  static DevSettings _load() {
    final box = Hive.box('settings');
    return DevSettings(
      autoAcceptOffers : box.get('dev_autoAccept',  defaultValue: false) as bool,
      surgePricing     : box.get('dev_surge',        defaultValue: false) as bool,
      slowNetwork      : box.get('dev_slowNet',      defaultValue: false) as bool,
      geoSpeed         : (box.get('dev_geoSpeed',    defaultValue: 1.0)  as num).toDouble(),
      persona          : DevPersona.values[
          box.get('dev_persona', defaultValue: 0) as int],
    );
  }

  Future<void> _save() async {
    final box = Hive.box('settings');
    await box.put('dev_autoAccept', state.autoAcceptOffers);
    await box.put('dev_surge',       state.surgePricing);
    await box.put('dev_slowNet',     state.slowNetwork);
    await box.put('dev_geoSpeed',    state.geoSpeed);
    await box.put('dev_persona',     state.persona.index);
  }

  void toggle(String key) {
    state = switch (key) {
      'autoAccept' => state.copyWith(autoAcceptOffers: !state.autoAcceptOffers),
      'surge'      => state.copyWith(surgePricing: !state.surgePricing),
      'slowNet'    => state.copyWith(slowNetwork: !state.slowNetwork),
      _            => state,
    };
    _save();
  }

  void setGeoSpeed(double v) {
    state = state.copyWith(geoSpeed: v);
    _save();
  }

  void setPersona(DevPersona persona) {
    state = state.copyWith(persona: persona);
    // Reset used vouchers untuk persona baru
    Hive.box('settings').delete('used_vouchers');
  }
}

// ── Network delay helper ──────────────────────────────────────────────────────

/// Call at the start of any mock transition to simulate slow network.
Future<void> devDelay(WidgetRef ref) async {
  if (!ref.read(devSettingsProvider).slowNetwork) return;
  final ms = 800 + (DateTime.now().millisecond % 1200); // 800–2000ms
  await Future.delayed(Duration(milliseconds: ms));
}

// ── Dev menu sheet ────────────────────────────────────────────────────────────

void showDevMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => const _DevMenuSheet(),
  );
}

class _DevMenuSheet extends ConsumerWidget {
  const _DevMenuSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s   = ref.watch(devSettingsProvider);
    final n   = ref.read(devSettingsProvider.notifier);
    final cs  = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s24, AppSpacing.s8,
            AppSpacing.s24, AppSpacing.s32),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.s16),
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(Icons.developer_mode_rounded,
                    color: AppColors.ink0, size: 20),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text('Dev Menu',
                  style: AppTypography.h2
                      .copyWith(color: cs.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger500.withOpacity(0.1),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text('DEBUG',
                    style: AppTypography.label
                        .copyWith(color: AppColors.danger500,
                            fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),

          // ── Toggles ────────────────────────────────────
          _Section(label: 'TOGGLES'),
          _ToggleRow(
            icon: Icons.bolt_rounded,
            iconColor: AppColors.accent500,
            label: 'Auto-accept driver offers',
            subtitle: 'Skip incoming order screen',
            value: s.autoAcceptOffers,
            onChanged: (_) => n.toggle('autoAccept'),
          ),
          _ToggleRow(
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.danger500,
            label: 'Surge pricing',
            subtitle: 'Adds 1.4× multiplier to fares',
            value: s.surgePricing,
            onChanged: (_) => n.toggle('surge'),
          ),
          _ToggleRow(
            icon: Icons.signal_cellular_alt_1_bar_rounded,
            iconColor: AppColors.ink500,
            label: 'Simulate slow network',
            subtitle: '800–2000ms delay on transitions',
            value: s.slowNetwork,
            onChanged: (_) => n.toggle('slowNet'),
          ),
          const SizedBox(height: AppSpacing.s16),

          // ── Geo speed ──────────────────────────────────
          _Section(label: 'GEO SIMULATOR'),
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded,
                        size: 18, color: AppColors.primary500),
                    const SizedBox(width: AppSpacing.s8),
                    Text('Speed multiplier',
                        style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Text('${s.geoSpeed.toStringAsFixed(1)}×',
                          style: AppTypography.mono.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary600)),
                    ),
                  ],
                ),
                Slider(
                  value: s.geoSpeed,
                  min: 0.5,
                  max: 4.0,
                  divisions: 7,
                  activeColor: AppColors.primary500,
                  onChanged: n.setGeoSpeed,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.5× slow',
                        style: AppTypography.bodySm
                            .copyWith(color: cs.onSurfaceVariant)),
                    Text('4.0× fast',
                        style: AppTypography.bodySm
                            .copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // ── Persona ────────────────────────────────────
          _Section(label: 'PERSONA'),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: DevPersona.values.map((p) {
              final isActive = s.persona == p;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s8),
                  child: GestureDetector(
                    onTap: () => n.setPersona(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary100
                            : cs.surfaceContainerHighest,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary500
                              : cs.outline,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.color,
                            ),
                            child: Center(
                              child: Text(p.initial,
                                  style: const TextStyle(
                                      color: AppColors.ink0,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(p.name.split(' ').first,
                              style: AppTypography.bodySm.copyWith(
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isActive
                                      ? AppColors.primary600
                                      : cs.onSurface)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.s24),

          // ── Data actions ───────────────────────────────
          _Section(label: 'DATA'),
          const SizedBox(height: AppSpacing.s8),
          _ActionButton(
            icon: Icons.add_road_rounded,
            label: 'Seed 10 fake trips',
            color: AppColors.primary500,
            onTap: () => _seedTrips(context),
          ),
          const SizedBox(height: AppSpacing.s8),
          _ActionButton(
            icon: Icons.history_toggle_off_rounded,
            label: 'Reset trip history',
            color: AppColors.accent500,
            onTap: () => _resetHistory(context),
          ),
          const SizedBox(height: AppSpacing.s8),
          _ActionButton(
            icon: Icons.delete_sweep_rounded,
            label: 'Reset all (clear Hive)',
            color: AppColors.danger500,
            onTap: () => _resetAll(context),
          ),
        ],
      ),
    );
  }

  // ── Data helpers ────────────────────────────────────────────────────────────

  Future<void> _seedTrips(BuildContext context) async {
    final box      = Hive.box('settings');
    final history  = (box.get('trip_history') as List?)?.cast<Map>() ?? [];
    final dHistory = (box.get('driver_history') as List?)?.cast<Map>() ?? [];

    final destinations = [
      'Trans Studio Bandung', 'ITB', 'Bandung Station',
      'BIP Mall', 'Gasibu', 'Cihampelas Walk', 'Dago Atas',
      'Pasar Baru', 'Alun-alun Bandung', 'Buah Batu',
    ];
    final pickups = ['Dago Plaza', 'Cihampelas', 'Setiabudi', 'Pasteur'];

    for (int i = 0; i < 10; i++) {
      final date = DateTime.now()
          .subtract(Duration(hours: i * 6 + 1));
      final dest = destinations[i % destinations.length];
      final pick = pickups[i % pickups.length];
      final fare = 8000 + (i * 2300);
      history.insert(0, {
        'tripId'  : 'seed-auto-$i-${date.millisecondsSinceEpoch}',
        'date'    : date.toIso8601String(),
        'pickup'  : pick,
        'dropoff' : dest,
        'fare'    : fare,
        'rating'  : (i % 5) + 1,
        'status'  : i == 3 ? 'cancelled' : 'completed',
      });
      dHistory.insert(0, {
        'tripId'  : 'drv-auto-$i-${date.millisecondsSinceEpoch}',
        'date'    : date.toIso8601String(),
        'pickup'  : pick,
        'dropoff' : dest,
        'fare'    : fare,
        'earn'    : (fare * 0.8).round(),
        'status'  : i == 3 ? 'cancelled' : 'completed',
      });
    }

    await box.put('trip_history',    history);
    await box.put('driver_history',  dHistory);

    if (context.mounted) {
      Navigator.pop(context);
      Toast.show(context,
          message: '10 trip ditambahkan',
          type: ToastType.success);
    }
  }

  Future<void> _resetHistory(BuildContext context) async {
    final box = Hive.box('settings');
    await box.delete('trip_history');
    await box.delete('driver_history');
    await box.put('driver_today_earn', 0);
    if (context.mounted) {
      Navigator.pop(context);
      Toast.show(context,
          message: 'Riwayat perjalanan dihapus',
          type: ToastType.info);
    }
  }

  Future<void> _resetAll(BuildContext context) async {
    await Hive.box('settings').clear();
    if (context.mounted) {
      Navigator.pop(context);
      Toast.show(context,
          message: 'Semua data dihapus',
          type: ToastType.warning);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Text(label,
          style: AppTypography.label.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   subtitle;
  final bool     value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface)),
                  Text(subtitle,
                      style: AppTypography.bodySm
                          .copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary500,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.s12),
            Text(label,
                style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Active persona helper ─────────────────────────────────────────────────────

PassengerPersona activePersona(WidgetRef ref) {
  final persona = ref.watch(devSettingsProvider).persona;
  return getPersona(persona.name.toLowerCase());
}