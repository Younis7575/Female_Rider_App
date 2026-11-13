import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Asks camera vs gallery and returns the picked file path (compressed JPEG), or null.
Future<String?> pickImagePath(BuildContext context, {String title = 'Add photo', bool allowCamera = true, int maxWidth = 2000}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.h3),
          const SizedBox(height: AppSpace.sm),
          if (allowCamera)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ]),
      ),
    ),
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(source: source, maxWidth: maxWidth.toDouble(), imageQuality: 85);
    return file?.path;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Could not open the camera or gallery. Check app permissions.')));
    }
    return null;
  }
}

/// Picks multiple images from the gallery (safety evidence etc.).
Future<List<String>> pickMultipleImagePaths({int limit = 5}) async {
  try {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2000, limit: limit);
    return files.map((f) => f.path).take(limit).toList();
  } catch (_) {
    return const [];
  }
}
