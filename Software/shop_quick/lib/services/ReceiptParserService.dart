import '../modules/receipt_upload/model/ParsedReceiptItemModel.dart';
import '../modules/receipt_upload/model/ParsedReceiptModel.dart';

class ReceiptParserService {
  const ReceiptParserService();

  ParsedReceiptModel parse(String rawText) {
    final List<String> cleanedLines = _cleanLines(rawText);
    final String normalizedRawText = cleanedLines.join('\n');
    final String? storeName = _extractStoreName(cleanedLines);
    final double? subtotal = _extractLabeledAmount(
      cleanedLines,
      keywords: const <String>['SUBTOTAL'],
    );
    final double? tax = _extractLabeledAmount(
      cleanedLines,
      keywords: const <String>['TAX', 'VAT', 'SALES TAX'],
    );
    final double? total = _extractLabeledAmount(
      cleanedLines,
      keywords: const <String>['TOTAL', 'AMOUNT DUE', 'GRAND TOTAL'],
      allowSubtotal: false,
    );
    final List<ParsedReceiptItemModel> items = _extractItems(
      cleanedLines,
      storeName: storeName,
    );

    return ParsedReceiptModel(
      storeName: storeName,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      rawText: normalizedRawText,
    );
  }

  List<String> _cleanLines(String rawText) {
    return rawText
        .replaceAll('£', '')
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ')
        .split('\n')
        .map((String line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((String line) => line.isNotEmpty)
        .toList();
  }

  String? _extractStoreName(List<String> lines) {
    final List<String> headerLines = lines.take(6).toList();

    for (final String line in headerLines) {
      final String normalized = line.toUpperCase();

      if (_isMetadataLine(normalized) || _looksAddressLike(normalized)) {
        continue;
      }

      final String lettersOnly = normalized.replaceAll(RegExp(r'[^A-Z ]'), '');
      final int letterCount = lettersOnly.replaceAll(' ', '').length;
      final int digitCount = normalized.replaceAll(RegExp(r'[^0-9]'), '').length;

      if (letterCount < 3 || digitCount > letterCount) {
        continue;
      }

      if (_isTotalsLine(normalized) || normalized.startsWith('ITEM ')) {
        continue;
      }

      return line;
    }

    return null;
  }

  List<ParsedReceiptItemModel> _extractItems(
    List<String> lines, {
    String? storeName,
  }) {
    final List<ParsedReceiptItemModel> parsedItems = <ParsedReceiptItemModel>[];
    final List<String> pendingItemLines = <String>[];
    final List<double> pendingPrices = <double>[];
    final RegExp trailingPricePattern = RegExp(r'^(.+?)\s+(\d+[.,]\d{2})$');
    final RegExp priceOnlyPattern = RegExp(r'^\d+[.,]\d{2}$');

    for (final String line in lines) {
      final String normalized = line.toUpperCase();

      if (storeName != null && normalized == storeName.toUpperCase()) {
        continue;
      }

      if (_isMetadataLine(normalized) || _isTotalsLine(normalized)) {
        continue;
      }

      final RegExpMatch? inlineMatch = trailingPricePattern.firstMatch(line);
      if (inlineMatch != null) {
        final String itemName = inlineMatch.group(1)!.trim();
        final double? price = _parsePrice(inlineMatch.group(2));

        if (price != null && _isLikelyItemLine(itemName)) {
          parsedItems.add(
            ParsedReceiptItemModel(
              itemName: itemName,
              price: price,
            ),
          );
        }
        continue;
      }

      if (priceOnlyPattern.hasMatch(line)) {
        final double? price = _parsePrice(line);
        if (price != null) {
          pendingPrices.add(price);
        }
        continue;
      }

      if (_isLikelyItemLine(line)) {
        pendingItemLines.add(line);
      }
    }

    final int pairCount = pendingItemLines.length < pendingPrices.length
        ? pendingItemLines.length
        : pendingPrices.length;

    for (int index = 0; index < pairCount; index++) {
      parsedItems.add(
        ParsedReceiptItemModel(
          itemName: pendingItemLines[index],
          price: pendingPrices[index],
        ),
      );
    }

    return _deduplicateItems(parsedItems);
  }

  double? _extractLabeledAmount(
    List<String> lines, {
    required List<String> keywords,
    bool allowSubtotal = true,
  }) {
    double? detectedAmount;

    for (int index = 0; index < lines.length; index++) {
      final String normalized = lines[index].toUpperCase();

      if (!keywords.any(normalized.contains)) {
        continue;
      }

      if (!allowSubtotal && normalized.contains('SUBTOTAL')) {
        continue;
      }

      final double? sameLineAmount = _extractPriceFromLine(lines[index]);
      if (sameLineAmount != null) {
        detectedAmount = sameLineAmount;
        continue;
      }

      if (index + 1 < lines.length) {
        final double? nextLineAmount = _parsePrice(lines[index + 1]);
        if (nextLineAmount != null) {
          detectedAmount = nextLineAmount;
        }
      }
    }

    return detectedAmount;
  }

  double? _extractPriceFromLine(String line) {
    final RegExpMatch? match = RegExp(r'(\d+[.,]\d{2})').firstMatch(line);
    return _parsePrice(match?.group(1));
  }

  double? _parsePrice(String? value) {
    if (value == null) {
      return null;
    }

    return double.tryParse(value.replaceAll(',', '.').trim());
  }

  bool _isLikelyItemLine(String line) {
    final String normalized = line.trim().toUpperCase();

    if (normalized.length < 2 ||
        _isMetadataLine(normalized) ||
        _isTotalsLine(normalized) ||
        _looksAddressLike(normalized)) {
      return false;
    }

    if (RegExp(r'^\d+$').hasMatch(normalized) ||
        RegExp(r'^\d+[.,]\d{2}$').hasMatch(normalized)) {
      return false;
    }

    final int letters = normalized.replaceAll(RegExp(r'[^A-Z]'), '').length;
    return letters >= 2;
  }

  List<ParsedReceiptItemModel> _deduplicateItems(
    List<ParsedReceiptItemModel> items,
  ) {
    final Set<String> seenKeys = <String>{};
    final List<ParsedReceiptItemModel> uniqueItems = <ParsedReceiptItemModel>[];

    for (final ParsedReceiptItemModel item in items) {
      final String key =
          '${item.itemName.toUpperCase()}|${item.price.toStringAsFixed(2)}';

      if (seenKeys.add(key)) {
        uniqueItems.add(item);
      }
    }

    return uniqueItems;
  }

  bool _isMetadataLine(String line) {
    const List<String> metadataKeywords = <String>[
      'TEL',
      'PHONE',
      'DATE',
      'TIME',
      'RECEIPT',
      'CASHIER',
      'MANAGER',
      'AUTH',
      'CARD',
      'VISA',
      'MASTERCARD',
      'TRANSACTION',
      'WELCOME',
    ];

    return metadataKeywords.any(line.contains);
  }

  bool _isTotalsLine(String line) {
    const List<String> totalKeywords = <String>[
      'SUBTOTAL',
      'TOTAL',
      'TAX',
      'VAT',
      'CASH',
      'CHANGE',
      'BALANCE',
      'AMOUNT DUE',
    ];

    return totalKeywords.any(line.contains);
  }

  bool _looksAddressLike(String line) {
    final bool hasPostcodeLikePattern = RegExp(
      r'[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}',
    ).hasMatch(line);
    final int digitCount = line.replaceAll(RegExp(r'[^0-9]'), '').length;
    return hasPostcodeLikePattern || digitCount >= 4;
  }
}
