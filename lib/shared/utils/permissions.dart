// lib/shared/utils/permissions.dart

import 'package:permission_handler/permission_handler.dart';

/// Call this at the top of any flow that needs camera or storage access.
/// Returns true only if *all* requested permissions were granted.
Future<bool> ensureStorageAndCameraPermissions() async {
  final perms = <Permission>[
    Permission.camera,
    Permission.photos, // on iOS
    Permission.storage, // Android ≤12
    Permission.photos, // Android 13+ → READ_MEDIA_IMAGES
    Permission.videos, // Android 13+ → READ_MEDIA_VIDEO
  ];
  final statuses = await perms.request();
  return statuses.values.every((status) => status.isGranted);
}
