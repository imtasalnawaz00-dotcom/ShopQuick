import 'package:flutter_test/flutter_test.dart';

/// Test adapter for the production RecommendationService.
///
/// The real service in `lib/services/RecommendationService.dart` cannot be unit
/// tested directly in a plain `flutter test` environment because it is tightly
/// coupled to:
/// - static `DatabaseService.instance`
/// - static `StoreLocationService()`
/// - sqflite-backed database access and seed side effects
///
/// This adapter mirrors the production logic closely while replacing those
/// dependencies with deterministic in-memory fakes so the documented service
/// behavior can be verified without database, network, or plugin runtime setup.
class TestableRecommendationService {
  TestableRecommendationService({
    required FakeDatabaseService databaseService,
    required FakeStoreLocationService storeLocationService,
  })  : _databaseService = databaseService,
        _storeLocationService = storeLocationService;

  final FakeDatabaseService _databaseService;
  final FakeStoreLocationService _storeLocationService;

  Future<RecommendationResultModel> getRecommendations({
    required String postcode,
    required List<String> shoppingItems,
    required double budget,
    double? userLatitude,
    double? userLongitude,
    bool onlyVerified = false,
    List<String>? allowedSources,
  }) async {
    await _databaseService.seedMockData();

    final List<String> normalizedItems = parseShoppingItems(shoppingItems);

    if (normalizedItems.isEmpty) {
      return const RecommendationResultModel(
        cheapestStore: null,
        secondBestStore: null,
        savingsAmount: 0,
      );
    }

    final List<NearbyStoreModel> candidateStores =
        await _storeLocationService.fetchNearbyStores(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      postcode: postcode,
      maxDistanceMiles: 3.0,
    );

    if (candidateStores.isEmpty) {
      return const RecommendationResultModel(
        cheapestStore: null,
        secondBestStore: null,
        savingsAmount: 0,
      );
    }

    List<StoreTotalModel> rankedStores = await buildRankedStores(
      candidateStores: candidateStores,
      normalizedItems: normalizedItems,
      onlyVerified: onlyVerified,
      allowedSources: allowedSources,
    );

    if (rankedStores.isEmpty &&
        userLatitude != null &&
        userLongitude != null &&
        postcode.trim().isNotEmpty) {
      final List<NearbyStoreModel> fallbackStores =
          await _storeLocationService.fetchNearbyStores(
        userLatitude: null,
        userLongitude: null,
        postcode: postcode,
        maxDistanceMiles: 3.0,
      );

      rankedStores = await buildRankedStores(
        candidateStores: fallbackStores,
        normalizedItems: normalizedItems,
        onlyVerified: onlyVerified,
        allowedSources: allowedSources,
      );
    }

    if (rankedStores.isEmpty) {
      return const RecommendationResultModel(
        cheapestStore: null,
        secondBestStore: null,
        savingsAmount: 0,
      );
    }

    final List<StoreTotalModel> completeMatchStores = rankedStores
        .where(
          (StoreTotalModel store) =>
              store.matchedItems.length == normalizedItems.length,
        )
        .toList();

    final List<StoreTotalModel> sortedStores =
        (completeMatchStores.isNotEmpty ? completeMatchStores : rankedStores)
          ..sort((StoreTotalModel a, StoreTotalModel b) {
            final int matchCountComparison =
                b.matchedItems.length.compareTo(a.matchedItems.length);
            if (matchCountComparison != 0) {
              return matchCountComparison;
            }

            final int totalComparison = a.totalPrice.compareTo(b.totalPrice);
            if (totalComparison != 0) {
              return totalComparison;
            }

            return a.storeName.compareTo(b.storeName);
          });

    final StoreTotalModel cheapestStore = sortedStores.first;
    final StoreTotalModel? secondBestStore =
        sortedStores.length > 1 ? sortedStores[1] : null;
    final double savingsAmount = secondBestStore == null
        ? 0
        : double.parse(
            (secondBestStore.totalPrice - cheapestStore.totalPrice)
                .toStringAsFixed(2),
          );

    return RecommendationResultModel(
      cheapestStore: cheapestStore,
      secondBestStore: secondBestStore,
      savingsAmount: savingsAmount < 0 ? 0 : savingsAmount,
    );
  }

