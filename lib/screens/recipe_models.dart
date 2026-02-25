import 'dart:convert';

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
  final direct = double.tryParse(normalized);
  if (direct != null) return direct;
  final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(normalized);
  return match == null ? null : double.tryParse(match.group(0)!);
}

dynamic _decodeJsonString(dynamic raw) {
  if (raw is! String) return raw;
  final text = raw.trim();
  if (text.isEmpty) return raw;
  if (!(text.startsWith('{') || text.startsWith('['))) return raw;
  try {
    return jsonDecode(text);
  } catch (_) {
    return raw;
  }
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

class RecipeSummary {
  final int id;
  final RecipeSource source;
  final String title;
  final String? image;
  final String? category;
  final String? totalTime;
  final int? readyInMinutes;
  final double? calories;
  final double? protein;
  final double? fat;
  final double? carbs;
  final int ingredientsCount;
  final int instructionsCount;

  RecipeSummary({
    required this.id,
    required this.source,
    required this.title,
    this.image,
    this.category,
    this.totalTime,
    this.readyInMinutes,
    this.calories,
    this.protein,
    this.fat,
    this.carbs,
    this.ingredientsCount = 0,
    this.instructionsCount = 0,
  });

  factory RecipeSummary.fromDb(Map<String, dynamic> json) {
    final nutritions = NutritionItem.listFromDynamic(
      json['nutritions'] ?? json['nutritionsJson'] ?? json['nutritions_json'],
    );

    double? findDbNutrient(List<String> names) {
      final keys = names.map((e) => e.toLowerCase()).toList();
      for (final n in nutritions) {
        final name = n.nutrient.toLowerCase();
        if (keys.any((k) => name.contains(k))) return _toDouble(n.amount);
      }
      return null;
    }

    final times = RecipeTimes.fromDynamic(
      json['times'] ?? json['timesJson'] ?? json['times_json'],
    );
    return RecipeSummary(
      id: _toInt(json['recipeId'] ?? json['recipe_id']) ?? 0,
      source: RecipeSource.db,
      title: (json['title'] ?? '').toString(),
      image: json['image']?.toString(),
      category:
          json['category']?.toString() ??
          json['categoryName']?.toString() ??
          json['category_name']?.toString(),
      totalTime: (times.totalTime ?? '').trim().isEmpty
          ? null
          : times.totalTime,
      readyInMinutes: times.totalMinutes,
      calories: findDbNutrient([
        'calories',
        'calorie',
        'kcal',
        'energy',
        'кал',
      ]),
      protein: findDbNutrient(['protein', 'белок']),
      fat: findDbNutrient(['fat', 'жир']),
      carbs: findDbNutrient(['carbohydrate', 'carb', 'углевод']),
      ingredientsCount:
          _toInt(json['ingredientsCount'] ?? json['ingredients_count']) ?? 0,
      instructionsCount:
          _toInt(json['instructionsCount'] ?? json['instructions_count']) ?? 0,
    );
  }
}

class RecipeDetails {
  final int id;
  final RecipeSource source;
  final String title;
  final String? image;
  final String? category;
  final RecipeTimes times;
  final List<IngredientItem> ingredients;
  final List<InstructionStepItem> instructionSteps;
  final List<NutritionItem> nutritions;
  final List<String> blockDietKeys;
  final List<String> blockAllergyKeys;
  final List<String> blockHealthKeys;
  final List<String> cautionHealthKeys;
  final List<RecipeConstraint> constraints;

  RecipeDetails({
    required this.id,
    required this.source,
    required this.title,
    this.image,
    this.category,
    required this.times,
    required this.ingredients,
    required this.instructionSteps,
    required this.nutritions,
    required this.blockDietKeys,
    required this.blockAllergyKeys,
    required this.blockHealthKeys,
    required this.cautionHealthKeys,
    required this.constraints,
  });

  RecipeDetails copyWith({
    int? id,
    RecipeSource? source,
    String? title,
    String? image,
    String? category,
    RecipeTimes? times,
    List<IngredientItem>? ingredients,
    List<InstructionStepItem>? instructionSteps,
    List<NutritionItem>? nutritions,
    List<String>? blockDietKeys,
    List<String>? blockAllergyKeys,
    List<String>? blockHealthKeys,
    List<String>? cautionHealthKeys,
    List<RecipeConstraint>? constraints,
  }) {
    return RecipeDetails(
      id: id ?? this.id,
      source: source ?? this.source,
      title: title ?? this.title,
      image: image ?? this.image,
      category: category ?? this.category,
      times: times ?? this.times,
      ingredients: ingredients ?? this.ingredients,
      instructionSteps: instructionSteps ?? this.instructionSteps,
      nutritions: nutritions ?? this.nutritions,
      blockDietKeys: blockDietKeys ?? this.blockDietKeys,
      blockAllergyKeys: blockAllergyKeys ?? this.blockAllergyKeys,
      blockHealthKeys: blockHealthKeys ?? this.blockHealthKeys,
      cautionHealthKeys: cautionHealthKeys ?? this.cautionHealthKeys,
      constraints: constraints ?? this.constraints,
    );
  }

  factory RecipeDetails.fromDb(Map<String, dynamic> json) {
    return RecipeDetails(
      id: _toInt(json['recipeId'] ?? json['recipe_id']) ?? 0,
      source: RecipeSource.db,
      title: (json['title'] ?? '').toString(),
      image: json['image']?.toString(),
      category:
          json['category']?.toString() ??
          json['categoryName']?.toString() ??
          json['category_name']?.toString(),
      times: RecipeTimes.fromDynamic(
        json['times'] ?? json['timesJson'] ?? json['times_json'],
      ),
      ingredients: IngredientItem.listFromDynamic(
        json['ingredients'] ??
            json['ingredientsJson'] ??
            json['ingredients_json'],
      ),
      instructionSteps: InstructionStepItem.listFromDynamic(
        json['instructionSteps'] ??
            json['instruction_steps'] ??
            json['instructionStepsJson'] ??
            json['instruction_steps_json'],
      ),
      nutritions: NutritionItem.listFromDynamic(
        json['nutritions'] ?? json['nutritionsJson'] ?? json['nutritions_json'],
      ),
      blockDietKeys: _toStringList(
        json['blockDietKeys'] ??
            json['block_diet_keys'] ??
            json['blockDietKeysJson'] ??
            json['block_diet_keys_json'],
      ),
      blockAllergyKeys: _toStringList(
        json['blockAllergyKeys'] ??
            json['block_allergy_keys'] ??
            json['blockAllergyKeysJson'] ??
            json['block_allergy_keys_json'],
      ),
      blockHealthKeys: _toStringList(
        json['blockHealthKeys'] ??
            json['block_health_keys'] ??
            json['blockHealthKeysJson'] ??
            json['block_health_keys_json'],
      ),
      cautionHealthKeys: _toStringList(
        json['cautionHealthKeys'] ??
            json['caution_health_keys'] ??
            json['cautionHealthKeysJson'] ??
            json['caution_health_keys_json'],
      ),
      constraints: RecipeConstraint.listFromDynamic(
        json['constraints'] ??
            json['constraintsJson'] ??
            json['constraints_json'],
      ),
    );
  }
}

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
      return IngredientItem(
        position: _toInt(m['position']),
        quantityText:
            m['quantityText']?.toString() ?? m['quantity_text']?.toString(),
        quantityValue: _toDouble(m['quantityValue'] ?? m['quantity_value']),
        unit: m['unit']?.toString(),
        ingredient: (m['ingredient'] ?? '').toString(),
        note: m['note']?.toString(),
        rawText: m['rawText']?.toString() ?? m['raw_text']?.toString(),
      );
    }).toList();
  }
}

