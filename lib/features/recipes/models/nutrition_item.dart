part of 'models.dart';

class NutritionItem {
  final String nutrient;
  final String amount;
  final String? unit;
  final String? rawText;

  NutritionItem({
    required this.nutrient,
    required this.amount,
    this.unit,
    this.rawText,
  });

  static List<NutritionItem> listFromDynamic(dynamic raw) {
    final decoded = _decodeJsonString(raw);

    String sanitizeNutrient(dynamic rawName) {
      final text = (rawName ?? '').toString().trim();
      if (text.isEmpty) return '';
      final normalized = text
          .replaceAll(RegExp('content', caseSensitive: false), '')
          .replaceAll(RegExp('содержание', caseSensitive: false), '')
          .replaceAll(RegExp('содержан', caseSensitive: false), '')
          .trim();
      final cleaned = normalized
          .replaceAll(RegExp(r'^[\s:;.,-]+'), '')
          .replaceAll(RegExp(r'[\s:;.,-]+$'), '')
          .trim();
      if (!RegExp(r'[A-Za-zА-Яа-я0-9]').hasMatch(cleaned)) return '';
      return cleaned;
    }

    ({String nutrient, String amount}) splitNameAndAmount(String text) {
      final m = RegExp(r'^([^:]+)\s*:\s*(.+)$').firstMatch(text.trim());
      if (m == null) return (nutrient: '', amount: text.trim());
      return (
        nutrient: sanitizeNutrient(m.group(1) ?? ''),
        amount: (m.group(2) ?? '').trim(),
      );
    }

    NutritionItem? fromMap(Map<String, dynamic> m) {
      var nutrient = sanitizeNutrient(
        m['nutrient'] ?? m['name'] ?? m['label'] ?? m['title'] ?? m['key'],
      );

      final amountRaw =
          m['amount'] ?? m['value'] ?? m['quantity'] ?? m['qty'] ?? m['number'];
      var amount = (amountRaw ?? '').toString().trim();

      var unit = (m['unit'] ?? m['measure'] ?? m['measurement'] ?? m['suffix'])
          ?.toString()
          .trim();

      final rawText = m['rawText']?.toString() ?? m['raw_text']?.toString();

      if (nutrient.isEmpty && m.length == 1) {
        final entry = m.entries.first;
        final key = sanitizeNutrient(entry.key);
        final val = entry.value?.toString().trim() ?? '';
        if (key.isNotEmpty && val.isNotEmpty) {
          final compound = splitNameAndAmount(val);
          if (compound.nutrient.isNotEmpty) {
            nutrient = compound.nutrient;
            amount = compound.amount;
          } else {
            nutrient = key;
            amount = val;
          }
          return NutritionItem(
            nutrient: nutrient,
            amount: amount,
            rawText: rawText,
          );
        }
      }

      if (amount.contains(':')) {
        final compound = splitNameAndAmount(amount);
        if (compound.nutrient.isNotEmpty) {
          if (nutrient.isEmpty || nutrient.toLowerCase() == 'value') {
            nutrient = compound.nutrient;
          }
          amount = compound.amount;
        }
      }

      if (nutrient.contains(':')) {
        final compound = splitNameAndAmount(nutrient);
        if (compound.nutrient.isNotEmpty) {
          nutrient = compound.nutrient;
          if (amount.isEmpty) amount = compound.amount;
        }
      }

      if (unit != null && unit.isNotEmpty && unit.contains(':')) {
        final compound = splitNameAndAmount(unit);
        if (compound.nutrient.isNotEmpty && nutrient.isEmpty) {
          nutrient = compound.nutrient;
          if (amount.isEmpty) amount = compound.amount;
          unit = null;
        }
      }

      amount = amount
          .replaceAll(RegExp(r'^[\s:;,-]+'), '')
          .replaceAll(RegExp(r'[\s;,-]+$'), '')
          .trim();

      if (nutrient.isEmpty || amount.isEmpty) return null;
      return NutritionItem(
        nutrient: nutrient,
        amount: amount,
        unit: (unit == null || unit.isEmpty) ? null : unit,
        rawText: rawText,
      );
    }

    if (decoded is List) {
      final out = <NutritionItem>[];
      for (final item in decoded) {
        if (item is Map) {
          final parsed = fromMap(Map<String, dynamic>.from(item));
          if (parsed != null) out.add(parsed);
          continue;
        }

        final text = item.toString().trim();
        if (text.isEmpty) continue;
        final match = RegExp(r'^([^:]+)\s*:\s*(.+)$').firstMatch(text);
        if (match != null) {
          final nutrient = sanitizeNutrient(match.group(1)!.trim());
          final amount = match.group(2)!.trim();
          if (nutrient.isEmpty || amount.isEmpty) continue;
          out.add(NutritionItem(nutrient: nutrient, amount: amount));
        }
      }
      return out;
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);

      for (final key in ['items', 'values', 'nutrients', 'data', 'list']) {
        final nested = map[key];
        if (nested is List) return listFromDynamic(nested);
      }

      final out = <NutritionItem>[];
      map.forEach((key, value) {
        var nutrient = sanitizeNutrient(key);
        var amount = value?.toString().trim() ?? '';
        if (nutrient.isEmpty && amount.contains(':')) {
          final compound = splitNameAndAmount(amount);
          nutrient = compound.nutrient;
          amount = compound.amount;
        }
        if (nutrient.isEmpty || amount.isEmpty) return;
        out.add(NutritionItem(nutrient: nutrient, amount: amount));
      });
      return out;
    }

    return const [];
  }
}
