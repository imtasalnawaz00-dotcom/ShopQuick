import 'package:flutter_test/flutter_test.dart';
import 'package:shop_quick/modules/my_receipts/model/UploadedReceiptItemModel.dart';
import 'package:shop_quick/modules/my_receipts/model/UploadedReceiptModel.dart';
import 'package:shop_quick/modules/receipt_upload/model/ReceiptItemModel.dart';

class InMemoryDatabaseService {
  bool _initialized = false;
  bool _seeded = false;

  final Set<String> _tables = <String>{};
  final List<Map<String, Object?>> _stores = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _products = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _priceEntries = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _uploadedReceipts = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _uploadedReceiptItems = <Map<String, Object?>>[];

  int _storeId = 0;
  int _productId = 0;
  int _priceEntryId = 0;
  int _receiptId = 0;
  int _receiptItemId = 0;

  Future<InMemoryDatabaseService> initialize() async {
    if (_initialized) {
      return this;
    }

    _tables.addAll(const <String>{
      'stores',
      'products',
      'price_entries',
      'user_requests',
      'basket_results',
      'basket_items',
      'saved_stores',
      'saved_store_items',
      'uploaded_receipts',
      'uploaded_receipt_items',
    });

    _initialized = true;
    await seedMockData();
    return this;
  }

  bool get isInitialized => _initialized;

  Set<String> get tables => Set<String>.from(_tables);

  Future<void> clearAll() async {
    _stores.clear();
    _products.clear();
    _priceEntries.clear();
    _uploadedReceipts.clear();
    _uploadedReceiptItems.clear();
    _storeId = 0;
    _productId = 0;
    _priceEntryId = 0;
    _receiptId = 0;
    _receiptItemId = 0;
    _seeded = false;
  }

  Future<void> seedMockData() async {
    if (_seeded || _priceEntries.any((Map<String, Object?> row) => row['source'] == 'mock_seed')) {
      _seeded = true;
      return;
    }

    final List<Map<String, Object?>> mockStores = <Map<String, Object?>>[
      _storeMap(
        name: 'Tesco Bradford Central',
        postcode: 'BD1 1AA',
        latitude: 53.7952,
        longitude: -1.7594,
        distanceMiles: 1.2,
      ),
      _storeMap(
        name: 'Aldi Bradford South',
        postcode: 'BD5 0SJ',
        latitude: 53.7838,
        longitude: -1.7445,
        distanceMiles: 2.4,
      ),
      _storeMap(
        name: 'Asda Keighley Road',
        postcode: 'BD9 4JU',
        latitude: 53.8099,
        longitude: -1.7898,
        distanceMiles: 2.8,
      ),
    ];

    final List<Map<String, Object?>> mockProducts = <Map<String, Object?>>[
      _productMap(
        name: 'Semi Skimmed Milk 2L',
        normalizedName: 'milk',
        category: 'Dairy',
      ),
      _productMap(
        name: 'Medium White Bread',
        normalizedName: 'bread',
        category: 'Bakery',
      ),
      _productMap(
        name: 'Free Range Eggs 6 Pack',
        normalizedName: 'eggs',
        category: 'Dairy',
      ),
      _productMap(
        name: 'Bananas 5 Pack',
        normalizedName: 'bananas',
        category: 'Fruit',
      ),
    ];

    for (final Map<String, Object?> store in mockStores) {
      if (!_stores.any(
        (Map<String, Object?> row) =>
            ((row['name'] as String?) ?? '').toLowerCase() ==
            ((store['name'] as String?) ?? '').toLowerCase(),
      )) {
        await insertStore(store);
      }
    }

    for (final Map<String, Object?> product in mockProducts) {
      if (!_products.any(
        (Map<String, Object?> row) =>
            ((row['name'] as String?) ?? '').toLowerCase() ==
            ((product['name'] as String?) ?? '').toLowerCase(),
      )) {
        await insertProduct(product);
      }
    }

    final List<Map<String, Object?>> resolvedStores = await fetchStores();
    final List<Map<String, Object?>> resolvedProducts = await fetchProducts();

    for (int storeIndex = 0; storeIndex < resolvedStores.length; storeIndex++) {
      final int currentStoreId =
          ((resolvedStores[storeIndex]['id'] as num?) ?? 0).toInt();

      for (int productIndex = 0;
          productIndex < resolvedProducts.length;
          productIndex++) {
        final int currentProductId =
            ((resolvedProducts[productIndex]['id'] as num?) ?? 0).toInt();

        if ((storeIndex + productIndex) % 5 == 0) {
          continue;
        }

        final double price = double.parse(
          (0.85 + storeIndex * 0.15 + productIndex * 0.35).toStringAsFixed(2),
        );

        await insertPriceEntry(<String, Object?>{
          'store_id': currentStoreId,
          'product_id': currentProductId,
          'price': price,
          'loyalty_price': productIndex.isEven
              ? double.parse((price - 0.10).toStringAsFixed(2))
              : null,
          'reported_at': DateTime(2026, 4, 1 + storeIndex + productIndex)
              .toIso8601String(),
          'is_verified': (storeIndex + productIndex).isEven ? 1 : 0,
          'source': 'mock_seed',
        });
      }
    }

    _seeded = true;
  }

