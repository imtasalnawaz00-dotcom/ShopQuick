class SavedStoreItemModel {
  const SavedStoreItemModel({
    required this.id,
    required this.savedStoreId,
    required this.itemName,
    required this.price,
  });

  factory SavedStoreItemModel.fromMap(Map<String, Object?> map) {
    return SavedStoreItemModel(
      id: ((map['id'] as num?) ?? 0).toInt(),
      savedStoreId: ((map['saved_store_id'] as num?) ?? 0).toInt(),
      itemName: (map['item_name'] as String? ?? '').trim(),
      price: ((map['price'] as num?) ?? 0).toDouble(),
    );
  }

  final int id;
  final int savedStoreId;
  final String itemName;
  final double price;
}
