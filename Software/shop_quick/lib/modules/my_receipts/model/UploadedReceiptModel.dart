class UploadedReceiptModel {
  const UploadedReceiptModel({
    required this.id,
    required this.userKey,
    required this.storeName,
    this.imagePath,
    required this.uploadedAt,
  });

  final int id;
  final String userKey;
  final String storeName;
  final String? imagePath;
  final DateTime uploadedAt;

  factory UploadedReceiptModel.fromMap(Map<String, Object?> map) {
    return UploadedReceiptModel(
      id: ((map['id'] as num?) ?? 0).toInt(),
      userKey: (map['user_key'] as String?) ?? '',
      storeName: (map['store_name'] as String?) ?? '',
      imagePath: map['image_path'] as String?,
      uploadedAt:
          DateTime.tryParse((map['uploaded_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