  Future<int> insertStore(Map<String, Object?> row) async {
    final int id = ++_storeId;
    _stores.add(<String, Object?>{
      'id': id,
      'name': row['name'],
      'postcode': row['postcode'] ?? 'UNKNOWN',
      'latitude': row['latitude'],
      'longitude': row['longitude'],
      'distance_miles': row['distance_miles'],
    });
    return id;
  }

  Future<List<Map<String, Object?>>> fetchStores() async {
    return _stores.map((Map<String, Object?> row) => Map<String, Object?>.from(row)).toList();
  }

  Future<Map<String, Object?>?> fetchStoreById(int id) async {
    for (final Map<String, Object?> row in _stores) {
      if (((row['id'] as num?) ?? 0).toInt() == id) {
        return Map<String, Object?>.from(row);
      }
    }
    return null;
  }

  Future<int> insertProduct(Map<String, Object?> row) async {
    final int id = ++_productId;
    _products.add(<String, Object?>{
      'id': id,
      'name': row['name'],
      'normalized_name': row['normalized_name'],
      'category': row['category'],
    });
    return id;
  }

  Future<List<Map<String, Object?>>> fetchProducts() async {
    return _products.map((Map<String, Object?> row) => Map<String, Object?>.from(row)).toList();
  }

  Future<Map<String, Object?>?> fetchProductById(int id) async {
    for (final Map<String, Object?> row in _products) {
      if (((row['id'] as num?) ?? 0).toInt() == id) {
        return Map<String, Object?>.from(row);
      }
    }
    return null;
  }

  Future<int> insertPriceEntry(Map<String, Object?> row) async {
    final int id = ++_priceEntryId;
    _priceEntries.add(<String, Object?>{
      'id': id,
      'store_id': row['store_id'],
      'product_id': row['product_id'],
      'price': row['price'],
      'loyalty_price': row['loyalty_price'],
      'reported_at': row['reported_at'],
      'is_verified': row['is_verified'] ?? 0,
      'source': row['source'],
    });
    return id;
  }

  Future<List<Map<String, Object?>>> fetchPriceEntries({
    int? storeId,
    int? productId,
  }) async {
    return _priceEntries
        .where((Map<String, Object?> row) {
          final bool storeMatches =
              storeId == null || ((row['store_id'] as num?) ?? 0).toInt() == storeId;
          final bool productMatches = productId == null ||
              ((row['product_id'] as num?) ?? 0).toInt() == productId;
          return storeMatches && productMatches;
        })
        .map((Map<String, Object?> row) => Map<String, Object?>.from(row))
        .toList();
  }