  Future<List<StoreTotalModel>> buildRankedStores({
    required List<NearbyStoreModel> candidateStores,
    required List<String> normalizedItems,
    required bool onlyVerified,
    required List<String>? allowedSources,
  }) async {
    if (candidateStores.isEmpty || normalizedItems.isEmpty) {
      return <StoreTotalModel>[];
    }

    final List<int> storeIds =
        candidateStores.map((NearbyStoreModel store) => store.id).toList();
    final List<FakePriceEntry> rows = await _databaseService.rawQuery(
      storeIds: storeIds,
      onlyVerified: onlyVerified,
      allowedSources: allowedSources,
    );

    final Map<int, List<FakePriceEntry>> entriesByStore =
        <int, List<FakePriceEntry>>{};

    for (final FakePriceEntry row in rows) {
      entriesByStore.putIfAbsent(row.storeId, () => <FakePriceEntry>[]);
      entriesByStore[row.storeId]!.add(row);
    }

    final List<StoreTotalModel> rankedStores = <StoreTotalModel>[];

    for (final NearbyStoreModel store in candidateStores) {
      final List<FakePriceEntry> storeEntries =
          entriesByStore[store.id] ?? <FakePriceEntry>[];

      if (storeEntries.isEmpty) {
        continue;
      }

      final List<String> matchedItems = <String>[];
      final List<MatchedItemModel> matchedItemDetails = <MatchedItemModel>[];
      final List<String> missingItems = <String>[];
      double totalPrice = 0;

      for (final String item in normalizedItems) {
        final FakePriceEntry? cheapestEntry = findCheapestEntryForItem(
          normalizedItem: item,
          storeEntries: storeEntries,
        );

        if (cheapestEntry == null) {
          missingItems.add(item);
          continue;
        }

        matchedItems.add(item);
        final double matchedPrice = resolveEntryPrice(cheapestEntry);
        matchedItemDetails.add(
          MatchedItemModel(
            name: item,
            price: double.parse(matchedPrice.toStringAsFixed(2)),
          ),
        );
        totalPrice += matchedPrice;
      }

      if (matchedItems.isEmpty) {
        continue;
      }

      rankedStores.add(
        StoreTotalModel(
          storeId: store.id.toString(),
          storeName: store.name,
          postcode: store.postcode,
          distanceMiles: store.distanceMiles,
          totalPrice: double.parse(totalPrice.toStringAsFixed(2)),
          matchedItems: matchedItems,
          matchedItemDetails: matchedItemDetails,
          missingItems: missingItems,
        ),
      );
    }

    return rankedStores;
  }

  List<String> parseShoppingItems(List<String> shoppingItems) {
    return shoppingItems
        .expand((String value) => value.split(','))
        .map(normalizeText)
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  FakePriceEntry? findCheapestEntryForItem({
    required String normalizedItem,
    required List<FakePriceEntry> storeEntries,
  }) {
    FakePriceEntry? cheapestEntry;

    for (final FakePriceEntry entry in storeEntries) {
      final String normalizedProductName = normalizeText(entry.productName);
      final String normalizedKey = normalizeText(entry.normalizedName);

      if (!isItemMatch(
        normalizedItem: normalizedItem,
        normalizedProductName: normalizedProductName,
        normalizedKey: normalizedKey,
      )) {
        continue;
      }

      if (cheapestEntry == null ||
          resolveEntryPrice(entry) < resolveEntryPrice(cheapestEntry)) {
        cheapestEntry = entry;
      }
    }

    return cheapestEntry;
  }

  bool isItemMatch({
    required String normalizedItem,
    required String normalizedProductName,
    required String normalizedKey,
  }) {
    return normalizedProductName.contains(normalizedItem) ||
        normalizedItem.contains(normalizedProductName) ||
        normalizedKey.contains(normalizedItem);
  }

  double resolveEntryPrice(FakePriceEntry entry) {
    return entry.loyaltyPrice ?? entry.price;
  }

  String normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}

class RecommendationResultModel {
  const RecommendationResultModel({
    this.cheapestStore,
    this.secondBestStore,
    required this.savingsAmount,
  });

