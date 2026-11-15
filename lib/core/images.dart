// Photo compression: every image is re-encoded on the device before upload, so storage
// and bandwidth stay small. Metadata (EXIF, GPS position…) is dropped; orientation is applied.
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Photos: 720 px on the short side (≈ 720×960), JPEG q70 → ~80–150 KB.
const photoShortSide = 720;
const photoQuality = 70;

/// Thumbnails for grids and the calendar: 256 px on the short side, ~10–20 KB.
const thumbShortSide = 256;
const thumbQuality = 60;

/// Contact pictures (only shown as avatars): 384 px.
const avatarShortSide = 384;

class CompressedPhoto {
  const CompressedPhoto(this.full, this.thumb);
  final Uint8List full;
  final Uint8List thumb;
}

/// Re-encodes [raw] so that its short side is at most [shortSide] (never upscales).
Future<Uint8List> compressImage(Uint8List raw, {int shortSide = photoShortSide, int quality = photoQuality}) async {
  try {
    // minWidth/minHeight = the size the image is scaled DOWN to, keeping its ratio:
    // a 3000×4000 photo becomes 720×960.
    final out = await FlutterImageCompress.compressWithList(
      raw,
      minWidth: shortSide,
      minHeight: shortSide,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );
    // Never upload something bigger than what we had (already tiny images).
    return out.isNotEmpty && out.length < raw.length ? out : raw;
  } catch (e) {
    debugPrint('compressImage: $e');
    return raw;
  }
}

Future<CompressedPhoto> compressPhoto(Uint8List raw) async {
  final full = await compressImage(raw);
  final thumb = await compressImage(full, shortSide: thumbShortSide, quality: thumbQuality);
  return CompressedPhoto(full, thumb);
}
