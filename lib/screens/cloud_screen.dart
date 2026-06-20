import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/google_drive_service.dart';
import '../services/onedrive_service.dart';
import '../services/camera_service.dart';
import '../models/media_item.dart';

class CloudScreen extends StatefulWidget {
  const CloudScreen({super.key});

  @override
  State<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends State<CloudScreen>
    with SingleTickerProviderStateMixin {
  final GoogleDriveService _googleDrive = GoogleDriveService();
  final OneDriveService _oneDrive = OneDriveService();
  final CameraService _cameraService = CameraService();
  late TabController _tabController;

  List<DriveFileInfo> _driveFiles = [];
  List<MediaItem> _localMedia = [];
  bool _loadingDrive = false;
  bool _uploadingAll = false;
  int _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocalMedia();
  }

  Future<void> _loadLocalMedia() async {
    final items = await _cameraService.loadSavedMedia();
    if (mounted) setState(() => _localMedia = items);
  }

  Future<void> _connectGoogleDrive() async {
    setState(() => _loadingDrive = true);
    final ok = await _googleDrive.signIn();
    if (ok) {
      await _loadDriveFiles();
    }
    if (mounted) setState(() => _loadingDrive = false);
  }

  Future<void> _disconnectGoogleDrive() async {
    await _googleDrive.signOut();
    setState(() => _driveFiles = []);
  }

  Future<void> _loadDriveFiles() async {
    setState(() => _loadingDrive = true);
    final files = await _googleDrive.listFiles();
    if (mounted) {
      setState(() {
      _driveFiles = files;
      _loadingDrive = false;
    });
    }
  }

  Future<void> _uploadAllToGoogleDrive() async {
    if (_localMedia.isEmpty) return;
    setState(() {
      _uploadingAll = true;
      _uploadProgress = 0;
    });

    for (int i = 0; i < _localMedia.length; i++) {
      await _googleDrive.uploadFile(_localMedia[i]);
      if (mounted) setState(() => _uploadProgress = i + 1);
    }

    await _loadDriveFiles();
    if (mounted) {
      setState(() => _uploadingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded $_uploadProgress files to Google Drive'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Cloud Storage',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1A73E8),
          labelColor: const Color(0xFF1A73E8),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Google Drive', icon: Icon(Icons.drive_file_rename_outline, size: 18)),
            Tab(text: 'OneDrive', icon: Icon(Icons.cloud_queue, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GoogleDriveTab(
            service: _googleDrive,
            files: _driveFiles,
            loading: _loadingDrive,
            uploadingAll: _uploadingAll,
            uploadProgress: _uploadProgress,
            totalLocal: _localMedia.length,
            onConnect: _connectGoogleDrive,
            onDisconnect: _disconnectGoogleDrive,
            onRefresh: _loadDriveFiles,
            onUploadAll: _uploadAllToGoogleDrive,
          ),
          _OneDriveTab(service: _oneDrive),
        ],
      ),
    );
  }
}

class _GoogleDriveTab extends StatelessWidget {
  final GoogleDriveService service;
  final List<DriveFileInfo> files;
  final bool loading;
  final bool uploadingAll;
  final int uploadProgress;
  final int totalLocal;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRefresh;
  final VoidCallback onUploadAll;

  const _GoogleDriveTab({
    required this.service,
    required this.files,
    required this.loading,
    required this.uploadingAll,
    required this.uploadProgress,
    required this.totalLocal,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRefresh,
    required this.onUploadAll,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account card
          _CloudAccountCard(
            provider: 'Google Drive',
            icon: Icons.drive_file_rename_outline,
            color: const Color(0xFF1A73E8),
            isConnected: service.isSignedIn,
            email: service.userEmail,
            userName: service.userName,
            onConnect: onConnect,
            onDisconnect: onDisconnect,
          ),

          const SizedBox(height: 20),

          if (service.isSignedIn) ...[
            // Upload all button
            if (totalLocal > 0) ...[
              _ActionCard(
                title: uploadingAll
                    ? 'Uploading... $uploadProgress/$totalLocal'
                    : 'Upload All Local Media',
                subtitle: '$totalLocal files ready to backup',
                icon: Icons.cloud_upload,
                color: Colors.green,
                loading: uploadingAll,
                onTap: uploadingAll ? null : onUploadAll,
                progress: uploadingAll
                    ? uploadProgress / totalLocal
                    : null,
              ),
              const SizedBox(height: 20),
            ],

            // Files in Drive
            Row(
              children: [
                const Text(
                  'GPS Camera Folder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                  onPressed: onRefresh,
                ),
              ],
            ),

            if (loading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child:
                    CircularProgressIndicator(color: Color(0xFF1A73E8)),
              ))
            else if (files.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.folder_open,
                          size: 48, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text(
                        'No files uploaded yet',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...files.map((f) => _DriveFileItem(file: f)),
          ],
        ],
      ),
    );
  }
}

class _OneDriveTab extends StatelessWidget {
  final OneDriveService service;
  const _OneDriveTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _CloudAccountCard(
            provider: 'Microsoft OneDrive',
            icon: Icons.cloud_queue,
            color: const Color(0xFF0078D4),
            isConnected: service.isSignedIn,
            email: service.userEmail,
            userName: service.userName,
            onConnect: () async {
              await service.signIn();
            },
            onDisconnect: () async {
              await service.signOut();
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0078D4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF0078D4).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF0078D4), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Setup Required',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'To enable OneDrive:\n'
                  '1. Register an app at portal.azure.com\n'
                  '2. Set redirect URI: gpscamera://auth\n'
                  '3. Add your Client ID in OneDriveService\n'
                  '4. Configure deep link handling',
                  style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://portal.azure.com');
                    if (await canLaunchUrl(url)) launchUrl(url);
                  },
                  child: const Text(
                    'Open Azure Portal →',
                    style: TextStyle(
                        color: Color(0xFF0078D4),
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudAccountCard extends StatelessWidget {
  final String provider;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final String? email;
  final String? userName;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _CloudAccountCard({
    required this.provider,
    required this.icon,
    required this.color,
    required this.isConnected,
    this.email,
    this.userName,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? color.withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 4),
                if (isConnected && email != null)
                  Text(email!,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12))
                else
                  Text('Not connected',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isConnected ? onDisconnect : onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isConnected ? Colors.red.withValues(alpha: 0.2) : color,
              foregroundColor: isConnected ? Colors.red : Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: isConnected
                      ? const BorderSide(color: Colors.red)
                      : BorderSide.none),
            ),
            child: Text(isConnected ? 'Disconnect' : 'Connect',
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool loading;
  final double? progress;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.loading = false,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                if (loading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                else
                  Icon(Icons.arrow_forward_ios, color: color, size: 16),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DriveFileItem extends StatelessWidget {
  final DriveFileInfo file;
  const _DriveFileItem({required this.file});

  bool get isImage => file.mimeType.contains('image');
  bool get isVideo => file.mimeType.contains('video');

  String get sizeStr {
    final bytes = int.tryParse(file.size) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isImage
                  ? const Color(0xFF1A73E8).withValues(alpha: 0.15)
                  : Colors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isImage ? Icons.image : Icons.videocam,
              color: isImage ? const Color(0xFF1A73E8) : Colors.purple,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sizeStr,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (file.webViewLink != null)
            IconButton(
              icon: const Icon(Icons.open_in_new,
                  color: Color(0xFF1A73E8), size: 18),
              onPressed: () async {
                final url = Uri.parse(file.webViewLink!);
                if (await canLaunchUrl(url)) launchUrl(url);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
