import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/core.dart';

class SafetySettingsScreen extends StatefulWidget {
  const SafetySettingsScreen({super.key});

  @override
  State<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends State<SafetySettingsScreen> {
  List<Map<String, String>> _contacts = [];

  static const _maxContacts = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final raw = Hive.box('settings').get('emergency_contacts') as List?;
    if (raw != null) {
      setState(() {
        _contacts = raw
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      });
    }
  }

  Future<void> _save() async {
    await Hive.box('settings').put('emergency_contacts', _contacts);
  }

  void _onAdd() {
    if (_contacts.length >= _maxContacts) {
      Toast.show(context,
          message: 'Maksimal $_maxContacts kontak darurat',
          type: ToastType.warning);
      return;
    }
    _showContactSheet(null);
  }

  Future<void> _onRemove(int idx) async {
    setState(() => _contacts.removeAt(idx));
    await _save();
    if (mounted) {
      Toast.show(context, message: 'Kontak dihapus', type: ToastType.warning);
    }
  }

  void _showContactSheet(int? editIdx) {
    final nameCtrl = TextEditingController(
        text: editIdx != null ? _contacts[editIdx]['name'] : '');
    final phoneCtrl = TextEditingController(
        text: editIdx != null ? _contacts[editIdx]['phone'] : '');
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s24,
            left: AppSpacing.s24,
            right: AppSpacing.s24,
            top: AppSpacing.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                editIdx != null ? 'Edit Kontak' : 'Tambah Kontak Darurat',
                style: AppTypography.h2,
              ),
              const SizedBox(height: AppSpacing.s24),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  hintText: 'contoh: Ibu, Bapak, Teman Reza',
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  hintText: '08xxxxxxxxxx',
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.lgAll),
                  ),
                  onPressed: () async {
                    final name  = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    if (name.isEmpty || phone.isEmpty) {
                      Toast.show(context,
                          message: 'Nama dan nomor HP wajib diisi',
                          type: ToastType.warning);
                      return;
                    }
                    final entry = {'name': name, 'phone': phone};
                    setState(() {
                      if (editIdx != null) {
                        _contacts[editIdx] = entry;
                      } else {
                        _contacts.add(entry);
                      }
                    });
                    await _save();
                    if (!mounted) return;
                    Navigator.pop(context);
                    Toast.show(context,
                        message: editIdx != null
                            ? 'Kontak diperbarui'
                            : 'Kontak ditambahkan',
                        type: ToastType.success);
                  },
                  child: Text(
                    editIdx != null ? 'Simpan Perubahan' : 'Tambah Kontak',
                    style: AppTypography.bodyMd.copyWith(
                        color: AppColors.ink0, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Keamanan', style: AppTypography.h3),
        elevation: 0,
        backgroundColor: cs.surface,
      ),
      floatingActionButton: _contacts.length < _maxContacts
          ? FloatingActionButton.extended(
              onPressed: _onAdd,
              backgroundColor: AppColors.primary500,
              foregroundColor: AppColors.ink0,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Kontak'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          // ── Emergency contacts ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kontak Darurat',
                  style: AppTypography.label
                      .copyWith(color: cs.onSurfaceVariant)),
              Text('${_contacts.length}/$_maxContacts',
                  style: AppTypography.label
                      .copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          if (_contacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.s12),
                  Text('Belum ada kontak darurat',
                      style: AppTypography.h3.copyWith(color: cs.onSurface)),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Tambah hingga 3 kontak yang akan dihubungi via WhatsApp saat tombol SOS ditekan.',
                    style: AppTypography.bodyMd
                        .copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _onAdd,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.lgAll),
                      ),
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.ink0, size: 18),
                      label: Text('Tambah Kontak Pertama',
                          style: AppTypography.bodyMd.copyWith(
                              color: AppColors.ink0,
                              fontWeight: FontWeight.w600)),
                    ),
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
                  for (int i = 0; i < _contacts.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 68),
                    _ContactTile(
                      contact: _contacts[i],
                      onEdit: () => _showContactSheet(i),
                      onRemove: () => _onRemove(i),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.s24),

          // ── How SOS works ──────────────────────────────────────────────────
          Text('Cara Kerja SOS',
              style: AppTypography.label.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.danger500.withOpacity(0.06),
              borderRadius: AppRadius.lgAll,
              border:
                  Border.all(color: AppColors.danger500.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _SosStep(
                  icon: Icons.touch_app_rounded,
                  iconColor: AppColors.danger500,
                  label: '1. Tahan tombol SOS 3 detik',
                  sub: 'Mencegah pengiriman tidak sengaja',
                ),
                const SizedBox(height: AppSpacing.s16),
                _SosStep(
                  icon: Icons.location_on_rounded,
                  iconColor: AppColors.info500,
                  label: '2. Lokasi GPS diambil otomatis',
                  sub: 'Koordinat real-time disertakan dalam pesan',
                ),
                const SizedBox(height: AppSpacing.s16),
                _SosStep(
                  icon: Icons.send_rounded,
                  iconColor: const Color(0xFF25D366),
                  label: '3. Pesan WhatsApp dikirim ke kontakmu',
                  sub: 'Semua kontak darurat yang kamu simpan di sini',
                ),
                const SizedBox(height: AppSpacing.s16),
                _SosStep(
                  icon: Icons.support_agent_rounded,
                  iconColor: AppColors.primary500,
                  label: '4. Tim RIHLAH diberitahu',
                  sub: 'Dashboard ops mendapat alert merah segera',
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onEdit,
    required this.onRemove,
  });
  final Map<String, String> contact;
  final VoidCallback         onEdit;
  final VoidCallback         onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary100,
            child: Text(
              contact['name']![0].toUpperCase(),
              style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary600),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact['name']!,
                    style: AppTypography.bodyMd
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(contact['phone']!,
                    style: AppTypography.bodySm
                        .copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: cs.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppColors.danger500,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SosStep extends StatelessWidget {
  const _SosStep({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
  });
  final IconData icon;
  final Color    iconColor;
  final String   label, sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: AppRadius.smAll,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              Text(sub,
                  style: AppTypography.bodySm
                      .copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
