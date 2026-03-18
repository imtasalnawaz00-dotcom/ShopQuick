class UploadedReceiptItemModel {
  const UploadedReceiptItemModel({
    required this.id,
    required this.receiptId,
    required this.itemName,
    required this.normalizedName,
    this.price,
  });

  final int id;
  final int receiptId;
  final String itemName;
  final String normalizedName;
  final double? price;

  factory UploadedReceiptItemModel.fromMap(Map<String, Object?> map) {
    return UploadedReceiptItemModel(
      id: ((map['id'] as num?) ?? 0).toInt(),
      receiptId: ((map['receipt_id'] as num?) ?? 0).toInt(),
      itemName: (map['item_name'] as String?) ?? '',
      normalizedName: (map['normalized_name'] as String?) ?? '',
      price: (map['price'] as num?)?.toDouble(),
    );
  }
}
