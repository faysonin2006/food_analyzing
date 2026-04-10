import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_feedback.dart';
import '../core/atelier_ui.dart';
import '../core/app_scope.dart';
import '../core/settings_sheet.dart';
import '../core/food_suggestions.dart';
import '../core/suggestion_panel.dart';
import '../core/tr.dart';
import '../local/search_history_local_db.dart';
import '../repositories/app_repository.dart';
import '../services/api_service.dart';
import '../features/likes/likes.dart';
import 'liked_recipes_screen.dart';
import 'recipe_detail_screen.dart';
import 'recipe_models.dart';
part 'recipe_search/recipe_search_ui.dart';

class _RecipePantryRank {
  final RecipeSummary recipe;
  final int originalIndex;
  final int matchingIngredientsCount;
  final int missingIngredientsCount;
  final double matchRatio;

  const _RecipePantryRank({
    required this.recipe,
    required this.originalIndex,
    required this.matchingIngredientsCount,
    required this.missingIngredientsCount,
    required this.matchRatio,
  });
}

const List<String> _recipeSearchQuickKeywordsEn = [
  'dessert',
  'breakfast',
  'chicken',
  'soup',
  'salad',
  'pasta',
  'rice',
  'healthy',
  'high protein',
  'mexican',
  'asian',
  'vegetable',
];

