// lib/features/passenger/profile/saved_addresses_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../core/providers/saved_address_provider.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../data/models/saved_address.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs        = Theme.of(context).colorScheme;
    final addresses = ref.watch(savedAddressProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Alamat Tersimpan', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: cs.onSurface),
            onPressed: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: addresses.isEmpty
          ? _EmptyState(onAdd: () => _showAddSheet(context, ref))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                // Slot cepat: Rumah & Kantor
                _QuickSlot(
                  icon      : Icons.home_rounded,
                  iconColor : AppColors.primary500,
                  label     : 'Rumah',
                  address   : _findByLabel(addresses, 'Rumah'),
                  onTap     : () => _showAddSheet(context, ref,
                      prefillLabel: 'Rumah'),
                  onDelete  : (id) =>
                      ref.read(savedAddressProvider.notifier).remove(id),
                ),
                const SizedBox(height: AppSpacing.s8),
                _QuickSlot(
                  icon      : Icons.work_rounded,
                  iconColor : AppColors.info500,
                  label     : 'Kantor',
                  address   : _findByLabel(addresses, 'Kantor'),
                  onTap     : () => _showAddSheet(context, ref,
                      prefillLabel: 'Kantor'),
                  onDelete  : (id) =>
                      ref.read(savedAddressProvider.notifier).remove(id),
                ),
                const SizedBox(height: AppSpacing.s24),

                // Alamat lainnya
                if (addresses
                    .where((a) =>
                        a.label != 'Rumah' && a.label != 'Kantor')
                    .isNotEmpty) ...[
                  Text('LAINNYA',
                      style: AppTypography.label
                          .copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.s8),
                  ...addresses
                      .where((a) =>
                          a.label != 'Rumah' && a.label != 'Kantor')
                      .map((a) => _AddressRow(
                            address : a,
                            onDelete: () => ref
                                .read(savedAddressProvider.notifier)
                                .remove(a.id),
                          )),
                ],
              ],
            ),
    );
  }

  SavedAddress? _findByLabel(
          List<SavedAddress> list, String label) =>
      list.where((a) => a.label == label).firstOrNull;

  void _showAddSheet(BuildContext context, WidgetRef ref,
      {String? prefillLabel}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _AddAddressSheet(
        prefillLabel: prefillLabel,
        onSave: (address) {
          // Jika label sudah ada (Rumah/Kantor), update; jika tidak, tambah
          final existing = ref
              .read(savedAddressProvider)
              .where((a) => a.label == address.label)
              .firstOrNull;
          if (existing != null) {
            ref.read(savedAddressProvider.notifier).update(
                  address.copyWith(id: existing.id),
                );
          } else {
            ref.read(savedAddressProvider.notifier).add(address);
          }
          Navigator.pop(context);
          Toast.show(context,
              message: 'Alamat disimpan', type: ToastType.success);
        },
      ),
    );
  }
}

// ── Quick slot (Rumah / Kantor) ───────────────────────────────────────────────

class _QuickSlot extends StatelessWidget {
  const _QuickSlot({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    required this.onTap,
    required this.onDelete,
  });

  final IconData        icon;
  final Color           iconColor;
  final String          label;
  final SavedAddress?   address;
  final VoidCallback    onTap;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final hasAddr = address != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: hasAddr ? cs.outline : AppColors.primary500,
            width: hasAddr ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: hasAddr
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: AppTypography.bodySm.copyWith(
                                color: cs.onSurfaceVariant)),
                        Text(address!.name,
                            style: AppTypography.bodyMd.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (address!.address.isNotEmpty)
                          Text(address!.address,
                              style: AppTypography.bodySm.copyWith(
                                  color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    )
                  : Text(
                      'Tambah $label',
                      style: AppTypography.bodyMd.copyWith(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.w500),
                    ),
            ),
            if (hasAddr)
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: cs.onSurfaceVariant),
                onPressed: () => onDelete(address!.id),
              )
            else
              const Icon(Icons.add_rounded,
                  color: AppColors.primary500),
          ],
        ),
      ),
    );
  }
}

// ── Address row ───────────────────────────────────────────────────────────────

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.onDelete,
  });
  final SavedAddress address;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(Icons.location_on_rounded,
                color: cs.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.label,
                    style: AppTypography.bodySm
                        .copyWith(color: cs.onSurfaceVariant)),
                Text(address.name,
                    style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 20, color: AppColors.danger500),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Add address sheet ─────────────────────────────────────────────────────────

