import 'package:flutter_test/flutter_test.dart';
import 'package:shop_quick/services/StoreLocationService.dart';

/// In-memory test adapter for the database-backed fetch flow.
///
/// The production `StoreLocationService.fetchNearbyStores()` reads from the
/// static sqflite-backed `DatabaseService.instance`, which is not appropriate
/// for plain deterministic unit tests. This adapter mirrors the production
/// filtering, distance, sorting, and postcode fallback logic while operating on
/// an injected in-memory store list.
class TestableStoreLocationService {
  TestableStoreLocationService({
    required List<NearbyStoreModel> stores,
  }) : _stores = stores;

  final List<NearbyStoreModel> _stores;
  final StoreLocationService _service = const StoreLocationService();

  double calculateDistanceMiles({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return _service.calculateDistanceMiles(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );
  }

  Future<List<NearbyStoreModel>> fetchNearbyStores({
    double? userLatitude,
    double? userLongitude,
    String? postcode,
    double maxDistanceMiles = 3.0,
  }) async {
    final List<NearbyStoreModel> stores = _stores
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

    return fetchStoresByPostcodeFallback(
      stores: stores,
      postcode: postcode,
    );
  }

  List<NearbyStoreModel> fetchStoresByPostcodeFallback({
    required List<NearbyStoreModel> stores,
    required String? postcode,
  }) {
    final String normalizedPostcode = normalizePostcode(postcode ?? '');

    if (normalizedPostcode.isEmpty) {
      return stores;
    }

    final String outwardCode = extractOutwardCode(normalizedPostcode);
    final String areaCode = extractAreaCode(normalizedPostcode);

    final List<NearbyStoreModel> outwardMatches =
        stores.where((NearbyStoreModel store) {
      return normalizePostcode(store.postcode).startsWith(outwardCode);
    }).toList();

    if (outwardMatches.isNotEmpty) {
      return outwardMatches;
    }

    final List<NearbyStoreModel> areaMatches =
        stores.where((NearbyStoreModel store) {
      return extractAreaCode(normalizePostcode(store.postcode)) == areaCode;
    }).toList();

    return areaMatches.isNotEmpty ? areaMatches : stores;
  }

  String normalizePostcode(String value) {
    return value.trim().toUpperCase().replaceAll(' ', '');
  }

  String extractOutwardCode(String normalizedPostcode) {
    if (normalizedPostcode.length <= 3) {
      return normalizedPostcode;
    }

    return normalizedPostcode.substring(0, normalizedPostcode.length - 3);
  }

  String extractAreaCode(String normalizedPostcode) {
    final RegExpMatch? match = RegExp(r'^[A-Z]+').firstMatch(normalizedPostcode);
    return match?.group(0) ?? normalizedPostcode;
  }
}

NearbyStoreModel store({
  required int id,
  required String name,
  required String postcode,
  required double latitude,
  required double longitude,
  double? distanceMiles,
}) {
  return NearbyStoreModel(
    id: id,
    name: name,
    postcode: postcode,
    latitude: latitude,
    longitude: longitude,
    distanceMiles: distanceMiles,
  );
}

void main() {
  group('StoreLocationService', () {
    const StoreLocationService realService = StoreLocationService();

    test('UT36 Return zero distance for identical coordinates', () {
      final double distance = realService.calculateDistanceMiles(
        startLatitude: 53.8008,
        startLongitude: -1.5491,
        endLatitude: 53.8008,
        endLongitude: -1.5491,
      );

      expect(distance, closeTo(0, 0.0001));
    });

    test('UT37 Calculate positive distance for different coordinates', () {
      final double distance = realService.calculateDistanceMiles(
        startLatitude: 53.8008,
        startLongitude: -1.5491,
        endLatitude: 53.8108,
        endLongitude: -1.5591,
      );

      expect(distance, greaterThan(0));
    });

    test('UT38 Return nearby stores within max distance', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'Very Close',
            postcode: 'BD1 1AA',
            latitude: 53.8008,
            longitude: -1.5491,
          ),
          store(
            id: 2,
            name: 'Still Nearby',
            postcode: 'BD2 2BB',
            latitude: 53.8158,
            longitude: -1.5591,
          ),
          store(
            id: 3,
            name: 'Far Away',
            postcode: 'LS1 4CC',
            latitude: 53.9008,
            longitude: -1.7000,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        userLatitude: 53.8008,
        userLongitude: -1.5491,
        maxDistanceMiles: 3.0,
      );

      expect(result.map((NearbyStoreModel item) => item.name), contains('Very Close'));
      expect(
        result.map((NearbyStoreModel item) => item.name),
        contains('Still Nearby'),
      );
      expect(
        result.map((NearbyStoreModel item) => item.name),
        isNot(contains('Far Away')),
      );
    });

    test('UT39 Exclude stores outside max distance', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'Close',
            postcode: 'BD1 1AA',
            latitude: 53.8008,
            longitude: -1.5491,
          ),
          store(
            id: 2,
            name: 'Beyond Limit',
            postcode: 'LS1 4CC',
            latitude: 53.9500,
            longitude: -1.8000,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        userLatitude: 53.8008,
        userLongitude: -1.5491,
        maxDistanceMiles: 3.0,
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Close');
    });