class InstructionStepItem {
  final int? position;
  final String text;
  final String? durationHint;
  final String? temperatureHint;
  final List<String> ingredients;
  final List<String> equipment;
  final Map<String, String> ingredientImages;
  final Map<String, String> equipmentImages;
  final String? section;

  InstructionStepItem({
    this.position,
    required this.text,
    this.durationHint,
    this.temperatureHint,
    this.ingredients = const [],
    this.equipment = const [],
    this.ingredientImages = const {},
    this.equipmentImages = const {},
    this.section,
  });

  static List<InstructionStepItem> listFromDynamic(dynamic raw) {
    final list = _asMapList(raw);
    return list.map((m) {
      return InstructionStepItem(
        position: _toInt(m['position']),
        text: (m['text'] ?? '').toString(),
        durationHint:
            m['durationHint']?.toString() ?? m['duration_hint']?.toString(),
        temperatureHint:
            m['temperatureHint']?.toString() ??
            m['temperature_hint']?.toString(),
        ingredients: _namesFromDynamicList(m['ingredients']),
        equipment: _namesFromDynamicList(m['equipment']),
        ingredientImages: _imageMapFromDynamicList(m['ingredients']),
        equipmentImages: _imageMapFromDynamicList(m['equipment']),
        section: m['section']?.toString(),
      );
    }).toList();
  }

  static List<String> _namesFromDynamicList(dynamic raw) {
    if (raw is! List) return const [];

    final out = <String>[];
    for (final e in raw) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final name = (m['name'] ?? m['ingredient'] ?? '').toString().trim();
        if (name.isNotEmpty) out.add(name);
      } else {
        final name = e.toString().trim();
        if (name.isNotEmpty) out.add(name);
      }
    }
    return out;
  }

  static Map<String, String> _imageMapFromDynamicList(dynamic raw) {
    if (raw is! List) return const {};

    final out = <String, String>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final name = (m['name'] ?? m['ingredient'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final image = (m['imageUrl'] ?? m['image_url'] ?? m['image'] ?? '')
          .toString()
          .trim();
      if (image.isEmpty) continue;
      out[name] = image;
    }
    return out;
  }
}

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
