import 'dart:io';

enum MediaType { photo, video }

class LocationData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final String? address;
  final String? city;
  final String? country;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.address,
    this.city,
    this.country,
  });

  String get coordinatesString =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get fullAddress {
    final parts = [address, city, country].where((e) => e != null && e.isNotEmpty);
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
        'address': address,
        'city': city,
        'country': country,
      };
}

class MediaItem {
  final String id;
  final String filePath;
  final MediaType type;
  final DateTime capturedAt;
  final LocationData? location;
  final Duration? videoDuration;
  bool isUploadedToGoogleDrive;
  bool isUploadedToOneDrive;
  String? googleDriveFileId;
  String? oneDriveFileId;

  MediaItem({
    required this.id,
    required this.filePath,
    required this.type,
    required this.capturedAt,
    this.location,
    this.videoDuration,
    this.isUploadedToGoogleDrive = false,
    this.isUploadedToOneDrive = false,
    this.googleDriveFileId,
    this.oneDriveFileId,
  });

  File get file => File(filePath);

  String get fileName => filePath.split('/').last;

  bool get exists => File(filePath).existsSync();

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${capturedAt.day} ${months[capturedAt.month - 1]} ${capturedAt.year}';
  }

  String get formattedTime {
    final h = capturedAt.hour.toString().padLeft(2, '0');
    final m = capturedAt.minute.toString().padLeft(2, '0');
    final s = capturedAt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