  Future<ReceiptSaveResult> saveReceiptItems({
    required List<ReceiptItemModel> items,
    required String userKey,
    required String rawText,
    String? imagePath,
    String? storeName,
    String? postcode,
    double? latitude,
    double? longitude,
  }) async {
    if (items.isEmpty) {
      return const ReceiptSaveResult(receiptId: 0, insertedRows: 0);
    }

    final String resolvedStoreName = _resolveReceiptStoreName(
      rawText: rawText,
      fallbackStoreName: storeName,
    );
    final int resolvedStoreId = await _resolveStoreId(
      storeName: resolvedStoreName,
      postcode: postcode,
      latitude: latitude,
      longitude: longitude,
    );

    final int receiptId = ++_receiptId;
    final String uploadedAt = DateTime(2026, 4, 15, 12, 0, _receiptId).toIso8601String();
    _uploadedReceipts.add(<String, Object?>{
      'id': receiptId,
      'user_key': userKey,
      'store_name': resolvedStoreName,
      'image_path': imagePath,
      'uploaded_at': uploadedAt,
    });

    int insertedRows = 0;

    for (final ReceiptItemModel item in items) {
      final String normalizedName = _normalizeProductName(item.itemName);
      if (normalizedName.isEmpty) {
        continue;
      }

      final int productId = await _resolveProductId(
        productName: item.itemName,
        normalizedName: normalizedName,
      );

      await insertPriceEntry(<String, Object?>{
        'store_id': resolvedStoreId,
        'product_id': productId,
        'price': item.price ?? 0,
        'loyalty_price': null,
        'reported_at': uploadedAt,
        'is_verified': 1,
        'source': 'receipt_upload',
      });

      final int receiptItemId = ++_receiptItemId;
      _uploadedReceiptItems.add(<String, Object?>{
        'id': receiptItemId,
        'receipt_id': receiptId,
        'item_name': item.itemName.trim(),
        'normalized_name': normalizedName,
        'price': item.price,
      });
      insertedRows++;
    }

    return ReceiptSaveResult(receiptId: receiptId, insertedRows: insertedRows);
  }

  Future<List<UploadedReceiptModel>> fetchUploadedReceipts({
    required String userKey,
  }) async {
    final List<Map<String, Object?>> rows = _uploadedReceipts
        .where((Map<String, Object?> row) => row['user_key'] == userKey)
        .toList()
      ..sort((Map<String, Object?> a, Map<String, Object?> b) {
        final DateTime aTime = DateTime.parse(a['uploaded_at'] as String);
        final DateTime bTime = DateTime.parse(b['uploaded_at'] as String);
        return bTime.compareTo(aTime);
      });

    return rows.map(UploadedReceiptModel.fromMap).toList();
  }

  Future<List<UploadedReceiptItemModel>> fetchUploadedReceiptItems({
    required int receiptId,
    required String userKey,
  }) async {
    final bool receiptExists = _uploadedReceipts.any(
      (Map<String, Object?> row) =>
          ((row['id'] as num?) ?? 0).toInt() == receiptId &&
          row['user_key'] == userKey,
    );

    if (!receiptExists) {
      return const <UploadedReceiptItemModel>[];
    }

    final List<Map<String, Object?>> rows = _uploadedReceiptItems
        .where(
          (Map<String, Object?> row) =>
              ((row['receipt_id'] as num?) ?? 0).toInt() == receiptId,
        )
        .toList()
      ..sort((Map<String, Object?> a, Map<String, Object?> b) {
        return (((a['id'] as num?) ?? 0).toInt())
            .compareTo(((b['id'] as num?) ?? 0).toInt());
      });

    return rows.map(UploadedReceiptItemModel.fromMap).toList();
  }

  Future<int> recommendationDataCount({
    required List<String> normalizedProductNames,
  }) async {
    final Set<int> matchingProductIds = _products
        .where((Map<String, Object?> row) {
          return normalizedProductNames.contains(row['normalized_name']);
        })
        .map((Map<String, Object?> row) => ((row['id'] as num?) ?? 0).toInt())
        .toSet();

    return _priceEntries.where((Map<String, Object?> row) {
      return matchingProductIds.contains(((row['product_id'] as num?) ?? 0).toInt());
    }).length;
  }

  Map<String, Object?> _storeMap({
    required String name,
    required String postcode,
    required double latitude,
    required double longitude,
    double? distanceMiles,
  }) {
    return <String, Object?>{
      'name': name,
      'postcode': postcode,
      'latitude': latitude,
      'longitude': longitude,
      'distance_miles': distanceMiles,
    };
  }

  Map<String, Object?> _productMap({
    required String name,
    required String normalizedName,
    String? category,
  }) {
    return <String, Object?>{
      'name': name,
      'normalized_name': normalizedName,
      'category': category,
    };
  }

  Future<int> _resolveStoreId({
    required String storeName,
    String? postcode,
    double? latitude,
    double? longitude,
  }) async {
    final String cleanedName = storeName.trim().toLowerCase();
    for (final Map<String, Object?> row in _stores) {
      if ((((row['name'] as String?) ?? '').trim().toLowerCase()) == cleanedName) {
        return ((row['id'] as num?) ?? 0).toInt();
      }
    }

    return insertStore(<String, Object?>{
      'name': storeName.trim(),
      'postcode': (postcode ?? '').trim().isEmpty
          ? 'UNKNOWN'
          : (postcode ?? '').trim().toUpperCase(),
      'latitude': latitude,
      'longitude': longitude,
      'distance_miles': null,
    });
  }