  final StoreTotalModel? cheapestStore;
  final StoreTotalModel? secondBestStore;
  final double savingsAmount;
}

class MatchedItemModel {
  const MatchedItemModel({
    required this.name,
    required this.price,
  });

  final String name;
  final double price;
}

class StoreTotalModel {
  const StoreTotalModel({
    required this.storeId,
    required this.storeName,
    required this.postcode,
    this.distanceMiles,
    required this.totalPrice,
    required this.matchedItems,
    required this.matchedItemDetails,
    required this.missingItems,
  });

  final String storeId;
  final String storeName;
  final String postcode;
  final double? distanceMiles;
  final double totalPrice;
  final List<String> matchedItems;
  final List<MatchedItemModel> matchedItemDetails;
  final List<String> missingItems;
}

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
}

class FakePriceEntry {
  const FakePriceEntry({
    required this.storeId,
    required this.productName,
    required this.normalizedName,
    required this.price,
    this.loyaltyPrice,
    this.isVerified = true,
    this.source = 'manual',
  });

  final int storeId;
  final String productName;
  final String normalizedName;
  final double price;
  final double? loyaltyPrice;
  final bool isVerified;
  final String source;
}

class FakeDatabaseService {
  FakeDatabaseService({
    List<FakePriceEntry>? entries,
  }) : _entries = entries ?? <FakePriceEntry>[];

  final List<FakePriceEntry> _entries;

  Future<void> seedMockData() async {}

  Future<List<FakePriceEntry>> rawQuery({
    required List<int> storeIds,
    required bool onlyVerified,
    required List<String>? allowedSources,
  }) async {
    return _entries.where((FakePriceEntry entry) {
      if (!storeIds.contains(entry.storeId)) {
        return false;
      }
      if (onlyVerified && !entry.isVerified) {
        return false;
      }
      if (allowedSources != null &&
          allowedSources.isNotEmpty &&
          !allowedSources.contains(entry.source)) {
        return false;
      }
      return true;
    }).toList();
  }
}

class FakeStoreLocationService {
  FakeStoreLocationService({
    List<NearbyStoreModel>? locationStores,
    List<NearbyStoreModel>? postcodeStores,
  })  : _locationStores = locationStores ?? <NearbyStoreModel>[],
        _postcodeStores = postcodeStores ?? locationStores ?? <NearbyStoreModel>[];

  final List<NearbyStoreModel> _locationStores;
  final List<NearbyStoreModel> _postcodeStores;

  Future<List<NearbyStoreModel>> fetchNearbyStores({
    double? userLatitude,
    double? userLongitude,
    String? postcode,
    double maxDistanceMiles = 3.0,
  }) async {
    if (userLatitude != null && userLongitude != null) {
      return _locationStores;
    }
    return _postcodeStores;
  }
}

TestableRecommendationService buildService({
  List<NearbyStoreModel>? locationStores,
  List<NearbyStoreModel>? postcodeStores,
  List<FakePriceEntry>? entries,
}) {
  return TestableRecommendationService(
    databaseService: FakeDatabaseService(entries: entries),
    storeLocationService: FakeStoreLocationService(
      locationStores: locationStores,
      postcodeStores: postcodeStores,
    ),
  );
}

