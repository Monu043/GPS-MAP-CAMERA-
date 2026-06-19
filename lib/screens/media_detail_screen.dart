import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/media_item.dart';
import '../services/google_drive_service.dart';

class MediaDetailScreen extends StatefulWidget {
  final MediaItem item;
  const MediaDetailScreen({super.key, required this.item});

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _uploading = false;
  String? _uploadMsg;

  Future<void> _uploadToGoogleDrive() async {
    if (!_driveService.isSignedIn) {
      final ok = await _driveService.signIn();
      if (!ok) {
        setState(() => _uploadMsg = 'Google sign-in failed');
        return;
      }
    }
    setState(() {
      _uploading = true;
      _uploadMsg = null;
    });
    final result = await _driveService.uploadFile(widget.item);
    setState(() {
      _uploading = false;
      _uploadMsg = result.success
          ? '✓ Uploaded to Google Drive'
          : '✗ ${result.error}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(item.type == MediaType.photo ? 'Photo' : 'Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Share.shareXFiles([XFile(item.filePath)],
                  text: 'Captured with GPS Camera');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Image/Video preview
          Expanded(
            child: item.type == MediaType.photo
                ? InteractiveViewer(
                    child: Center(
                      child: Image.file(
                        File(item.filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                            size: 80),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam,
                              color: Colors.white38, size: 80),
                          SizedBox(height: 8),
                          Text('Video Preview',
                              style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
          ),

          // Info panel
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF111111),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & time
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Captured',
                  value:
                      '${item.formattedDate}  ${item.formattedTime}',
                ),

                if (item.location != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.location_on,
                    label: 'Coordinates',
                    value: item.location!.coordinatesString,
                    color: const Color(0xFF1A73E8),
                  ),
                  if (item.location!.fullAddress.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.place,
                      label: 'Address',
                      value: item.location!.fullAddress,
                    ),
                  ],
                  if (item.location!.accuracy != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.gps_fixed,
                      label: 'GPS Accuracy',
                      value:
                          '±${item.location!.accuracy!.toStringAsFixed(1)} m',
                    ),
                  ],
                  if (item.location!.altitude != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.terrain,
                      label: 'Altitude',
                      value:
                          '${item.location!.altitude!.toStringAsFixed(1)} m',
                    ),
                  ],
                ],

                const SizedBox(height: 20),

                // Upload buttons
                if (_uploadMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _uploadMsg!,
                      style: TextStyle(
                        color: _uploadMsg!.startsWith('✓')
                            ? Colors.green
                            : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: _UploadButton(
                        label: 'Google Drive',
                        icon: Icons.cloud_upload,
                        color: const Color(0xFF1A73E8),
                        loading: _uploading,
                        onTap: _uploadToGoogleDrive,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UploadButton(
                        label: 'OneDrive',
                        icon: Icons.backup,
                        color: const Color(0xFF0078D4),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Configure Azure App ID in OneDriveService to enable'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.white38),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace')),
          ],
        ),
      ],
    );
  }
}

class _UploadButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  const _UploadButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 12,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