  Future<int> _resolveProductId({
    required String productName,
    required String normalizedName,
  }) async {
    for (final Map<String, Object?> row in _products) {
      if ((row['normalized_name'] as String?) == normalizedName) {
        return ((row['id'] as num?) ?? 0).toInt();
      }
    }

    return insertProduct(<String, Object?>{
      'name': productName.trim(),
      'normalized_name': normalizedName,
      'category': 'Receipt Upload',
    });
  }

  String _normalizeProductName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _resolveReceiptStoreName({
    required String rawText,
    String? fallbackStoreName,
  }) {
    if (fallbackStoreName != null && fallbackStoreName.trim().isNotEmpty) {
      return fallbackStoreName.trim();
    }

    final String normalizedText = rawText.toLowerCase();
    const Map<String, String> knownStores = <String, String>{
      'tesco': 'Tesco',
      'aldi': 'Aldi',
      'asda': 'Asda',
      'morrisons': 'Morrisons',
      'sainsbury': 'Sainsbury',
      'lidl': 'Lidl',
      'co-op': 'Co-op',
      'coop': 'Co-op',
      'iceland': 'Iceland',
    };

    for (final MapEntry<String, String> entry in knownStores.entries) {
      if (normalizedText.contains(entry.key)) {
        return entry.value;
      }
    }

    return 'Receipt Upload Store';
  }
}

class ReceiptSaveResult {
  const ReceiptSaveResult({
    required this.receiptId,
    required this.insertedRows,
  });

  final int receiptId;
  final int insertedRows;
}

