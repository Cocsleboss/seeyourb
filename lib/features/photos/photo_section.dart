// Photo gallery (grid of 3), uploader and fullscreen viewer (§4.6, §5.8).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../core/i18n.dart';
import '../events/moderation.dart';

/// Picks images resized to 1600 px max (long side) at ~80 % JPEG quality.
Future<List<XFile>> pickPhotos(BuildContext context, {bool multiple = true}) async {
  final source = await showAppSheet<ImageSource>(
    context,
    title: tr.photoAdd,
    builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppButton(tr.photoTake,
          icon: LucideIcons.camera, variant: ButtonVariant.secondary, onPressed: () => Navigator.pop(ctx, ImageSource.camera)),
      const SizedBox(height: 10),
      AppButton(tr.photoGallery,
          icon: LucideIcons.images, variant: ButtonVariant.secondary, onPressed: () => Navigator.pop(ctx, ImageSource.gallery)),
    ]),
  );
  if (source == null) return [];
  final picker = ImagePicker();
  try {
    if (source == ImageSource.gallery && multiple) {
      return await picker.pickMultiImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 95);
    }
    final one = await picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 95);
    return one == null ? [] : [one];
  } catch (e) {
    showToast(tr.photoAccessDenied, kind: ToastKind.error);
    return [];
  }
}

class PhotoSection extends ConsumerStatefulWidget {
  const PhotoSection(
      {super.key, required this.title, required this.photos, this.contactId, this.rdvId, this.emptyText, this.canAdd = true, this.eventId});

  /// Shared event: each photo shows who added it (small avatar, name on tap).
  final String? eventId;
  final String title;
  final AsyncValue<List<Photo>> photos;
  final String? contactId;
  final String? rdvId;
  final String? emptyText;

  /// False on public events for everyone but the organizer.
  final bool canAdd;

  @override
  ConsumerState<PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends ConsumerState<PhotoSection> {
  int _uploading = 0;

  Future<void> _add() async {
    final files = await pickPhotos(context);
    if (files.isEmpty) return;
    setState(() => _uploading += files.length);
    for (final f in files) {
      await guard(() async => ref.read(apiProvider).addPhoto(await f.readAsBytes(), contactId: widget.contactId, rdvId: widget.rdvId));
      if (!mounted) return;
      setState(() => _uploading--);
      refreshData(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photos = widget.photos.value ?? const <Photo>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(
        widget.title,
        action: !widget.canAdd
            ? null
            : AppButton(tr.add,
                icon: LucideIcons.camera, variant: ButtonVariant.ghost, size: ButtonSize.sm, onPressed: _uploading > 0 ? null : _add),
      ),
      if (widget.photos.isLoading && !widget.photos.hasValue)
        const SkeletonList(rows: 1)
      else if (photos.isEmpty && _uploading == 0)
        Text(widget.emptyText ?? tr.photoEmpty, style: TextStyle(color: c.textMuted, fontSize: 14.5))
      else
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < _uploading; i++) _PendingTile(),
            for (var i = 0; i < photos.length; i++)
              PhotoTile(photos: photos, index: i, eventId: widget.eventId),
          ],
        ),
    ]);
  }
}

class _PendingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Shimmer.fromColors(
      baseColor: c.isDark ? Palette.gray800 : Palette.gray200,
      highlightColor: c.isDark ? Palette.gray700 : Palette.gray100,
      child: Container(decoration: BoxDecoration(color: Palette.gray200, borderRadius: BorderRadius.circular(12))),
    );
  }
}

void openPhotoViewer(BuildContext context, List<Photo> photos, int index, {String? eventId}) {
  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (_, _, _) => PhotoViewer(photos: photos, initial: index, eventId: eventId),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
}