class _AddAddressSheet extends ConsumerStatefulWidget {
  const _AddAddressSheet({
    required this.onSave,
    this.prefillLabel,
  });
  final ValueChanged<SavedAddress> onSave;
  final String? prefillLabel;

  @override
  ConsumerState<_AddAddressSheet> createState() =>
      _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<_AddAddressSheet> {
  final _labelCtrl  = TextEditingController();
  final _searchCtrl = TextEditingController();

  List<PlaceResult> _results   = [];
  bool  _searching             = false;
  PlaceResult? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.prefillLabel != null) {
      _labelCtrl.text = widget.prefillLabel!;
    }
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.length < 3) {
      setState(() => _results = []);
      return;
    }
    _search(q);
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    final r = await GeocodingService.instance.search(q);
    if (!mounted) return;
    setState(() { _results = r; _searching = false; });
  }

  void _onSelectPlace(PlaceResult place) {
    setState(() {
      _selected = place;
      _searchCtrl.text = place.name;
      _results = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _onSave() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      Toast.show(context,
          message: 'Nama label tidak boleh kosong',
          type: ToastType.warning);
      return;
    }
    if (_selected == null) {
      Toast.show(context,
          message: 'Pilih lokasi terlebih dahulu',
          type: ToastType.warning);
      return;
    }
    widget.onSave(SavedAddress(
      id       : SavedAddressNotifier.newId(),
      label    : label,
      name     : _selected!.name,
      address  : _selected!.address,
      latitude : _selected!.latLng.latitude,
      longitude: _selected!.latLng.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        top: AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text('Tambah Alamat', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.s24),

          // Label input
          Text('Nama label',
              style: AppTypography.bodyMd
                  .copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.s8),
          // Quick label chips
          Wrap(
            spacing: AppSpacing.s8,
            children: ['Rumah', 'Kantor', 'Gym', 'Kampus']
                .map((l) => GestureDetector(
                      onTap: () {
                        _labelCtrl.text = l;
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _labelCtrl.text == l
                              ? AppColors.primary500
                              : cs.surfaceContainerHighest,
                          borderRadius: AppRadius.pillAll,
                          border: Border.all(
                            color: _labelCtrl.text == l
                                ? AppColors.primary500
                                : cs.outline,
                          ),
                        ),
                        child: Text(l,
                            style: AppTypography.bodySm.copyWith(
                              color: _labelCtrl.text == l
                                  ? AppColors.ink0
                                  : cs.onSurface,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: _labelCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'atau ketik nama label',
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Location search
          Text('Lokasi',
              style: AppTypography.bodyMd
                  .copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari lokasi…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _selected = null;
                          _results  = [];
                        });
                      },
                    )
                  : null,
            ),
          ),

          // Search results
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.s8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: cs.outline),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _results[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.location_on_rounded,
                        color: cs.onSurfaceVariant, size: 18),
                    title: Text(p.name,
                        style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w500)),
                    subtitle: p.address.isNotEmpty
                        ? Text(p.address,
                            style: AppTypography.bodySm
                                .copyWith(color: cs.onSurfaceVariant))
                        : null,
                    onTap: () => _onSelectPlace(p),
                  );
                },
              ),
            ),

          // Selected confirmation
          if (_selected != null && _results.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.s8),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.success500.withOpacity(0.08),
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                    color: AppColors.success500.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success500, size: 18),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(_selected!.name,
                        style: AppTypography.bodySm.copyWith(
                            color: AppColors.success500,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.s24),
          RihlahButton(label: 'Simpan', onPressed: _onSave),
          const SizedBox(height: AppSpacing.s24),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: AppRadius.lgAll,
              ),
              child: Icon(Icons.bookmark_border_rounded,
                  size: 40, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text('Belum ada alamat tersimpan',
                style: AppTypography.h2,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s8),
            Text('Simpan alamat favorit untuk memesan lebih cepat.',
                style: AppTypography.bodyMd
                    .copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s24),
            RihlahButton(
              label: 'Tambah alamat',
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extension ─────────────────────────────────────────────────────────────────

extension _SavedAddressX on SavedAddress {
  SavedAddress copyWith({String? id}) => SavedAddress(
    id        : id        ?? this.id,
    label     : label,
    name      : name,
    address   : address,
    latitude  : latitude,
    longitude : longitude,
  );
}