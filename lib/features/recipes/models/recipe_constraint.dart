part of 'models.dart';

class RecipeConstraint {
  final String key;
  final String type;
  final String status;
  final String? reason;
  final String? source;
  final double? confidence;

  RecipeConstraint({
    required this.key,
    required this.type,
    required this.status,
    this.reason,
    this.source,
    this.confidence,
  });

  static RecipeConstraint? _fromMap(
    Map<String, dynamic> m, {
    String? fallbackType,
    String fallbackStatus = 'UNKNOWN',
  }) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    final key = pick([
      'key',
      'constraintKey',
      'name',
      'code',
      'item',
      'value',
      'id',
    ]);
    final type = pick(['type', 'constraintType', 'group', 'category', 'kind']);
    final status = pick(['status', 'state', 'level', 'severity', 'verdict']);
    final reason = pick(['reason', 'message', 'description']);
    final source = pick(['source', 'origin', 'provider']);

    final normalizedKey = key.isNotEmpty ? key : reason;
    if (normalizedKey.isEmpty) return null;

    return RecipeConstraint(
      key: normalizedKey,
      type: type.isNotEmpty ? type : (fallbackType ?? 'CONSTRAINT'),
      status: status.isNotEmpty ? status : fallbackStatus,
      reason: reason.isNotEmpty ? reason : null,
      source: source.isNotEmpty ? source : null,
      confidence: _toDouble(m['confidence'] ?? m['score']),
    );
  }

  static List<RecipeConstraint> listFromDynamic(dynamic raw) {
    final decoded = _decodeJsonString(raw);

    if (decoded is List) {
      final out = <RecipeConstraint>[];
      for (final item in decoded) {
        if (item is Map) {
          final parsed = _fromMap(Map<String, dynamic>.from(item));
          if (parsed != null) out.add(parsed);
          continue;
        }
        final text = item.toString().trim();
        if (text.isNotEmpty) {
          out.add(
            RecipeConstraint(key: text, type: 'CONSTRAINT', status: 'UNKNOWN'),
          );
        }
      }
      return out;
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final out = <RecipeConstraint>[];

      map.forEach((group, value) {
        final groupType = group.toString().trim();
        if (value is List) {
          for (final item in value) {
            if (item is Map) {
              final parsed = _fromMap(
                Map<String, dynamic>.from(item),
                fallbackType: groupType,
                fallbackStatus: 'BLOCK',
              );
              if (parsed != null) out.add(parsed);
              continue;
            }
            final text = item.toString().trim();
            if (text.isNotEmpty) {
              out.add(
                RecipeConstraint(
                  key: text,
                  type: groupType.isEmpty ? 'CONSTRAINT' : groupType,
                  status: 'BLOCK',
                ),
              );
            }
          }
          return;
        }

        if (value is Map) {
          final parsed = _fromMap(
            Map<String, dynamic>.from(value),
            fallbackType: groupType,
            fallbackStatus: 'BLOCK',
          );
          if (parsed != null) out.add(parsed);
          return;
        }

        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          out.add(
            RecipeConstraint(
              key: text,
              type: groupType.isEmpty ? 'CONSTRAINT' : groupType,
              status: 'BLOCK',
            ),
          );
        }
      });

      return out;
    }

    return const [];
  }
}
