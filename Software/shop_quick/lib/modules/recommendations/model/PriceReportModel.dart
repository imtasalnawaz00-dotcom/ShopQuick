class PriceReportModel {
  const PriceReportModel({
    required this.storeId,
    required this.storeName,
    required this.postcode,
    required this.productName,
    required this.normalizedProductName,
    required this.price,
    required this.reportedAt,
    required this.isVerified,
    this.loyaltyPrice,
  });

  final String storeId;
  final String storeName;
  final String postcode;
  final String productName;
  final String normalizedProductName;
  final double price;
  final DateTime? reportedAt;
  final bool isVerified;
  final double? loyaltyPrice;

  factory PriceReportModel.fromMap(Map<String, dynamic> map) {
    return PriceReportModel(
      storeId: map['storeId'] as String? ?? '',
      storeName: map['storeName'] as String? ?? '',
      postcode: map['postcode'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      normalizedProductName: map['normalizedProductName'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      reportedAt: map['reportedAt'] as DateTime?,
      isVerified: map['isVerified'] as bool? ?? false,
      loyaltyPrice: (map['loyaltyPrice'] as num?)?.toDouble(),
    );
  }
}
