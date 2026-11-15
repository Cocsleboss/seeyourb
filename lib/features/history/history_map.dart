// History → Carte: past events placed on a map (those whose place was picked
// from the search). Tap a pin: recap card, then the full event.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../maps/maps.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';

class HistoryMap extends ConsumerStatefulWidget {
  const HistoryMap({super.key});
  @override
  ConsumerState<HistoryMap> createState() => _HistoryMapState();
}

class _HistoryMapState extends ConsumerState<HistoryMap> {
  Rendezvous? _selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = ref.watch(historyProvider);
    return AsyncBody<List<Rendezvous>>(
      value: value,
      onRetry: () => ref.invalidate(historyProvider),
      builder: (all) {
        final placed = all.where((r) => r.event?.lat != null && r.event?.lng != null).toList();
        final points = [for (final r in placed) LatLng(r.event!.lat!, r.event!.lng!)];
        final options = points.isEmpty
            ? const MapOptions(initialCenter: LatLng(50.85, 4.35), initialZoom: 5)
            : points.length == 1
                ? MapOptions(initialCenter: points.first, initialZoom: 14, onTap: (_, _) => setState(() => _selected = null))
                : MapOptions(
                    initialCameraFit: CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 15),
                    onTap: (_, _) => setState(() => _selected = null),
                  );
        return Stack(children: [
          Positioned.fill(
            child: AppMap(
              options: options,
              children: [
                MarkerLayer(markers: [
                  for (final r in placed)
                    Marker(
                      point: LatLng(r.event!.lat!, r.event!.lng!),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = r),
                        child: MapPin(
                          icon: r.status == RdvStatus.annule ? LucideIcons.x : LucideIcons.calendarCheck,
                          color: r.status == RdvStatus.annule ? Palette.gray500 : Palette.brand600,
                          selected: _selected?.id == r.id,
                        ),
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
          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    RdvRow(rdv: _selected!),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: AppButton(tr.openEvent,
                          icon: LucideIcons.arrowRight, full: true, onPressed: () => context.push('/rdv/${_selected!.id}')),
                    ),
                  ]),
                ),
              ),
            ),
        ]);
      },
    );
  }
}