NearbyStoreModel store({
  required int id,
  required String name,
  required String postcode,
  double? distanceMiles,
}) {
  return NearbyStoreModel(
    id: id,
    name: name,
    postcode: postcode,
    latitude: 53.0 + id,
    longitude: -1.0 - id,
    distanceMiles: distanceMiles,
  );
}

FakePriceEntry priceEntry({
  required int storeId,
  required String productName,
  required String normalizedName,
  required double price,
  double? loyaltyPrice,
  bool isVerified = true,
  String source = 'manual',
}) {
  return FakePriceEntry(
    storeId: storeId,
    productName: productName,
    normalizedName: normalizedName,
    price: price,
    loyaltyPrice: loyaltyPrice,
    isVerified: isVerified,
    source: source,
  );
}

void main() {
  group('RecommendationService', () {
    test('UT1 Return empty result when shopping list is empty', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>[],
        budget: 20,
      );

      expect(result.cheapestStore, isNull);
      expect(result.secondBestStore, isNull);
      expect(result.savingsAmount, 0);
    });

    test(
      'UT2 Return empty result when parsed shopping items become empty after cleaning',
      () async {
        final TestableRecommendationService service = buildService(
          locationStores: <NearbyStoreModel>[
            store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
          ],
        );

        final RecommendationResultModel result =
            await service.getRecommendations(
          postcode: 'BD1 1AA',
          shoppingItems: <String>[' ', ',,,', ' !@# '],
          budget: 20,
        );

        expect(result.cheapestStore, isNull);
        expect(result.secondBestStore, isNull);
        expect(result.savingsAmount, 0);
      },
    );

    test('UT3 Return empty result when no candidate stores are found', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 1.50,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['milk'],
        budget: 20,
      );

      expect(result.cheapestStore, isNull);
      expect(result.secondBestStore, isNull);
      expect(result.savingsAmount, 0);
    });

    test('UT4 Return cheapest store when matching stores exist', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
          store(id: 2, name: 'Bravo', postcode: 'BD2 2BB'),
        ],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 1.50,
          ),
          priceEntry(
            storeId: 1,
            productName: 'Bread',
            normalizedName: 'bread',
            price: 1.00,
          ),
          priceEntry(
            storeId: 2,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 2.20,
          ),
          priceEntry(
            storeId: 2,
            productName: 'Bread',
            normalizedName: 'bread',
            price: 1.40,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['milk', 'bread'],
        budget: 20,
      );

      expect(result.cheapestStore, isNotNull);
      expect(result.cheapestStore!.storeName, 'Alpha');
      expect(result.cheapestStore!.totalPrice, 2.50);
      expect(result.cheapestStore!.matchedItems, <String>['milk', 'bread']);
    });

    test(
      'UT5 Return second best store when more than one ranked store exists',
      () async {
        final TestableRecommendationService service = buildService(
          locationStores: <NearbyStoreModel>[
            store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
            store(id: 2, name: 'Bravo', postcode: 'BD2 2BB'),
            store(id: 3, name: 'Charlie', postcode: 'BD3 3CC'),
          ],
          entries: <FakePriceEntry>[
            priceEntry(
              storeId: 1,
              productName: 'Milk',
              normalizedName: 'milk',
              price: 1.50,
            ),
            priceEntry(
              storeId: 1,
              productName: 'Bread',
              normalizedName: 'bread',
              price: 1.00,
            ),
            priceEntry(
              storeId: 2,
              productName: 'Milk',
              normalizedName: 'milk',
              price: 1.90,
            ),
            priceEntry(
              storeId: 2,
              productName: 'Bread',
              normalizedName: 'bread',
              price: 1.40,
            ),
            priceEntry(
              storeId: 3,
              productName: 'Milk',
              normalizedName: 'milk',
              price: 2.50,
            ),
            priceEntry(
              storeId: 3,
              productName: 'Bread',
              normalizedName: 'bread',
              price: 1.80,
            ),
          ],
        );

        final RecommendationResultModel result =
            await service.getRecommendations(
          postcode: 'BD1 1AA',
          shoppingItems: <String>['milk', 'bread'],
          budget: 20,
        );

        expect(result.cheapestStore!.storeName, 'Alpha');
        expect(result.secondBestStore, isNotNull);
        expect(result.secondBestStore!.storeName, 'Bravo');
        expect(result.secondBestStore!.totalPrice, 3.30);
      },
    );

    test(
      'UT6 Calculate savings correctly between cheapest and second best store',
      () async {
        final TestableRecommendationService service = buildService(
          locationStores: <NearbyStoreModel>[
            store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
            store(id: 2, name: 'Bravo', postcode: 'BD2 2BB'),
          ],
          entries: <FakePriceEntry>[
            priceEntry(
              storeId: 1,
              productName: 'Milk',
              normalizedName: 'milk',
              price: 5.25,
            ),
            priceEntry(
              storeId: 1,
              productName: 'Bread',
              normalizedName: 'bread',
              price: 3.25,
            ),
            priceEntry(
              storeId: 2,
              productName: 'Milk',
              normalizedName: 'milk',
              price: 6.00,
            ),
            priceEntry(
              storeId: 2,
              productName: 'Bread',
              normalizedName: 'bread',
              price: 4.00,
            ),
          ],
        );

        final RecommendationResultModel result =
            await service.getRecommendations(
          postcode: 'BD1 1AA',
          shoppingItems: <String>['milk', 'bread'],
          budget: 20,
        );

        expect(result.cheapestStore!.totalPrice, 8.50);
        expect(result.secondBestStore!.totalPrice, 10.00);
        expect(result.savingsAmount, 1.50);
      },
    );

    test('UT7 Return savings as zero when only one store is available', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
        ],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 1.50,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['milk'],
        budget: 20,
      );

      expect(result.cheapestStore, isNotNull);
      expect(result.secondBestStore, isNull);
      expect(result.savingsAmount, 0);
    });

    test('UT8 Prefer complete basket matches over partial matches', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'Partial Cheap', postcode: 'BD1 1AA'),
          store(id: 2, name: 'Complete Slightly Higher', postcode: 'BD2 2BB'),
        ],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 0.80,
          ),
          priceEntry(
            storeId: 2,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 1.10,
          ),
          priceEntry(
            storeId: 2,
            productName: 'Bread',
            normalizedName: 'bread',
            price: 1.20,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['milk', 'bread'],
        budget: 20,
      );

      expect(result.cheapestStore, isNotNull);
      expect(result.cheapestStore!.storeName, 'Complete Slightly Higher');
      expect(result.cheapestStore!.matchedItems.length, 2);
      expect(result.cheapestStore!.missingItems, isEmpty);
    });

    test('UT9 Rank stores by number of matched items then by total price', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'More Matches', postcode: 'BD1 1AA'),
          store(id: 2, name: 'Fewer But Cheaper', postcode: 'BD2 2BB'),
          store(id: 3, name: 'Same Matches Higher Total', postcode: 'BD3 3CC'),
        ],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 2.00,
          ),
          priceEntry(
            storeId: 1,
            productName: 'Bread',
            normalizedName: 'bread',
            price: 2.00,
          ),
          priceEntry(
            storeId: 2,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 0.50,
          ),
          priceEntry(
            storeId: 3,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 2.50,
          ),
          priceEntry(
            storeId: 3,
            productName: 'Bread',
            normalizedName: 'bread',
            price: 2.50,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['milk', 'bread', 'eggs'],
        budget: 20,
      );

      expect(result.cheapestStore, isNotNull);
      expect(result.cheapestStore!.storeName, 'More Matches');
      expect(result.secondBestStore, isNotNull);
      expect(result.secondBestStore!.storeName, 'Same Matches Higher Total');
    });

    test('UT10 Mark unavailable items when some basket items are missing', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
        ],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 1.50,
          ),
          priceEntry(
            storeId: 1,
            productName: 'Bread',
            normalizedName: 'bread',
            price: 1.10,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['milk', 'bread', 'eggs'],
        budget: 20,
      );

      expect(result.cheapestStore, isNotNull);
      expect(result.cheapestStore!.matchedItems, <String>['milk', 'bread']);
      expect(result.cheapestStore!.missingItems, <String>['eggs']);
    });

    test('UT11 Use loyalty price when available instead of standard price', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
          store(id: 2, name: 'Bravo', postcode: 'BD2 2BB'),
        ],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 3.00,
            loyaltyPrice: 1.20,
          ),
          priceEntry(
            storeId: 2,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 1.80,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['milk'],
        budget: 20,
      );

      expect(result.cheapestStore, isNotNull);
      expect(result.cheapestStore!.storeName, 'Alpha');
      expect(result.cheapestStore!.totalPrice, 1.20);
      expect(result.cheapestStore!.matchedItemDetails.first.price, 1.20);
    });

    test('UT12 Use standard price when loyalty price is null', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
        ],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Milk',
            normalizedName: 'milk',
            price: 2.75,
            loyaltyPrice: null,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['milk'],
        budget: 20,
      );

      expect(result.cheapestStore, isNotNull);
      expect(result.cheapestStore!.totalPrice, 2.75);
      expect(result.cheapestStore!.matchedItemDetails.first.price, 2.75);
    });

    test('UT13 Parse and normalize shopping list correctly', () {
      final TestableRecommendationService service = buildService();

      final List<String> items = service.parseShoppingItems(<String>[
        '  MILK  ',
        'bread, milk',
        'Eggs!!',
        ' eggs ',
        '   ',
      ]);

      expect(items.length, 3);
      expect(items, containsAll(<String>['milk', 'bread', 'eggs']));
    });

    test('UT14 Match product names using normalized comparison', () async {
      final TestableRecommendationService service = buildService(
        locationStores: <NearbyStoreModel>[
          store(id: 1, name: 'Alpha', postcode: 'BD1 1AA'),
        ],
        entries: <FakePriceEntry>[
          priceEntry(
            storeId: 1,
            productName: 'Semi-Skimmed Milk 2L',
            normalizedName: 'semi skimmed milk 2l',
            price: 1.90,
          ),
        ],
      );

      final RecommendationResultModel result = await service.getRecommendations(
        postcode: 'BD1 1AA',
        shoppingItems: <String>['semi skimmed milk'],
        budget: 20,
      );

      expect(result.cheapestStore, isNotNull);
      expect(result.cheapestStore!.matchedItems, <String>['semi skimmed milk']);
      expect(result.cheapestStore!.missingItems, isEmpty);
    });

    test(
      'UT15 Fallback to postcode based matching when location based store matching gives no basket result',
      () async {
        final TestableRecommendationService service = buildService(
          locationStores: <NearbyStoreModel>[
            store(id: 1, name: 'Nearby No Match', postcode: 'BD1 1AA'),
          ],
          postcodeStores: <NearbyStoreModel>[
            store(id: 2, name: 'Postcode Match', postcode: 'BD1 2BB'),
          ],
          entries: <FakePriceEntry>[
            priceEntry(
              storeId: 1,
              productName: 'Coffee',
              normalizedName: 'coffee',
              price: 4.00,
            ),
            priceEntry(
              storeId: 2,
              productName: 'Milk',
              normalizedName: 'milk',
              price: 1.25,
            ),
          ],
        );

        final RecommendationResultModel result =
            await service.getRecommendations(
          postcode: 'BD1 1AA',
          shoppingItems: <String>['milk'],
          budget: 20,
          userLatitude: 53.79,
          userLongitude: -1.75,
        );

        expect(result.cheapestStore, isNotNull);
        expect(result.cheapestStore!.storeName, 'Postcode Match');
        expect(result.cheapestStore!.totalPrice, 1.25);
        expect(result.secondBestStore, isNull);
      },
    );
  });
}
