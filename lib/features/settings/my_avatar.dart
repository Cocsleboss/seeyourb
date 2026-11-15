// My SeeU profile picture: what friends and people in my events see.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../photos/photo_section.dart';

class MyAvatarPicker extends ConsumerStatefulWidget {
  const MyAvatarPicker({super.key, this.size = 76});
  final double size;
  @override
  ConsumerState<MyAvatarPicker> createState() => _MyAvatarPickerState();
}

class _MyAvatarPickerState extends ConsumerState<MyAvatarPicker> {
  bool _busy = false;

  Future<void> _set(bool remove) async {
    final me = ref.read(profileProvider);
    if (me == null) return;
    final api = ref.read(apiProvider);
    final session = ref.read(sessionProvider);
    final bytes = remove ? null : await _pick();
    if (!remove && bytes == null) return;
    setState(() => _busy = true);
    final p = await guard(() => api.setMyAvatar(bytes, oldPath: me.avatarPath), success: remove ? tr.avatarRemoved : tr.avatarUpdated);
    if (!mounted) return;
    setState(() => _busy = false);
    if (p != null) {
      session.setProfile(p);
      ref.invalidate(avatarUrlProvider(me.id));
    }
  }

  Future<Uint8List?> _pick() async {
    final files = await pickPhotos(context, multiple: false);
    return files.isEmpty ? null : await files.first.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final me = ref.watch(profileProvider);
    if (me == null) return const SizedBox.shrink();
    final hasPhoto = me.avatarPath != null;
    return Row(children: [
      SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(children: [
          Avatar(key: ValueKey(me.avatarPath), name: me.name.isEmpty ? '?' : me.name, size: widget.size, userId: hasPhoto ? me.id : null),
          if (_busy)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            ),
        ]),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            AppButton(hasPhoto ? tr.change : tr.photoAdd,
                icon: LucideIcons.camera, variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: _busy ? null : () => _set(false)),
            if (hasPhoto)
              AppButton(tr.remove, variant: ButtonVariant.ghost, size: ButtonSize.sm, onPressed: _busy ? null : () => _set(true)),
          ]),
          const SizedBox(height: 6),
          Text(tr.avatarHint, style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.3)),
        ]),
      ),
    ]);
  }
}
