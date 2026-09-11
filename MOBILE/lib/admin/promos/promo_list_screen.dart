import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/promo_model.dart';
import '../widgets/admin_widgets.dart';

class PromoListScreen extends StatefulWidget {
  const PromoListScreen({super.key});

  @override
  State<PromoListScreen> createState() => _PromoListScreenState();
}

class _PromoListScreenState extends State<PromoListScreen> {
  final Set<String> _busy = {};

  Future<void> _openForm({PromoModel? existing}) async {
    await showDialog(
      context: context,
      builder: (_) => _PromoFormDialog(existing: existing),
    );
  }

  Future<void> _toggleActive(PromoModel p) async {
    setState(() => _busy.add(p.promoId));
    try {
      await FirestoreService.instance
          .updatePromo(p.promoId, {'isActive': !p.isActive});
    } finally {
      if (mounted) setState(() => _busy.remove(p.promoId));
    }
  }

  Future<void> _delete(PromoModel p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus promo?'),
        content: Text('Kode "${p.code}" akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger500),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy.add(p.promoId));
    try {
      await FirestoreService.instance.deletePromo(p.promoId);
    } finally {
      if (mounted) setState(() => _busy.remove(p.promoId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminListScaffold(
      title: 'Promos / Voucher',
      actions: [
        FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Tambah Promo'),
        ),
      ],
      child: StreamBuilder<List<PromoModel>>(
        stream: FirestoreService.instance.getPromosStream(),
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorState(error: snap.error!);
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final promos = snap.data!;
          if (promos.isEmpty) {
            return AdminEmptyState(
              message: 'Belum ada promo. Tambah promo pertama.',
              icon: Icons.local_offer_outlined,
            );
          }
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Kode')),
                  DataColumn(label: Text('Judul')),
                  DataColumn(label: Text('Diskon')),
                  DataColumn(label: Text('Min. Order'), numeric: true),
                  DataColumn(label: Text('Berlaku')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('')),
                ],
                rows: promos.map((p) {
                  final busy = _busy.contains(p.promoId);
                  final discountLabel = p.discountType == PromoDiscountType.percent
                      ? '${p.discountValue}%'
                      : formatIdr(p.discountValue);
                  return DataRow(cells: [
                    DataCell(Text(p.code,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(p.title)),
                    DataCell(Text(discountLabel)),
                    DataCell(Text(formatIdr(p.minOrder))),
                    DataCell(Text(p.expiryLabel)),
                    DataCell(StatusPill(
                      label: p.isActive ? 'Aktif' : 'Nonaktif',
                      color: p.isActive ? AppColors.success500 : AppColors.ink400,
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: busy ? null : () => _openForm(existing: p),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => _toggleActive(p),
                          child: Text(p.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => _delete(p),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger500),
                          child: const Text('Hapus'),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Add/Edit form dialog ─────────────────────────────────────────────────────

class _PromoFormDialog extends StatefulWidget {
  const _PromoFormDialog({this.existing});
  final PromoModel? existing;

  @override
  State<_PromoFormDialog> createState() => _PromoFormDialogState();
}

class _PromoFormDialogState extends State<_PromoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _discountValueCtrl;
  late final TextEditingController _minOrderCtrl;
  late final TextEditingController _expiryLabelCtrl;
  late PromoDiscountType _discountType;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _codeCtrl = TextEditingController(text: e?.code ?? '');
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _discountValueCtrl =
        TextEditingController(text: e?.discountValue.toString() ?? '');
    _minOrderCtrl = TextEditingController(text: e?.minOrder.toString() ?? '0');
    _expiryLabelCtrl = TextEditingController(text: e?.expiryLabel ?? '');
    _discountType = e?.discountType ?? PromoDiscountType.flat;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _discountValueCtrl.dispose();
    _minOrderCtrl.dispose();
    _expiryLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'code': _codeCtrl.text.trim().toUpperCase(),
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'discountType': _discountType.name,
        'discountValue': int.parse(_discountValueCtrl.text.trim()),
        'minOrder': int.tryParse(_minOrderCtrl.text.trim()) ?? 0,
        'expiryLabel': _expiryLabelCtrl.text.trim(),
      };
      if (_isEdit) {
        await FirestoreService.instance.updatePromo(widget.existing!.promoId, data);
      } else {
        await FirestoreService.instance.createPromo(PromoModel(
          promoId: '',
          code: data['code'] as String,
          title: data['title'] as String,
          description: data['description'] as String,
          discountType: _discountType,
          discountValue: data['discountValue'] as int,
          minOrder: data['minOrder'] as int,
          expiryLabel: data['expiryLabel'] as String,
        ));
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Promo' : 'Tambah Promo'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(labelText: 'Kode (mis. HEMAT10K)'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Judul'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PromoDiscountType>(
                        initialValue: _discountType,
                        decoration: const InputDecoration(labelText: 'Tipe diskon'),
                        items: const [
                          DropdownMenuItem(
                              value: PromoDiscountType.flat, child: Text('Flat (Rp)')),
                          DropdownMenuItem(
                              value: PromoDiscountType.percent, child: Text('Persen (%)')),
                        ],
                        onChanged: (v) => setState(
                            () => _discountType = v ?? PromoDiscountType.flat),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _discountValueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _discountType == PromoDiscountType.percent
                              ? 'Nilai (%)'
                              : 'Nilai (Rp)',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'Angka > 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minOrderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minimum order (Rp)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expiryLabelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Label masa berlaku (mis. "Berlaku hari ini")'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _onSave,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
