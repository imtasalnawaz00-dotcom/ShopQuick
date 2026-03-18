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
