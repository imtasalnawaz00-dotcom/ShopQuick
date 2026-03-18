import 'ParsedReceiptItemModel.dart';

class ParsedReceiptModel {
  const ParsedReceiptModel({
    required this.storeName,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.rawText,
  });

  final String? storeName;
  final List<ParsedReceiptItemModel> items;
  final double? subtotal;
  final double? tax;
  final double? total;
  final String rawText;
}
