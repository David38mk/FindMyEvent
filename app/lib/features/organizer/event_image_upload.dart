import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Storage bucket created in migration 20260828132157.
const eventImagesBucket = 'event-images';

/// Longest edge after downscale. Event cards and the detail sheet are at most
/// a phone width; 1600px still looks sharp on a 3x screen and cuts a typical
/// 4MB camera shot to a couple hundred KB.
const _maxEdge = 1600.0;
const _jpegQuality = 80;

/// Picks an image and downscales/recompresses it **before** it ever leaves the
/// device. image_picker does this natively (its Android/iOS resizers), which
/// beats pulling in a Dart image codec: no extra dependency, no decoding a
/// 12MP bitmap into the Dart heap on a mid-range phone.
Future<XFile?> pickEventImage(ImageSource source) {
  return ImagePicker().pickImage(
    source: source,
    maxWidth: _maxEdge,
    maxHeight: _maxEdge,
    imageQuality: _jpegQuality,
  );
}

/// Uploads to `<uid>/<random>.<ext>` and returns the public URL to store in
/// `events.image_url`. The `<uid>/` prefix is not cosmetic — the storage
/// INSERT policy requires it, so one organizer can never write into another's
/// folder.
Future<String> uploadEventImage(XFile file, String userId) async {
  final bytes = await file.readAsBytes();
  final extension = _extensionOf(file.name);
  final name =
      '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}.$extension';
  final path = '$userId/$name';

  final storage = Supabase.instance.client.storage.from(eventImagesBucket);
  await storage.uploadBinary(
    path,
    bytes,
    fileOptions: FileOptions(contentType: _contentTypeOf(extension)),
  );
  return storage.getPublicUrl(path);
}

String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return 'jpg';
  final ext = fileName.substring(dot + 1).toLowerCase();
  // The bucket only allows these three MIME types; anything else would be
  // rejected server-side, so normalize to JPEG (what the resizer emits).
  return const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
}

String _contentTypeOf(String extension) => switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
