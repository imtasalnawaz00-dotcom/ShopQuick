import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocationResult {
  const CurrentLocationResult({
    required this.latitude,
    required this.longitude,
    required this.postcode,
  });

  final double latitude;
  final double longitude;
  final String postcode;
}

class CurrentLocationService {
  const CurrentLocationService();

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<bool> ensurePermissionGranted() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<CurrentLocationResult> fetchCurrentLocation() async {
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    if (!_isValidCoordinate(position.latitude, position.longitude)) {
      throw Exception('Invalid coordinates returned by location service.');
    }

    final String postcode = await resolvePostcode(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    return CurrentLocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      postcode: postcode,
    );
  }

  Future<String> resolvePostcode({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isValidCoordinate(latitude, longitude)) {
      return '';
    }

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return '';
      }

      for (final Placemark placemark in placemarks) {
        final String postcode = _extractPostcodeFromPlacemark(placemark);

        if (postcode.isNotEmpty) {
          return postcode;
        }
      }

      return '';
    } on NoResultFoundException {
      return '';
    } catch (_) {
      return '';
    }
  }

  String _extractPostcodeFromPlacemark(Placemark placemark) {
    final String directPostcode =
        (placemark.postalCode ?? '').trim().toUpperCase();

    if (directPostcode.isNotEmpty) {
      return directPostcode;
    }

    final RegExp ukPostcodePattern = RegExp(
      r'\b[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}\b',
      caseSensitive: false,
    );

    final List<String> candidates = <String>[
      placemark.name ?? '',
      placemark.street ?? '',
      placemark.subLocality ?? '',
      placemark.locality ?? '',
      placemark.subAdministrativeArea ?? '',
      placemark.administrativeArea ?? '',
    ];

    for (final String candidate in candidates) {
      final RegExpMatch? match = ukPostcodePattern.firstMatch(
        candidate.toUpperCase(),
      );

      if (match != null) {
        return match.group(0)!.trim().toUpperCase();
      }
    }

    return '';
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }
}
