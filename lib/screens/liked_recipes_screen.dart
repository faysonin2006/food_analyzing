import 'package:flutter/material.dart';

import '../core/app_top_bar.dart';
import '../core/tr.dart';
import '../services/api_service.dart';
import '../services/likes_service.dart';
import 'recipe_detail_screen.dart';
import 'recipe_models.dart';

class LikedRecipesScreen extends StatefulWidget {
  const LikedRecipesScreen({super.key});

  @override
  State<LikedRecipesScreen> createState() => _LikedRecipesScreenState();
}

class _LikedRecipesScreenState extends State<LikedRecipesScreen> {
  final ApiService _api = ApiService();
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
          final details = await _api.getRecipeDetails(recipeId: id);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isRu
              ? 'Не удалось удалить из избранного'
              : 'Failed to remove from liked recipes',
        ),
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 42,
                color: accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr(context, 'liked_empty_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, 'liked_empty_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(color: onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 92,
                height: 92,
                child: _recipeImage(recipe.image, recipe.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metaChip(
                        cs,
                        Icons.inventory_2_outlined,
                        _isRu
                            ? '${recipe.ingredientsCount} ингредиентов'
                            : '${recipe.ingredientsCount} ingredients',
                      ),
                      if (totalTime.isNotEmpty)
                        _metaChip(cs, Icons.access_time_rounded, totalTime),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _isRu ? 'Убрать лайк' : 'Remove like',
              onPressed: isLiked ? () => _toggleLike(recipe.id) : null,
              icon: Icon(
                isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isLiked
                    ? const Color(0xFFFF4F65)
                    : cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(ColorScheme cs, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenBg = isDark
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFF4D9B1);
    final panelBg = isDark
        ? Color.alphaBlend(
            cs.surfaceContainerHighest.withValues(alpha: 0.55),
            cs.surface,
          )
        : const Color(0xFFF6F6F7);

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppTopBar(title: tr(context, 'tab_liked'), actions: const []),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(34),
              bottom: Radius.circular(34),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              await _likes.refresh();
              await _reloadLikedRecipes();
            },
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      _emptyState(cs.primary, cs.onSurfaceVariant),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 120),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _recipeCard(_items[i], cs),
                  ),
          ),
        ),
      ),
    );
  }
}
