import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/tr.dart';
import '../repositories/app_repository.dart';
import '../features/likes/likes.dart';
import 'recipe_detail_screen.dart';
import 'recipe_models.dart';

class LikedRecipesScreen extends StatefulWidget {
  const LikedRecipesScreen({super.key});

  @override
  State<LikedRecipesScreen> createState() => _LikedRecipesScreenState();
}

class _LikedRecipesScreenState extends State<LikedRecipesScreen> {
  final AppRepository _repository = AppRepository.instance;
  final LikesService _likes = LikesService.instance;
  final Map<int, RecipeSummary> _cache = {};
  final List<String> _placeholders = const [
    'assets/images/recipe_placeholder1.png',
    'assets/images/recipe_placeholder2.png',
  ];

  bool _loading = false;
  int _requestId = 0;
  List<RecipeSummary> _items = const [];

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  String get _feedbackSource => _isRu ? 'Избранное' : 'Favorites';

  @override
  void initState() {
    super.initState();
    _likes.addListener(_onLikesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadLikedRecipes());
  }

  @override
  void dispose() {
    _likes.removeListener(_onLikesChanged);
    super.dispose();
  }

  void _onLikesChanged() {
    _reloadLikedRecipes();
  }

  String _pickPlaceholder(int key) =>
      _placeholders[key.abs() % _placeholders.length];

  bool _isBadImageUrl(String? image) {
    final url = (image ?? '').trim().toLowerCase();
    if (url.isEmpty) return true;
    return url.contains('img.sndimg.com') &&
        url.contains('fdc-sharegraphic.png');
  }

  double? _extractCalories(List<NutritionItem> nutritions) {
    for (final n in nutritions) {
      final token = n.nutrient.trim().toLowerCase();
      if (!token.contains('cal') && !token.contains('энерг')) continue;
      final text = n.amount.trim().replaceAll(',', '.');
      final value = double.tryParse(text);
      if (value != null) return value;
    }
    return null;
  }

  RecipeSummary _fallbackSummary(int id) {
    return RecipeSummary(
      id: id,
      source: RecipeSource.db,
      title: _isRu ? 'Рецепт #$id' : 'Recipe #$id',
    );
  }

  RecipeSummary _summaryFromDetails(RecipeDetails details) {
    return RecipeSummary(
      id: details.id,
      source: details.source,
      title: details.title,
      image: details.image,
      category: details.category,
      totalTime: details.times.totalTime,
      readyInMinutes: details.times.totalMinutes,
      calories: _extractCalories(details.nutritions),
      ingredientsCount: details.ingredients.length,
      instructionsCount: details.instructionSteps.length,
    );
  }

  Future<void> _reloadLikedRecipes() async {
    final requestId = ++_requestId;
    if (!_loading && mounted) {
      setState(() => _loading = true);
    }

    await _likes.ensureLoaded();
    final ids = _likes.entries.map((e) => e.recipeId).toList();
    _cache.removeWhere((id, _) => !ids.contains(id));
    final missingIds = ids.where((id) => !_cache.containsKey(id)).toList();

    if (missingIds.isNotEmpty) {
      final loaded = await Future.wait(
        missingIds.map((id) async {
          final details = await _repository.getRecipeDetails(recipeId: id);
          if (details == null) return _fallbackSummary(id);
          return _summaryFromDetails(details);
        }),
      );
      for (final summary in loaded) {
        _cache[summary.id] = summary;
      }
    }

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _items = ids.map((id) => _cache[id] ?? _fallbackSummary(id)).toList();
      _loading = false;
    });
  }

  Future<void> _toggleLike(int recipeId) async {
    final ok = await _likes.unlike(recipeId);
    if (ok || !mounted) return;
    showAppFeedback(
      context,
      _isRu
          ? 'Не удалось удалить из избранного'
          : 'Failed to remove from favorites',
      kind: AppFeedbackKind.error,
      source: _feedbackSource,
      preferPopup: true,
    );
  }

  Widget _recipeImage(String? image, int recipeId) {
    final fallback = _pickPlaceholder(recipeId);
    if (_isBadImageUrl(image)) {
      return Image.asset(fallback, fit: BoxFit.cover);
    }
    return Image.network(
      image!.trim(),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.asset(fallback, fit: BoxFit.cover),
    );
  }

  Widget _emptyState(Color accent, Color onSurfaceVariant) {
    return AtelierEmptyState(
      icon: Icons.favorite_border_rounded,
      title: tr(context, 'liked_empty_title'),
      subtitle: tr(context, 'liked_empty_subtitle'),
      accent: accent,
    );
  }

  Widget _recipeCard(RecipeSummary recipe, ColorScheme cs) {
    final totalTime = (recipe.totalTime ?? '').trim();
    final isLiked = _likes.isLiked(recipe.id);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RecipeDetailScreen(recipeId: recipe.id, seed: recipe),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 98,
                height: 98,
                child: _recipeImage(recipe.image, recipe.id),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.04,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              (isLiked
                                      ? const Color(0xFFFF4F65)
                                      : cs.surfaceContainerHighest)
                                  .withValues(alpha: isLiked ? 0.14 : 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: _isRu ? 'Убрать лайк' : 'Remove like',
                          onPressed: isLiked
                              ? () => _toggleLike(recipe.id)
                              : null,
                          icon: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: isLiked
                                ? const Color(0xFFFF4F65)
                                : cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    recipe.category?.trim().isNotEmpty == true
                        ? recipe.category!
                        : (_isRu ? 'Без категории' : 'No category'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AtelierTagChip(
                        icon: Icons.inventory_2_outlined,
                        foreground: cs.primary,
                        label: _isRu
                            ? '${recipe.ingredientsCount} ингредиентов'
                            : '${recipe.ingredientsCount} ingredients',
                      ),
                      if (totalTime.isNotEmpty)
                        AtelierTagChip(
                          icon: Icons.access_time_rounded,
                          foreground: cs.tertiary,
                          label: totalTime,
                        ),
                      if (recipe.calories != null)
                        AtelierTagChip(
                          icon: Icons.local_fire_department_rounded,
                          foreground: cs.secondary,
                          label: '${recipe.calories!.round()} kcal',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppTopBar(title: tr(context, 'tab_liked'), actions: const []),
      body: RefreshIndicator(
        onRefresh: () async {
          await _likes.refresh();
          await _reloadLikedRecipes();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              _emptyState(cs.primary, cs.onSurfaceVariant)
            else
              ..._items.map(
                (recipe) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _recipeCard(recipe, cs),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
