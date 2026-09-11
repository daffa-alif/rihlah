import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/core.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/providers/trip_booking_provider.dart';
import '../../../core/providers/saved_address_provider.dart';
import '../../../data/models/saved_address.dart';
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';
import 'map_picker_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();

  List<PlaceResult> _results    = [];
  bool _searching               = false;
  bool _loadingGps              = false;
  String _pickupLabel           = 'Mendeteksi lokasi…';

  Timer? _debounce;

  // Suggested places (static seed)
  static final _suggested = [
    PlaceResult(name: 'Trans Studio Bandung', address: 'Jl. Gatot Subroto', latLng: LatLng(-6.9206, 107.6066)),
    PlaceResult(name: 'Bandung Station', address: 'Jl. Stasiun Timur', latLng: LatLng(-6.9114, 107.6075)),
    PlaceResult(name: 'Institut Teknologi Bandung', address: 'Jl. Ganesha 10', latLng: LatLng(-6.8915, 107.6107)),
    PlaceResult(name: 'BIP Mall', address: 'Jl. Merdeka 56', latLng: LatLng(-6.9157, 107.6066)),
    PlaceResult(name: 'Gasibu Square', address: 'Jl. Diponegoro', latLng: LatLng(-6.9024, 107.6192)),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _initGps();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initGps() async {
    setState(() => _loadingGps = true);
    final pos   = await LocationService.instance.getCurrentPosition();
    final label = await GeocodingService.instance.reverseGeocode(pos);
    if (!mounted) return;
    ref.read(tripBookingProvider.notifier).setPickup(pos, label);
    setState(() { _pickupLabel = label; _loadingGps = false; });
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) { setState(() => _results = []); return; }
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    setState(() => _searching = true);
    final r = await GeocodingService.instance.search(q);
    if (!mounted) return;
    setState(() { _results = r; _searching = false; });
  }

  // 👇 PERUBAHAN ROUTE: Langsung ke Confirm Screen
  void _onSelected(PlaceResult place) {
    _focusNode.unfocus();
    ref.read(tripBookingProvider.notifier).setDropoff(place);
    context.push(Routes.pConfirm);
  }

  // 👇 PERUBAHAN ROUTE: Langsung ke Confirm Screen
  void _onSavedAddressSelected(SavedAddress addr) {
    _focusNode.unfocus();
    ref.read(tripBookingProvider.notifier).setDropoffRaw(addr.latLng, addr.name);
    context.push(Routes.pConfirm);
  }

  @override
  Widget build(BuildContext context) {
    final s            = AppLocalizations.of(context);
    final hasInput     = _searchCtrl.text.isNotEmpty;
    final savedAddrs   = ref.watch(savedAddressProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Tema warna background baru
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary500),
          onPressed: () => context.pop(),
        ),
        title: Text(
            s.search_title,
            style: AppTypography.h3.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w700)
        ),
      ),
      body: Column(
        children: [
          // ── Input card Modern ─────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            decoration: BoxDecoration(
              color: AppColors.ink0,
              borderRadius: AppRadius.xlAll,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                // Pickup Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location_rounded, color: AppColors.primary500, size: 20),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: _loadingGps
                            ? Row(children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary500)),
                          const SizedBox(width: 8),
                          Text('Mendeteksi lokasi…', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                        ])
                            : Text(_pickupLabel,
                            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink900),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final result = await context.push<MapPickerResult>('/p/map-picker?title=Pilih+Penjemputan');
                          if (result != null && mounted) {
                            ref.read(tripBookingProvider.notifier).setPickup(result.latLng, result.name);
                            setState(() => _pickupLabel = result.name);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: AppRadius.smAll),
                          child: const Icon(Icons.map_rounded, size: 18, color: AppColors.ink500),
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider Line
                const Padding(
                  padding: EdgeInsets.only(left: 48, right: 16),
                  child: Divider(height: 1, color: Color(0xFFF1F3F5)),
                ),

                // Dropoff Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.danger500, size: 20),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _focusNode,
                          style: AppTypography.bodyMd.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: s.search_placeholder,
                            hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.ink400, fontWeight: FontWeight.w400),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (hasInput)
                        GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: const Icon(Icons.cancel_rounded, size: 20, color: AppColors.ink300),
                        ),
                      if (!hasInput)
                        GestureDetector(
                          onTap: () async {
                            final result = await context.push<MapPickerResult>('/p/map-picker?title=Pilih+Tujuan');
                            if (result != null && mounted) {
                              ref.read(tripBookingProvider.notifier).setDropoffRaw(result.latLng, result.name);
                              setState(() {
                                _searchCtrl.text = result.name;
                                _results = [];
                              });
                              // 👇 PERUBAHAN ROUTE: Langsung ke Confirm Screen
                              context.push(Routes.pConfirm);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: AppRadius.smAll),
                            child: const Icon(Icons.map_rounded, size: 18, color: AppColors.ink500),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Search Results List ───────────────────────────────────────
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary500))
                : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              children: [
                if (hasInput && _results.isNotEmpty) ...[
                  _Header(label: s.search_results),
                  ..._results.map((p) => _Row(place: p, onTap: () => _onSelected(p))),
                ],
                if (hasInput && _results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s32),
                    child: Text(
                      '${s.search_no_results} "${_searchCtrl.text}"',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.ink500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!hasInput) ...[
                  // Saved addresses
                  if (savedAddrs.isNotEmpty) ...[
                    _Header(label: s.search_saved),
                    ...savedAddrs.map((a) => _SavedRow(address: a, onTap: () => _onSavedAddressSelected(a))),
                  ],
                  _Header(label: s.search_suggested),
                  ..._suggested.map((p) => _Row(place: p, onTap: () => _onSelected(p))),
                ],
                const SizedBox(height: AppSpacing.s32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Komponen UI Pendukung ────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s16, AppSpacing.s12, AppSpacing.s8),
    child: Text(label, style: AppTypography.label.copyWith(color: AppColors.ink500, fontWeight: FontWeight.w700)),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.place, required this.onTap});
  final PlaceResult  place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F3F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded, size: 20, color: AppColors.ink500),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (place.address.isNotEmpty)
                    Text(place.address, style: AppTypography.bodySm.copyWith(color: AppColors.ink500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.address, required this.onTap});
  final SavedAddress address;
  final VoidCallback onTap;

  IconData get _icon => switch (address.label) {
    'Rumah'  => Icons.home_rounded,
    'Kantor' => Icons.work_rounded,
    _        => Icons.bookmark_rounded,
  };

  Color get _iconColor => switch (address.label) {
    'Rumah'  => AppColors.primary500,
    'Kantor' => AppColors.info500,
    _        => AppColors.accent500,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 20, color: _iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.label, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                  Text(address.name, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}