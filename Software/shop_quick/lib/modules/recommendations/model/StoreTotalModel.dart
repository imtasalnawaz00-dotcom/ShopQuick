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
    this.recommendationScore = 0,
    this.completenessScore = 0,
    this.priceScore = 0,
    this.distanceScore = 0,
    this.budgetScore = 0,
    this.recommendationReason = '',
  });

  final String storeId;
  final String storeName;
  final String postcode;
  final double? distanceMiles;
  final double totalPrice;
  final List<String> matchedItems;
  final List<MatchedItemModel> matchedItemDetails;
  final List<String> missingItems;
  final double recommendationScore;
  final double completenessScore;
  final double priceScore;
  final double distanceScore;
  final double budgetScore;
  final String recommendationReason;

  StoreTotalModel copyWith({
    String? storeId,
    String? storeName,
    String? postcode,
    double? distanceMiles,
    double? totalPrice,
    List<String>? matchedItems,
    List<MatchedItemModel>? matchedItemDetails,
    List<String>? missingItems,
    double? recommendationScore,
    double? completenessScore,
    double? priceScore,
    double? distanceScore,
    double? budgetScore,
    String? recommendationReason,
  }) {
    return StoreTotalModel(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      postcode: postcode ?? this.postcode,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      totalPrice: totalPrice ?? this.totalPrice,
      matchedItems: matchedItems ?? this.matchedItems,
      matchedItemDetails: matchedItemDetails ?? this.matchedItemDetails,
      missingItems: missingItems ?? this.missingItems,
      recommendationScore: recommendationScore ?? this.recommendationScore,
      completenessScore: completenessScore ?? this.completenessScore,
      priceScore: priceScore ?? this.priceScore,
      distanceScore: distanceScore ?? this.distanceScore,
      budgetScore: budgetScore ?? this.budgetScore,
      recommendationReason: recommendationReason ?? this.recommendationReason,
    );
  }
}
