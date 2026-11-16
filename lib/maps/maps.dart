// Maps & places, behind small interfaces so the provider can change later.
//   • tiles: OpenStreetMap (fine for testing; a public launch should switch the
//     URL to a free-tier provider with a key: MapTiler, Stadia…)
//   • place search: Photon (OSM data, made for search-as-you-type)
// Only generic headers are sent (app package name), never anything about the user.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

const _packageName = 'com.seeuapp.mobile';
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// false in widget tests (no network): maps render as a plain placeholder.
final mapsEnabledProvider = Provider<bool>((ref) => true);

class PlaceResult {
  const PlaceResult({required this.name, this.address, required this.lat, required this.lng, this.kind});
  final String name;
  final String? address;
  final double lat;
  final double lng;

  /// OSM type ("bar", "restaurant", "house"…), for the icon.
  final String? kind;

  /// What goes into the event's place field.
  String get label => address == null || address!.isEmpty ? name : '$name, $address';
}

abstract class PlaceSearch {
  Future<List<PlaceResult>> search(String query, {required String lang, LatLng? near});
}

class PhotonPlaceSearch implements PlaceSearch {
  PhotonPlaceSearch([http.Client? client]) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  Future<List<PlaceResult>> search(String query, {required String lang, LatLng? near}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'limit': '7',
      // Photon knows de / en / fr / it
      'lang': const {'fr', 'en', 'de', 'it'}.contains(lang) ? lang : 'en',
      if (near != null) ...{'lat': '${near.latitude}', 'lon': '${near.longitude}'},
    });
    final res = await _client.get(uri, headers: {'User-Agent': 'SeeU/1.0 ($_packageName)'}).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw HttpException('places ${res.statusCode}');
    final features = (jsonDecode(res.body) as Map<String, dynamic>)['features'] as List? ?? const [];
    final out = <PlaceResult>[];
    for (final f in features.cast<Map<String, dynamic>>()) {
      final coords = (f['geometry'] as Map?)?['coordinates'] as List?;
      final p = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (coords == null || coords.length < 2) continue;
      final street = [p['street'], p['housenumber']].whereType<String>().join(' ');
      final city = [p['postcode'], p['city'] ?? p['town'] ?? p['village']].whereType<String>().join(' ');
      final name = (p['name'] as String?) ?? (street.isNotEmpty ? street : city);
      if (name.isEmpty) continue;
      final address = [if (street.isNotEmpty && street != name) street, if (city.isNotEmpty && city != name) city, ?(p['country'] as String?)]
          .join(', ');
      out.add(PlaceResult(
        name: name,
        address: address,
        lat: (coords[1] as num).toDouble(),
        lng: (coords[0] as num).toDouble(),
        kind: p['osm_value'] as String?,
      ));
    }
    return out;
  }
}

final placeSearchProvider = Provider<PlaceSearch>((ref) => PhotonPlaceSearch());

IconData placeIcon(String? kind) => switch (kind) {
      'bar' || 'pub' || 'biergarten' => LucideIcons.beer,
      'cafe' => LucideIcons.coffee,
      'restaurant' || 'fast_food' || 'food_court' => LucideIcons.utensils,
      'cinema' || 'theatre' => LucideIcons.clapperboard,
      'park' || 'garden' => LucideIcons.trees,
      'museum' || 'gallery' => LucideIcons.landmark,
      'nightclub' => LucideIcons.music,
      'station' || 'halt' || 'bus_stop' => LucideIcons.trainFront,
      _ => LucideIcons.mapPin,
    };

/// Opens the place in the phone's maps app (Apple Plans / Google Maps…).
/// iOS: the maps:// scheme opens Plans directly (an https link went through
/// the system's link handling and only logged a sandbox error).
Future<void> openInMaps(double lat, double lng, String label) async {
  final q = Uri.encodeComponent(label);
  final tries = Platform.isIOS
      ? [
          Uri.parse('maps://?ll=$lat,$lng&q=$q'),
          Uri.parse('https://maps.apple.com/?ll=$lat,$lng&q=$q'),
        ]
      : [Uri.parse('geo:$lat,$lng?q=$lat,$lng($q)')];
  for (final uri in tries) {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (ok) return;
  }
  await launchUrl(Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng'), mode: LaunchMode.externalApplication)
      .catchError((_) => false);
}

/// Base map: OSM tiles + attribution; [children] add markers.
class AppMap extends ConsumerWidget {
  const AppMap({super.key, required this.options, this.children = const [], this.mapController});
  final MapOptions options;
  final List<Widget> children;
  final MapController? mapController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    if (!ref.watch(mapsEnabledProvider)) {
      return Container(color: c.secondaryFill, alignment: Alignment.center, child: Icon(LucideIcons.map, color: c.textSubtle, size: 32));
    }
    return FlutterMap(
      mapController: mapController,
      options: options,
      children: [
        TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _packageName, maxZoom: 19),
        ...children,
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomRight,
          attributions: [TextSourceAttribution('OpenStreetMap', onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')))],
        ),
      ],
    );
  }
}

/// Pin used on every map.
class MapPin extends StatelessWidget {
  const MapPin({super.key, this.icon = LucideIcons.mapPin, this.color, this.selected = false});
  final IconData icon;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final col = color ?? Palette.brand600;
    final s = selected ? 40.0 : 34.0;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: col,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, size: s * 0.5, color: Colors.white),
    );
  }
}

/// Small map of one place (event page): tap → maps app.
class PlaceMapCard extends StatelessWidget {
  const PlaceMapCard({super.key, required this.lat, required this.lng, required this.label, this.height = 170});
  final double lat;
  final double lng;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final point = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          AppMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15.5,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              onTap: (_, _) => openInMaps(lat, lng, label),
            ),
            children: [MarkerLayer(markers: [Marker(point: point, width: 40, height: 40, child: const MapPin())])],
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Material(
              color: c.card,
              borderRadius: BorderRadius.circular(99),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => openInMaps(lat, lng, label),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.navigation, size: 15, color: c.brandText),
                    const SizedBox(width: 6),
                    Text(tr.openInMaps, style: TextStyle(color: c.brandText, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
