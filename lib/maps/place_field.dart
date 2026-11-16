// Event place: free text, or a real place / address picked from the suggestions
// (then shown on a small map). Typing again un-picks it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';
import 'maps.dart';

class PlaceField extends ConsumerStatefulWidget {
  const PlaceField({super.key, required this.controller, required this.lat, required this.lng, required this.onPlace, this.hint});
  final TextEditingController controller;
  final double? lat;
  final double? lng;

  /// A place was picked (null: back to free text).
  final ValueChanged<PlaceResult?> onPlace;
  final String? hint;

  @override
  ConsumerState<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends ConsumerState<PlaceField> {
  Timer? _debounce;
  List<PlaceResult> _results = const [];
  bool _searching = false;
  bool _failed = false;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    if (widget.lat != null) widget.onPlace(null);
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final seq = ++_seq;
    final lang = Localizations.localeOf(context).languageCode;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final near = await ref.read(searchBiasProvider.future).catchError((_) => null);
        final r = await ref.read(placeSearchProvider).search(v, lang: lang, near: near);
        if (mounted && seq == _seq) setState(() => (_results = r, _failed = false));
      } catch (_) {
        if (mounted && seq == _seq) setState(() => (_results = const [], _failed = true));
      } finally {
        if (mounted && seq == _seq) setState(() => _searching = false);
      }
    });
  }

  void _clear() {
    _debounce?.cancel();
    _seq++;
    widget.controller.clear();
    if (widget.lat != null) widget.onPlace(null);
    setState(() {
      _results = const [];
      _searching = false;
      _failed = false;
    });
  }

  /// Keep the typed text as the place ("Chez moi", "Au parc"…), no map.
  void _keepText([String? text]) {
    _debounce?.cancel();
    _seq++;
    if (text != null) widget.controller.text = text;
    if (widget.lat != null) widget.onPlace(null);
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _searching = false;
    });
  }

  void _pick(PlaceResult p) {
    widget.controller.text = p.label;
    widget.onPlace(p);
    FocusScope.of(context).unfocus();
    setState(() => _results = const []);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final picked = widget.lat != null && widget.lng != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppTextField(
        controller: widget.controller,
        hint: widget.hint ?? tr.placeSearchHint,
        maxLength: 200,
        onChanged: (v) {
          _onChanged(v);
          setState(() {}); // show / hide the clear button
        },
        prefix: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Icon(picked ? LucideIcons.mapPinCheck : LucideIcons.search, size: 19, color: picked ? c.brandText : c.textMuted),
        ),
        // Loading indicator AND clear button, side by side.
        suffix: _searching || widget.controller.text.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                if (_searching)
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                if (widget.controller.text.isNotEmpty)
                  IconButton(
                    tooltip: tr.clearField,
                    visualDensity: VisualDensity.compact,
                    onPressed: _clear,
                    icon: Icon(LucideIcons.x, size: 18, color: c.textMuted),
                  ),
              ])
            : null,
      ),
      // Places that aren't addresses: one tap.
      if (widget.controller.text.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (icon, label) in [
              (LucideIcons.house, tr.placeAtMine),
              (LucideIcons.video, tr.placeVideo),
              (LucideIcons.circleHelp, tr.placeTbd),
            ])
              ActionChip(
                avatar: Icon(icon, size: 16, color: c.brandText),
                label: Text(label),
                labelStyle: TextStyle(color: c.text, fontWeight: FontWeight.w500, fontSize: 13.5),
                backgroundColor: c.secondaryFill,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                onPressed: () => _keepText(label),
              ),
          ]),
        ),
      if (_results.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              // First choice: keep exactly what was typed.
              ListTile(
                dense: true,
                leading: Icon(LucideIcons.pencilLine, size: 20, color: c.textMuted),
                title: Text(tr.placeUseText(widget.controller.text.trim()),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                subtitle: Text(tr.placeUseTextSub, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
                onTap: () => _keepText(),
              ),
              const Divider(height: 1),
              for (final p in _results)
                ListTile(
                  dense: true,
                  leading: Icon(placeIcon(p.kind), size: 20, color: c.brandText),
                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                  subtitle: p.address == null || p.address!.isEmpty
                      ? null
                      : Text(p.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
                  trailing: p.km == null
                      ? null
                      : Text(p.km! < 1 ? '${(p.km! * 1000).round()} m' : (p.km! < 10 ? '${p.km!.toStringAsFixed(1)} km' : '${p.km!.round()} km'),
                          style: TextStyle(color: c.textSubtle, fontSize: 12)),
                  onTap: () => _pick(p),
                ),
            ]),
          ),
        )
      else if (_failed)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(tr.placeSearchFailed, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
        ),
      if (picked) ...[
        const SizedBox(height: 8),
        PlaceMapCard(lat: widget.lat!, lng: widget.lng!, label: widget.controller.text, height: 130),
      ],
    ]);
  }
}