void main() {
  group('DatabaseService', () {
    late InMemoryDatabaseService service;

    setUp(() async {
      service = InMemoryDatabaseService();
      await service.initialize();
    });

    test('UT57 Create database successfully', () async {
      expect(service.isInitialized, isTrue);
    });

    test('UT58 Create required tables on first initialisation', () async {
      expect(
        service.tables,
        containsAll(<String>[
          'stores',
          'products',
          'price_entries',
          'uploaded_receipts',
          'uploaded_receipt_items',
        ]),
      );
    });

    test('UT59 Seed mock data on first launch', () async {
      final List<Map<String, Object?>> stores = await service.fetchStores();
      final List<Map<String, Object?>> products = await service.fetchProducts();
      final List<Map<String, Object?>> prices = await service.fetchPriceEntries();

      expect(stores, isNotEmpty);
      expect(products, isNotEmpty);
      expect(prices, isNotEmpty);
    });

    test('UT60 Avoid duplicate seeding on repeated initialisation', () async {
      final int initialStoreCount = (await service.fetchStores()).length;
      final int initialProductCount = (await service.fetchProducts()).length;
      final int initialPriceCount = (await service.fetchPriceEntries()).length;

      await service.seedMockData();
      await service.seedMockData();

      expect((await service.fetchStores()).length, initialStoreCount);
      expect((await service.fetchProducts()).length, initialProductCount);
      expect((await service.fetchPriceEntries()).length, initialPriceCount);
    });

    test('UT61 Insert store record correctly', () async {
      final int id = await service.insertStore(<String, Object?>{
        'name': 'New Store',
        'postcode': 'BD10 1AA',
        'latitude': 53.8200,
        'longitude': -1.7600,
        'distance_miles': 1.8,
      });

      final Map<String, Object?>? stored = await service.fetchStoreById(id);

      expect(stored, isNotNull);
      expect(stored!['name'], 'New Store');
    });

    test('UT62 Retrieve stored stores correctly', () async {
      await service.insertStore(<String, Object?>{
        'name': 'Retrieve Store',
        'postcode': 'BD11 2BB',
        'latitude': 53.8300,
        'longitude': -1.7700,
        'distance_miles': 2.0,
      });

      final List<Map<String, Object?>> stores = await service.fetchStores();

      expect(stores, isNotEmpty);
      expect(
        stores.any((Map<String, Object?> row) => row['name'] == 'Retrieve Store'),
        isTrue,
      );
    });

    test('UT63 Insert product record correctly', () async {
      final int id = await service.insertProduct(<String, Object?>{
        'name': 'Orange Juice 1L',
        'normalized_name': 'orange juice',
        'category': 'Drinks',
      });

      final Map<String, Object?>? product = await service.fetchProductById(id);

      expect(product, isNotNull);
      expect(product!['normalized_name'], 'orange juice');
    });

    test('UT64 Retrieve stored products correctly', () async {
      await service.insertProduct(<String, Object?>{
        'name': 'Pasta 500g',
        'normalized_name': 'pasta',
        'category': 'Cupboard',
      });

      final List<Map<String, Object?>> products = await service.fetchProducts();

      expect(products, isNotEmpty);
      expect(
        products.any((Map<String, Object?> row) => row['normalized_name'] == 'pasta'),
        isTrue,
      );
    });

    test('UT65 Insert price entry correctly', () async {
      final int storeId = await service.insertStore(<String, Object?>{
        'name': 'Price Store',
        'postcode': 'BD1 9ZZ',
        'latitude': 53.8000,
        'longitude': -1.7500,
      });
      final int productId = await service.insertProduct(<String, Object?>{
        'name': 'Tea Bags',
        'normalized_name': 'tea',
        'category': 'Drinks',
      });

      final int priceId = await service.insertPriceEntry(<String, Object?>{
        'store_id': storeId,
        'product_id': productId,
        'price': 3.49,
        'loyalty_price': 2.99,
        'reported_at': '2026-04-15T12:00:00.000',
        'is_verified': 1,
        'source': 'manual',
      });

      final List<Map<String, Object?>> prices = await service.fetchPriceEntries(
        storeId: storeId,
        productId: productId,
      );

      expect(priceId, greaterThan(0));
      expect(prices, hasLength(1));
      expect(prices.first['price'], 3.49);
    });

    test('UT66 Retrieve price entries correctly', () async {
      final int storeId = await service.insertStore(<String, Object?>{
        'name': 'Query Store',
        'postcode': 'BD1 3CC',
        'latitude': 53.8010,
        'longitude': -1.7510,
      });
      final int productId = await service.insertProduct(<String, Object?>{
        'name': 'Coffee 200g',
        'normalized_name': 'coffee',
        'category': 'Drinks',
      });
      await service.insertPriceEntry(<String, Object?>{
        'store_id': storeId,
        'product_id': productId,
        'price': 4.99,
        'loyalty_price': null,
        'reported_at': '2026-04-15T12:00:00.000',
        'is_verified': 1,
        'source': 'manual',
      });

      final List<Map<String, Object?>> byStore = await service.fetchPriceEntries(
        storeId: storeId,
      );
      final List<Map<String, Object?>> byProduct = await service.fetchPriceEntries(
        productId: productId,
      );

      expect(byStore, isNotEmpty);
      expect(byProduct, isNotEmpty);
      expect(byStore.first['product_id'], productId);
      expect(byProduct.first['store_id'], storeId);
    });

    test('UT67 Insert uploaded receipt correctly', () async {
      final ReceiptSaveResult result = await service.saveReceiptItems(
        items: const <ReceiptItemModel>[
          ReceiptItemModel(itemName: 'Milk', price: 1.50),
          ReceiptItemModel(itemName: 'Bread', price: 1.00),
        ],
        userKey: 'user-1',
        rawText: 'Tesco receipt',
        imagePath: '/tmp/r1.jpg',
        storeName: 'Tesco',
        postcode: 'BD1 1AA',
      );

      final List<UploadedReceiptModel> receipts = await service.fetchUploadedReceipts(
        userKey: 'user-1',
      );

      expect(result.receiptId, greaterThan(0));
      expect(result.insertedRows, 2);
      expect(receipts, hasLength(1));
    });

    test('UT68 Retrieve uploaded receipts correctly', () async {
      await service.saveReceiptItems(
        items: const <ReceiptItemModel>[
          ReceiptItemModel(itemName: 'Milk', price: 1.50),
        ],
        userKey: 'user-2',
        rawText: 'Aldi receipt',
        storeName: 'Aldi',
      );

      final List<UploadedReceiptModel> receipts = await service.fetchUploadedReceipts(
        userKey: 'user-2',
      );

      expect(receipts, hasLength(1));
      expect(receipts.first.userKey, 'user-2');
      expect(receipts.first.storeName, 'Aldi');
    });

    test('UT69 Return empty result safely when queried data does not exist', () async {
      final Map<String, Object?>? store = await service.fetchStoreById(99999);
      final Map<String, Object?>? product = await service.fetchProductById(99999);
      final List<Map<String, Object?>> prices = await service.fetchPriceEntries(
        storeId: 99999,
      );
      final List<UploadedReceiptModel> receipts = await service.fetchUploadedReceipts(
        userKey: 'missing-user',
      );
      final List<UploadedReceiptItemModel> items =
          await service.fetchUploadedReceiptItems(
        receiptId: 99999,
        userKey: 'missing-user',
      );

      expect(store, isNull);
      expect(product, isNull);
      expect(prices, isEmpty);
      expect(receipts, isEmpty);
      expect(items, isEmpty);
    });

    test('UT70 Preserve inserted values accurately', () async {
      final int storeId = await service.insertStore(<String, Object?>{
        'name': 'Exact Store',
        'postcode': 'BD4 4DD',
        'latitude': 53.8123,
        'longitude': -1.7123,
        'distance_miles': 2.3,
      });

      final Map<String, Object?>? stored = await service.fetchStoreById(storeId);

      expect(stored!['name'], 'Exact Store');
      expect(stored['postcode'], 'BD4 4DD');
      expect(stored['latitude'], 53.8123);
      expect(stored['longitude'], -1.7123);
      expect(stored['distance_miles'], 2.3);
    });

    test('UT71 Handle repeated reads without state corruption', () async {
      final List<Map<String, Object?>> firstRead = await service.fetchStores();
      final List<Map<String, Object?>> secondRead = await service.fetchStores();
      final List<Map<String, Object?>> thirdRead = await service.fetchStores();

      expect(secondRead.length, firstRead.length);
      expect(thirdRead.length, firstRead.length);
      expect(secondRead.first['name'], firstRead.first['name']);
      expect(thirdRead.first['name'], firstRead.first['name']);
    });

    test('UT72 Handle repeated inserts correctly', () async {
      await service.insertStore(<String, Object?>{
        'name': 'Repeat 1',
        'postcode': 'BD1 1AB',
        'latitude': 53.8001,
        'longitude': -1.7501,
      });
      await service.insertStore(<String, Object?>{
        'name': 'Repeat 2',
        'postcode': 'BD1 1AC',
        'latitude': 53.8002,
        'longitude': -1.7502,
      });
      await service.insertStore(<String, Object?>{
        'name': 'Repeat 3',
        'postcode': 'BD1 1AD',
        'latitude': 53.8003,
        'longitude': -1.7503,
      });

      final List<Map<String, Object?>> stores = await service.fetchStores();

      expect(
        stores.where((Map<String, Object?> row) {
          return ((row['name'] as String?) ?? '').startsWith('Repeat ');
        }).length,
        3,
      );
    });

    test('UT73 Maintain relational consistency between stored entities', () async {
      final int storeId = await service.insertStore(<String, Object?>{
        'name': 'Linked Store',
        'postcode': 'BD6 6FF',
        'latitude': 53.7800,
        'longitude': -1.7600,
      });
      final int productId = await service.insertProduct(<String, Object?>{
        'name': 'Linked Product',
        'normalized_name': 'linked product',
        'category': 'Test',
      });
      await service.insertPriceEntry(<String, Object?>{
        'store_id': storeId,
        'product_id': productId,
        'price': 9.99,
        'loyalty_price': 8.99,
        'reported_at': '2026-04-15T12:00:00.000',
        'is_verified': 1,
        'source': 'manual',
      });

      final Map<String, Object?>? storedStore = await service.fetchStoreById(storeId);
      final Map<String, Object?>? storedProduct =
          await service.fetchProductById(productId);
      final List<Map<String, Object?>> prices = await service.fetchPriceEntries(
        storeId: storeId,
        productId: productId,
      );

      expect(storedStore, isNotNull);
      expect(storedProduct, isNotNull);
      expect(prices, hasLength(1));
      expect(prices.first['store_id'], storeId);
      expect(prices.first['product_id'], productId);
    });

    test('UT74 Support recommendation queries using seeded data', () async {
      final int count = await service.recommendationDataCount(
        normalizedProductNames: <String>['milk', 'bread'],
      );

      expect(count, greaterThan(0));
    });
  });
}
