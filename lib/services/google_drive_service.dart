import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  String? _gpsCameraFolderId;

  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.displayName;

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;
      await _initDriveApi();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _gpsCameraFolderId = null;
  }

  Future<void> _initDriveApi() async {
    final headers = await _currentUser!.authHeaders;
    final authClient = GoogleAuthClient(headers);
    _driveApi = drive.DriveApi(authClient);
    _gpsCameraFolderId = await _getOrCreateFolder('GPS Camera');
  }

  Future<String?> _getOrCreateFolder(String name) async {
    if (_driveApi == null) return null;
    try {
      // Search for existing folder
      final result = await _driveApi!.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and name='$name' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id;
      }

      // Create folder
      final folder = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await _driveApi!.files.create(folder);
      return created.id;
    } catch (e) {
      return null;
    }
  }

  Future<UploadResult> uploadFile(MediaItem item) async {
    if (_driveApi == null) {
      return UploadResult(success: false, error: 'Not signed in to Google');
    }

    try {
      final file = File(item.filePath);
      if (!await file.exists()) {
        return UploadResult(success: false, error: 'File not found');
      }

      final mimeType =
          item.type == MediaType.photo ? 'image/jpeg' : 'video/mp4';

      // Build description with GPS data
      final desc = _buildFileDescription(item);

      final driveFile = drive.File()
        ..name = item.fileName
        ..parents = _gpsCameraFolderId != null ? [_gpsCameraFolderId!] : null
        ..description = desc;

      final media = drive.Media(
        file.openRead(),
        await file.length(),
        contentType: mimeType,
      );

      final uploaded = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      return UploadResult(
        success: true,
        fileId: uploaded.id,
        webViewLink:
            'https://drive.google.com/file/d/${uploaded.id}/view',
      );
    } catch (e) {
      return UploadResult(success: false, error: e.toString());
    }
  }

  String _buildFileDescription(MediaItem item) {
    final parts = <String>[];
    parts.add('Captured with GPS Camera App');
    parts.add('Date: ${item.formattedDate} ${item.formattedTime}');
    if (item.location != null) {
      parts.add('Coordinates: ${item.location!.coordinatesString}');
      if (item.location!.fullAddress.isNotEmpty) {
        parts.add('Address: ${item.location!.fullAddress}');
      }
    }
    return parts.join('\n');
  }

  Future<List<DriveFileInfo>> listFiles() async {
    if (_driveApi == null) return [];
    try {
      final q = _gpsCameraFolderId != null
          ? "'$_gpsCameraFolderId' in parents and trashed=false"
          : "trashed=false";
      final result = await _driveApi!.files.list(
        q: q,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, size, createdTime, webViewLink)',
        orderBy: 'createdTime desc',
      );
      return (result.files ?? [])
          .map((f) => DriveFileInfo(
                id: f.id ?? '',
                name: f.name ?? '',
                mimeType: f.mimeType ?? '',
                size: f.size ?? '0',
                createdTime: f.createdTime,
                webViewLink: f.webViewLink,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class UploadResult {
  final bool success;
  final String? fileId;
  final String? webViewLink;
  final String? error;

  UploadResult({
    required this.success,
    this.fileId,
    this.webViewLink,
    this.error,
  });
}

class DriveFileInfo {
  final String id;
  final String name;
  final String mimeType;
  final String size;
  final DateTime? createdTime;
  final String? webViewLink;

  DriveFileInfo({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    this.createdTime,
    this.webViewLink,
  });
}
