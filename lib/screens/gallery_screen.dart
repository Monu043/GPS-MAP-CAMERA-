import 'dart:io';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/camera_service.dart';
import '../services/google_drive_service.dart';
import 'media_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final CameraService _cameraService = CameraService();
  final GoogleDriveService _driveService = GoogleDriveService();
  List<MediaItem> _items = [];
  bool _loading = true;
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _loading = true);
    final items = await _cameraService.loadSavedMedia();
    if (mounted) {
      setState(() {
      _items = items;
      _loading = false;
    });
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _uploadSelected() async {
    final selected = _items.where((i) => _selectedIds.contains(i.id)).toList();
    if (selected.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UploadDialog(
        items: selected,
        driveService: _driveService,
        onDone: () {
          Navigator.pop(context);
          setState(() {
            _selectionMode = false;
            _selectedIds.clear();
          });
        },
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${_selectedIds.length} item(s)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final item in _items.where((i) => _selectedIds.contains(i.id))) {
        try {
          await File(item.filePath).delete();
        } catch (_) {}
      }
      await _loadMedia();
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} selected')
            : const Text('Gallery',
                style: TextStyle(fontWeight: FontWeight.bold)),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  onPressed: _uploadSelected,
                  tooltip: 'Upload to Cloud',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _deleteSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectionMode = false;
                    _selectedIds.clear();
                  }),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadMedia,
                ),
              ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A73E8)))
          : _items.isEmpty
              ? _EmptyState(onRefresh: _loadMedia)
              : RefreshIndicator(
                  onRefresh: _loadMedia,
                  color: const Color(0xFF1A73E8),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final isSelected = _selectedIds.contains(item.id);
                      return GestureDetector(
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelect(item.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MediaDetailScreen(item: item),
                              ),
                            ).then((_) => _loadMedia());
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _selectionMode = true;
                            _selectedIds.add(item.id);
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Thumbnail
                            item.type == MediaType.photo
                                ? Image.file(
                                    File(item.filePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image,
                                            color: Colors.white24),
                                  )
                                : Container(
                                    color: Colors.grey.shade900,
                                    child: const Icon(Icons.videocam,
                                        color: Colors.white38, size: 36),
                                  ),

                            // Selection overlay
                            if (_selectionMode)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                color: isSelected
                                    ? const Color(0xFF1A73E8).withValues(alpha: 0.4)
                                    : Colors.transparent,
                              ),
                            if (isSelected)
                              const Positioned(
                                top: 6,
                                right: 6,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFF1A73E8),
                                  child: Icon(Icons.check,
                                      size: 14, color: Colors.white),
                                ),
                              ),

                            // Video badge
                            if (item.type == MediaType.video)
                              const Positioned(
                                bottom: 6,
                                left: 6,
                                child: Icon(Icons.play_circle_filled,
                                    color: Colors.white70, size: 20),
                              ),

                            // GPS badge
                            if (item.location != null)
                              const Positioned(
                                bottom: 6,
                                right: 6,
                                child: Icon(Icons.location_on,
                                    color: Color(0xFF1A73E8), size: 16),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 80, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No media yet',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture photos or videos with\nthe GPS camera',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A73E8),
              side: const BorderSide(color: Color(0xFF1A73E8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadDialog extends StatefulWidget {
  final List<MediaItem> items;
  final GoogleDriveService driveService;
  final VoidCallback onDone;

  const _UploadDialog({
    required this.items,
    required this.driveService,
    required this.onDone,
  });

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  int _uploaded = 0;
  int _failed = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _upload();
  }

  Future<void> _upload() async {
    for (final item in widget.items) {
      final result = await widget.driveService.uploadFile(item);
      if (mounted) {
        setState(() {
          if (result.success) {
            _uploaded++;
          } else {
            _failed++;
          }
        });
      }
    }
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        _done ? 'Upload Complete' : 'Uploading...',
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_done) ...[
            const CircularProgressIndicator(color: Color(0xFF1A73E8)),
            const SizedBox(height: 16),
            Text(
              'Uploading ${_uploaded + _failed + 1} of ${widget.items.length}...',
              style: const TextStyle(color: Colors.white70),
            ),
          ] else ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            Text(
              '$_uploaded uploaded, $_failed failed',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
      actions: _done
          ? [
              TextButton(
                onPressed: widget.onDone,
                child: const Text('Done',
                    style: TextStyle(color: Color(0xFF1A73E8))),
              ),
            ]
          : null,
    );
  }
}
