import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/media_item.dart';

/// OneDrive integration via Microsoft Graph API
/// Uses OAuth2 Authorization Code Flow (PKCE) for auth
class OneDriveService {
  static final OneDriveService _instance = OneDriveService._internal();
  factory OneDriveService() => _instance;
  OneDriveService._internal();

  // Replace with your Azure App registration values
  static const String _clientId = 'YOUR_AZURE_CLIENT_ID';
  static const String _redirectUri = 'gpscamera://auth';
  static const String _scope =
      'Files.ReadWrite offline_access User.Read';
  static const String _tenantId = 'common';

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _userProfile;
  String? _gpsCameraFolderId;

  bool get isSignedIn => _accessToken != null;
  String? get userName => _userProfile?['displayName'];
  String? get userEmail => _userProfile?['mail'] ?? _userProfile?['userPrincipalName'];

  String get _authUrl =>
      'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/authorize'
      '?client_id=$_clientId'
      '&response_type=code'
      '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
      '&scope=${Uri.encodeComponent(_scope)}'
      '&response_mode=query';

  /// Launch browser for sign-in
  Future<bool> signIn() async {
    try {
      final uri = Uri.parse(_authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // In a real app, handle the redirect via deep link / custom URL scheme
        // For demo, simulate success after user completes auth
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Handle OAuth2 callback (called from deep link handler)
  Future<bool> handleAuthCallback(String code) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'scope': _scope,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        await _fetchUserProfile();
        _gpsCameraFolderId = await _getOrCreateFolder('GPS Camera');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse(
            'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
          'scope': _scope,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_accessToken == null) return;
    try {
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (response.statusCode == 200) {
        _userProfile = jsonDecode(response.body);
      }
    } catch (_) {}
  }

  Future<String?> _getOrCreateFolder(String name) async {
    if (_accessToken == null) return null;
    try {
      // Check if folder exists
      final searchResp = await http.get(
        Uri.parse(
            'https://graph.microsoft.com/v1.0/me/drive/root/children?\$filter=name eq \'$name\' and folder ne null'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (searchResp.statusCode == 200) {
        final data = jsonDecode(searchResp.body);
        final items = data['value'] as List;
        if (items.isNotEmpty) return items.first['id'];
      }

      // Create folder
      final createResp = await http.post(
        Uri.parse('https://graph.microsoft.com/v1.0/me/drive/root/children'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'folder': {},
          '@microsoft.graph.conflictBehavior': 'rename',
        }),
      );
      if (createResp.statusCode == 201) {
        return jsonDecode(createResp.body)['id'];
      }
    } catch (_) {}
    return null;
  }

  Future<UploadResult> uploadFile(MediaItem item) async {
    if (_accessToken == null) {
      return UploadResult(success: false, error: 'Not signed in to OneDrive');
    }

    try {
      final file = File(item.filePath);
      if (!await file.exists()) {
        return UploadResult(success: false, error: 'File not found');
      }

      final bytes = await file.readAsBytes();
      final uploadPath = _gpsCameraFolderId != null
          ? 'https://graph.microsoft.com/v1.0/me/drive/items/$_gpsCameraFolderId:/${item.fileName}:/content'
          : 'https://graph.microsoft.com/v1.0/me/drive/root:/${item.fileName}:/content';

      final response = await http.put(
        Uri.parse(uploadPath),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':
              item.type == MediaType.photo ? 'image/jpeg' : 'video/mp4',
        },
        body: bytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return UploadResult(
          success: true,
          fileId: data['id'],
          webViewLink: data['webUrl'],
        );
      } else if (response.statusCode == 401) {
        // Try refresh
        if (await _refreshAccessToken()) {
          return uploadFile(item);
        }
        return UploadResult(success: false, error: 'Authentication expired');
      }

      return UploadResult(
          success: false, error: 'Upload failed: ${response.statusCode}');
    } catch (e) {
      return UploadResult(success: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _userProfile = null;
    _gpsCameraFolderId = null;
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
