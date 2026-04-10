import 'dart:convert';

part 'recipe_summary.dart';
part 'recipe_details.dart';
part 'recipe_comment.dart';
part 'ingredient_item.dart';
part 'instruction_step_item.dart';
part 'nutrition_item.dart';
part 'recipe_times.dart';
part 'recipe_constraint.dart';

enum RecipeSource { db }

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final text = v.toString().trim();
  if (text.isEmpty) return null;
  final direct = int.tryParse(text);
  if (direct != null) return direct;
  final match = RegExp(r'[-+]?\d+').firstMatch(text);
  return match == null ? null : int.tryParse(match.group(0)!);
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  final text = v.toString().trim();
  if (text.isEmpty) return null;
  final normalized = text.replaceAll(',', '.');

  final mixedFraction = RegExp(
    r'^([-+]?\d+)\s+(\d+)/(\d+)$',
  ).firstMatch(normalized);
  if (mixedFraction != null) {
    final whole = double.tryParse(mixedFraction.group(1)!);
    final numerator = double.tryParse(mixedFraction.group(2)!);
    final denominator = double.tryParse(mixedFraction.group(3)!);
    if (whole != null &&
        numerator != null &&
        denominator != null &&
        denominator != 0) {
      final sign = whole < 0 ? -1.0 : 1.0;
      return whole + sign * (numerator / denominator);
    }
  }

  final simpleFraction = RegExp(r'^([-+]?\d+)/(\d+)$').firstMatch(normalized);
  if (simpleFraction != null) {
    final numerator = double.tryParse(simpleFraction.group(1)!);
    final denominator = double.tryParse(simpleFraction.group(2)!);
    if (numerator != null && denominator != null && denominator != 0) {
      return numerator / denominator;
    }
  }

  final direct = double.tryParse(normalized);
  if (direct != null) return direct;
  final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(normalized);
  return match == null ? null : double.tryParse(match.group(0)!);
}

dynamic _decodeJsonString(dynamic raw) {
  if (raw is! String) return raw;
  final text = raw.trim();
  if (text.isEmpty) return raw;

  dynamic decodeCandidate(String candidate) {
    final variants = <String>[candidate, candidate.replaceAll('""', '"')];

    for (final variant in variants) {
      try {
        final decoded = jsonDecode(variant);
        if (decoded is String) {
          final inner = decoded.trim();
          if (inner.startsWith('{') || inner.startsWith('[')) {
            try {
              return jsonDecode(inner);
            } catch (_) {}
          }
        }
        return decoded;
      } catch (_) {}
    }

    return null;
  }

  final decodedText = decodeCandidate(text);
  if (decodedText != null) return decodedText;

  if (text.startsWith('"') && text.endsWith('"') && text.length >= 2) {
    final unwrapped = text.substring(1, text.length - 1);
    final decodedUnwrapped = decodeCandidate(unwrapped);
    if (decodedUnwrapped != null) return decodedUnwrapped;
  }

  return raw;
}

String? _cleanText(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

String _normalizeFractionSlash(String text) {
  return text.replaceAllMapped(
    RegExp(r'(\d+)\s*/\s*(\d+)'),
    (m) => '${m.group(1)}⁄${m.group(2)}',
  );
}

String _normalizeSpaces(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();

bool _containsQuantityToken(String text) {
  final normalized = text.replaceAll('⁄', '/');
  return RegExp(
    r'(^|\s)\d+([.,]\d+)?(\s+\d+/\d+|/\d+)?($|\s)',
  ).hasMatch(normalized);
}

String? _formatQuantityFromValue(double? value) {
  if (value == null) return null;

  const denominators = [2, 3, 4, 8, 16];
  final sign = value < 0 ? -1 : 1;
  final abs = value.abs();
  final whole = abs.floor();
  final frac = abs - whole;

  if (frac < 0.000001) {
    return (sign * whole).toString();
  }

  int bestDen = 0;
  int bestNum = 0;
  double bestError = double.infinity;
  for (final den in denominators) {
    final num = (frac * den).round();
    final err = (frac - (num / den)).abs();
    if (err < bestError) {
      bestError = err;
      bestDen = den;
      bestNum = num;
    }
  }

  if (bestError <= 0.02 && bestNum > 0) {
    final signedWhole = sign < 0 ? -whole : whole;
    if (whole == 0) {
      return '${sign < 0 ? '-' : ''}$bestNum/$bestDen';
    }
    return '$signedWhole $bestNum/$bestDen';
  }

  var text = abs.toStringAsFixed(4);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return sign < 0 ? '-$text' : text;
}

String _composeIngredientLine({
  String? rawText,
  String? quantityText,
  double? quantityValue,
  String? unit,
  String? ingredient,
  String? note,
}) {
  final qText =
      _cleanText(quantityText) ?? _formatQuantityFromValue(quantityValue);
  final u = _cleanText(unit);
  final ing = _cleanText(ingredient);
  final n = _cleanText(note);

  var line = _cleanText(rawText) ?? '';
  if (line.isEmpty) {
    line = [
      if (qText != null) qText,
      if (u != null) u,
      if (ing != null) ing,
    ].join(' ').trim();
  }

  if (qText != null && !_containsQuantityToken(line)) {
    line = '$qText $line'.trim();
  }

  if (u != null && !line.toLowerCase().contains(u.toLowerCase())) {
    if (qText != null && line.startsWith(qText)) {
      final rest = line.substring(qText.length).trim();
      line = '$qText $u $rest'.trim();
    } else {
      line = '$u $line'.trim();
    }
  }

  if (ing != null && !line.toLowerCase().contains(ing.toLowerCase())) {
    line = '$line $ing'.trim();
  }

  if (n != null && !line.toLowerCase().contains(n.toLowerCase())) {
    line = '$line, $n'.trim();
  }

  line = _normalizeFractionSlash(_normalizeSpaces(line));
  return line.isEmpty ? '-' : line;
}

List<String> _toStringList(dynamic raw) {
  final decoded = _decodeJsonString(raw);

  String pickValue(dynamic e) {
    if (e is Map) {
      final m = Map<String, dynamic>.from(e);
      return (m['name'] ??
              m['key'] ??
              m['value'] ??
              m['item'] ??
              m['code'] ??
              m['description'] ??
              m['title'] ??
              m['id'] ??
              '')
          .toString()
          .trim();
    }
    return e.toString().trim();
  }

  if (decoded is List) {
    return decoded
        .map(pickValue)
        .where((e) => e.isNotEmpty && RegExp(r'[A-Za-zА-Яа-я0-9]').hasMatch(e))
        .toList();
  }

  if (decoded is Map) {
    return decoded.values
        .map(pickValue)
        .where((e) => e.isNotEmpty && RegExp(r'[A-Za-zА-Яа-я0-9]').hasMatch(e))
        .toList();
  }

  return const [];
}

List<Map<String, dynamic>> _asMapList(dynamic raw) {
  final decoded = _decodeJsonString(raw);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