const List<String> _recipeSearchQuickKeywordsRu = [
  'десерт',
  'завтрак',
  'курица',
  'суп',
  'салат',
  'паста',
  'рис',
  'здоровый',
  'высокое содержание белка',
  'мексиканский',
  'азиатский',
  'овощной',
];

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key, this.onOpenOrganizerTap});

  final VoidCallback? onOpenOrganizerTap;

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  static const int _pageSize = 20;
  static const int _minIngredientTokenLength = 3;
  static const int _minIngredientPrefixMatchLength = 5;
  static const int _maxIngredientPrefixExtraChars = 3;
  static const List<String> _ingredientCanonicalSuffixes = [
    'иями',
    'ями',
    'ами',
    'ого',
    'его',
    'ому',
    'ему',
    'ыми',
    'ими',
    'ов',
    'ев',
    'ей',
    'ом',
    'ем',
    'ам',
    'ям',
    'ах',
    'ях',
    'ую',
    'юю',
    'ый',
    'ий',
    'ой',
    'ая',
    'яя',
    'ое',
    'ее',
    'ые',
    'ие',
    'ых',
    'их',
    'es',
    's',
    'ы',
    'и',
    'ь',
  ];

  final AppRepository repository = AppRepository.instance;
  final likes = LikesService.instance;
  final titleCtrl = TextEditingController();
  final _titleFocusNode = FocusNode();
  final keywordCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _resultsTopKey = GlobalKey();
  List<SearchHistoryEntry> _searchHistory = const [];
  bool _historyLoading = false;
  String? _lastLocaleCode;
  bool _dashboardLoading = false;
  List<Map<String, dynamic>> _recommendedPantryRecipes = const [];
  bool _pantryNamesReady = false;
  Future<void>? _pantryNamesLoadFuture;
  Set<String> _pantryNames = const {};
  List<SuggestionOption> _searchSuggestions = const [];

  String? diet;
  String? selectedKeyword;
  bool loading = false;
  bool searched = false;
  int currentPage = 1;
  bool hasNextPage = false;
  int? totalPages;
  List<RecipeSummary> results = [];
  int _activeSearchRequestId = 0;

  final diets = ['gluten free', 'ketogenic', 'vegetarian', 'vegan', 'paleo'];

  final List<String> _placeholders = const [
    'assets/images/recipe_placeholder1.png',
    'assets/images/recipe_placeholder2.png',
  ];

  bool get _isRu => AppScope.settingsOf(context).locale.languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => Theme.of(context).colorScheme;
  bool get _isDarkTheme => _theme.brightness == Brightness.dark;
  Color get _screenBackground => _theme.scaffoldBackgroundColor;
  String get _screenTitle => _isRu ? 'Рецепты' : 'Recipes';
  List<String> get _activeQuickKeywords =>
      _isRu ? _recipeSearchQuickKeywordsRu : _recipeSearchQuickKeywordsEn;
  String get _langUpper =>
      AppScope.settingsOf(context).locale.languageCode.trim().toUpperCase();

  String _errorText(Object error, String fallback) {
    if (error is ApiException) return error.message;
    final text = error.toString().trim();
    if (text.isEmpty) return fallback;
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _showMessage(
    String message, {
    AppFeedbackKind? kind,
    bool preferPopup = false,
    bool addToInbox = true,
  }) {
    if (!mounted) return;
    showAppFeedback(
      context,
      message,
      kind: kind,
      source: _screenTitle,
      preferPopup: preferPopup,
      addToInbox: addToInbox,
    );
  }

  Future<T> _loadWithFallback<T>({
    required Future<T> future,
    required T fallback,
    required List<String> errors,
    required String fallbackMessage,
  }) async {
    try {
      return await future;
    } catch (error) {
      errors.add(_errorText(error, fallbackMessage));
      return fallback;
    }
  }

  @override
  void initState() {
    super.initState();
    titleCtrl.addListener(_handleTitleInputChanged);
    _titleFocusNode.addListener(_handleTitleFocusChanged);
    likes.addListener(_onLikesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSearchHistory();
      _loadRecipeHighlights();
      _ensurePantryNamesLoaded();
      likes.ensureLoaded();
      _searchFromFirstPage();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = AppScope.settingsOf(context).locale.languageCode;

    if (_lastLocaleCode == null) {
      _lastLocaleCode = localeCode;
      return;
    }

    if (_lastLocaleCode != localeCode) {
      _lastLocaleCode = localeCode;
      setState(() {
        selectedKeyword = null;
        keywordCtrl.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || loading) return;
        _loadSearchHistory();
        _loadRecipeHighlights();
        _searchFromFirstPage();
      });
    }
  }

  @override
  void dispose() {
    titleCtrl.removeListener(_handleTitleInputChanged);
    _titleFocusNode.removeListener(_handleTitleFocusChanged);
    likes.removeListener(_onLikesChanged);
    titleCtrl.dispose();
    _titleFocusNode.dispose();
    keywordCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLikesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  bool _queryHasWrongAlphabet(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(normalized);
    final hasCyrillic = RegExp(r'[А-Яа-яЁё]').hasMatch(normalized);
    if (_isRu) {
      return hasLatin;
    }
    return hasCyrillic;
  }

  String _wrongAlphabetSearchMessage() {
    if (_isRu) {
      return 'В русском интерфейсе доступен поиск только по русским рецептам';
    }
    return 'English interface searches only English recipes';
  }

  void _handleTitleInputChanged() {
    if (!_titleFocusNode.hasFocus) return;
    _refreshSearchSuggestions();
  }

  void _handleTitleFocusChanged() {
    if (_titleFocusNode.hasFocus) {
      _refreshSearchSuggestions();
      return;
    }
    if (!mounted || _searchSuggestions.isEmpty) return;
    setState(() => _searchSuggestions = const []);
  }

  void _refreshSearchSuggestions() {
    final query = titleCtrl.text;
    if (_queryHasWrongAlphabet(query)) {
      if (mounted && _searchSuggestions.isNotEmpty) {
        setState(() => _searchSuggestions = const []);
      }
      return;
    }
    final candidates = FoodSuggestions.collectRecipeSuggestions(
      isRu: _isRu,
      history: _searchHistory,
      keywords: _activeQuickKeywords,
    );
    final local = FoodSuggestions.rankSuggestions(
      candidates,
      query: query,
      limit: 7,
    );
    if (!_sameSuggestionList(_searchSuggestions, local) && mounted) {
      setState(() => _searchSuggestions = local);
    }
  }

  bool _sameSuggestionList(
    List<SuggestionOption> left,
    List<SuggestionOption> right,
  ) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].primaryText != right[index].primaryText ||
          left[index].source != right[index].source) {
        return false;
      }
    }
    return true;
  }

  Future<void> _applySearchSuggestion(SuggestionOption option) async {
    _safeSetState(() {
      titleCtrl.text = option.primaryText;
      titleCtrl.selection = TextSelection.collapsed(
        offset: titleCtrl.text.length,
      );
      _searchSuggestions = const [];
    });
    _dismissKeyboard();
    await _searchFromFirstPage();
  }

  void _scrollToResultsTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchorContext = _resultsTopKey.currentContext;
      if (anchorContext != null) {
        Scrollable.ensureVisible(
          anchorContext,
          alignment: 0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _loadRecipeHighlights() async {
    if (_dashboardLoading) return;
    _safeSetState(() => _dashboardLoading = true);
    final errors = <String>[];
    final recommendationsFuture = _loadWithFallback<List<Map<String, dynamic>>>(
      future: repository.getRecommendedRecipes(
        size: _pageSize,
        lang: AppScope.settingsOf(context).locale.languageCode,
      ),
      fallback: _recommendedPantryRecipes,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить рекомендации из кладовой'
          : 'Failed to load pantry recommendations',
    );
    final recommendedPantryRecipes = await recommendationsFuture;

    if (!mounted) return;
    setState(() {
      _recommendedPantryRecipes = recommendedPantryRecipes;
      _dashboardLoading = false;
    });
    if (errors.isNotEmpty) {
      _showMessage(errors.toSet().join('\n'));
    }
  }

  Future<Set<String>> _ensurePantryNamesLoaded() async {
    if (_pantryNamesReady) return _pantryNames;
    final future = _pantryNamesLoadFuture ??= _loadPantryNames();
    await future;
    return _pantryNames;
  }

  Future<void> _loadPantryNames() async {
    try {
      final pantryItems = await repository.getPantryItems();
      _pantryNames = pantryItems
          .map((item) => _normalizeIngredientText(item['name']?.toString()))
          .where((value) => value.isNotEmpty)
          .toSet();
    } catch (_) {
      _pantryNames = const {};
    } finally {
      _pantryNamesReady = true;
      _pantryNamesLoadFuture = null;
    }
  }

  bool _recipeNeedsCardHydration(RecipeSummary recipe) {
    final missingTime =
        recipe.readyInMinutes == null &&
        (recipe.totalTime ?? '').trim().isEmpty;
    final missingNutrition =
        recipe.calories == null &&
        recipe.protein == null &&
        recipe.fat == null &&
        recipe.carbs == null;
    return missingTime || missingNutrition;
  }

  double? _extractNutritionValue(
    List<NutritionItem> nutritions,
    List<String> names,
  ) {
    final keys = names.map((value) => value.toLowerCase()).toList();
    for (final nutrition in nutritions) {
      final nutrient = nutrition.nutrient.toLowerCase();
      if (keys.any(nutrient.contains)) {
        return double.tryParse(
          nutrition.amount
              .trim()
              .replaceAll(',', '.')
              .replaceAll(RegExp(r'[^0-9.\-]'), ''),
        );
      }
    }
    return null;
  }

  RecipeSummary _mergeSummaryWithDetails(
    RecipeSummary recipe,
    RecipeDetails details,
  ) {
    final mergedTime = (recipe.totalTime ?? '').trim().isNotEmpty
        ? recipe.totalTime
        : details.times.totalTime;
    final mergedReadyMinutes =
        recipe.readyInMinutes ?? details.times.totalMinutes;

    return recipe.copyWith(
      image: _cleanText(recipe.image) ?? _cleanText(details.image),
      category: _cleanText(recipe.category) ?? _cleanText(details.category),
      totalTime: (mergedTime ?? '').trim().isEmpty ? null : mergedTime,
      readyInMinutes: mergedReadyMinutes,
      calories:
          recipe.calories ??
          _extractNutritionValue(details.nutritions, [
            'calories',
            'calorie',
            'kcal',
            'energy',
            'кал',
          ]),
      protein:
          recipe.protein ??
          _extractNutritionValue(details.nutritions, ['protein', 'белок']),
      fat:
          recipe.fat ??
          _extractNutritionValue(details.nutritions, ['fat', 'fats', 'жир']),
      carbs:
          recipe.carbs ??
          _extractNutritionValue(details.nutritions, [
            'carbohydrate',
            'carb',
            'carbs',
            'углевод',
          ]),
    );
  }

  Future<List<RecipeSummary>> _hydrateRecipeSummaries(
    List<RecipeSummary> recipes,
  ) async {
    final targets = <int>[
      for (var index = 0; index < recipes.length; index++)
        if (_recipeNeedsCardHydration(recipes[index])) index,
    ];
    if (targets.isEmpty) return recipes;

    final hydrated = List<RecipeSummary>.from(recipes);
    await Future.wait(
      targets.map((index) async {
        final seed = recipes[index];
        final details = await repository.getRecipeDetails(
          recipeId: seed.id,
          seedSummary: seed,
        );
        if (details == null) return;
        hydrated[index] = _mergeSummaryWithDetails(seed, details);
      }),
    );
    return hydrated;
  }

  String _canonicalIngredientToken(String token) {
    if (token.isEmpty) return token;
    if (token.endsWith('ies') && token.length > _minIngredientTokenLength + 2) {
      return '${token.substring(0, token.length - 3)}y';
    }
    for (final suffix in _ingredientCanonicalSuffixes) {
      if (!token.endsWith(suffix)) continue;
      final trimmed = token.substring(0, token.length - suffix.length);
      if (trimmed.length >= _minIngredientTokenLength) {
        return trimmed;
      }
    }
    return token;
  }

  String _normalizeIngredientText(String? value) {
    if (value == null) return '';
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{Nd}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _ingredientTokens(String value) => value
      .split(RegExp(r'\s+'))
      .map((token) => token.trim())
      .where((token) => token.length >= _minIngredientTokenLength)
      .toList();

  bool _hasMeaningfulIngredientPhraseOverlap(String left, String right) {
    if (!left.contains(' ') && !right.contains(' ')) {
      return false;
    }
    final shorterLength = left.length < right.length
        ? left.length
        : right.length;
    if (shorterLength < _minIngredientPrefixMatchLength) {
      return false;
    }
    return left.contains(right) || right.contains(left);
  }

  bool _hasSafeIngredientPrefixOverlap(String left, String right) {
    final shorter = left.length <= right.length ? left : right;
    final longer = identical(shorter, left) ? right : left;
    if (shorter.length < _minIngredientPrefixMatchLength) {
      return false;
    }
    if (!longer.startsWith(shorter)) {
      return false;
    }
    return longer.length - shorter.length <= _maxIngredientPrefixExtraChars;
  }

  bool _ingredientTokensPartiallyMatch(String left, String right) {
    if (left == right) return true;

    final leftCanonical = _canonicalIngredientToken(left);
    final rightCanonical = _canonicalIngredientToken(right);
    if (leftCanonical == rightCanonical) {
      return true;
    }

    return _hasSafeIngredientPrefixOverlap(left, right) ||
        _hasSafeIngredientPrefixOverlap(leftCanonical, rightCanonical);
  }

  bool _ingredientsCompatible(String ingredientName, String pantryName) {
    if (ingredientName == pantryName) {
      return true;
    }
    if (_hasMeaningfulIngredientPhraseOverlap(ingredientName, pantryName)) {
      return true;
    }
    final ingredientTokens = _ingredientTokens(ingredientName);
    final pantryTokens = _ingredientTokens(pantryName);
    for (final ingredientToken in ingredientTokens) {
      for (final pantryToken in pantryTokens) {
        if (_ingredientTokensPartiallyMatch(ingredientToken, pantryToken)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _ingredientInPantry(IngredientItem item) {
    if (_pantryNames.isEmpty) return false;
    final candidates = <String>{
      _normalizeIngredientText(item.ingredient),
      _normalizeIngredientText(item.note),
      _normalizeIngredientText(item.rawText),
      _normalizeIngredientText('${item.ingredient} ${item.note ?? ''}'),
    }..removeWhere((value) => value.isEmpty);

    for (final candidate in candidates) {
      for (final pantryName in _pantryNames) {
        if (_ingredientsCompatible(candidate, pantryName)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<_RecipePantryRank> _pantryRankRecipe(
    RecipeSummary recipe,
    int originalIndex,
  ) async {
    final details = await repository.getRecipeDetails(
      recipeId: recipe.id,
      seedSummary: recipe,
    );
    final ingredients = details?.ingredients ?? const <IngredientItem>[];
    if (ingredients.isEmpty) {
      return _RecipePantryRank(
        recipe: recipe,
        originalIndex: originalIndex,
        matchingIngredientsCount: 0,
        missingIngredientsCount: 0,
        matchRatio: 0,
      );
    }

    final matchingCount = ingredients.where(_ingredientInPantry).length;
    final missingCount = ingredients.length - matchingCount;
    return _RecipePantryRank(
      recipe: recipe,
      originalIndex: originalIndex,
      matchingIngredientsCount: matchingCount,
      missingIngredientsCount: missingCount < 0 ? 0 : missingCount,
      matchRatio: matchingCount / ingredients.length,
    );
  }

  Future<List<RecipeSummary>> _rankRecipesByPantry(
    List<RecipeSummary> recipes,
  ) async {
    if (recipes.length < 2) return recipes;
    await _ensurePantryNamesLoaded();
    if (_pantryNames.isEmpty) return recipes;

    final ranked = await Future.wait([
      for (var index = 0; index < recipes.length; index++)
        _pantryRankRecipe(recipes[index], index),
    ]);

    ranked.sort((left, right) {
      final byMatching = right.matchingIngredientsCount.compareTo(
        left.matchingIngredientsCount,
      );
      if (byMatching != 0) return byMatching;

      final byRatio = right.matchRatio.compareTo(left.matchRatio);
      if (byRatio != 0) return byRatio;

      final byMissing = left.missingIngredientsCount.compareTo(
        right.missingIngredientsCount,
      );
      if (byMissing != 0) return byMissing;

      return left.originalIndex.compareTo(right.originalIndex);
    });

    return ranked.map((entry) => entry.recipe).toList();
  }

  String _buildHistoryQueryText({
    required String title,
    required String category,
    String? dietValue,
  }) {
    final parts = <String>[
      if (title.trim().isNotEmpty) title.trim(),
      if (category.trim().isNotEmpty) _keywordLabel(category.trim()),
      if ((dietValue ?? '').trim().isNotEmpty) _dietLabel(dietValue!.trim()),
    ];
    return parts.join(' • ').trim();
  }

  String _composeSearchQuery(String title, String keyword) {
    final parts = <String>[];
    final normalized = <String>{};

    void addPart(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final key = trimmed.toLowerCase();
      if (!normalized.add(key)) return;
      parts.add(trimmed);
    }

    addPart(title);
    addPart(keyword);
    return parts.join(' ').trim();
  }

  Future<void> _loadSearchHistory() async {
    if (_historyLoading) return;
    setState(() => _historyLoading = true);
    final entries = await repository.getSearchHistory(
      lang: _langUpper,
      limit: 20,
    );
    if (!mounted) return;
    setState(() {
      _searchHistory = entries;
      _historyLoading = false;
    });
    if (_titleFocusNode.hasFocus) {
      _refreshSearchSuggestions();
    }
  }

  Future<void> _saveSearchHistoryEntry({
    required String title,
    required String category,
    required String? dietValue,
  }) async {
    final queryText = _buildHistoryQueryText(
      title: title,
      category: category,
      dietValue: dietValue,
    );
    if (queryText.isEmpty) return;

    await repository.saveSearchHistory(
      SearchHistoryDraft(
        queryText: queryText,
        titleQuery: _cleanText(title),
        categoryQuery: _cleanText(category),
        dietQuery: _cleanText(dietValue),
        lang: _langUpper,
      ),
    );
    if (!mounted) return;
    await _loadSearchHistory();
  }

  Future<void> _applySearchHistoryEntry(SearchHistoryEntry entry) async {
    _dismissKeyboard();
    setState(() {
      titleCtrl.text = entry.titleQuery ?? '';
      selectedKeyword = _cleanText(entry.categoryQuery);
      keywordCtrl.text = selectedKeyword ?? '';
      diet = _cleanText(entry.dietQuery);
      _searchSuggestions = const [];
    });
    await _searchFromFirstPage();
  }

  Future<void> _deleteSearchHistoryEntry(int id) async {
    await repository.deleteSearchHistoryItem(id);
    if (!mounted) return;
    await _loadSearchHistory();
  }

  Future<void> _clearSearchHistory() async {
    await repository.clearSearchHistory(lang: _langUpper);
    if (!mounted) return;
    setState(() => _searchHistory = const []);
  }

  void _openLikedRecipes() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LikedRecipesScreen()))
        .then((_) => likes.refresh());
  }

  Future<void> _searchFromFirstPage() => search(page: 1);

  Future<void> search({int page = 1}) async {
    _dismissKeyboard();
    final requestedPage = page < 1 ? 1 : page;
    final previousPage = currentPage;
    final requestId = ++_activeSearchRequestId;
    final lang = AppScope.settingsOf(context).locale.languageCode;
    final selectedKeywordValue = (selectedKeyword ?? '').trim().isNotEmpty
        ? selectedKeyword!.trim()
        : keywordCtrl.text.trim();
    final titleQuery = titleCtrl.text.trim();
    final combinedQuery = _composeSearchQuery(titleQuery, selectedKeywordValue);

    if (_queryHasWrongAlphabet(combinedQuery)) {
      _showMessage(
        _wrongAlphabetSearchMessage(),
        kind: AppFeedbackKind.info,
        preferPopup: true,
        addToInbox: false,
      );
      return;
    }

    setState(() {
      loading = true;
      searched = true;
      _searchSuggestions = const [];
      if (requestedPage == 1) {
        results = [];
      }
    });

    try {
      final hasDirectTextSearch = combinedQuery.isNotEmpty;
      List<RecipeSummary> list;
      bool nextPageAvailable;
      int? pageCount;

      final pageResult = await repository.searchRecipesPage(
        diet: diet,
        title: combinedQuery,
        category: null,
        lang: lang,
        page: requestedPage,
        size: _pageSize,
      );
      list = hasDirectTextSearch
          ? pageResult.items
          : await _rankRecipesByPantry(pageResult.items);
      nextPageAvailable = pageResult.hasNext;
      pageCount = pageResult.totalPages;

      list = await _hydrateRecipeSummaries(list);

      if (!mounted || requestId != _activeSearchRequestId) return;
      if (requestedPage > 1 && list.isEmpty) {
        setState(() {
          loading = false;
          hasNextPage = false;
          currentPage = previousPage;
        });
        _showMessage(
          _isRu ? 'Это последняя страница' : 'This is the last page',
          kind: AppFeedbackKind.info,
          preferPopup: true,
          addToInbox: false,
        );
        return;
      }

      setState(() {
        loading = false;
        currentPage = requestedPage;
        hasNextPage = nextPageAvailable;
        totalPages = pageCount;
        results = list;
      });
      if (requestedPage == 1) {
        await _saveSearchHistoryEntry(
          title: titleCtrl.text,
          category: selectedKeywordValue,
          dietValue: diet,
        );
      }
      if (requestedPage != previousPage) {
        _scrollToResultsTop();
      }
    } catch (_) {
      if (!mounted || requestId != _activeSearchRequestId) return;
      setState(() {
        loading = false;
        currentPage = previousPage;
        if (requestedPage == 1) {
          results = [];
          totalPages = null;
        }
      });
      _showMessage(
        tr(context, 'search_error'),
        kind: AppFeedbackKind.error,
        preferPopup: true,
      );
    }
  }

  Future<void> _goPrevPage() async {
    if (loading || currentPage <= 1) return;
    await search(page: currentPage - 1);
  }

  Future<void> _goNextPage() async {
    if (loading || !hasNextPage) return;
    await search(page: currentPage + 1);
  }

  Future<void> _openPageJump() async {
    final knownMaxPage = totalPages;

    final controller = TextEditingController(text: '$currentPage');
    final targetPage = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_isRu ? 'Перейти на страницу' : 'Go to page'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: _isRu ? 'Введите номер' : 'Enter page number',
            ),
            onSubmitted: (_) {
              final page = int.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(page);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_isRu ? 'Отмена' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(controller.text.trim());
                Navigator.of(dialogContext).pop(page);
              },
              child: Text(_isRu ? 'Перейти' : 'Go'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (targetPage == null) return;
    final normalizedPage = knownMaxPage != null
        ? targetPage.clamp(1, knownMaxPage)
        : (targetPage < 1 ? 1 : targetPage);
    if (normalizedPage == currentPage || loading) return;
    await search(page: normalizedPage);
  }

  Future<void> _toggleLike(int recipeId) async {
    final ok = await likes.toggle(recipeId);
    if (ok || !mounted) return;
    _showMessage(
      _isRu ? 'Не удалось обновить лайк' : 'Failed to update like',
      kind: AppFeedbackKind.error,
      preferPopup: true,
    );
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _dietLabel(String value) {
    if (!_isRu) return _titleCase(value);
    switch (value) {
      case 'gluten free':
        return 'Без глютена';
      case 'ketogenic':
        return 'Кетогенная';
      case 'vegetarian':
        return 'Вегетарианская';
      case 'vegan':
        return 'Веганская';
      case 'paleo':
        return 'Палео';
      default:
        return value;
    }
  }

  String _keywordLabel(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    final isCyrillic = RegExp(r'[А-Яа-я]').hasMatch(v);
    if (isCyrillic) return v;
    return _titleCase(v);
  }

  void _applyKeyword(String keyword) {
    final k = keyword.trim();
    if (k.isEmpty) return;
    if ((selectedKeyword ?? '').trim().toLowerCase() == k.toLowerCase()) {
      selectedKeyword = null;
      keywordCtrl.clear();
    } else {
      selectedKeyword = k;
      keywordCtrl.text = k;
    }
    _dismissKeyboard();
  }

  String? _cleanText(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  bool _isBadImageUrl(String? image) {
    final url = (image ?? '').trim().toLowerCase();
    if (url.isEmpty) return true;
    return url.contains('img.sndimg.com') &&
        url.contains('fdc-sharegraphic.png');
  }

  String _pickPlaceholder(int key) =>
      _placeholders[key.abs() % _placeholders.length];

  bool _isInvalidTimeText(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'none' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == '-' ||
        normalized == '--' ||
        normalized == '{}' ||
        normalized == '[]' ||
        normalized == 'unknown' ||
        normalized == 'неизвестно' ||
        RegExp(r'^0+([.,]0+)?$').hasMatch(normalized);
  }

  int? _parseTimeToMinutes(String? raw) {
    final text = raw?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(text)) return int.tryParse(text);

    int h = 0;
    int m = 0;
    for (final match in RegExp(
      r'(\d+)\s*(h|hr|hrs|hour|hours|ч)',
    ).allMatches(text)) {
      h += int.parse(match.group(1)!);
    }
    for (final match in RegExp(
      r'(\d+)\s*(m|min|mins|minute|minutes|мин)',
    ).allMatches(text)) {
      m += int.parse(match.group(1)!);
    }
    final hm = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(text);
    if (hm != null) {
      h = int.parse(hm.group(1)!);
      m = int.parse(hm.group(2)!);
    }
    final total = h * 60 + m;
    return total > 0 ? total : null;
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (_isRu) {
      if (h > 0 && m > 0) return '$h ч $m мин';
      if (h > 0) return '$h ч';
      return '$m мин';
    }
    if (h > 0 && m > 0) return '$h hr $m min';
    if (h > 0) return '$h hr';
    return '$m min';
  }

  String? _totalTimeLabel(RecipeSummary recipe) {
    final raw = _cleanText(recipe.totalTime);
    if (raw != null && !_isInvalidTimeText(raw)) {
      final minutes = _parseTimeToMinutes(raw);
      if (minutes != null && minutes > 0) return _formatMinutes(minutes);
      return null;
    }
    if (recipe.readyInMinutes != null && recipe.readyInMinutes! > 0) {
      return _formatMinutes(recipe.readyInMinutes!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final showResults = searched || loading || results.isNotEmpty;

    return Scaffold(
      backgroundColor: _screenBackground,
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadRecipeHighlights();
              await _loadSearchHistory();
              await likes.refresh();
              await _searchFromFirstPage();
            },
            child: ListView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              children: [
                _buildTopBlock(),
                const SizedBox(height: 24),
                if (!showResults) ...[
                  _buildSearchHistorySection(),
                  const SizedBox(height: 24),
                ],
                SizedBox(key: _resultsTopKey, height: 0),
                if (showResults) ...[
                  _buildRecommended(),
                  _buildPaginationControls(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
