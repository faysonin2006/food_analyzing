import '../local/search_history_local_db.dart';

part 'food_catalog_data.dart';

enum SuggestionSource { pantry, shopping, history, keyword, catalog }

class SuggestionOption {
  const SuggestionOption({
    required this.primaryText,
    required this.source,
    this.secondaryText,
    this.category,
    this.brand,
    this.pantryUnit,
    this.shoppingUnit,
    this.quantity,
    this.calories,
    this.protein,
    this.fat,
    this.carbs,
    this.searchTerms = const <String>[],
  });

  final String primaryText;
  final String? secondaryText;
  final SuggestionSource source;
  final String? category;
  final String? brand;
  final String? pantryUnit;
  final String? shoppingUnit;
  final String? quantity;
  final int? calories;
  final double? protein;
  final double? fat;
  final double? carbs;
  final List<String> searchTerms;
}

class FoodSuggestions {
  FoodSuggestions._();

  static Iterable<_CatalogFoodEntry> get _catalogEntries => <_CatalogFoodEntry>[
    ..._catalog,
    ..._extendedCatalog,
  ];

  static Iterable<_RecipePromptEntry> get _recipePromptEntries =>
      <_RecipePromptEntry>[..._recipePrompts, ..._extendedRecipePrompts];

  static Iterable<_MealPromptEntry> get _mealPromptEntries =>
      <_MealPromptEntry>[..._mealPrompts];

