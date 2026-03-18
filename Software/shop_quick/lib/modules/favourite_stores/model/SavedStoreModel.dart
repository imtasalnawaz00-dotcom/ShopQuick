import 'SavedStoreItemModel.dart';

class SavedStoreModel {
  const SavedStoreModel({
    required this.id,
    required this.userKey,
    required this.storeName,
    required this.storePostcode,
    required this.basketTotal,
    required this.savedAt,
    required this.items,
  });

  factory SavedStoreModel.fromMap(
    Map<String, Object?> map, {
    List<SavedStoreItemModel> items = const <SavedStoreItemModel>[],
  }) {
    return SavedStoreModel(
      id: ((map['id'] as num?) ?? 0).toInt(),
      userKey: (map['user_key'] as String? ?? '').trim(),
      storeName: (map['store_name'] as String? ?? '').trim(),
      storePostcode: (map['store_postcode'] as String? ?? '').trim(),
      basketTotal: ((map['basket_total'] as num?) ?? 0).toDouble(),
      savedAt: DateTime.tryParse((map['saved_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      items: items,
    );
  }

  final int id;
  final String userKey;
  final String storeName;
  final String storePostcode;
  final double basketTotal;
  final DateTime savedAt;
  final List<SavedStoreItemModel> items;
}
