// SeeU design kit: buttons, cards, pills, chips, avatars, states.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../data/providers.dart';
import '../domain/dates.dart';
import '../domain/models.dart';
import '../domain/text.dart';
import '../core/i18n.dart';

/* ------------------------------------------------------------------ */
/*  Pressable: shrinks slightly on touch                               */
/* ------------------------------------------------------------------ */

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.borderRadius});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/*  Buttons                                                            */
/* ------------------------------------------------------------------ */

enum ButtonVariant { primary, secondary, outline, ghost, success, danger }

enum ButtonSize { sm, md, lg }

/// Button. For actions that take time, pass [onAsync]: the button shows a spinner
/// and ignores taps until the future completes (no need to track `loading` by hand).
class AppButton extends StatefulWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.onAsync,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.loading = false,
    this.full = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Future<void> Function()? onAsync;
  final IconData? icon;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool loading;
  final bool full;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _running = false;

  Future<void> _runAsync() async {
    setState(() => _running = true);
    try {
      await widget.onAsync!();
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final icon = widget.icon;
    final variant = widget.variant;
    final size = widget.size;
    final full = widget.full;
    final loading = widget.loading || _running;
    final VoidCallback? onPressed = widget.onAsync != null ? _runAsync : widget.onPressed;
    final c = context.colors;
    final (Color bg, Color fg, Color? border) = switch (variant) {
      ButtonVariant.primary => (Palette.brand600, Colors.white, null),
      ButtonVariant.secondary => (c.secondaryFill, c.text, null),
      ButtonVariant.outline => (c.card, c.text, c.isDark ? Palette.gray700 : Palette.gray300),
      ButtonVariant.ghost => (Colors.transparent, c.brandText, null),
      ButtonVariant.success => (c.tone(Tone.green).solid, Colors.white, null),
      ButtonVariant.danger => (c.tone(Tone.red).solid, Colors.white, null),
    };
    final height = switch (size) { ButtonSize.sm => 38.0, ButtonSize.md => 46.0, ButtonSize.lg => 54.0 };
    final fontSize = switch (size) { ButtonSize.sm => 14.0, ButtonSize.md => 15.5, ButtonSize.lg => 16.5 };
    final disabled = onPressed == null || loading;

    final content = Row(
      mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: fontSize + 3, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: Pressable(
        onTap: disabled ? null : onPressed,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: size == ButtonSize.sm ? 12 : 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.button),
            border: border == null ? null : Border.all(color: border),
          ),
          child: content,
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.color, this.filled = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        scale: 0.92,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: filled ? const BoxDecoration(color: Palette.brand600, shape: BoxShape.circle) : null,
          child: Icon(icon, size: 24, color: filled ? Colors.white : (color ?? c.text)),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/*  Cards & sections                                                   */
/* ------------------------------------------------------------------ */

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.borderColor, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: borderColor ?? c.border),
        boxShadow: c.isDark
            ? null
            : const [
                BoxShadow(color: Color(0x0F101828), blurRadius: 2, offset: Offset(0, 1)),
                BoxShadow(color: Color(0x1A101828), blurRadius: 3, offset: Offset(0, 1)),
              ],
      ),
      // Ink (ListTile/InkWell ripples) must paint above the card background.
      child: Material(type: MaterialType.transparency, child: child),
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: 0.99, child: box);
  }
}

/// Card with rows separated by dividers (no padding).
class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: c.divider),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.count, this.padding = const EdgeInsets.only(top: 24, bottom: 10)});
  final String title;
  final Widget? action;
  final int? count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: title),
                if (count != null) TextSpan(text: ' ($count)', style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w500)),
              ]),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class Overline extends StatelessWidget {
  const Overline(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 12.5, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: context.colors.textMuted),
        ),
      );
}

/// Info box on light brand background.
class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.child, this.tone});
  final Widget child;
  final Tone? tone;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = tone == null ? null : c.tone(tone!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t?.bg ?? c.brandSoft, borderRadius: BorderRadius.circular(16)),
      child: DefaultTextStyle.merge(style: TextStyle(color: t?.fg ?? c.text, fontSize: 14.5, height: 1.35), child: child),
    );
  }
}

/* ------------------------------------------------------------------ */
/*  Pills & chips                                                      */
/* ------------------------------------------------------------------ */

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = Tone.gray, this.icon, this.dot = false, this.large = false});
  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dot;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(tone);
    final fs = large ? 15.0 : 12.5;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: large ? 6 : 4),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: t.solid, shape: BoxShape.circle)),
            const SizedBox(width: 7),
          ],
          if (icon != null) ...[Icon(icon, size: fs + 2, color: t.fg), const SizedBox(width: 6)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.fg, fontSize: fs, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

Tone dueTone(DueKind k) => switch (k) {
      DueKind.overdue => Tone.red,
      DueKind.today => Tone.orange,
      DueKind.soon => Tone.amber,
      DueKind.ok => Tone.green,
    };

class DueBadge extends StatelessWidget {
  const DueBadge(this.contact, {super.key, this.short = false, this.large = false});
  final HasDue contact;
  final bool short;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final info = dueInfo(contact);
    return Pill(short ? info.short : info.label, tone: dueTone(info.kind), dot: true, large: large);
  }
}