    test('UT40 Sort nearby stores by shortest distance first', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'Second Closest',
            postcode: 'BD1 1AA',
            latitude: 53.8058,
            longitude: -1.5491,
          ),
          store(
            id: 2,
            name: 'Closest',
            postcode: 'BD2 2BB',
            latitude: 53.8018,
            longitude: -1.5491,
          ),
          store(
            id: 3,
            name: 'Third Closest',
            postcode: 'BD3 3CC',
            latitude: 53.8208,
            longitude: -1.5491,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        userLatitude: 53.8008,
        userLongitude: -1.5491,
        maxDistanceMiles: 3.0,
      );

      expect(
        result.map((NearbyStoreModel store) => store.name).toList(),
        <String>['Closest', 'Second Closest', 'Third Closest'],
      );
    });

    test('UT41 Exclude stores with zero latitude or longitude', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'Valid',
            postcode: 'BD1 1AA',
            latitude: 53.8010,
            longitude: -1.5490,
          ),
          store(
            id: 2,
            name: 'Zero Latitude',
            postcode: 'BD2 2BB',
            latitude: 0,
            longitude: -1.5500,
          ),
          store(
            id: 3,
            name: 'Zero Longitude',
            postcode: 'BD3 3CC',
            latitude: 53.8020,
            longitude: 0,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        userLatitude: 53.8008,
        userLongitude: -1.5491,
        maxDistanceMiles: 3.0,
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Valid');
    });

    test('UT42 Use location-based result when nearby stores exist', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'Nearby Local',
            postcode: 'BD1 1AA',
            latitude: 53.8010,
            longitude: -1.5490,
          ),
          store(
            id: 2,
            name: 'Fallback Candidate',
            postcode: 'LS1 1ZZ',
            latitude: 53.9500,
            longitude: -1.8000,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        userLatitude: 53.8008,
        userLongitude: -1.5491,
        postcode: 'LS1 4CC',
        maxDistanceMiles: 3.0,
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Nearby Local');
      expect(result.first.distanceMiles, isNotNull);
    });

    test('UT43 Use postcode fallback when no nearby stores are found from coordinates', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'Bradford Match',
            postcode: 'BD1 1AA',
            latitude: 53.9000,
            longitude: -1.8000,
          ),
          store(
            id: 2,
            name: 'Leeds Other',
            postcode: 'LS1 4CC',
            latitude: 53.9500,
            longitude: -1.8500,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        userLatitude: 51.5074,
        userLongitude: -0.1278,
        postcode: 'BD1 4HU',
        maxDistanceMiles: 3.0,
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Bradford Match');
    });

    test('UT44 Match stores by outward postcode code', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'BD1 Store',
            postcode: 'BD1 1AA',
            latitude: 53.9000,
            longitude: -1.8000,
          ),
          store(
            id: 2,
            name: 'BD1 Another',
            postcode: 'BD1 7ZZ',
            latitude: 53.9010,
            longitude: -1.8010,
          ),
          store(
            id: 3,
            name: 'BD7 Store',
            postcode: 'BD7 1DP',
            latitude: 53.9020,
            longitude: -1.8020,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        postcode: 'BD1 4HU',
      );

      expect(result, hasLength(2));
      expect(
        result.map((NearbyStoreModel store) => store.name).toList(),
        <String>['BD1 Store', 'BD1 Another'],
      );
    });

    test('UT45 Match stores by area code when outward code has no match', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'BD7 Store',
            postcode: 'BD7 1DP',
            latitude: 53.9000,
            longitude: -1.8000,
          ),
          store(
            id: 2,
            name: 'BD3 Store',
            postcode: 'BD3 9QX',
            latitude: 53.9010,
            longitude: -1.8010,
          ),
          store(
            id: 3,
            name: 'LS1 Store',
            postcode: 'LS1 4CC',
            latitude: 53.9020,
            longitude: -1.8020,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        postcode: 'BD9 4JU',
      );

      expect(result, hasLength(2));
      expect(
        result.map((NearbyStoreModel store) => store.name),
        containsAll(<String>['BD7 Store', 'BD3 Store']),
      );
    });

    test('UT46 Return all stores when postcode fallback finds no outward or area match', () async {
      final List<NearbyStoreModel> stores = <NearbyStoreModel>[
        store(
          id: 1,
          name: 'Bradford',
          postcode: 'BD1 1AA',
          latitude: 53.9000,
          longitude: -1.8000,
        ),
        store(
          id: 2,
          name: 'Leeds',
          postcode: 'LS1 4CC',
          latitude: 53.9010,
          longitude: -1.8010,
        ),
      ];
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: stores,
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        postcode: 'M1 1AA',
      );

      expect(result, hasLength(2));
      expect(result.map((NearbyStoreModel store) => store.name), containsAll(<String>['Bradford', 'Leeds']));
    });

    test('UT47 Return all stores when postcode is empty during fallback', () async {
      final List<NearbyStoreModel> stores = <NearbyStoreModel>[
        store(
          id: 1,
          name: 'Bradford',
          postcode: 'BD1 1AA',
          latitude: 53.9000,
          longitude: -1.8000,
        ),
        store(
          id: 2,
          name: 'Leeds',
          postcode: 'LS1 4CC',
          latitude: 53.9010,
          longitude: -1.8010,
        ),
      ];
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: stores,
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        postcode: '   ',
      );

      expect(result, hasLength(2));
      expect(result.map((NearbyStoreModel store) => store.name), containsAll(<String>['Bradford', 'Leeds']));
    });

    test('UT48 Normalize postcode before comparison', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'Match',
            postcode: 'BD7 1DP',
            latitude: 53.9000,
            longitude: -1.8000,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        postcode: '  bd7 1dp ',
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'Match');
    });

    test('UT49 Extract outward-code-based match correctly for standard UK postcode format', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'BD7 Match',
            postcode: 'BD7 4EY',
            latitude: 53.9000,
            longitude: -1.8000,
          ),
          store(
            id: 2,
            name: 'BD1 Other',
            postcode: 'BD1 1AA',
            latitude: 53.9010,
            longitude: -1.8010,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        postcode: 'BD7 1DP',
      );

      expect(result, hasLength(1));
      expect(result.first.name, 'BD7 Match');
    });

    test('UT50 Preserve computed distance in returned nearby store model', () async {
      final TestableStoreLocationService service = TestableStoreLocationService(
        stores: <NearbyStoreModel>[
          store(
            id: 1,
            name: 'Nearby',
            postcode: 'BD1 1AA',
            latitude: 53.8020,
            longitude: -1.5495,
          ),
        ],
      );

      final List<NearbyStoreModel> result = await service.fetchNearbyStores(
        userLatitude: 53.8008,
        userLongitude: -1.5491,
        maxDistanceMiles: 3.0,
      );

      expect(result, hasLength(1));
      expect(result.first.distanceMiles, isNotNull);
      expect(result.first.distanceMiles!, greaterThan(0));
    });
  });
}