class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({super.key, required this.photos, required this.initial, this.eventId});
  final List<Photo> photos;
  final int initial;
  final String? eventId;
  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final PageController _page = PageController(initialPage: widget.initial);
  late final List<Photo> _photos = [...widget.photos];
  late int _index = widget.initial;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final photo = _photos[_index];
    final ok = await confirmSheet(context,
        title: tr.photoDeleteTitle, message: tr.irreversible, confirmLabel: tr.delete);
    if (!ok) return;
    final done = await guard(() async {
      await withProgress(() => ref.read(apiProvider).deletePhoto(photo));
      return true;
    }, success: tr.photoDeleted);
    if (done == null || !mounted) return;
    refreshData(ref);
    setState(() {
      _photos.removeAt(_index);
      if (_index >= _photos.length) _index = _photos.length - 1;
    });
    if (_photos.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userIdProvider);
    final mine = _photos.isNotEmpty && _photos[_index].userId == me;
    Widget arrow(IconData icon, int delta) => IconButton(
          onPressed: () => _page.animateToPage(_index + delta, duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
          icon: Icon(icon, color: Colors.white, size: 30),
          style: IconButton.styleFrom(backgroundColor: Colors.white12),
        );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _page,
          itemCount: _photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            child: Center(child: StorageImage(_photos[i].storagePath, fit: BoxFit.contain, placeholder: const SizedBox())),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              IconButton(
                tooltip: tr.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.white, size: 28),
              ),
              Expanded(
                child: Text('${_index + 1} / ${_photos.length}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ),
              if (mine)
                IconButton(tooltip: tr.delete, onPressed: _delete, icon: const Icon(LucideIcons.trash2, color: Colors.white, size: 24))
              else if (_photos.isNotEmpty)
                IconButton(
                  tooltip: tr.reportPhoto,
                  onPressed: () {
                    final photo = _photos[_index];
                    showReportSheet(context, ref,
                        title: tr.reportPhoto,
                        photoId: photo.id,
                        userId: photo.userId,
                        name: photoAuthorName(ref, photo, eventId: widget.eventId));
                  },
                  icon: const Icon(LucideIcons.flag, color: Colors.white, size: 22),
                )
              else
                const SizedBox(width: 48),
            ]),
          ),
        ),
        // Who added it, bottom-left.
        if (_photos.isNotEmpty)
          Positioned(
            left: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    PhotoAuthorBadge(photo: _photos[_index], eventId: widget.eventId, size: 28),
                    const SizedBox(width: 8),
                    Text(photoAuthorName(ref, _photos[_index], eventId: widget.eventId) ?? 'SeeU',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        if (_index > 0) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.all(8), child: arrow(LucideIcons.chevronLeft, -1))),
        if (_index < _photos.length - 1)
          Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.all(8), child: arrow(LucideIcons.chevronRight, 1))),
      ]),
    );
  }
}


/// Who added a photo: "Vous", a friend's name, or (in an event) a participant's.
String? photoAuthorName(WidgetRef ref, Photo p, {String? eventId}) {
  final me = ref.watch(profileProvider);
  if (p.userId == me?.id) return tr.you;
  return (ref.watch(friendsProvider).value ?? const <Friend>[]).where((f) => f.userId == p.userId).firstOrNull?.displayName ??
      (eventId == null
          ? null
          : (ref.watch(participantsProvider(eventId)).value ?? const <Participant>[]).where((x) => x.userId == p.userId).firstOrNull?.name);
}

/// The uploader's small avatar; tap → a tip with their name.
class PhotoAuthorBadge extends ConsumerWidget {
  const PhotoAuthorBadge({super.key, required this.photo, this.eventId, this.size = 24});
  final Photo photo;
  final String? eventId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(profileProvider);
    final name = photoAuthorName(ref, photo, eventId: eventId);
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 2),
      message: name ?? 'SeeU',
      child: Avatar(
        name: photo.userId == me?.id ? (me?.name ?? '?') : (name ?? '?'),
        userId: photo.userId,
        size: size,
        ring: Colors.white,
      ),
    );
  }
}

/// A photo in a grid, with its uploader's avatar bottom-right (every photo).
class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.photos, required this.index, this.eventId});
  final List<Photo> photos;
  final int index;
  final String? eventId;

  @override
  Widget build(BuildContext context) {
    final p = photos[index];
    return Stack(fit: StackFit.expand, children: [
      GestureDetector(
        onTap: () => openPhotoViewer(context, photos, index, eventId: eventId),
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: StorageImage(p.previewPath, cacheWidth: 360)),
      ),
      Positioned(right: 5, bottom: 5, child: PhotoAuthorBadge(photo: p, eventId: eventId)),
    ]);
  }
}
