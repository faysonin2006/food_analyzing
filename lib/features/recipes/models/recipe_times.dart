part of 'models.dart';

class RecipeTimes {
  final String? prepTime;
  final String? cookTime;
  final String? totalTime;

  RecipeTimes({this.prepTime, this.cookTime, this.totalTime});

  bool get hasAnyValue =>
      (prepTime ?? '').trim().isNotEmpty ||
      (cookTime ?? '').trim().isNotEmpty ||
      (totalTime ?? '').trim().isNotEmpty;

  int? get totalMinutes {
    int? parseMinutes(String? raw) {
      final t = raw?.trim() ?? '';
      if (t.isEmpty) return null;
      final s = t.toLowerCase();

      if (RegExp(r'^\d+$').hasMatch(s)) return int.tryParse(s);

      int h = 0;
      int m = 0;

      for (final match in RegExp(
        r'(\d+)\s*(h|hr|hrs|hour|hours|ч)',
      ).allMatches(s)) {
        h += int.parse(match.group(1)!);
      }

      for (final match in RegExp(
        r'(\d+)\s*(m|min|mins|minute|minutes|мин)',
      ).allMatches(s)) {
        m += int.parse(match.group(1)!);
      }

      final hm = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(s);
      if (hm != null) {
        h = int.parse(hm.group(1)!);
        m = int.parse(hm.group(2)!);
      }

      final total = h * 60 + m;
      return total > 0 ? total : null;
    }

    final total = parseMinutes(totalTime);
    if (total != null) return total;

    final prep = parseMinutes(prepTime);
    final cook = parseMinutes(cookTime);
    if (prep == null && cook == null) return null;
    return (prep ?? 0) + (cook ?? 0);
  }

  factory RecipeTimes.fromDynamic(dynamic raw) {
    String? normalizeTime(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return null;
      final lower = text.toLowerCase();
      if (lower == 'null' ||
          lower == 'none' ||
          lower == 'n/a' ||
          lower == 'na' ||
          lower == '-' ||
          lower == '--' ||
          lower == '{}' ||
          lower == '[]' ||
          lower == 'unknown' ||
          lower == 'неизвестно' ||
          RegExp(r'^0+([.,]0+)?$').hasMatch(lower)) {
        return null;
      }
      return text;
    }

    String? pickFirst(List<dynamic> values) {
      for (final value in values) {
        final normalized = normalizeTime(value);
        if (normalized != null) return normalized;
      }
      return null;
    }

    final decoded = _decodeJsonString(raw);
    if (decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      return RecipeTimes(
        prepTime: pickFirst([m['prepTime'], m['prep_time'], m['prep']]),
        cookTime: pickFirst([m['cookTime'], m['cook_time'], m['cook']]),
        totalTime: pickFirst([
          m['totalTime'],
          m['total_time'],
          m['totalMinutes'],
          m['total_minutes'],
          m['total'],
        ]),
      );
    }
    if (decoded is String) {
      final total = normalizeTime(decoded);
      if (total != null) return RecipeTimes(totalTime: total);
    }
    return RecipeTimes();
  }
}
