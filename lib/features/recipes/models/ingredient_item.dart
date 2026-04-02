part of 'models.dart';

class IngredientItem {
  final int? position;
  final String? quantityText;
  final double? quantityValue;
  final String? unit;
  final String ingredient;
  final String? note;
  final String? rawText;

  IngredientItem({
    this.position,
    this.quantityText,
    this.quantityValue,
    this.unit,
    required this.ingredient,
    this.note,
    this.rawText,
  });

  static List<IngredientItem> listFromDynamic(dynamic raw) {
    final list = _asMapList(raw);
    return list.map((m) {
      final keyMap = <String, dynamic>{};
      for (final entry in m.entries) {
        final normalized = entry.key.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
        keyMap[normalized] = entry.value;
      }

      String? pickText(List<String> keys) {
        for (final k in keys) {
          final value = m[k];
          if (value == null) continue;
          final text = value.toString().trim();
          if (text.isNotEmpty) return text;
        }
        return null;
      }

      dynamic byNorm(String key) =>
          keyMap[key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')];

      String? quantityFromRawText(String? rawText) {
        final text = _cleanText(rawText);
        if (text == null) return null;
        final normalized = text.replaceAll('⁄', '/');
        final m = RegExp(
          r'^\s*([-+]?\d+(?:[.,]\d+)?(?:\s+\d+/\d+|/\d+)?)\b',
        ).firstMatch(normalized);
        return m?.group(1)?.trim();
      }

      dynamic nestedQuantity = m['quantity'] ?? byNorm('quantity');
      String? nestedQuantityText;
      double? nestedQuantityValue;
      if (nestedQuantity is Map) {
        final q = Map<String, dynamic>.from(nestedQuantity);
        nestedQuantityText =
            q['text']?.toString() ??
            q['quantityText']?.toString() ??
            q['quantity_text']?.toString() ??
            q['display']?.toString();
        nestedQuantityValue = _toDouble(
          q['value'] ??
              q['quantityValue'] ??
              q['quantity_value'] ??
              q['amount'],
        );
      }

      final quantityText =
          pickText([
            'quantityText',
            'quantity_text',
            'quantitytext',
            'qtyText',
            'qty_text',
            'qtytext',
            'quantity',
            'qty',
            'amountText',
            'amount_text',
            'amounttext',
            'amount',
            'value',
            'number',
          ]) ??
          nestedQuantityText ??
          byNorm('quantitytext')?.toString() ??
          byNorm('qtytext')?.toString() ??
          byNorm('amounttext')?.toString();

      final quantityValue =
          _toDouble(
            m['quantityValue'] ??
                m['quantity_value'] ??
                m['quantityvalue'] ??
                m['amountValue'] ??
                m['amount_value'] ??
                m['amountvalue'] ??
                m['quantity'] ??
                m['qty'] ??
                m['amount'] ??
                m['value'] ??
                m['number'] ??
                byNorm('quantityvalue') ??
                byNorm('amountvalue') ??
                byNorm('quantity') ??
                byNorm('qty') ??
                byNorm('amount') ??
                byNorm('value') ??
                byNorm('number'),
          ) ??
          nestedQuantityValue ??
          _toDouble(quantityText);

      final unit = pickText(['unit', 'measure', 'measurement', 'suffix']);
      final ingredient =
          pickText(['ingredient', 'name', 'title', 'item', 'label']) ?? '';
      final note = pickText(['note', 'comment', 'description']);
      var rawText =
          pickText([
            'rawText',
            'raw_text',
            'rawtext',
            'rawLine',
            'raw_line',
            'raw',
            'line',
            'original',
            'text',
          ]) ??
          byNorm('rawtext')?.toString();

      final quantityTextFixed =
          _cleanText(quantityText) ?? quantityFromRawText(rawText);

      rawText = _composeIngredientLine(
        rawText: rawText,
        quantityText: quantityTextFixed,
        quantityValue: quantityValue,
        unit: unit,
        ingredient: ingredient,
        note: note,
      );

      return IngredientItem(
        position: _toInt(m['position']),
        quantityText: quantityTextFixed,
        quantityValue: quantityValue,
        unit: unit,
        ingredient: ingredient,
        note: note,
        rawText: rawText,
      );
    }).toList();
  }
}
