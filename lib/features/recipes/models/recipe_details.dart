part of 'models.dart';

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
  final List<RecipeComment> comments;
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
    required this.comments,
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
    List<RecipeComment>? comments,
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
      comments: comments ?? this.comments,
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
      comments: RecipeComment.listFromDynamic(
        json['comments'] ?? json['commentsJson'] ?? json['comments_json'],
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
