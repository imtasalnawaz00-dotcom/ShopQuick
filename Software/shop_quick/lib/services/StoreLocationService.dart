import 'dart:math' as math;

import 'DatabaseService.dart';

class NearbyStoreModel {
  const NearbyStoreModel({
    required this.id,
    required this.name,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    this.distanceMiles,
  });

  final int id;
  final String name;
  final String postcode;
  final double latitude;
  final double longitude;
  final double? distanceMiles;

  factory NearbyStoreModel.fromMap(Map<String, Object?> map) {
    return NearbyStoreModel(
      id: (map['id'] as int?) ?? 0,
      name: (map['name'] as String?) ?? '',
      postcode: (map['postcode'] as String?) ?? '',
      latitude: ((map['latitude'] as num?) ?? 0).toDouble(),
      longitude: ((map['longitude'] as num?) ?? 0).toDouble(),
      distanceMiles: (map['distance_miles'] as num?)?.toDouble(),
    );
  }

  NearbyStoreModel copyWith({
    double? distanceMiles,
  }) {
    return NearbyStoreModel(
      id: id,
      name: name,
      postcode: postcode,
      latitude: latitude,
      longitude: longitude,
      distanceMiles: distanceMiles ?? this.distanceMiles,
    );
  }
}

class StoreLocationService {
  const StoreLocationService();

  static const double _earthRadiusMiles = 3958.8;
  static final DatabaseService _databaseService = DatabaseService.instance;

  double calculateDistanceMiles({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final double latitudeDistance = _toRadians(endLatitude - startLatitude);
    final double longitudeDistance = _toRadians(endLongitude - startLongitude);

    final double startLatitudeRadians = _toRadians(startLatitude);
    final double endLatitudeRadians = _toRadians(endLatitude);

    final double haversine = math.pow(math.sin(latitudeDistance / 2), 2) +
        math.cos(startLatitudeRadians) *
            math.cos(endLatitudeRadians) *
            math.pow(math.sin(longitudeDistance / 2), 2);

    final double arc = 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return _earthRadiusMiles * arc;
  }

  Future<List<NearbyStoreModel>> fetchNearbyStores({
    double? userLatitude,
    double? userLongitude,
    String? postcode,
    double maxDistanceMiles = 3.0,
  }) async {
    final database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query('stores');
    final List<NearbyStoreModel> stores = rows
        .map(NearbyStoreModel.fromMap)
        .where(
          (NearbyStoreModel store) => store.latitude != 0 && store.longitude != 0,
        )
        .toList();

    if (userLatitude != null && userLongitude != null) {
      final List<NearbyStoreModel> nearbyStores = stores
          .map(
            (NearbyStoreModel store) => store.copyWith(
              distanceMiles: calculateDistanceMiles(
                startLatitude: userLatitude,
                startLongitude: userLongitude,
                endLatitude: store.latitude,
                endLongitude: store.longitude,
              ),
            ),
          )
          .where(
            (NearbyStoreModel store) =>
                (store.distanceMiles ?? double.infinity) <= maxDistanceMiles,
          )
          .toList()
        ..sort(
          (NearbyStoreModel a, NearbyStoreModel b) =>
              (a.distanceMiles ?? double.infinity)
                  .compareTo(b.distanceMiles ?? double.infinity),
        );

      if (nearbyStores.isNotEmpty) {
        return nearbyStores;
      }
    }

    return _fetchStoresByPostcodeFallback(
      stores: stores,
      postcode: postcode,
    );
  }

  List<NearbyStoreModel> _fetchStoresByPostcodeFallback({
    required List<NearbyStoreModel> stores,
    required String? postcode,
  }) {
    final String normalizedPostcode = _normalizePostcode(postcode ?? '');

    if (normalizedPostcode.isEmpty) {
      return stores;
    }

    final String outwardCode = _extractOutwardCode(normalizedPostcode);
    final String areaCode = _extractAreaCode(normalizedPostcode);

    final List<NearbyStoreModel> outwardMatches = stores.where((NearbyStoreModel store) {
      return _normalizePostcode(store.postcode).startsWith(outwardCode);
    }).toList();

    if (outwardMatches.isNotEmpty) {
      return outwardMatches;
    }

    final List<NearbyStoreModel> areaMatches = stores.where((NearbyStoreModel store) {
      return _extractAreaCode(_normalizePostcode(store.postcode)) == areaCode;
    }).toList();

    return areaMatches.isNotEmpty ? areaMatches : stores;
  }

  String _normalizePostcode(String value) {
    return value.trim().toUpperCase().replaceAll(' ', '');
  }

  String _extractOutwardCode(String normalizedPostcode) {
    if (normalizedPostcode.length <= 3) {
      return normalizedPostcode;
    }

    return normalizedPostcode.substring(0, normalizedPostcode.length - 3);
  }

  String _extractAreaCode(String normalizedPostcode) {
    final RegExpMatch? match = RegExp(r'^[A-Z]+').firstMatch(normalizedPostcode);
    return match?.group(0) ?? normalizedPostcode;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}