  static const List<_CatalogFoodEntry> _catalog = <_CatalogFoodEntry>[
    _CatalogFoodEntry(
      nameEn: 'Milk',
      nameRu: 'Молоко',
      categoryEn: 'Dairy',
      categoryRu: 'Молочное',
      pantryUnit: 'LITER',
      quantity: '1',
      aliasesEn: <String>['whole milk', 'skim milk'],
      aliasesRu: <String>['молочко'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Eggs',
      nameRu: 'Яйца',
      categoryEn: 'Protein',
      categoryRu: 'Белок',
      pantryUnit: 'PIECE',
      quantity: '10',
      aliasesEn: <String>['egg'],
      aliasesRu: <String>['яйцо'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Greek yogurt',
      nameRu: 'Греческий йогурт',
      categoryEn: 'Dairy',
      categoryRu: 'Молочное',
      pantryUnit: 'PACK',
      quantity: '1',
      aliasesEn: <String>['yogurt', 'yoghurt'],
      aliasesRu: <String>['йогурт'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Cottage cheese',
      nameRu: 'Творог',
      categoryEn: 'Dairy',
      categoryRu: 'Молочное',
      pantryUnit: 'PACK',
      quantity: '1',
      aliasesEn: <String>['curd'],
      aliasesRu: <String>['зерненый творог'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Cheese',
      nameRu: 'Сыр',
      categoryEn: 'Dairy',
      categoryRu: 'Молочное',
      pantryUnit: 'GRAM',
      quantity: '200',
      aliasesEn: <String>['cheddar', 'mozzarella'],
      aliasesRu: <String>['моцарелла', 'чеддер'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Butter',
      nameRu: 'Масло сливочное',
      categoryEn: 'Dairy',
      categoryRu: 'Молочное',
      pantryUnit: 'GRAM',
      quantity: '180',
      aliasesEn: <String>['butter'],
      aliasesRu: <String>['сливочное масло'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Kefir',
      nameRu: 'Кефир',
      categoryEn: 'Dairy',
      categoryRu: 'Молочное',
      pantryUnit: 'LITER',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Sour cream',
      nameRu: 'Сметана',
      categoryEn: 'Dairy',
      categoryRu: 'Молочное',
      pantryUnit: 'PACK',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Chicken breast',
      nameRu: 'Куриная грудка',
      categoryEn: 'Protein',
      categoryRu: 'Белок',
      pantryUnit: 'GRAM',
      quantity: '500',
      aliasesEn: <String>['chicken'],
      aliasesRu: <String>['курица'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Ground beef',
      nameRu: 'Говяжий фарш',
      categoryEn: 'Protein',
      categoryRu: 'Белок',
      pantryUnit: 'GRAM',
      quantity: '500',
      aliasesEn: <String>['beef mince'],
      aliasesRu: <String>['фарш'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Turkey fillet',
      nameRu: 'Филе индейки',
      categoryEn: 'Protein',
      categoryRu: 'Белок',
      pantryUnit: 'GRAM',
      quantity: '500',
      aliasesEn: <String>['turkey'],
      aliasesRu: <String>['индейка'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Salmon',
      nameRu: 'Лосось',
      categoryEn: 'Fish',
      categoryRu: 'Рыба',
      pantryUnit: 'GRAM',
      quantity: '300',
      aliasesEn: <String>['salmon fillet'],
      aliasesRu: <String>['семга'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Tuna',
      nameRu: 'Тунец',
      categoryEn: 'Fish',
      categoryRu: 'Рыба',
      pantryUnit: 'CAN',
      quantity: '1',
      aliasesEn: <String>['canned tuna'],
      aliasesRu: <String>['консервированный тунец'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Rice',
      nameRu: 'Рис',
      categoryEn: 'Grains',
      categoryRu: 'Крупы',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Buckwheat',
      nameRu: 'Гречка',
      categoryEn: 'Grains',
      categoryRu: 'Крупы',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['buckwheat'],
      aliasesRu: <String>['гречневая крупа'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Oats',
      nameRu: 'Овсянка',
      categoryEn: 'Grains',
      categoryRu: 'Крупы',
      pantryUnit: 'PACK',
      quantity: '1',
      aliasesEn: <String>['oatmeal'],
      aliasesRu: <String>['овсяные хлопья'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Pasta',
      nameRu: 'Паста',
      categoryEn: 'Grains',
      categoryRu: 'Крупы',
      pantryUnit: 'PACK',
      quantity: '1',
      aliasesEn: <String>['spaghetti', 'macaroni'],
      aliasesRu: <String>['макароны', 'спагетти'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Bread',
      nameRu: 'Хлеб',
      categoryEn: 'Bakery',
      categoryRu: 'Выпечка',
      pantryUnit: 'PACK',
      quantity: '1',
      aliasesEn: <String>['toast bread'],
      aliasesRu: <String>['батон'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Flour',
      nameRu: 'Мука',
      categoryEn: 'Pantry',
      categoryRu: 'Бакалея',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Sugar',
      nameRu: 'Сахар',
      categoryEn: 'Pantry',
      categoryRu: 'Бакалея',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Salt',
      nameRu: 'Соль',
      categoryEn: 'Pantry',
      categoryRu: 'Бакалея',
      pantryUnit: 'PACK',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Black pepper',
      nameRu: 'Черный перец',
      categoryEn: 'Spices',
      categoryRu: 'Специи',
      pantryUnit: 'PACK',
      quantity: '1',
      aliasesEn: <String>['pepper'],
      aliasesRu: <String>['перец'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Olive oil',
      nameRu: 'Оливковое масло',
      categoryEn: 'Pantry',
      categoryRu: 'Бакалея',
      pantryUnit: 'BOTTLE',
      quantity: '1',
      aliasesEn: <String>['oil'],
      aliasesRu: <String>['масло'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Potatoes',
      nameRu: 'Картофель',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['potato'],
      aliasesRu: <String>['картошка'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Tomatoes',
      nameRu: 'Помидоры',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['tomato'],
      aliasesRu: <String>['томат'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Cucumbers',
      nameRu: 'Огурцы',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['cucumber'],
      aliasesRu: <String>['огурец'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Bell pepper',
      nameRu: 'Болгарский перец',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['sweet pepper'],
      aliasesRu: <String>['сладкий перец'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Onion',
      nameRu: 'Лук',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['onions'],
      aliasesRu: <String>['репчатый лук'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Garlic',
      nameRu: 'Чеснок',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'PIECE',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Carrots',
      nameRu: 'Морковь',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['carrot'],
      aliasesRu: <String>['морковка'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Broccoli',
      nameRu: 'Брокколи',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'PIECE',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Mushrooms',
      nameRu: 'Шампиньоны',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'GRAM',
      quantity: '300',
      aliasesEn: <String>['mushroom'],
      aliasesRu: <String>['грибы'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Spinach',
      nameRu: 'Шпинат',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'PACK',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Lettuce',
      nameRu: 'Салат',
      categoryEn: 'Vegetables',
      categoryRu: 'Овощи',
      pantryUnit: 'PIECE',
      quantity: '1',
      aliasesEn: <String>['lettuce leaves'],
      aliasesRu: <String>['листовой салат'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Avocado',
      nameRu: 'Авокадо',
      categoryEn: 'Fruits',
      categoryRu: 'Фрукты',
      pantryUnit: 'PIECE',
      quantity: '2',
    ),
    _CatalogFoodEntry(
      nameEn: 'Bananas',
      nameRu: 'Бананы',
      categoryEn: 'Fruits',
      categoryRu: 'Фрукты',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['banana'],
      aliasesRu: <String>['банан'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Apples',
      nameRu: 'Яблоки',
      categoryEn: 'Fruits',
      categoryRu: 'Фрукты',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['apple'],
      aliasesRu: <String>['яблоко'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Lemons',
      nameRu: 'Лимоны',
      categoryEn: 'Fruits',
      categoryRu: 'Фрукты',
      pantryUnit: 'KILOGRAM',
      quantity: '1',
      aliasesEn: <String>['lemon'],
      aliasesRu: <String>['лимон'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Beans',
      nameRu: 'Фасоль',
      categoryEn: 'Pantry',
      categoryRu: 'Бакалея',
      pantryUnit: 'CAN',
      quantity: '1',
      aliasesEn: <String>['kidney beans'],
      aliasesRu: <String>['консервированная фасоль'],
    ),
    _CatalogFoodEntry(
      nameEn: 'Chickpeas',
      nameRu: 'Нут',
      categoryEn: 'Pantry',
      categoryRu: 'Бакалея',
      pantryUnit: 'CAN',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Coffee',
      nameRu: 'Кофе',
      categoryEn: 'Beverages',
      categoryRu: 'Напитки',
      pantryUnit: 'PACK',
      quantity: '1',
    ),
    _CatalogFoodEntry(
      nameEn: 'Tea',
      nameRu: 'Чай',
      categoryEn: 'Beverages',
      categoryRu: 'Напитки',
      pantryUnit: 'PACK',
      quantity: '1',
    ),
  ];

  static const List<_RecipePromptEntry> _recipePrompts = <_RecipePromptEntry>[
    _RecipePromptEntry(
      labelEn: 'Chicken pasta',
      labelRu: 'Паста с курицей',
      aliasesEn: <String>['pasta', 'chicken pasta'],
      aliasesRu: <String>['паста', 'макароны с курицей'],
    ),
    _RecipePromptEntry(
      labelEn: 'Vegetable soup',
      labelRu: 'Овощной суп',
      aliasesEn: <String>['soup', 'vegetable soup'],
      aliasesRu: <String>['суп', 'овощной суп'],
    ),
    _RecipePromptEntry(
      labelEn: 'Fresh salad',
      labelRu: 'Свежий салат',
      aliasesEn: <String>['salad'],
      aliasesRu: <String>['салат'],
    ),
    _RecipePromptEntry(
      labelEn: 'Oatmeal breakfast',
      labelRu: 'Овсяный завтрак',
      aliasesEn: <String>['oatmeal', 'breakfast'],
      aliasesRu: <String>['овсянка', 'завтрак'],
    ),
    _RecipePromptEntry(
      labelEn: 'Rice bowl',
      labelRu: 'Райс боул',
      aliasesEn: <String>['rice bowl', 'bowl'],
      aliasesRu: <String>['боул', 'рис с овощами'],
    ),
    _RecipePromptEntry(
      labelEn: 'Healthy pancakes',
      labelRu: 'Полезные панкейки',
      aliasesEn: <String>['pancakes'],
      aliasesRu: <String>['панкейки', 'оладьи'],
    ),
    _RecipePromptEntry(
      labelEn: 'Sandwich',
      labelRu: 'Сэндвич',
      aliasesEn: <String>['sandwich'],
      aliasesRu: <String>['сэндвич', 'бутерброд'],
    ),
    _RecipePromptEntry(
      labelEn: 'Smoothie',
      labelRu: 'Смузи',
      aliasesEn: <String>['smoothie'],
      aliasesRu: <String>['смузи'],
    ),
  ];

  static List<SuggestionOption> collectProductSuggestions({
    required bool isRu,
    Iterable<Map<String, dynamic>> pantryItems = const <Map<String, dynamic>>[],
    Iterable<Map<String, dynamic>> shoppingItems =
        const <Map<String, dynamic>>[],
  }) {
    final suggestions = <SuggestionOption>[];
    final seen = <String>{};

    void addSuggestion(SuggestionOption option) {
      final key = _normalize(option.primaryText);
      if (key.isEmpty || !seen.add(key)) return;
      suggestions.add(option);
    }

    for (final item in pantryItems) {
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final brand = item['brand']?.toString().trim();
      final category = item['category']?.toString().trim();
      final pantryUnit = _normalizePantryUnit(item['unit']?.toString());
      addSuggestion(
        SuggestionOption(
          primaryText: name,
          source: SuggestionSource.pantry,
          secondaryText: _composeProductSecondary(
            isRu: isRu,
            source: SuggestionSource.pantry,
            category: category,
            brand: brand,
          ),
          category: category,
          brand: brand,
          pantryUnit: pantryUnit,
          shoppingUnit: _shoppingUnitLabel(
            pantryUnit ?? item['unit']?.toString(),
            isRu: isRu,
          ),
          quantity: item['quantity']?.toString(),
          searchTerms: <String>[
            name,
            if (brand != null) brand,
            if (category != null) category,
          ],
        ),
      );
    }

    for (final item in shoppingItems) {
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final unit = item['unit']?.toString().trim();
      addSuggestion(
        SuggestionOption(
          primaryText: name,
          source: SuggestionSource.shopping,
          secondaryText: _composeProductSecondary(
            isRu: isRu,
            source: SuggestionSource.shopping,
            category: unit,
          ),
          shoppingUnit: unit,
          quantity: item['quantity']?.toString(),
          searchTerms: <String>[name, if (unit != null) unit],
        ),
      );
    }

    for (final entry in _catalogEntries) {
      final label = entry.label(isRu: isRu);
      addSuggestion(
        SuggestionOption(
          primaryText: label,
          source: SuggestionSource.catalog,
          secondaryText: _composeProductSecondary(
            isRu: isRu,
            source: SuggestionSource.catalog,
            category: entry.category(isRu: isRu),
          ),
          category: entry.category(isRu: isRu),
          pantryUnit:
              _normalizePantryUnit(entry.pantryUnit) ?? entry.pantryUnit,
          shoppingUnit: _shoppingUnitLabel(entry.pantryUnit, isRu: isRu),
          quantity: entry.quantity,
          searchTerms: entry.searchTerms,
        ),
      );
    }

    return suggestions;
  }

  static List<SuggestionOption> buildProductSuggestions({
    required String query,
    required bool isRu,
    Iterable<Map<String, dynamic>> pantryItems = const <Map<String, dynamic>>[],
    Iterable<Map<String, dynamic>> shoppingItems =
        const <Map<String, dynamic>>[],
    int limit = 8,
  }) {
    return rankSuggestions(
      collectProductSuggestions(
        isRu: isRu,
        pantryItems: pantryItems,
        shoppingItems: shoppingItems,
      ),
      query: query,
      limit: limit,
    );
  }

  static List<SuggestionOption> collectCategorySuggestions({
    required bool isRu,
    Iterable<Map<String, dynamic>> pantryItems = const <Map<String, dynamic>>[],
  }) {
    final suggestions = <SuggestionOption>[];
    final seen = <String>{};

    void addCategory(String value, SuggestionSource source) {
      final category = value.trim();
      if (category.isEmpty) return;
      final key = _normalize(category);
      if (!seen.add(key)) return;
      suggestions.add(
        SuggestionOption(
          primaryText: category,
          source: source,
          secondaryText: source == SuggestionSource.catalog
              ? (isRu ? 'Категория из каталога' : 'Catalog category')
              : (isRu ? 'Категория из вашей кладовой' : 'From your pantry'),
          searchTerms: <String>[category],
        ),
      );
    }

    for (final item in pantryItems) {
      addCategory(item['category']?.toString() ?? '', SuggestionSource.pantry);
    }
    for (final entry in _catalogEntries) {
      addCategory(entry.category(isRu: isRu), SuggestionSource.catalog);
    }

    return suggestions;
  }

  static List<SuggestionOption> buildCategorySuggestions({
    required String query,
    required bool isRu,
    Iterable<Map<String, dynamic>> pantryItems = const <Map<String, dynamic>>[],
    int limit = 6,
  }) {
    return rankSuggestions(
      collectCategorySuggestions(isRu: isRu, pantryItems: pantryItems),
      query: query,
      limit: limit,
    );
  }

  static List<SuggestionOption> collectRecipeSuggestions({
    required bool isRu,
    Iterable<SearchHistoryEntry> history = const <SearchHistoryEntry>[],
    Iterable<String> keywords = const <String>[],
  }) {
    final suggestions = <SuggestionOption>[];
    final seen = <String>{};

    void addSuggestion(SuggestionOption option) {
      final key = _normalize(option.primaryText);
      if (key.isEmpty || !seen.add(key)) return;
      suggestions.add(option);
    }

    for (final entry in history) {
      final value = entry.displayText.trim();
      if (value.isEmpty) continue;
      addSuggestion(
        SuggestionOption(
          primaryText: value,
          source: SuggestionSource.history,
          secondaryText: isRu ? 'Из истории поиска' : 'From search history',
          searchTerms: <String>[
            value,
            if ((entry.titleQuery ?? '').trim().isNotEmpty) entry.titleQuery!,
            if ((entry.categoryQuery ?? '').trim().isNotEmpty)
              entry.categoryQuery!,
          ],
        ),
      );
    }

    for (final keyword in keywords) {
      final value = keyword.trim();
      if (value.isEmpty) continue;
      addSuggestion(
        SuggestionOption(
          primaryText: value,
          source: SuggestionSource.keyword,
          secondaryText: isRu ? 'Быстрый вариант' : 'Quick pick',
          searchTerms: <String>[value],
        ),
      );
    }

    for (final prompt in _recipePromptEntries) {
      final label = prompt.label(isRu: isRu);
      addSuggestion(
        SuggestionOption(
          primaryText: label,
          source: SuggestionSource.catalog,
          secondaryText: isRu ? 'Идея для рецепта' : 'Recipe idea',
          searchTerms: prompt.searchTerms,
        ),
      );
    }

    for (final entry in _catalogEntries) {
      final label = entry.label(isRu: isRu);
      addSuggestion(
        SuggestionOption(
          primaryText: label,
          source: SuggestionSource.catalog,
          secondaryText: isRu ? 'Ингредиент' : 'Ingredient',
          searchTerms: entry.searchTerms,
        ),
      );
    }

    return suggestions;
  }

  static List<SuggestionOption> buildRecipeSuggestions({
    required String query,
    required bool isRu,
    Iterable<SearchHistoryEntry> history = const <SearchHistoryEntry>[],
    Iterable<String> keywords = const <String>[],
    int limit = 8,
  }) {
    return rankSuggestions(
      collectRecipeSuggestions(
        isRu: isRu,
        history: history,
        keywords: keywords,
      ),
      query: query,
      limit: limit,
    );
  }

  static List<SuggestionOption> collectMealSuggestions({
    required bool isRu,
    Iterable<Map<String, dynamic>> mealItems = const <Map<String, dynamic>>[],
  }) {
    final suggestions = <SuggestionOption>[];
    final seen = <String>{};

    void addSuggestion(SuggestionOption option) {
      final key = _normalize(option.primaryText);
      if (key.isEmpty || !seen.add(key)) return;
      suggestions.add(option);
    }

    for (final item in mealItems) {
      final title = item['title']?.toString().trim() ?? '';
      if (title.isEmpty) continue;
      final calories = _parseInt(item['calories']);
      final protein = _parseDouble(item['proteins'] ?? item['protein']);
      final fat = _parseDouble(item['fats'] ?? item['fat']);
      final carbs = _parseDouble(
        item['carbohydrates'] ?? item['carbs'] ?? item['carbohydrate'],
      );
      final notes = item['notes']?.toString().trim();
      addSuggestion(
        SuggestionOption(
          primaryText: title,
          source: SuggestionSource.history,
          secondaryText: _composeMealSecondary(
            isRu: isRu,
            source: SuggestionSource.history,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
          ),
          calories: calories,
          protein: protein,
          fat: fat,
          carbs: carbs,
          searchTerms: <String>[
            title,
            if (notes != null && notes.isNotEmpty) notes,
          ],
        ),
      );
    }

    for (final prompt in _mealPromptEntries) {
      addSuggestion(
        SuggestionOption(
          primaryText: prompt.label(isRu: isRu),
          source: SuggestionSource.catalog,
          secondaryText: _composeMealSecondary(
            isRu: isRu,
            source: SuggestionSource.catalog,
            calories: prompt.calories,
            protein: prompt.protein,
            fat: prompt.fat,
            carbs: prompt.carbs,
          ),
          calories: prompt.calories,
          protein: prompt.protein,
          fat: prompt.fat,
          carbs: prompt.carbs,
          searchTerms: prompt.searchTerms,
        ),
      );
    }

    return suggestions;
  }

  static List<SuggestionOption> buildMealSuggestions({
    required String query,
    required bool isRu,
    Iterable<Map<String, dynamic>> mealItems = const <Map<String, dynamic>>[],
    int limit = 8,
  }) {
    return rankSuggestions(
      collectMealSuggestions(isRu: isRu, mealItems: mealItems),
      query: query,
      limit: limit,
    );
  }

  static List<SuggestionOption> rankSuggestions(
    List<SuggestionOption> suggestions, {
    required String query,
    required int limit,
  }) {
    final normalizedQuery = _normalize(query);
    if (suggestions.isEmpty) return const <SuggestionOption>[];
    if (normalizedQuery.isEmpty) {
      return suggestions.take(limit).toList();
    }

    final ranked = suggestions
        .map(
          (option) => _RankedSuggestion(
            option: option,
            score: _scoreSuggestion(option, normalizedQuery),
          ),
        )
        .where((entry) => normalizedQuery.isEmpty || entry.score >= 560)
        .toList();

    ranked.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) return byScore;
      final byLength = left.option.primaryText.length.compareTo(
        right.option.primaryText.length,
      );
      if (byLength != 0) return byLength;
      return left.option.primaryText.compareTo(right.option.primaryText);
    });

    return ranked.take(limit).map((entry) => entry.option).toList();
  }

  static int _scoreSuggestion(SuggestionOption option, String normalizedQuery) {
    final sourceWeight = switch (option.source) {
      SuggestionSource.pantry => 220,
      SuggestionSource.shopping => 205,
      SuggestionSource.history => 200,
      SuggestionSource.keyword => 190,
      SuggestionSource.catalog => 170,
    };

    if (normalizedQuery.isEmpty) {
      return sourceWeight;
    }

    final primary = _normalize(option.primaryText);
    final terms = <String>{
      primary,
      ...option.searchTerms.map(_normalize),
    }.where((value) => value.isNotEmpty).toList();

    var score = sourceWeight;
    if (primary == normalizedQuery) {
      score += 1200;
    } else if (primary.startsWith(normalizedQuery)) {
      score +=
          1080 - _safeClamp(primary.length - normalizedQuery.length, 0, 60);
    } else if (_containsWordPrefix(primary, normalizedQuery)) {
      score += 930;
    } else if (_containsWholeWord(primary, normalizedQuery)) {
      score += 820;
    }

    final queryTokens = _tokens(normalizedQuery);
    var tokenMatches = 0;

    for (final term in terms) {
      if (term == normalizedQuery) {
        score = score > sourceWeight + 1180 ? score : sourceWeight + 1180;
      } else if (term.startsWith(normalizedQuery)) {
        score = score > sourceWeight + 1040
            ? score
            : sourceWeight +
                  1040 -
                  _safeClamp(term.length - normalizedQuery.length, 0, 60);
      } else if (_containsWordPrefix(term, normalizedQuery)) {
        score = score > sourceWeight + 900 ? score : sourceWeight + 900;
      } else if (_containsWholeWord(term, normalizedQuery)) {
        score = score > sourceWeight + 780 ? score : sourceWeight + 780;
      }

      if (queryTokens.isNotEmpty) {
        final matchedTokens = queryTokens.where((token) {
          return term == token ||
              term.startsWith(token) ||
              _containsWordPrefix(term, token);
        }).length;
        tokenMatches = matchedTokens > tokenMatches
            ? matchedTokens
            : tokenMatches;
      }

      if (normalizedQuery.length >= 4 && term.length <= 18) {
        final distance = _levenshtein(normalizedQuery, term);
        if (distance <= 2) {
          final fuzzy = sourceWeight + 680 - (distance * 70);
          score = score > fuzzy ? score : fuzzy;
        }
      }
    }

    score += tokenMatches * 85;
    score -= (_tokens(primary).length - 1) * 16;
    score -= _safeClamp((primary.length - normalizedQuery.length).abs(), 0, 40);
    return score;
  }

  static String? _normalizePantryUnit(String? raw) {
    final unit = (raw ?? '').trim().toUpperCase();
    if (unit.isEmpty) return null;
    switch (unit) {
      case 'PIECE':
      case 'GRAM':
      case 'KILOGRAM':
      case 'MILLILITER':
      case 'LITER':
      case 'PACK':
      case 'BOTTLE':
      case 'CAN':
        return unit;
      case 'JAR':
        return 'PACK';
      case 'BAR':
        return 'PIECE';
      case 'PCS':
      case 'PC':
      case 'ШТ':
      case 'ШТ.':
        return 'PIECE';
      case 'G':
      case 'Г':
        return 'GRAM';
      case 'KG':
      case 'КГ':
        return 'KILOGRAM';
      case 'ML':
      case 'МЛ':
        return 'MILLILITER';
      case 'L':
      case 'Л':
        return 'LITER';
      default:
        return null;
    }
  }

  static String _shoppingUnitLabel(String? raw, {required bool isRu}) {
    switch (_normalizePantryUnit(raw)) {
      case 'PIECE':
        return isRu ? 'шт' : 'pcs';
      case 'GRAM':
        return isRu ? 'г' : 'g';
      case 'KILOGRAM':
        return isRu ? 'кг' : 'kg';
      case 'MILLILITER':
        return isRu ? 'мл' : 'ml';
      case 'LITER':
        return isRu ? 'л' : 'l';
      case 'PACK':
        return isRu ? 'уп.' : 'pack';
      case 'BOTTLE':
        return isRu ? 'бут.' : 'bottle';
      case 'CAN':
        return isRu ? 'банка' : 'can';
      default:
        final text = raw?.trim() ?? '';
        return text;
    }
  }

  static String _composeProductSecondary({
    required bool isRu,
    required SuggestionSource source,
    String? category,
    String? brand,
  }) {
    final parts = <String>[
      switch (source) {
        SuggestionSource.pantry => isRu ? 'Из кладовой' : 'From pantry',
        SuggestionSource.shopping =>
          isRu ? 'Из списка покупок' : 'From shopping list',
        SuggestionSource.history => isRu ? 'Из истории' : 'From history',
        SuggestionSource.keyword => isRu ? 'Быстрый вариант' : 'Quick pick',
        SuggestionSource.catalog => isRu ? 'Каталог' : 'Catalog',
      },
    ];
    if ((category ?? '').trim().isNotEmpty) {
      parts.add(category!.trim());
    }
    if ((brand ?? '').trim().isNotEmpty) {
      parts.add(brand!.trim());
    }
    return parts.join(' • ');
  }

  static String _composeMealSecondary({
    required bool isRu,
    required SuggestionSource source,
    int? calories,
    double? protein,
    double? fat,
    double? carbs,
  }) {
    final parts = <String>[
      switch (source) {
        SuggestionSource.pantry => isRu ? 'Из кладовой' : 'From pantry',
        SuggestionSource.shopping =>
          isRu ? 'Из списка покупок' : 'From shopping list',
        SuggestionSource.history =>
          isRu ? 'Из истории приёмов пищи' : 'From meal history',
        SuggestionSource.keyword => isRu ? 'Быстрый вариант' : 'Quick pick',
        SuggestionSource.catalog =>
          isRu ? 'Каталог приёмов пищи' : 'Meal catalog',
      },
    ];

    if (calories != null && calories > 0) {
      parts.add(isRu ? '$calories ккал' : '$calories kcal');
    }

    String formatMacro(String labelRu, String labelEn, double? value) {
      if (value == null) return '';
      final rounded = value >= 10
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return isRu ? '$labelRu $rounded г' : '$labelEn $rounded g';
    }

    final macros = <String>[
      formatMacro('Б', 'P', protein),
      formatMacro('Ж', 'F', fat),
      formatMacro('У', 'C', carbs),
    ].where((value) => value.isNotEmpty);

    parts.addAll(macros);
    return parts.join(' • ');
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{Nd}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _tokens(String value) {
    return _normalize(
      value,
    ).split(' ').where((token) => token.trim().length >= 2).toList();
  }

  static bool _containsWordPrefix(String haystack, String needle) {
    if (needle.isEmpty) return false;
    for (final token in _tokens(haystack)) {
      if (token.startsWith(needle)) return true;
    }
    return false;
  }

  static bool _containsWholeWord(String haystack, String needle) {
    if (needle.isEmpty) return false;
    return _tokens(haystack).contains(needle);
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final insertCost = current[j] + 1;
        final deleteCost = previous[j + 1] + 1;
        final replaceCost =
            previous[j] + (a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1);
        current[j + 1] = insertCost < deleteCost
            ? (insertCost < replaceCost ? insertCost : replaceCost)
            : (deleteCost < replaceCost ? deleteCost : replaceCost);
      }
      for (var j = 0; j < previous.length; j++) {
        previous[j] = current[j];
      }
    }
    return previous.last;
  }

  static int _safeClamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim());
  }

  static double? _parseDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }
}

class _CatalogFoodEntry {
  const _CatalogFoodEntry({
    required this.nameEn,
    required this.nameRu,
    required this.categoryEn,
    required this.categoryRu,
    required this.pantryUnit,
    required this.quantity,
    this.aliasesEn = const <String>[],
    this.aliasesRu = const <String>[],
  });

  final String nameEn;
  final String nameRu;
  final String categoryEn;
  final String categoryRu;
  final String pantryUnit;
  final String quantity;
  final List<String> aliasesEn;
  final List<String> aliasesRu;

  String label({required bool isRu}) => isRu ? nameRu : nameEn;

  String category({required bool isRu}) => isRu ? categoryRu : categoryEn;

  List<String> get searchTerms => <String>[
    nameEn,
    nameRu,
    categoryEn,
    categoryRu,
    ...aliasesEn,
    ...aliasesRu,
  ];
}

class _RecipePromptEntry {
  const _RecipePromptEntry({
    required this.labelEn,
    required this.labelRu,
    this.aliasesEn = const <String>[],
    this.aliasesRu = const <String>[],
  });

  final String labelEn;
  final String labelRu;
  final List<String> aliasesEn;
  final List<String> aliasesRu;

  String label({required bool isRu}) => isRu ? labelRu : labelEn;

  List<String> get searchTerms => <String>[
    labelEn,
    labelRu,
    ...aliasesEn,
    ...aliasesRu,
  ];
}

class _MealPromptEntry {
  const _MealPromptEntry({
    required this.labelEn,
    required this.labelRu,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.aliasesEn = const <String>[],
    this.aliasesRu = const <String>[],
  });

  final String labelEn;
  final String labelRu;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final List<String> aliasesEn;
  final List<String> aliasesRu;

  String label({required bool isRu}) => isRu ? labelRu : labelEn;

  List<String> get searchTerms => <String>[
    labelEn,
    labelRu,
    ...aliasesEn,
    ...aliasesRu,
  ];
}

class _RankedSuggestion {
  const _RankedSuggestion({required this.option, required this.score});

  final SuggestionOption option;
  final int score;
}
