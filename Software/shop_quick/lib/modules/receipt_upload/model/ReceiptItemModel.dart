class ReceiptItemModel {
  const ReceiptItemModel({
    required this.itemName,
    this.price,
  });

  final String itemName;
  final double? price;
}
