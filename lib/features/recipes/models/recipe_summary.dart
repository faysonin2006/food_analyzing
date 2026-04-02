part of 'models.dart';

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
  final List<String> searchMatchReasons;

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
    this.searchMatchReasons = const [],
  });

  RecipeSummary copyWith({
    int? id,
    RecipeSource? source,
    String? title,
    String? image,
    String? category,
    String? totalTime,
    int? readyInMinutes,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
    int? ingredientsCount,
    int? instructionsCount,
    List<String>? searchMatchReasons,
  }) {
    return RecipeSummary(
      id: id ?? this.id,
      source: source ?? this.source,
      title: title ?? this.title,
      image: image ?? this.image,
      category: category ?? this.category,
      totalTime: totalTime ?? this.totalTime,
      readyInMinutes: readyInMinutes ?? this.readyInMinutes,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
      ingredientsCount: ingredientsCount ?? this.ingredientsCount,
      instructionsCount: instructionsCount ?? this.instructionsCount,
      searchMatchReasons: searchMatchReasons ?? this.searchMatchReasons,
    );
  }

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
      searchMatchReasons:
          ((json['searchMatchReasons'] ?? json['search_match_reasons'])
                  as List?)
              ?.map((value) => value?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toList() ??
          const <String>[],
    );
  }

  factory RecipeSummary.fromRecommendation(Map<String, dynamic> json) {
    final nutritions = NutritionItem.listFromDynamic(
      json['nutritions'] ?? json['nutritionsJson'] ?? json['nutritions_json'],
    );
    final times = RecipeTimes.fromDynamic(
      json['times'] ?? json['timesJson'] ?? json['times_json'],
    );

    double? findNutrient(List<String> names) {
      final keys = names.map((e) => e.toLowerCase()).toList();
      for (final n in nutritions) {
        final name = n.nutrient.toLowerCase();
        if (keys.any(name.contains)) return _toDouble(n.amount);
      }
      return null;
    }

    return RecipeSummary(
      id: _toInt(json['recipeId'] ?? json['recipe_id']) ?? 0,
      source: RecipeSource.db,
      title: (json['title'] ?? '').toString().trim(),
      image: _cleanText(json['image']?.toString()),
      category: _cleanText(json['category']?.toString()),
      totalTime: (times.totalTime ?? '').trim().isEmpty
          ? null
          : times.totalTime,
      readyInMinutes: times.totalMinutes,
      calories:
          _toDouble(json['estimatedCalories'] ?? json['estimated_calories']) ??
          findNutrient(['calories', 'calorie', 'kcal', 'energy', 'кал']),
      protein: findNutrient(['protein', 'белок']),
      fat: findNutrient(['fat', 'fats', 'жир']),
      carbs: findNutrient(['carbohydrate', 'carb', 'carbs', 'углевод']),
    );
  }
}
