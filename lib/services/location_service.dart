import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/media_item.dart';

class LocationService {
  static Position? _lastPosition;

  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _lastPosition = position;
      return position;
    } catch (e) {
      return _lastPosition;
    }
  }

  static Future<LocationData?> getLocationData() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    String? address;
    String? city;
    String? country;

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = [place.street, place.subLocality]
            .where((e) => e != null && e.isNotEmpty)
            .join(', ');
        city = place.locality ?? place.subAdministrativeArea;
        country = place.country;
      }
    } catch (_) {}

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      address: address,
      city: city,
      country: country,
    );
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}
