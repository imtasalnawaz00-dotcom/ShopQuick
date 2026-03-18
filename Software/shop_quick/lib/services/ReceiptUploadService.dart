import 'dart:io';

import '../modules/receipt_upload/model/ReceiptItemModel.dart';

class ReceiptUploadService {
  const ReceiptUploadService();

  Future<void> uploadReceiptData({
    required List<ReceiptItemModel> items,
    required String rawText,
    File? image,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
