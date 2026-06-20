import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/media_item.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import 'media_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final CameraService _cameraService = CameraService();
  final MapController _mapController = MapController();
  List<MediaItem> _mediaItems = [];
  Position? _currentPosition;
  bool _loading = true;
  MediaItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await _cameraService.loadSavedMedia();
    final pos = await LocationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _mediaItems = items.where((i) => i.location != null).toList();
        _currentPosition = pos;
        _loading = false;
      });
      if (pos != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _mapController.move(
              LatLng(pos.latitude, pos.longitude),
              13,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Media Map',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(
                  LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude),
                  15,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A73E8)))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude)
                        : const LatLng(28.6139, 77.2090), // Delhi default
                    initialZoom: 12,
                    onTap: (_, __) => setState(() => _selectedItem = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.gps_camera_app',
                    ),

                    // Current location marker
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude),
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A73E8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1A73E8)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                    // Media location markers
                    MarkerLayer(
                      markers: _mediaItems.map((item) {
                        final isSelected = _selectedItem?.id == item.id;
                        return Marker(
                          point: LatLng(
                            item.location!.latitude,
                            item.location!.longitude,
                          ),
                          width: isSelected ? 54 : 42,
                          height: isSelected ? 54 : 42,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedItem = item),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orange
                                    : (item.type == MediaType.photo
                                        ? const Color(0xFF1A73E8)
                                        : Colors.purple),
                                borderRadius: BorderRadius.circular(
                                    isSelected ? 16 : 12),
                                border: Border.all(
                                    color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: item.type == MediaType.photo &&
                                      item.exists
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      child: Image.file(
                                        File(item.filePath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: isSelected ? 28 : 20,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      item.type == MediaType.photo
                                          ? Icons.photo
                                          : Icons.videocam,
                                      color: Colors.white,
                                      size: isSelected ? 28 : 20,
                                    ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Selected item card
                if (_selectedItem != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _MediaInfoCard(
                      item: _selectedItem!,
                      onView: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MediaDetailScreen(item: _selectedItem!),
                          ),
                        );
                      },
                      onClose: () =>
                          setState(() => _selectedItem = null),
                    ),
                  ),

                // Legend
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LegendItem(
                            color: const Color(0xFF1A73E8),
                            label: 'Photos (${_mediaItems.where((i) => i.type == MediaType.photo).length})'),
                        const SizedBox(height: 4),
                        _LegendItem(
                            color: Colors.purple,
                            label: 'Videos (${_mediaItems.where((i) => i.type == MediaType.video).length})'),
                        const SizedBox(height: 4),
                        const _LegendItem(
                            color: Color(0xFF1A73E8),
                            isCircle: true,
                            label: 'You'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isCircle;

  const _LegendItem(
      {required this.color, required this.label, this.isCircle = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _MediaInfoCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onView;
  final VoidCallback onClose;

  const _MediaInfoCard(
      {required this.item, required this.onView, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 60,
              height: 60,
              child: item.type == MediaType.photo && item.exists
                  ? Image.file(File(item.filePath), fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.videocam,
                          color: Colors.white38, size: 28)),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.type == MediaType.photo ? 'Photo' : 'Video',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.formattedDate}  ${item.formattedTime}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (item.location != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.location!.coordinatesString,
                    style: const TextStyle(
                        color: Color(0xFF1A73E8),
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ],
              ],
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white38, size: 20),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: onView,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View',
                    style:
                        TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
