// History → Carte: past events placed on a map (those whose place was picked
// from the search). Events at the same place share one pin (with a count);
// tapping it opens a card right above the pin, listing them.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../maps/maps.dart';
import '../../ui/kit.dart';

const _popupWidth = 290.0;
const _popupRowHeight = 64.0;
const _popupMaxRows = 4;

class _Place {
  _Place(this.point, this.rdvs);
  final LatLng point;
  final List<Rendezvous> rdvs;
  String get key => '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
}

/// Same place = same coordinates within ~10 m.
List<_Place> _groupByPlace(List<Rendezvous> all) {
  final byKey = <String, _Place>{};
  for (final r in all) {
    final lat = r.event?.lat, lng = r.event?.lng;
    if (lat == null || lng == null) continue;
    final k = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    (byKey[k] ??= _Place(LatLng(lat, lng), [])).rdvs.add(r);
  }
  for (final p in byKey.values) {
    p.rdvs.sort((a, b) => b.appointmentAt.compareTo(a.appointmentAt));
  }
  return byKey.values.toList();
}

class HistoryMap extends ConsumerStatefulWidget {
  const HistoryMap({super.key});
  @override
  ConsumerState<HistoryMap> createState() => _HistoryMapState();
}

class _HistoryMapState extends ConsumerState<HistoryMap> {
  final _map = MapController();
  String? _selected;

  double _popupHeight(_Place p) => 44 + _popupRowHeight * p.rdvs.length.clamp(1, _popupMaxRows);

  void _select(_Place p) {
    setState(() => _selected = p.key);
    // Recenter so the card above the pin is fully visible: the pin goes
    // below the middle by half the card's height.
    try {
      final zoom = _map.camera.zoom;
      _map.move(p.point, zoom, offset: Offset(0, _popupHeight(p) / 2 + 20));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = ref.watch(historyProvider);
    return AsyncBody<List<Rendezvous>>(
      value: value,
      onRetry: () => ref.invalidate(historyProvider),
      builder: (all) {
        final places = _groupByPlace(all);
        final points = [for (final p in places) p.point];
        final selected = places.where((p) => p.key == _selected).firstOrNull;
        void clear(TapPosition _, LatLng _) => setState(() => _selected = null);
        final options = points.isEmpty
            ? const MapOptions(initialCenter: LatLng(50.85, 4.35), initialZoom: 5)
            : points.length == 1
                ? MapOptions(initialCenter: points.first, initialZoom: 14, onTap: clear)
                : MapOptions(
                    initialCameraFit: CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(56), maxZoom: 15),
                    onTap: clear,
                  );
        return Stack(children: [
          Positioned.fill(
            child: AppMap(
              mapController: _map,
              options: options,
              children: [
                MarkerLayer(markers: [
                  for (final p in places)
                    Marker(
                      point: p.point,
                      width: 48,
                      height: 48,
                      child: GestureDetector(onTap: () => _select(p), child: _PlacePin(place: p, selected: p.key == _selected)),
                    ),
                ]),
                // The card sits right above its pin and moves with the map.
                if (selected != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: selected.point,
                      width: _popupWidth,
                      height: _popupHeight(selected) + 34,
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 34),
                        child: _PlaceCard(place: selected, onClose: () => setState(() => _selected = null)),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
          if (points.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: AppCard(
                child: Row(children: [
                  Icon(LucideIcons.mapPinOff, color: c.textMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tr.historyMapEmpty, style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.35))),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _PlacePin extends StatelessWidget {
  const _PlacePin({required this.place, required this.selected});
  final _Place place;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final n = place.rdvs.length;
    final allCancelled = place.rdvs.every((r) => r.status == RdvStatus.annule);
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      MapPin(
        icon: allCancelled ? LucideIcons.x : LucideIcons.calendarCheck,
        color: allCancelled ? Palette.gray500 : Palette.brand600,
        selected: selected,
      ),
      if (n > 1)
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            constraints: const BoxConstraints(minWidth: 20),
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.colors.tone(Tone.amber).solid, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white, width: 2)),
            child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onClose});
  final _Place place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = place.rdvs.first;
    return Material(
      color: c.card,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // place name + close
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 2, 0),
          child: Row(children: [
            Icon(LucideIcons.mapPin, size: 15, color: c.brandText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                place.rdvs.length > 1 ? '${first.location ?? ''} · ${tr.nEventsHere(place.rdvs.length)}' : (first.location ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tr.close,
              onPressed: onClose,
              icon: Icon(LucideIcons.x, size: 18, color: c.textMuted),
            ),
          ]),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 4),
            shrinkWrap: true,
            children: [
              for (final r in place.rdvs)
                InkWell(
                  onTap: () => context.push('/rdv/${r.id}'),
                  child: SizedBox(
                    height: _popupRowHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.displayTitle,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.text)),
                            const SizedBox(height: 2),
                            Text(capitalize(formatDateLong(r.appointmentAt)),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                          ]),
                        ),
                        PhasePill(r),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronRight, size: 18, color: c.textMuted),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}