Tone statusTone(RdvStatus s) => switch (s) {
      RdvStatus.planifie => Tone.brand,
      RdvStatus.valide => Tone.green,
      RdvStatus.annule => Tone.gray,
    };

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final RdvStatus status;
  @override
  Widget build(BuildContext context) => Pill(status.label, tone: statusTone(status));
}

/// Status as shown to people: Prévu / En cours / Passé / A eu lieu / Annulé.
class PhasePill extends StatelessWidget {
  const PhasePill(this.rdv, {super.key});
  final Rendezvous rdv;
  @override
  Widget build(BuildContext context) {
    final p = rdv.phase();
    return Pill(p.label,
        dot: p == RdvPhase.now,
        tone: switch (p) {
          RdvPhase.upcoming => Tone.brand,
          RdvPhase.now => Tone.green,
          RdvPhase.past => Tone.amber,
          RdvPhase.done => statusTone(RdvStatus.valide),
          RdvPhase.cancelled => statusTone(RdvStatus.annule),
        });
  }
}

class AppChip extends StatelessWidget {
  const AppChip(this.label, {super.key, required this.selected, this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Palette.brand600 : c.card,
          border: Border.all(color: selected ? Palette.brand600 : (c.isDark ? Palette.gray700 : Palette.gray300)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: selected ? Colors.white : c.text), const SizedBox(width: 6)],
          Text(label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: selected ? Colors.white : c.text)),
        ]),
      ),
    );
  }
}

class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: children);
}

/// Horizontally scrolling chip row (bleeds to screen edges).
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(children: [for (final w in children) Padding(padding: const EdgeInsets.only(right: 8), child: w)]),
      );
}

/* ------------------------------------------------------------------ */
/*  Avatars                                                            */
/* ------------------------------------------------------------------ */

const _avatarLight = [
  (Color(0xFFFECDD3), Color(0xFF881337)),
  (Color(0xFFFED7AA), Color(0xFF7C2D12)),
  (Color(0xFFFDE68A), Color(0xFF78350F)),
  (Color(0xFFD9F99D), Color(0xFF365314)),
  (Color(0xFFA7F3D0), Color(0xFF064E3B)),
  (Color(0xFF99F6E4), Color(0xFF134E4A)),
  (Color(0xFFBAE6FD), Color(0xFF0C4A6E)),
  (Color(0xFFC7D2FE), Color(0xFF312E81)),
  (Color(0xFFDDD6FE), Color(0xFF4C1D95)),
  (Color(0xFFF5D0FE), Color(0xFF701A75)),
];

/// Photo of a private file (signed URL), cached by storage path.
class StorageImage extends ConsumerWidget {
  const StorageImage(this.path, {super.key, this.fit = BoxFit.cover, this.placeholder, this.width, this.height, this.cacheWidth});
  final String path;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;

  /// Decoded width in memory (px): small for grid cells.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedUrlProvider(path));
    final ph = placeholder ?? Container(color: context.colors.secondaryFill);
    return url.when(
      data: (u) => CachedNetworkImage(
        imageUrl: u,
        cacheKey: path,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: cacheWidth ?? (width == null ? null : (width! * MediaQuery.devicePixelRatioOf(context)).round()),
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => ph,
        errorWidget: (_, _, _) => ph,
      ),
      loading: () => ph,
      error: (_, _) => ph,
    );
  }
}

class Avatar extends ConsumerWidget {
  const Avatar({super.key, required this.name, this.path, this.size = 44, this.ring, this.seeu = true, this.userId});
  final String name;

  /// My own photo for a contact (private bucket).
  final String? path;
  final double size;
  final Color? ring;

  /// Convention: someone without a SeeU account (a contact not linked) is a plain
  /// grey person icon (or the photo I set, with a small "regular contact" badge);
  /// SeeU accounts get their profile picture, else colored initials.
  final bool seeu;

