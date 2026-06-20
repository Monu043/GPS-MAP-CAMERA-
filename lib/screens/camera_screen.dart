import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/media_item.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  LocationData? _currentLocation;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  Timer? _clockTimer;
  String _currentTime = '';
  bool _isCapturing = false;
  bool _isVideoMode = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  FlashMode _flashMode = FlashMode.off;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  MediaItem? _lastCapture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _startLocationTracking();
    _startClock();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.initialize();
      if (mounted) {
        setState(() {});
        _maxZoom = await _cameraService.getMaxZoom();
        _minZoom = await _cameraService.getMinZoom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _startLocationTracking() {
    _positionSub = LocationService.getPositionStream().listen((pos) async {
      _currentPosition = pos;
      final location = LocationData(
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        accuracy: pos.accuracy,
      );
      if (mounted) setState(() => _currentLocation = location);
    });
    // Get initial location
    LocationService.getLocationData().then((loc) {
      if (mounted && loc != null) setState(() => _currentLocation = loc);
    });
  }

  void _startClock() {
    _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(
            () => _currentTime = DateFormat('HH:mm:ss').format(DateTime.now()));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    final item =
        await _cameraService.capturePhoto(locationData: _currentLocation);
    if (mounted) {
      setState(() {
        _isCapturing = false;
        if (item != null) _lastCapture = item;
      });
      if (item != null) {
        _showCaptureSuccess('Photo saved!');
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      await _cameraService.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer =
          Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });
    } else {
      _recordingTimer?.cancel();
      final item = await _cameraService.stopVideoRecording(
          locationData: _currentLocation);
      setState(() => _isRecording = false);
      if (item != null) _showCaptureSuccess('Video saved!');
    }
  }

  void _showCaptureSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(msg),
          ],
        ),
        backgroundColor: const Color(0xFF1A73E8),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _cycleFlash() {
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final idx = modes.indexOf(_flashMode);
    final next = modes[(idx + 1) % modes.length];
    setState(() => _flashMode = next);
    _cameraService.setFlashMode(next);
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_off;
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _clockTimer?.cancel();
    _recordingTimer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_cameraService.isInitialized &&
              _cameraService.controller != null)
            Positioned.fill(
              child: GestureDetector(
                onScaleUpdate: (details) {
                  final newZoom = (_currentZoom * details.scale)
                      .clamp(_minZoom, _maxZoom);
                  _cameraService.setZoom(newZoom);
                  setState(() => _currentZoom = newZoom);
                },
                child: CameraPreview(_cameraService.controller!),
              ),
            )
          else
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1A73E8)),
              ),
            ),

          // Top controls bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _ControlButton(
                      icon: _flashIcon,
                      onTap: _cycleFlash,
                    ),
                    const Spacer(),
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    _ControlButton(
                      icon: Icons.flip_camera_ios,
                      onTap: () async {
                        await _cameraService.switchCamera();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // GPS overlay - bottom left
          Positioned(
            bottom: 160,
            left: 16,
            right: 16,
            child: _GpsOverlay(
              location: _currentLocation,
              time: _currentTime,
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ModeButton(
                          label: 'PHOTO',
                          selected: !_isVideoMode,
                          onTap: () =>
                              setState(() => _isVideoMode = false),
                        ),
                        const SizedBox(width: 24),
                        _ModeButton(
                          label: 'VIDEO',
                          selected: _isVideoMode,
                          onTap: () =>
                              setState(() => _isVideoMode = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Capture row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Last capture thumbnail
                        GestureDetector(
                          onTap: () {
                            // TODO: open gallery
                          },
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white38, width: 1.5),
                            ),
                            child: const Icon(Icons.photo_library,
                                color: Colors.white, size: 24),
                          ),
                        ),

                        // Shutter button
                        GestureDetector(
                          onTap: _isVideoMode
                              ? _toggleRecording
                              : _capturePhoto,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isVideoMode
                                  ? (_isRecording
                                      ? Colors.red
                                      : Colors.white)
                                  : Colors.white,
                              border: Border.all(
                                  color: Colors.white38, width: 4),
                            ),
                            child: _isVideoMode
                                ? Icon(
                                    _isRecording
                                        ? Icons.stop
                                        : Icons.videocam,
                                    color: _isRecording
                                        ? Colors.white
                                        : Colors.red,
                                    size: 36,
                                  )
                                : (_isCapturing
                                    ? const CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 3,
                                      )
                                    : null),
                          ),
                        ),

                        // Zoom indicator
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white38, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '${_currentZoom.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    // Zoom slider
                    if (_maxZoom > _minZoom)
                      Slider(
                        value: _currentZoom,
                        min: _minZoom,
                        max: _maxZoom,
                        activeColor: const Color(0xFF1A73E8),
                        inactiveColor: Colors.white24,
                        onChanged: (v) {
                          setState(() => _currentZoom = v);
                          _cameraService.setZoom(v);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A73E8).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1A73E8)
                : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1A73E8) : Colors.white60,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _GpsOverlay extends StatelessWidget {
  final LocationData? location;
  final String time;

  const _GpsOverlay({this.location, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: Color(0xFF1A73E8), size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location != null
                      ? location!.coordinatesString
                      : 'Getting location...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          if (location?.fullAddress.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(
              location!.fullAddress,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white54, size: 12),
              const SizedBox(width: 4),
              Text(
                time,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (location?.accuracy != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.gps_fixed, color: Colors.white54, size: 12),
                const SizedBox(width: 4),
                Text(
                  '±${location!.accuracy!.toStringAsFixed(0)}m',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
