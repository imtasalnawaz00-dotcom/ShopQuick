import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../modules/favourite_stores/model/SavedStoreItemModel.dart';
import '../modules/favourite_stores/model/SavedStoreModel.dart';
import '../modules/my_receipts/model/UploadedReceiptItemModel.dart';
import '../modules/my_receipts/model/UploadedReceiptModel.dart';
import '../modules/receipt_upload/model/ReceiptItemModel.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _databaseName = 'shopquick.db';
  static const int _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String databasesPath = await getDatabasesPath();
    final String databasePath = path.join(databasesPath, _databaseName);

    final Database db = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _seedMockDataIfNeeded(db);
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createStoresTable);
    await db.execute(_createProductsTable);
    await db.execute(_createPriceEntriesTable);
    await db.execute(_createUserRequestsTable);
    await db.execute(_createBasketResultsTable);
    await db.execute(_createBasketItemsTable);
    await db.execute(_createSavedStoresTable);
    await db.execute(_createSavedStoreItemsTable);
    await db.execute(_createUploadedReceiptsTable);
    await db.execute(_createUploadedReceiptItemsTable);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(_createUploadedReceiptsTable);
      await db.execute(_createUploadedReceiptItemsTable);
    }

    if (oldVersion < 3) {
      await db.execute(_createSavedStoresTable);
      await db.execute(_createSavedStoreItemsTable);
    }
  }

  Future<void> clearAllTables() async {
    final Database db = await database;

    await db.delete('basket_items');
    await db.delete('basket_results');
    await db.delete('user_requests');
    await db.delete('price_entries');
    await db.delete('saved_store_items');
    await db.delete('saved_stores');
    await db.delete('uploaded_receipt_items');
    await db.delete('uploaded_receipts');
    await db.delete('products');
    await db.delete('stores');
  }

  Future<void> saveFavouriteStore({
    required String userKey,
    required String storeName,
    required String storePostcode,
    required double basketTotal,
    required List<SavedStoreItemModel> items,
  }) async {
    if (items.isEmpty) {
      return;
    }

    final Database db = await database;

    await db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> existingStores = await txn.query(
        'saved_stores',
        where: 'user_key = ? AND LOWER(store_name) = ?',
        whereArgs: <Object?>[userKey, storeName.trim().toLowerCase()],
        limit: 1,
      );

      final String cleanedPostcode = storePostcode.trim().toUpperCase();
      final String savedAt = DateTime.now().toIso8601String();
      int savedStoreId;

      if (existingStores.isNotEmpty) {
        savedStoreId = ((existingStores.first['id'] as num?) ?? 0).toInt();
        await txn.update(
          'saved_stores',
          <String, Object?>{
            'store_name': storeName.trim(),
            'store_postcode': cleanedPostcode,
            'basket_total': double.parse(basketTotal.toStringAsFixed(2)),
            'saved_at': savedAt,
          },
          where: 'id = ?',
          whereArgs: <Object?>[savedStoreId],
        );
        await txn.delete(
          'saved_store_items',
          where: 'saved_store_id = ?',
          whereArgs: <Object?>[savedStoreId],
        );
      } else {
        savedStoreId = await txn.insert('saved_stores', <String, Object?>{
          'user_key': userKey,
          'store_name': storeName.trim(),
          'store_postcode': cleanedPostcode,
          'basket_total': double.parse(basketTotal.toStringAsFixed(2)),
          'saved_at': savedAt,
        });
      }

      for (final SavedStoreItemModel item in items) {
        await txn.insert('saved_store_items', <String, Object?>{
          'saved_store_id': savedStoreId,
          'item_name': item.itemName.trim(),
          'price': double.parse(item.price.toStringAsFixed(2)),
        });
      }
    });
  }

  Future<List<SavedStoreModel>> fetchFavouriteStores({
    required String userKey,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> storeRows = await db.query(
      'saved_stores',
      where: 'user_key = ?',
      whereArgs: <Object?>[userKey],
      orderBy: 'saved_at DESC, id DESC',
    );

    if (storeRows.isEmpty) {
      return const <SavedStoreModel>[];
    }

    final List<int> savedStoreIds = storeRows
        .map((Map<String, Object?> row) => ((row['id'] as num?) ?? 0).toInt())
        .where((int id) => id > 0)
        .toList();
    final String placeholders = List<String>.filled(savedStoreIds.length, '?')
        .join(',');
    final List<Map<String, Object?>> itemRows = await db.rawQuery(
      '''
      SELECT id, saved_store_id, item_name, price
      FROM saved_store_items
      WHERE saved_store_id IN ($placeholders)
      ORDER BY id ASC
      ''',
      savedStoreIds,
    );

    final Map<int, List<SavedStoreItemModel>> itemsByStoreId =
        <int, List<SavedStoreItemModel>>{};
    for (final Map<String, Object?> row in itemRows) {
      final SavedStoreItemModel item = SavedStoreItemModel.fromMap(row);
      itemsByStoreId.putIfAbsent(
        item.savedStoreId,
        () => <SavedStoreItemModel>[],
      );
      itemsByStoreId[item.savedStoreId]!.add(item);
    }

    return storeRows
        .map(
          (Map<String, Object?> row) => SavedStoreModel.fromMap(
            row,
            items: itemsByStoreId[((row['id'] as num?) ?? 0).toInt()] ??
                const <SavedStoreItemModel>[],
          ),
        )
        .toList();
  }

  Future<DeleteFavouriteItemResult> deleteFavouriteStoreItem({
    required int savedStoreItemId,
    required String userKey,
  }) async {
    final Database db = await database;

    return db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> matchedItems = await txn.rawQuery(
        '''
        SELECT ssi.id, ssi.saved_store_id
        FROM saved_store_items ssi
        INNER JOIN saved_stores ss ON ss.id = ssi.saved_store_id
        WHERE ssi.id = ? AND ss.user_key = ?
        LIMIT 1
        ''',
        <Object?>[savedStoreItemId, userKey],
      );

      if (matchedItems.isEmpty) {
        return const DeleteFavouriteItemResult(
          deletedItem: false,
          deletedStore: false,
        );
      }

      final int savedStoreId =
          ((matchedItems.first['saved_store_id'] as num?) ?? 0).toInt();

      await txn.delete(
        'saved_store_items',
        where: 'id = ?',
        whereArgs: <Object?>[savedStoreItemId],
      );

      final int remainingItemCount = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM saved_store_items WHERE saved_store_id = ?',
              <Object?>[savedStoreId],
            ),
          ) ??
          0;

      if (remainingItemCount == 0) {
        await txn.delete(
          'saved_stores',
          where: 'id = ? AND user_key = ?',
          whereArgs: <Object?>[savedStoreId, userKey],
        );
        return const DeleteFavouriteItemResult(
          deletedItem: true,
          deletedStore: true,
        );
      }

      final num? recalculatedTotal = (await txn.rawQuery(
        'SELECT SUM(price) AS total FROM saved_store_items WHERE saved_store_id = ?',
        <Object?>[savedStoreId],
      ))
          .first['total'] as num?;

      await txn.update(
        'saved_stores',
        <String, Object?>{
          'basket_total': (recalculatedTotal ?? 0).toDouble(),
          'saved_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND user_key = ?',
        whereArgs: <Object?>[savedStoreId, userKey],
      );

      return const DeleteFavouriteItemResult(
        deletedItem: true,
        deletedStore: false,
      );
    });
  }

  Future<void> seedMockData() async {
    final Database db = await database;
    await _seedMockDataIfNeeded(db);
  }

  Future<void> _seedMockDataIfNeeded(Database db) async {
    final int existingMockPriceCount =
        Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM price_entries WHERE source = 'mock_seed'",
        )) ??
        0;
    final List<Map<String, Object?>> mockStoreSeed = _buildMockStores();
    final List<Map<String, Object?>> mockProductSeed = _buildMockProducts();

    if (existingMockPriceCount > 0) {
      return;
    }

    final Batch batch = db.batch();

    for (final Map<String, Object?> store in mockStoreSeed) {
      final String storeName = ((store['name'] as String?) ?? '').trim().toLowerCase();
      final List<Map<String, Object?>> existingStore = await db.query(
        'stores',
        where: 'LOWER(name) = ?',
        whereArgs: <Object?>[storeName],
        limit: 1,
      );

      if (existingStore.isEmpty) {
        batch.insert('stores', store);
      }
    }

    for (final Map<String, Object?> product in mockProductSeed) {
      final String productName =
          ((product['name'] as String?) ?? '').trim().toLowerCase();
      final List<Map<String, Object?>> existingProduct = await db.query(
        'products',
        where: 'LOWER(name) = ?',
        whereArgs: <Object?>[productName],
        limit: 1,
      );

      if (existingProduct.isEmpty) {
        batch.insert('products', product);
      }
    }

    await batch.commit(noResult: true);

    final List<Map<String, Object?>> resolvedStores = <Map<String, Object?>>[];
    for (final Map<String, Object?> store in mockStoreSeed) {
      final List<Map<String, Object?>> rows = await db.query(
        'stores',
        where: 'LOWER(name) = ?',
        whereArgs: <Object?>[
          ((store['name'] as String?) ?? '').trim().toLowerCase(),
        ],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        resolvedStores.add(rows.first);
      }
    }

    final List<Map<String, Object?>> resolvedProducts = <Map<String, Object?>>[];
    for (final Map<String, Object?> product in mockProductSeed) {
      final List<Map<String, Object?>> rows = await db.query(
        'products',
        where: 'LOWER(name) = ?',
        whereArgs: <Object?>[
          ((product['name'] as String?) ?? '').trim().toLowerCase(),
        ],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        resolvedProducts.add(rows.first);
      }
    }

    final Batch priceEntriesBatch = db.batch();
    final List<Map<String, Object?>> priceEntries = _buildMockPriceEntries(
      stores: resolvedStores,
      products: resolvedProducts,
    );

    for (final Map<String, Object?> priceEntry in priceEntries) {
      priceEntriesBatch.insert('price_entries', priceEntry);
    }

    await priceEntriesBatch.commit(noResult: true);
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

    final Database db = await database;
    await seedMockData();
    int insertedRows = 0;
    int receiptId = 0;

    // Save the uploaded receipt and link each extracted item to it.
    await db.transaction((Transaction txn) async {
      final String resolvedStoreName = _resolveReceiptStoreName(
        rawText: rawText,
        fallbackStoreName: storeName,
      );
      receiptId = await txn.insert('uploaded_receipts', <String, Object?>{
        'user_key': userKey,
        'store_name': resolvedStoreName,
        'image_path': imagePath,
        'uploaded_at': DateTime.now().toIso8601String(),
      });

      final int resolvedStoreId = await _resolveStoreId(
        txn: txn,
        storeName: resolvedStoreName,
        postcode: postcode,
        latitude: latitude,
        longitude: longitude,
      );

      for (final ReceiptItemModel item in items) {
        final String normalizedName = _normalizeProductName(item.itemName);
        if (normalizedName.isEmpty) {
          continue;
        }

        final int productId = await _resolveProductId(
          txn: txn,
          productName: item.itemName,
          normalizedName: normalizedName,
        );

        await txn.insert('price_entries', <String, Object?>{
          'store_id': resolvedStoreId,
          'product_id': productId,
          'price': item.price ?? 0,
          'loyalty_price': null,
          'reported_at': DateTime.now().toIso8601String(),
          'is_verified': 1,
          'source': 'receipt_upload',
        });
        await txn.insert('uploaded_receipt_items', <String, Object?>{
          'receipt_id': receiptId,
          'item_name': item.itemName.trim(),
          'normalized_name': normalizedName,
          'price': item.price,
        });
        insertedRows++;
      }
    });

    return ReceiptSaveResult(
      receiptId: receiptId,
      insertedRows: insertedRows,
    );
  }

  Future<List<UploadedReceiptModel>> fetchUploadedReceipts({
    required String userKey,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'uploaded_receipts',
      where: 'user_key = ?',
      whereArgs: <Object?>[userKey],
      orderBy: 'uploaded_at DESC, id DESC',
    );

    return rows.map(UploadedReceiptModel.fromMap).toList();
  }

  Future<List<UploadedReceiptItemModel>> fetchUploadedReceiptItems({
    required int receiptId,
    required String userKey,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT uri.id, uri.receipt_id, uri.item_name, uri.normalized_name, uri.price
      FROM uploaded_receipt_items uri
      INNER JOIN uploaded_receipts ur ON ur.id = uri.receipt_id
      WHERE uri.receipt_id = ? AND ur.user_key = ?
      ORDER BY uri.id ASC
      ''',
      <Object?>[receiptId, userKey],
    );

    return rows.map(UploadedReceiptItemModel.fromMap).toList();
  }

  Future<void> deleteUploadedReceipt({
    required int receiptId,
    required String userKey,
  }) async {
    final Database db = await database;

    // Remove both the receipt record and its extracted item rows.
    await db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> matches = await txn.query(
        'uploaded_receipts',
        columns: <String>['id'],
        where: 'id = ? AND user_key = ?',
        whereArgs: <Object?>[receiptId, userKey],
        limit: 1,
      );

      if (matches.isEmpty) {
        return;
      }

      await txn.delete(
        'uploaded_receipt_items',
        where: 'receipt_id = ?',
        whereArgs: <Object?>[receiptId],
      );
      await txn.delete(
        'uploaded_receipts',
        where: 'id = ? AND user_key = ?',
        whereArgs: <Object?>[receiptId, userKey],
      );
    });
  }

  List<Map<String, Object?>> _buildMockStores() {
    return <Map<String, Object?>>[
      {
        'name': 'Tesco Bradford Central',
        'postcode': 'BD1 1AA',
        'latitude': 53.7952,
        'longitude': -1.7594,
        'distance_miles': 1.2,
      },
      {
        'name': 'Aldi Bradford South',
        'postcode': 'BD5 0SJ',
        'latitude': 53.7838,
        'longitude': -1.7445,
        'distance_miles': 2.4,
      },
      {
        'name': 'Asda Keighley Road',
        'postcode': 'BD9 4JU',
        'latitude': 53.8099,
        'longitude': -1.7898,
        'distance_miles': 2.8,
      },
      {
        'name': 'Morrisons Thornbury',
        'postcode': 'BD3 7DL',
        'latitude': 53.7935,
        'longitude': -1.7167,
        'distance_miles': 2.1,
      },
      {
        'name': 'Sainsbury Local Manningham',
        'postcode': 'BD8 7HJ',
        'latitude': 53.8051,
        'longitude': -1.7679,
        'distance_miles': 1.9,
      },
      {
        'name': 'Lidl Leeds Road',
        'postcode': 'BD3 9QX',
        'latitude': 53.7969,
        'longitude': -1.7308,
        'distance_miles': 2.7,
      },
      {
        'name': 'Co-op Great Horton',
        'postcode': 'BD7 4EY',
        'latitude': 53.7847,
        'longitude': -1.7802,
        'distance_miles': 1.5,
      },
      {
        'name': 'Iceland Forster Square',
        'postcode': 'BD1 4HU',
        'latitude': 53.7963,
        'longitude': -1.7519,
        'distance_miles': 1.0,
      },
    ];
  }

  List<Map<String, Object?>> _buildMockProducts() {
    final List<Map<String, String>> items = <Map<String, String>>[
      {'name': 'Semi Skimmed Milk 2L', 'normalized_name': 'milk', 'category': 'Dairy'},
      {'name': 'Whole Milk 2L', 'normalized_name': 'milk', 'category': 'Dairy'},
      {'name': 'Medium White Bread', 'normalized_name': 'bread', 'category': 'Bakery'},
      {'name': 'Wholemeal Bread', 'normalized_name': 'bread', 'category': 'Bakery'},
      {'name': 'Free Range Eggs 6 Pack', 'normalized_name': 'eggs', 'category': 'Dairy'},
      {'name': 'Long Grain Rice 1kg', 'normalized_name': 'rice', 'category': 'Cupboard'},
      {'name': 'Basmati Rice 1kg', 'normalized_name': 'rice', 'category': 'Cupboard'},
      {'name': 'Penne Pasta 500g', 'normalized_name': 'pasta', 'category': 'Cupboard'},
      {'name': 'Spaghetti Pasta 500g', 'normalized_name': 'pasta', 'category': 'Cupboard'},
      {'name': 'Chicken Breast Fillets 500g', 'normalized_name': 'chicken breast', 'category': 'Meat'},
      {'name': 'Chicken Breast Mini Fillets 400g', 'normalized_name': 'chicken breast', 'category': 'Meat'},
      {'name': 'Bananas 5 Pack', 'normalized_name': 'bananas', 'category': 'Fruit'},
      {'name': 'Salted Butter 250g', 'normalized_name': 'butter', 'category': 'Dairy'},
      {'name': 'Unsalted Butter 250g', 'normalized_name': 'butter', 'category': 'Dairy'},
      {'name': 'Greek Yogurt 500g', 'normalized_name': 'yogurt', 'category': 'Dairy'},
      {'name': 'Strawberry Yogurt 4 Pack', 'normalized_name': 'yogurt', 'category': 'Dairy'},
      {'name': 'Cheddar Cheese 400g', 'normalized_name': 'cheese', 'category': 'Dairy'},
      {'name': 'Mild Cheddar Cheese 250g', 'normalized_name': 'cheese', 'category': 'Dairy'},
      {'name': 'Tomatoes 6 Pack', 'normalized_name': 'tomatoes', 'category': 'Vegetables'},
      {'name': 'Cherry Tomatoes 250g', 'normalized_name': 'tomatoes', 'category': 'Vegetables'},
      {'name': 'Onions 1kg', 'normalized_name': 'onions', 'category': 'Vegetables'},
      {'name': 'Red Onions 500g', 'normalized_name': 'onions', 'category': 'Vegetables'},
      {'name': 'Potatoes 2kg', 'normalized_name': 'potatoes', 'category': 'Vegetables'},
      {'name': 'Baby Potatoes 750g', 'normalized_name': 'potatoes', 'category': 'Vegetables'},
      {'name': 'Carrots 1kg', 'normalized_name': 'carrots', 'category': 'Vegetables'},
      {'name': 'Cucumber', 'normalized_name': 'cucumber', 'category': 'Vegetables'},
      {'name': 'Lettuce Iceberg', 'normalized_name': 'lettuce', 'category': 'Vegetables'},
      {'name': 'Apples 6 Pack', 'normalized_name': 'apples', 'category': 'Fruit'},
      {'name': 'Oranges 6 Pack', 'normalized_name': 'oranges', 'category': 'Fruit'},
      {'name': 'Porridge Oats 1kg', 'normalized_name': 'oats', 'category': 'Breakfast'},
      {'name': 'Corn Flakes 500g', 'normalized_name': 'cereal', 'category': 'Breakfast'},
      {'name': 'Baked Beans 4 Pack', 'normalized_name': 'beans', 'category': 'Cupboard'},
      {'name': 'Chopped Tomatoes 4 Pack', 'normalized_name': 'tinned tomatoes', 'category': 'Cupboard'},
      {'name': 'Tuna Chunks 4 Pack', 'normalized_name': 'tuna', 'category': 'Cupboard'},
      {'name': 'Frozen Peas 900g', 'normalized_name': 'peas', 'category': 'Frozen'},
      {'name': 'Frozen Mixed Vegetables 1kg', 'normalized_name': 'mixed vegetables', 'category': 'Frozen'},
      {'name': 'Orange Juice 1L', 'normalized_name': 'orange juice', 'category': 'Drinks'},
      {'name': 'Apple Juice 1L', 'normalized_name': 'apple juice', 'category': 'Drinks'},
      {'name': 'Olive Oil 500ml', 'normalized_name': 'olive oil', 'category': 'Cupboard'},
      {'name': 'Sunflower Oil 1L', 'normalized_name': 'oil', 'category': 'Cupboard'},
      {'name': 'Plain Flour 1.5kg', 'normalized_name': 'flour', 'category': 'Baking'},
      {'name': 'Granulated Sugar 1kg', 'normalized_name': 'sugar', 'category': 'Baking'},
      {'name': 'Tea Bags 80 Pack', 'normalized_name': 'tea', 'category': 'Drinks'},
      {'name': 'Instant Coffee 200g', 'normalized_name': 'coffee', 'category': 'Drinks'},
      {'name': 'Tomato Ketchup 560g', 'normalized_name': 'ketchup', 'category': 'Condiments'},
      {'name': 'Mayonnaise 400g', 'normalized_name': 'mayonnaise', 'category': 'Condiments'},
      {'name': 'Jam Strawberry 340g', 'normalized_name': 'jam', 'category': 'Breakfast'},
      {'name': 'Peanut Butter 340g', 'normalized_name': 'peanut butter', 'category': 'Breakfast'},
    ];

    return items
        .map(
          (Map<String, String> item) => <String, Object?>{
            'name': item['name'],
            'normalized_name': item['normalized_name'],
            'category': item['category'],
          },
        )
        .toList();
  }

  List<Map<String, Object?>> _buildMockPriceEntries({
    required List<Map<String, Object?>> stores,
    required List<Map<String, Object?>> products,
  }) {
    final List<Map<String, Object?>> entries = <Map<String, Object?>>[];
    final DateTime now = DateTime.now();

    for (int storeIndex = 0; storeIndex < stores.length; storeIndex++) {
      final int storeId = (stores[storeIndex]['id'] as int?) ?? 0;

      for (int productIndex = 0; productIndex < products.length; productIndex++) {
        final int productId = (products[productIndex]['id'] as int?) ?? 0;

        if (_shouldSkipProductForStore(storeIndex, productIndex)) {
          continue;
        }

        final double price = _generatePrice(storeIndex, productIndex);
        final bool isVerified = (storeIndex + productIndex).isEven;
        final double? loyaltyPrice = productIndex % 5 == 0
            ? double.parse(math.max(price - 0.15, 0.5).toStringAsFixed(2))
            : null;

        entries.add(<String, Object?>{
          'store_id': storeId,
          'product_id': productId,
          'price': price,
          'loyalty_price': loyaltyPrice,
          'reported_at': now
              .subtract(Duration(days: (storeIndex + productIndex) % 7))
              .toIso8601String(),
          'is_verified': isVerified ? 1 : 0,
          'source': 'mock_seed',
        });
      }
    }

    return entries;
  }

  bool _shouldSkipProductForStore(int storeIndex, int productIndex) {
    return (storeIndex + productIndex) % 6 == 0 ||
        (storeIndex.isOdd && productIndex % 11 == 0);
  }

  double _generatePrice(int storeIndex, int productIndex) {
    final double basePrice = 0.85 + (productIndex % 9) * 0.42;
    final double storeAdjustment = storeIndex * 0.08;
    final double variance = ((productIndex + 3) * (storeIndex + 2)) % 5 * 0.07;
    final double price = basePrice + storeAdjustment + variance;

    return double.parse(
      math.max(price, 0.65).toStringAsFixed(2),
    );
  }

  Future<int> _resolveStoreId({
    required Transaction txn,
    String? storeName,
    String? postcode,
    double? latitude,
    double? longitude,
  }) async {
    final String cleanedPostcode = (postcode ?? '').trim().toUpperCase();
    final bool hasPostcode = cleanedPostcode.isNotEmpty;
    final bool hasLatitude = latitude != null;
    final bool hasLongitude = longitude != null;

    if (storeName != null && storeName.trim().isNotEmpty) {
      final List<Map<String, Object?>> matches = await txn.query(
        'stores',
        where: 'LOWER(name) = ?',
        whereArgs: <Object?>[storeName.trim().toLowerCase()],
        limit: 1,
      );

      if (matches.isNotEmpty) {
        final Map<String, Object?> existingStore = matches.first;
        final int storeId = ((existingStore['id'] as num?) ?? 0).toInt();
        final String existingPostcode =
            ((existingStore['postcode'] as String?) ?? '').trim().toUpperCase();
        final bool shouldUpdatePostcode =
            hasPostcode && (existingPostcode.isEmpty || existingPostcode == 'UNKNOWN');
        final bool shouldUpdateLatitude =
            hasLatitude && existingStore['latitude'] == null;
        final bool shouldUpdateLongitude =
            hasLongitude && existingStore['longitude'] == null;

        if (shouldUpdatePostcode || shouldUpdateLatitude || shouldUpdateLongitude) {
          await txn.update(
            'stores',
            <String, Object?>{
              if (shouldUpdatePostcode) 'postcode': cleanedPostcode,
              if (shouldUpdateLatitude) 'latitude': latitude,
              if (shouldUpdateLongitude) 'longitude': longitude,
            },
            where: 'id = ?',
            whereArgs: <Object?>[storeId],
          );
        }

        return storeId;
      }

      return txn.insert('stores', <String, Object?>{
        'name': storeName.trim(),
        'postcode': hasPostcode ? cleanedPostcode : 'UNKNOWN',
        'latitude': latitude,
        'longitude': longitude,
        'distance_miles': null,
      });
    }

    final List<Map<String, Object?>> fallbackStore = await txn.query(
      'stores',
      where: 'name = ?',
      whereArgs: <Object?>['Receipt Upload Store'],
      limit: 1,
    );

    if (fallbackStore.isNotEmpty) {
      final Map<String, Object?> existingStore = fallbackStore.first;
      final int storeId = ((existingStore['id'] as num?) ?? 0).toInt();
      final String existingPostcode =
          ((existingStore['postcode'] as String?) ?? '').trim().toUpperCase();
      final bool shouldUpdatePostcode =
          hasPostcode && (existingPostcode.isEmpty || existingPostcode == 'UNKNOWN');
      final bool shouldUpdateLatitude =
          hasLatitude && existingStore['latitude'] == null;
      final bool shouldUpdateLongitude =
          hasLongitude && existingStore['longitude'] == null;

      if (shouldUpdatePostcode || shouldUpdateLatitude || shouldUpdateLongitude) {
        await txn.update(
          'stores',
          <String, Object?>{
            if (shouldUpdatePostcode) 'postcode': cleanedPostcode,
            if (shouldUpdateLatitude) 'latitude': latitude,
            if (shouldUpdateLongitude) 'longitude': longitude,
          },
          where: 'id = ?',
          whereArgs: <Object?>[storeId],
        );
      }

      return storeId;
    }

    return txn.insert('stores', <String, Object?>{
      'name': 'Receipt Upload Store',
      'postcode': hasPostcode ? cleanedPostcode : 'UNKNOWN',
      'latitude': latitude,
      'longitude': longitude,
      'distance_miles': null,
    });
  }

  Future<int> _resolveProductId({
    required Transaction txn,
    required String productName,
    required String normalizedName,
  }) async {
    final List<Map<String, Object?>> existingProducts = await txn.query(
      'products',
      where: 'normalized_name = ?',
      whereArgs: <Object?>[normalizedName],
      limit: 1,
    );

    if (existingProducts.isNotEmpty) {
      return ((existingProducts.first['id'] as num?) ?? 0).toInt();
    }

    return txn.insert('products', <String, Object?>{
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

    for (final MapEntry<String, String> store in knownStores.entries) {
      if (normalizedText.contains(store.key)) {
        return store.value;
      }
    }

    return 'Receipt Upload Store';
  }

  static const String _createStoresTable = '''
    CREATE TABLE stores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      postcode TEXT NOT NULL,
      latitude REAL,
      longitude REAL,
      distance_miles REAL
    )
  ''';

  static const String _createProductsTable = '''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      normalized_name TEXT NOT NULL,
      category TEXT
    )
  ''';

  static const String _createPriceEntriesTable = '''
    CREATE TABLE price_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      price REAL NOT NULL,
      loyalty_price REAL,
      reported_at TEXT,
      is_verified INTEGER NOT NULL DEFAULT 0,
      source TEXT,
      FOREIGN KEY (store_id) REFERENCES stores(id),
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''';

  static const String _createUserRequestsTable = '''
    CREATE TABLE user_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      postcode TEXT,
      user_latitude REAL,
      user_longitude REAL,
      budget REAL NOT NULL,
      shopping_list_raw TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''';

  static const String _createBasketResultsTable = '''
    CREATE TABLE basket_results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_request_id INTEGER NOT NULL,
      store_id INTEGER NOT NULL,
      total_price REAL NOT NULL,
      savings_amount REAL,
      is_within_budget INTEGER NOT NULL DEFAULT 0,
      missing_items_count INTEGER NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_request_id) REFERENCES user_requests(id),
      FOREIGN KEY (store_id) REFERENCES stores(id)
    )
  ''';

  static const String _createBasketItemsTable = '''
    CREATE TABLE basket_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      basket_result_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      normalized_product_name TEXT,
      price REAL,
      is_missing INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (basket_result_id) REFERENCES basket_results(id)
    )
  ''';

  static const String _createSavedStoresTable = '''
    CREATE TABLE saved_stores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_key TEXT NOT NULL,
      store_name TEXT NOT NULL,
      store_postcode TEXT,
      basket_total REAL NOT NULL,
      saved_at TEXT NOT NULL
    )
  ''';

  static const String _createSavedStoreItemsTable = '''
    CREATE TABLE saved_store_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      saved_store_id INTEGER NOT NULL,
      item_name TEXT NOT NULL,
      price REAL NOT NULL,
      FOREIGN KEY (saved_store_id) REFERENCES saved_stores(id)
    )
  ''';

  static const String _createUploadedReceiptsTable = '''
    CREATE TABLE uploaded_receipts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_key TEXT NOT NULL,
      store_name TEXT NOT NULL,
      image_path TEXT,
      uploaded_at TEXT NOT NULL
    )
  ''';

  static const String _createUploadedReceiptItemsTable = '''
    CREATE TABLE uploaded_receipt_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receipt_id INTEGER NOT NULL,
      item_name TEXT NOT NULL,
      normalized_name TEXT NOT NULL,
      price REAL,
      FOREIGN KEY (receipt_id) REFERENCES uploaded_receipts(id)
    )
  ''';
}

class ReceiptSaveResult {
  const ReceiptSaveResult({
    required this.receiptId,
    required this.insertedRows,
  });

  final int receiptId;
  final int insertedRows;
}

class DeleteFavouriteItemResult {
  const DeleteFavouriteItemResult({
    required this.deletedItem,
    required this.deletedStore,
  });

  final bool deletedItem;
  final bool deletedStore;
}
