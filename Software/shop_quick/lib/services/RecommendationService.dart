import '../modules/recommendations/model/RecommendationResultModel.dart';
import '../modules/recommendations/model/StoreTotalModel.dart';
import 'DatabaseService.dart';
import 'StoreLocationService.dart';

class RecommendationService {
  const RecommendationService();

  static final DatabaseService _databaseService = DatabaseService.instance;
  static const StoreLocationService _storeLocationService =
      StoreLocationService();
  // Completeness stays dominant so partial baskets do not beat fuller baskets.
  // Price still matters, but distance now has enough weight to influence the
  // final rank instead of acting only as a candidate filter.
  static const double _completenessWeight = 0.55;
  static const double _priceWeight = 0.15;
  static const double _distanceWeight = 0.20;
  static const double _budgetWeight = 0.10;

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

    final List<String> normalizedItems = _parseShoppingItems(shoppingItems);

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

    List<StoreTotalModel> rankedStores = await _buildRankedStores(
      candidateStores: candidateStores,
      normalizedItems: normalizedItems,
      onlyVerified: onlyVerified,
      allowedSources: allowedSources,
    );

    // Fall back to postcode matches if nearby stores exist but none match the basket.
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

      rankedStores = await _buildRankedStores(
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

    final List<StoreTotalModel> sortedStores = _applyRecommendationScores(
      rankedStores: rankedStores,
      budget: budget,
      requestedItemCount: normalizedItems.length,
    )..sort((StoreTotalModel a, StoreTotalModel b) {
        final int scoreComparison =
            b.recommendationScore.compareTo(a.recommendationScore);
        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final int matchCountComparison =
            b.matchedItems.length.compareTo(a.matchedItems.length);
        if (matchCountComparison != 0) {
          return matchCountComparison;
        }

        final int totalComparison = a.totalPrice.compareTo(b.totalPrice);
        if (totalComparison != 0) {
          return totalComparison;
        }

        final int distanceComparison = (a.distanceMiles ?? double.infinity)
            .compareTo(b.distanceMiles ?? double.infinity);
        if (distanceComparison != 0) {
          return distanceComparison;
        }

        return a.storeName.compareTo(b.storeName);
      });

    final StoreTotalModel cheapestStore = sortedStores.first;
    final StoreTotalModel? secondBestStore = sortedStores.length > 1
        ? sortedStores[1]
        : null;
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

  Future<List<StoreTotalModel>> _buildRankedStores({
    required List<NearbyStoreModel> candidateStores,
    required List<String> normalizedItems,
    required bool onlyVerified,
    required List<String>? allowedSources,
  }) async {
    if (candidateStores.isEmpty || normalizedItems.isEmpty) {
      return <StoreTotalModel>[];
    }

    final database = await _databaseService.database;
    final List<int> storeIds = candidateStores
        .map((NearbyStoreModel store) => store.id)
        .toList();
    final String placeholders = List<String>.filled(storeIds.length, '?').join(',');
    final List<Object?> queryArguments = <Object?>[...storeIds];
    final StringBuffer whereClause = StringBuffer(
      'WHERE pe.store_id IN ($placeholders)',
    );

    if (onlyVerified) {
      whereClause.write(' AND pe.is_verified = 1');
    }

    if (allowedSources != null && allowedSources.isNotEmpty) {
      final String sourcePlaceholders = List<String>.filled(
        allowedSources.length,
        '?',
      ).join(',');
      whereClause.write(' AND pe.source IN ($sourcePlaceholders)');
      queryArguments.addAll(allowedSources);
    }

    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT
        pe.store_id,
        pe.price,
        pe.loyalty_price,
        pe.is_verified,
        pe.source,
        p.name AS product_name,
        p.normalized_name
      FROM price_entries pe
      INNER JOIN products p ON p.id = pe.product_id
      ${whereClause.toString()}
      ''',
      queryArguments,
    );

    final Map<int, List<Map<String, Object?>>> entriesByStore =
        <int, List<Map<String, Object?>>>{};

    for (final Map<String, Object?> row in rows) {
      final int storeId = ((row['store_id'] as num?) ?? 0).toInt();
      entriesByStore.putIfAbsent(storeId, () => <Map<String, Object?>>[]);
      entriesByStore[storeId]!.add(row);
    }

    final List<StoreTotalModel> rankedStores = <StoreTotalModel>[];

    for (final NearbyStoreModel store in candidateStores) {
      final List<Map<String, Object?>> storeEntries =
          entriesByStore[store.id] ?? <Map<String, Object?>>[];

      if (storeEntries.isEmpty) {
        continue;
      }

      final List<String> matchedItems = <String>[];
      final List<MatchedItemModel> matchedItemDetails = <MatchedItemModel>[];
      final List<String> missingItems = <String>[];
      double totalPrice = 0;

      for (final String item in normalizedItems) {
        final Map<String, Object?>? cheapestEntry = _findCheapestEntryForItem(
          normalizedItem: item,
          storeEntries: storeEntries,
        );

        if (cheapestEntry == null) {
          missingItems.add(item);
          continue;
        }

        matchedItems.add(item);
        final double matchedPrice = _resolveEntryPrice(cheapestEntry);
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

  List<String> _parseShoppingItems(List<String> shoppingItems) {
    return shoppingItems
        .expand((String value) => value.split(','))
        .map(_normalizeText)
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Map<String, Object?>? _findCheapestEntryForItem({
    required String normalizedItem,
    required List<Map<String, Object?>> storeEntries,
  }) {
    Map<String, Object?>? cheapestEntry;

    for (final Map<String, Object?> entry in storeEntries) {
      final String normalizedProductName = _normalizeText(
        (entry['product_name'] as String?) ?? '',
      );
      final String normalizedKey = _normalizeText(
        (entry['normalized_name'] as String?) ?? '',
      );

      if (!_isItemMatch(
        normalizedItem: normalizedItem,
        normalizedProductName: normalizedProductName,
        normalizedKey: normalizedKey,
      )) {
        continue;
      }

      if (cheapestEntry == null ||
          _resolveEntryPrice(entry) < _resolveEntryPrice(cheapestEntry)) {
        cheapestEntry = entry;
      }
    }

    return cheapestEntry;
  }

  bool _isItemMatch({
    required String normalizedItem,
    required String normalizedProductName,
    required String normalizedKey,
  }) {
    return normalizedProductName.contains(normalizedItem) ||
        normalizedItem.contains(normalizedProductName) ||
        normalizedKey.contains(normalizedItem);
  }

  double _resolveEntryPrice(Map<String, Object?> entry) {
    final num? loyaltyPrice = entry['loyalty_price'] as num?;
    final num? standardPrice = entry['price'] as num?;
    return (loyaltyPrice ?? standardPrice ?? 0).toDouble();
  }

  List<StoreTotalModel> _applyRecommendationScores({
    required List<StoreTotalModel> rankedStores,
    required double budget,
    required int requestedItemCount,
  }) {
    if (rankedStores.isEmpty || requestedItemCount == 0) {
      return rankedStores;
    }

    final double minTotalPrice = rankedStores
        .map((StoreTotalModel store) => store.totalPrice)
        .reduce((double a, double b) => a < b ? a : b);
    final double maxTotalPrice = rankedStores
        .map((StoreTotalModel store) => store.totalPrice)
        .reduce((double a, double b) => a > b ? a : b);
    final List<double> knownDistances = rankedStores
        .map((StoreTotalModel store) => store.distanceMiles)
        .whereType<double>()
        .toList();
    final double minDistance = knownDistances.isEmpty
        ? 0
        : knownDistances.reduce((double a, double b) => a < b ? a : b);
    final double maxDistance = knownDistances.isEmpty
        ? 0
        : knownDistances.reduce((double a, double b) => a > b ? a : b);

    return rankedStores.map((StoreTotalModel store) {
      final double completenessRatio =
          store.matchedItems.length / requestedItemCount;
      final bool isCompleteBasket =
          store.matchedItems.length == requestedItemCount;
      final double completenessScore =
          double.parse((completenessRatio * 100).toStringAsFixed(2));
      final double priceScore = double.parse(
        _calculateLowerIsBetterScore(
          value: store.totalPrice,
          minValue: minTotalPrice,
          maxValue: maxTotalPrice,
        ).toStringAsFixed(2),
      );
      final double distanceScore = double.parse(
        _calculateDistanceScore(
          distanceMiles: store.distanceMiles,
          minDistance: minDistance,
          maxDistance: maxDistance,
        ).toStringAsFixed(2),
      );
      final double budgetScore = double.parse(
        _calculateBudgetScore(
          totalPrice: store.totalPrice,
          budget: budget,
        ).toStringAsFixed(2),
      );
      final double recommendationScore = double.parse(
        ((_completenessWeight * completenessScore) +
                (_priceWeight * priceScore) +
                (_distanceWeight * distanceScore) +
                (_budgetWeight * budgetScore))
            .toStringAsFixed(2),
      );

      return store.copyWith(
        recommendationScore: recommendationScore,
        completenessScore: completenessScore,
        priceScore: priceScore,
        distanceScore: distanceScore,
        budgetScore: budgetScore,
        recommendationReason: _buildRecommendationReason(
          store: store,
          isCompleteBasket: isCompleteBasket,
          budget: budget,
          priceScore: priceScore,
          distanceScore: distanceScore,
        ),
      );
    }).toList();
  }

  double _calculateLowerIsBetterScore({
    required double value,
    required double minValue,
    required double maxValue,
  }) {
    if (maxValue <= minValue) {
      return 100;
    }

    final double normalized = 1 - ((value - minValue) / (maxValue - minValue));
    return normalized.clamp(0.0, 1.0) * 100;
  }

  double _calculateDistanceScore({
    required double? distanceMiles,
    required double minDistance,
    required double maxDistance,
  }) {
    if (distanceMiles == null) {
      return 35;
    }

    return _calculateLowerIsBetterScore(
      value: distanceMiles,
      minValue: minDistance,
      maxValue: maxDistance,
    );
  }

  double _calculateBudgetScore({
    required double totalPrice,
    required double budget,
  }) {
    if (budget <= 0) {
      return 50;
    }

    if (totalPrice <= budget) {
      final double headroomRatio =
          ((budget - totalPrice) / budget).clamp(0.0, 1.0);
      return 70 + (headroomRatio * 30);
    }

    final double overBudgetRatio =
        ((totalPrice - budget) / budget).clamp(0.0, 1.0);
    return (40 - (overBudgetRatio * 40)).clamp(0.0, 40.0);
  }

  String _buildRecommendationReason({
    required StoreTotalModel store,
    required bool isCompleteBasket,
    required double budget,
    required double priceScore,
    required double distanceScore,
  }) {
    final List<String> reasons = <String>[];

    if (isCompleteBasket) {
      reasons.add('offers a complete basket');
    } else {
      reasons.add(
        'matches ${store.matchedItems.length} of ${store.missingItems.length + store.matchedItems.length} items',
      );
    }

    if (priceScore >= 70) {
      reasons.add('keeps the basket price competitive');
    }

    if (store.distanceMiles != null && distanceScore >= 70) {
      reasons.add('is relatively close');
    }

    if (budget > 0) {
      reasons.add(
        store.totalPrice <= budget ? 'fits within budget' : 'is over budget',
      );
    }

    return 'Recommended because it ${reasons.join(', ')}.';
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}