  /// SeeU account: shows their profile picture when they have one.
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isSeeu = seeu || userId != null;
    final url = userId == null ? null : ref.watch(avatarUrlProvider(userId!)).value;
    final (bg, fg) = _avatarLight[colorIndexFor(name)];
    final initialsBox = isSeeu
        ? Container(
            color: bg,
            alignment: Alignment.center,
            child: Text(initials(name),
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: (size * 0.38).clamp(11, 40))),
          )
        : Container(
            color: c.isDark ? Palette.gray700 : Palette.gray200,
            alignment: Alignment.center,
            child: Icon(LucideIcons.user, size: size * 0.52, color: c.isDark ? Palette.gray400 : Palette.gray500),
          );
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: ring == null ? null : Border.all(color: ring!, width: 2)),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover,
                placeholder: (_, _) => initialsBox, errorWidget: (_, _, _) => initialsBox)
            : path == null
                ? initialsBox
                : StorageImage(path!, placeholder: initialsBox, width: size, height: size),
      ),
    );
    // A photo on someone without SeeU: small "regular contact" badge (the plain
    // grey icon says it already when there's no photo).
    if (isSeeu || path == null || size < 32) return circle;
    final badge = size * 0.4;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        circle,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: badge,
            height: badge,
            decoration: BoxDecoration(
                color: c.isDark ? Palette.gray600 : Palette.gray400, shape: BoxShape.circle, border: Border.all(color: c.card, width: 2)),
            child: Icon(LucideIcons.user, size: badge * 0.55, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.people, this.size = 28, this.max = 3});
  final List<ContactLite> people;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = people.take(max).toList();
    final rest = people.length - shown.length;
    final items = <Widget>[
      for (final p in shown) Avatar(name: p.name, path: p.photoPath, size: size, ring: c.card, seeu: p.linkedUserId != null, userId: p.linkedUserId),
      if (rest > 0)
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.secondaryFill, shape: BoxShape.circle, border: Border.all(color: c.card, width: 2)),
          child: Text('+$rest', style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w600, color: c.text)),
        ),
    ];
    final step = size * 0.7;
    return SizedBox(
      width: size + step * (items.length - 1),
      height: size,
      child: Stack(children: [for (var i = 0; i < items.length; i++) Positioned(left: i * step, child: items[i])]),
    );
  }
}

/* ------------------------------------------------------------------ */
/*  States: empty, error, loading                                      */
/* ------------------------------------------------------------------ */

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actions = const []});
  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
            child: Icon(icon, color: c.brandText, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 15, height: 1.4)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 10), child: a),
          ],
        ],
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(Tone.red);
    return AppCard(
      color: t.bg,
      borderColor: t.bg,
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, color: t.fg),
          const SizedBox(width: 12),
          Expanded(child: Text(errorMessage(error), style: TextStyle(color: t.fg, fontSize: 15))),
          if (onRetry != null) AppButton(tr.retry, size: ButtonSize.sm, variant: ButtonVariant.outline, onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Grey animated rows while a list loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4});
  final int rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = c.isDark ? Palette.gray800 : Palette.gray200;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: c.isDark ? Palette.gray700 : Palette.gray100,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 14, width: 160, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 220, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6))),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Renders an AsyncValue with the standard loading skeleton / error card.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry, this.skeletonRows = 4});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final int skeletonRows;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return builder(value.requireValue);
    if (value.hasError) return ErrorCard(error: value.error!, onRetry: onRetry);
    return SkeletonList(rows: skeletonRows);
  }
}


/// A contact category, always drawn the same way: a small colored box with a
/// tag icon (color fixed per category name), so it reads as "category".
Tone categoryTone(String name) {
  const tones = [Tone.violet, Tone.green, Tone.amber, Tone.pink, Tone.orange, Tone.brand];
  final key = normalizeText(name);
  var h = 0;
  for (final u in key.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return tones[h % tones.length];
}

class CategoryTag extends StatelessWidget {
  const CategoryTag(this.name, {super.key, this.large = false, this.selected, this.onTap});
  final String name;
  final bool large;

  /// Picker mode: null = plain tag; true / false = selectable.
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = c.tone(categoryTone(name));
    final picking = selected != null;
    final on = selected ?? true;
    final fs = large ? 14.5 : (picking ? 13.5 : 11.5);
    final tag = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.symmetric(horizontal: large || picking ? 10 : 6, vertical: large || picking ? 6 : 2),
      decoration: BoxDecoration(
        color: on ? t.bg : t.bg.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(large || picking ? 10 : 6),
        border: Border.all(color: on ? t.solid.withValues(alpha: 0.35) : c.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(picking && on ? LucideIcons.check : LucideIcons.tag, size: fs, color: on ? t.fg : c.textMuted),
        SizedBox(width: large || picking ? 5 : 3),
        Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: on ? t.fg : c.textMuted, height: 1.2)),
        ),
      ]),
    );
    return onTap == null ? tag : Pressable(onTap: onTap, scale: 0.95, child: tag);
  }
}

/// Up to [max] category tags on one line, then "+n".
class CategoryTags extends StatelessWidget {
  const CategoryTags(this.names, {super.key, this.max = 2});
  final List<String> names;
  final int max;
  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final n in shown) ...[Flexible(child: CategoryTag(n)), const SizedBox(width: 4)],
      if (names.length > max)
        Text('+${names.length - max}', style: TextStyle(fontSize: 11.5, color: context.colors.textMuted, fontWeight: FontWeight.w600)),
    ]);
  }
}
