import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestAll() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.storage,
      Permission.photos,
    ].request();
  }

  static Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  static Future<bool> hasLocationPermission() async {
    return await Permission.locationWhenInUse.isGranted ||
        await Permission.location.isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    return await Permission.storage.isGranted ||
        await Permission.photos.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
