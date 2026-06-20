import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../models/media_item.dart';
import 'location_service.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  bool _isRecording = false;

  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  CameraController? get controller => _controller;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw Exception('No cameras found');
    await _initController(_cameras[_currentCameraIndex]);
  }

  Future<void> _initController(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    _isInitialized = true;
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    _isInitialized = false;
    await _initController(_cameras[_currentCameraIndex]);
  }

  Future<void> setFlashMode(FlashMode mode) async {
    await _controller?.setFlashMode(mode);
  }

  Future<void> setZoom(double zoom) async {
    await _controller?.setZoomLevel(zoom);
  }

  Future<double> getMaxZoom() async {
    return await _controller?.getMaxZoomLevel() ?? 1.0;
  }

  Future<double> getMinZoom() async {
    return await _controller?.getMinZoomLevel() ?? 1.0;
  }

  /// Capture photo with GPS watermark overlay
  Future<MediaItem?> capturePhoto({LocationData? locationData}) async {
    if (_controller == null || !_isInitialized) return null;

    try {
      final xFile = await _controller!.takePicture();
      final location = locationData ?? await LocationService.getLocationData();

      // Read raw bytes
      final rawBytes = await xFile.readAsBytes();
      img.Image? image = img.decodeImage(rawBytes);
      if (image == null) return null;

      // Add GPS watermark
      if (location != null) {
        image = _addGpsWatermark(image, location);
      }

      // Save to app directory
      final dir = await _getMediaDirectory();
      final fileName =
          'GPS_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.jpg';
      final filePath = p.join(dir.path, fileName);
      final outputBytes = img.encodeJpg(image, quality: 92);
      await File(filePath).writeAsBytes(outputBytes);

      // Also save to gallery
      await ImageGallerySaver.saveFile(filePath);

      return MediaItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: filePath,
        type: MediaType.photo,
        capturedAt: DateTime.now(),
        location: location,
      );
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      return null;
    }
  }

  /// Start video recording
  Future<void> startVideoRecording() async {
    if (_controller == null || !_isInitialized || _isRecording) return;
    await _controller!.startVideoRecording();
    _isRecording = true;
  }

  /// Stop video recording and return MediaItem
  Future<MediaItem?> stopVideoRecording({LocationData? locationData}) async {
    if (_controller == null || !_isRecording) return null;
    _isRecording = false;

    try {
      final xFile = await _controller!.stopVideoRecording();
      final location = locationData ?? await LocationService.getLocationData();

      final dir = await _getMediaDirectory();
      final fileName =
          'GPS_VID_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.mp4';
      final filePath = p.join(dir.path, fileName);
      await File(xFile.path).copy(filePath);

      // Save to gallery
      await ImageGallerySaver.saveFile(filePath);

      return MediaItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: filePath,
        type: MediaType.video,
        capturedAt: DateTime.now(),
        location: location,
      );
    } catch (e) {
      debugPrint('Error stopping video: $e');
      return null;
    }
  }

  img.Image _addGpsWatermark(img.Image image, LocationData location) {
    final now = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    final lat = location.latitude.toStringAsFixed(6);
    final lng = location.longitude.toStringAsFixed(6);
    final lines = <String>[
      '📍 $lat, $lng',
      if (location.address != null && location.address!.isNotEmpty)
        location.address!,
      if (location.city != null) '${location.city}, ${location.country ?? ""}',
      '🕐 $now',
      if (location.accuracy != null)
        'Accuracy: ±${location.accuracy!.toStringAsFixed(1)}m',
    ];

    // Draw semi-transparent bar at bottom
    final barHeight = 22 * lines.length + 20;
    final barTop = image.height - barHeight;
    img.fillRect(
    image,
    x1: 0,
    y1: barTop,
    x2: image.width - 1,
    y2: image.height - 1,
    color: img.ColorRgba8(0, 0, 0, 128),
  );

    // Draw text lines
    int yPos = barTop + 10;
    for (final line in lines) {
 img.drawString(
  image,
  line,
  font: img.arial24,
  x: 10,
  y: yPos,
  color: img.ColorRgb8(255, 255, 255),
);
      yPos += 22;
    }

    return image;
  }

  Future<Directory> _getMediaDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'GPS_Camera'));
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    return mediaDir;
  }

  Future<List<MediaItem>> loadSavedMedia() async {
    try {
      final dir = await _getMediaDirectory();
      final files = dir.listSync().whereType<File>().toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return files.where((f) {
        final ext = p.extension(f.path).toLowerCase();
        return ['.jpg', '.jpeg', '.png', '.mp4', '.mov'].contains(ext);
      }).map((f) {
        final ext = p.extension(f.path).toLowerCase();
        final isVideo = ['.mp4', '.mov'].contains(ext);
        return MediaItem(
          id: f.path.hashCode.toString(),
          filePath: f.path,
          type: isVideo ? MediaType.video : MediaType.photo,
          capturedAt: f.statSync().modified,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
  }
}
