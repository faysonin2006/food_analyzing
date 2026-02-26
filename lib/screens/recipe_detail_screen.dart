import 'package:flutter/material.dart';

import '../core/tr.dart';
import '../services/api_service.dart';
import '../services/likes_service.dart';
import 'recipe_models.dart';

class _RestrictionTag {
  final String key;
  final String type;
  final String status;

  const _RestrictionTag({
    required this.key,
    required this.type,
    required this.status,
  });
}

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  final RecipeSummary? seed;

  const RecipeDetailScreen({super.key, required this.recipeId, this.seed});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  static const Color _accentOrange = Color(0xFFF2A62B);

  final api = ApiService();
  final likes = LikesService.instance;
  late final Future<RecipeDetails?> future;
  bool _likeBusy = false;

  static const List<String> _placeholders = [
    'assets/images/recipe_placeholder1.png',
    'assets/images/recipe_placeholder2.png',
  ];

  @override
  void initState() {
    super.initState();
    likes.addListener(_onLikesChanged);
    future = api.getRecipeDetails(
      recipeId: widget.recipeId,
      seedSummary: widget.seed,
    );
    likes.ensureLoaded();
  }

  @override
  void dispose() {
    likes.removeListener(_onLikesChanged);
    super.dispose();
  }

  ThemeData get _theme => Theme.of(context);

  ColorScheme get _colorScheme => _theme.colorScheme;

  bool get _isDarkTheme => _theme.brightness == Brightness.dark;

  Color get _screenBackground =>
      _isDarkTheme ? _theme.scaffoldBackgroundColor : const Color(0xFFEED0A5);

  Color get _sheetBackground =>
      _isDarkTheme ? _colorScheme.surface : const Color(0xFFEDEDEF);

  Color get _cardBackground =>
      _isDarkTheme ? _colorScheme.surfaceContainer : const Color(0xFFF4F4F5);

  Color get _softCardBackground => _isDarkTheme
      ? _colorScheme.surfaceContainerHighest
      : const Color(0xFFF0E4D2);

  Color get _outlineColor => _isDarkTheme
      ? _colorScheme.outlineVariant.withValues(alpha: 0.55)
      : const Color(0xFFD8D0C5);

  Color get _mutedTextColor => _isDarkTheme
      ? _colorScheme.onSurfaceVariant
      : Colors.black.withValues(alpha: 0.62);

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';

  void _onLikesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _pickPlaceholder(int key) =>
      _placeholders[key.abs() % _placeholders.length];

  bool _isBadImageUrl(String? image) {
    final url = (image ?? '').trim().toLowerCase();
    if (url.isEmpty) return true;
    return url.contains('img.sndimg.com') &&
        url.contains('fdc-sharegraphic.png');
  }

  String? _cleanText(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

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

  String? _formatTimeText(String? raw) {
    final text = _cleanText(raw);
    if (text == null || _isInvalidTimeText(text)) return null;
    final minutes = _parseTimeToMinutes(text);
    if (minutes == null || minutes <= 0) return null;
    return _formatMinutes(minutes);
  }

  String _servesText(RecipeDetails r) {
    final serves = (r.ingredients.length / 2).clamp(1, 8).round();
    return '$serves ${_isRu ? 'порц.' : 'serve'}';
  }

  List<NutritionItem> _allNutrients(RecipeDetails r) {
    if (r.nutritions.isNotEmpty) {
      return r.nutritions
          .where(
            (n) =>
                n.nutrient.trim().isNotEmpty && n.amount.toString().isNotEmpty,
          )
          .toList();
    }

    final seed = widget.seed;
    if (seed == null) return const [];

    final out = <NutritionItem>[];
    if (seed.calories != null) {
      out.add(
        NutritionItem(
          nutrient: _isRu ? 'Калории' : 'Calories',
          amount: seed.calories!.round().toString(),
          unit: tr(context, 'kcal'),
        ),
      );
    }
    if (seed.protein != null) {
      out.add(
        NutritionItem(
          nutrient: tr(context, 'protein'),
          amount: seed.protein!.toStringAsFixed(1),
          unit: tr(context, 'grams'),
        ),
      );
    }
    if (seed.fat != null) {
      out.add(
        NutritionItem(
          nutrient: tr(context, 'fats'),
          amount: seed.fat!.toStringAsFixed(1),
          unit: tr(context, 'grams'),
        ),
      );
    }
    if (seed.carbs != null) {
      out.add(
        NutritionItem(
          nutrient: tr(context, 'carbs'),
          amount: seed.carbs!.toStringAsFixed(1),
          unit: tr(context, 'grams'),
        ),
      );
    }
    return out;
  }

  String _nutritionValue(NutritionItem n) {
    var value = n.amount.trim();
    var unit = (n.unit ?? '').trim();
    if (value.isEmpty && unit.isEmpty) return '-';
    if (_isRu) {
      value = value.replaceAll('.', ',');
    }
    final hasUnitInsideValue = RegExp(r'[A-Za-zА-Яа-я%]+').hasMatch(value);
    if (!hasUnitInsideValue && unit.isEmpty) {
      unit = _defaultNutritionUnit(n.nutrient);
    }
    if (hasUnitInsideValue || unit.isEmpty) return value;
    return '$value $unit'.trim();
  }

  String _humanizeNutrientToken(String raw) {
    final normalized = raw
        .replaceAll(RegExp('content', caseSensitive: false), '')
        .replaceAll(RegExp('содержание', caseSensitive: false), '')
        .replaceAll(RegExp('содержан', caseSensitive: false), '')
        .trim();

    final cleaned = normalized
        .replaceAll(RegExp(r'^[\s:;.,-]+'), '')
        .replaceAll(RegExp(r'[\s:;.,-]+$'), '')
        .trim();
    if (cleaned.isEmpty) return '';

    final withSpaces = cleaned
        .replaceAllMapped(
          RegExp(r'([a-zа-я])([A-ZА-Я])'),
          (m) => '${m.group(1)} ${m.group(2)}',
        )
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (withSpaces.isEmpty) return '';
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  String _nutritionKind(String raw) {
    final lower = _humanizeNutrientToken(raw).toLowerCase();
    if (lower.contains('cal') ||
        lower.contains('kcal') ||
        lower.contains('энерг')) {
      return 'calories';
    }
    if (lower.contains('protein') || lower.contains('бел')) return 'protein';
    if (lower.contains('fat') ||
        lower.contains('жир') ||
        lower.contains('lipid')) {
      return 'fats';
    }
    if (lower.contains('carb') ||
        lower.contains('carbo') ||
        lower.contains('углев')) {
      return 'carbs';
    }
    if (lower.contains('sugar') ||
        lower.contains('сахар') ||
        lower.contains('glucose')) {
      return 'sugar';
    }
    if (lower.contains('fiber') || lower.contains('клетчат')) return 'fiber';
    if (lower.contains('sodium') || lower.contains('натрий')) return 'sodium';
    if (lower.contains('salt') || lower.contains('соль')) return 'salt';
    return 'other';
  }

  String _nutritionLabel(String raw) {
    return switch (_nutritionKind(raw)) {
      'calories' => tr(context, 'calories'),
      'protein' => tr(context, 'protein'),
      'fats' => tr(context, 'fats'),
      'carbs' => tr(context, 'carbs'),
      'sugar' => _isRu ? 'Сахар' : 'Sugar',
      'fiber' => _isRu ? 'Клетчатка' : 'Fiber',
      'sodium' => _isRu ? 'Натрий' : 'Sodium',
      'salt' => _isRu ? 'Соль' : 'Salt',
      _ => _humanizeNutrientToken(raw),
    };
  }

  String _defaultNutritionUnit(String raw) {
    return switch (_nutritionKind(raw)) {
      'calories' => tr(context, 'kcal'),
      'protein' ||
      'fats' ||
      'carbs' ||
      'sugar' ||
      'fiber' ||
      'salt' => tr(context, 'grams'),
      'sodium' => 'mg',
      _ => '',
    };
  }

  IconData _nutritionIcon(String raw) {
    return switch (_nutritionKind(raw)) {
      'calories' => Icons.local_fire_department_rounded,
      'protein' => Icons.fitness_center_rounded,
      'fats' => Icons.opacity_rounded,
      'carbs' => Icons.grain_rounded,
      'sugar' => Icons.icecream_outlined,
      'fiber' => Icons.eco_outlined,
      'sodium' => Icons.science_outlined,
      'salt' => Icons.restaurant_rounded,
      _ => Icons.bubble_chart_outlined,
    };
  }

  List<_RestrictionTag> _collectRestrictionTags(RecipeDetails r) {
    final out = <_RestrictionTag>[];

    void addMany(List<String> values, String type, String status) {
      for (final v in values) {
        final key = v.trim();
        if (key.isEmpty) continue;
        out.add(_RestrictionTag(key: key, type: type, status: status));
      }
    }

    addMany(r.blockDietKeys, 'DIET', 'BLOCK');
    addMany(r.blockAllergyKeys, 'ALLERGY', 'BLOCK');
    addMany(r.blockHealthKeys, 'HEALTH', 'BLOCK');
    addMany(r.cautionHealthKeys, 'HEALTH', 'CAUTION');

    for (final c in r.constraints) {
      final key = c.key.trim();
      if (key.isEmpty) continue;
      out.add(
        _RestrictionTag(
          key: key,
          type: c.type.trim().isEmpty ? 'CONSTRAINT' : c.type,
          status: c.status.trim().isEmpty ? 'UNKNOWN' : c.status,
        ),
      );
    }

    final unique = <String, _RestrictionTag>{};
    for (final t in out) {
      final id = '${t.type}|${t.status}|${t.key}';
      unique[id] = t;
    }
    return unique.values.toList();
  }

  Color _restrictionBg(String status) {
    final s = status.toUpperCase();
    if (s.contains('BLOCK') || s.contains('WARN') || s.contains('FAIL')) {
      return _isDarkTheme ? const Color(0xFF5F2D2A) : const Color(0xFFFFE8E5);
    }
    if (s.contains('CAUTION')) {
      return _isDarkTheme ? const Color(0xFF5D4622) : const Color(0xFFFFF3DD);
    }
    return _isDarkTheme
        ? _colorScheme.surfaceContainerHighest
        : const Color(0xFFF1F1F2);
  }

  Color _restrictionFg(String status) {
    final s = status.toUpperCase();
    if (s.contains('BLOCK') || s.contains('WARN') || s.contains('FAIL')) {
      return _isDarkTheme ? const Color(0xFFFFB4AB) : const Color(0xFFCB4B40);
    }
    if (s.contains('CAUTION')) {
      return _isDarkTheme ? const Color(0xFFFFD9A5) : const Color(0xFFD8881E);
    }
    return _isDarkTheme
        ? _colorScheme.onSurfaceVariant
        : const Color(0xFF60616A);
  }

  String _ingredientEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('tomato') || n.contains('помид')) return '🍅';
    if (n.contains('cheese') || n.contains('сыр')) return '🧀';
    if (n.contains('green') || n.contains('spinach') || n.contains('салат')) {
      return '🥬';
    }
    if (n.contains('onion') || n.contains('лук')) return '🧅';
    if (n.contains('chicken') || n.contains('кур')) return '🍗';
    if (n.contains('fish') || n.contains('рыб')) return '🐟';
    if (n.contains('egg') || n.contains('яй')) return '🥚';
    if (n.contains('milk') || n.contains('мол')) return '🥛';
    if (n.contains('rice') || n.contains('рис')) return '🍚';
    return '🍽️';
  }

  Color _ingredientColor(int index) {
    const colors = [
      Color(0xFFF9E6E1),
      Color(0xFFF8F0CC),
      Color(0xFFE0F3E2),
      Color(0xFFFBEBDD),
      Color(0xFFE6EDF9),
    ];
    return colors[index % colors.length];
  }

  RecipeDetails _mergeWithSeed(RecipeDetails details) {
    final seed = widget.seed;
    if (seed == null) return details;

    final title = details.title.trim().isEmpty ? seed.title : details.title;
    final image = (details.image ?? '').trim().isEmpty
        ? seed.image
        : details.image;
    final category = (details.category ?? '').trim().isEmpty
        ? seed.category
        : details.category;
    final times =
        details.times.hasAnyValue || (seed.totalTime ?? '').trim().isEmpty
        ? details.times
        : RecipeTimes(totalTime: seed.totalTime);

    return details.copyWith(
      title: title,
      image: image,
      category: category,
      times: times,
    );
  }

  Widget _heroImage(RecipeDetails r) {
    final fallback = _pickPlaceholder(r.id);
    if (_isBadImageUrl(r.image)) {
      return Image.asset(fallback, fit: BoxFit.cover);
    }
    return Image.network(
      r.image!.trim(),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.asset(fallback, fit: BoxFit.cover),
    );
  }

  Widget _topIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (_isDarkTheme ? Colors.black : const Color(0xFF1D2432))
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    final ok = await likes.toggle(widget.recipeId);
    if (!mounted) return;
    setState(() => _likeBusy = false);
    if (ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isRu ? 'Не удалось обновить лайк' : 'Failed to update like',
        ),
      ),
    );
  }

  Widget _metaItem({
    required IconData icon,
    required String text,
    Color? iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: iconColor ?? _accentOrange),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: _mutedTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _ingredientCard(
    IngredientItem item,
    int index, {
    required double width,
  }) {
    final name =
        (item.ingredient.isNotEmpty ? item.ingredient : item.rawText ?? '')
            .trim();
    final emoji = _ingredientEmoji(name);
    final sub = (item.quantityText ?? item.rawText ?? '').trim();
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outlineColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _ingredientColor(index),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? (_isRu ? 'Ингредиент' : 'Ingredient') : name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: _colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub.isNotEmpty ? sub : (_isRu ? '1 шт' : '1 item'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(InstructionStepItem step, int index) {
    final stepNo = step.position ?? (index + 1);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softCardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_isRu ? 'Шаг' : 'Step'} $stepNo',
            style: const TextStyle(
              color: _accentOrange,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.text.trim().isEmpty
                ? (_isRu ? 'Описание шага отсутствует' : 'No step description')
                : step.text,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: _colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(RecipeDetails raw) {
    final r = _mergeWithSeed(raw);
    final isLiked = likes.isLiked(widget.recipeId);
    final ingredients = r.ingredients;
    final category = _cleanText(r.category);
    final nutrients = _allNutrients(r);
    final restrictions = _collectRestrictionTags(r);
    final prepTime = _formatTimeText(r.times.prepTime);
    final cookTime = _formatTimeText(r.times.cookTime);
    final totalTime = _formatTimeText(r.times.totalTime);

    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
              child: Column(
                children: [
                  SizedBox(
                    height: 520,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: _heroImage(r),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: _topIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: _topIconButton(
                            icon: isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            iconColor: isLiked
                                ? const Color(0xFFFF6F7E)
                                : Colors.white,
                            onTap: _toggleLike,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                            decoration: BoxDecoration(
                              color: _sheetBackground,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: _isDarkTheme ? 0.24 : 0.08,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  r.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.04,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  category ??
                                      '${r.ingredients.length} ${_isRu ? 'ингредиентов' : 'ingredients'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _mutedTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _cardBackground,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: _outlineColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: _isDarkTheme ? 0.18 : 0.06,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceAround,
                                    runSpacing: 10,
                                    spacing: 20,
                                    children: [
                                      if (prepTime != null)
                                        _metaItem(
                                          icon: Icons.timer_outlined,
                                          text:
                                              '${tr(context, 'prep')}: $prepTime',
                                        ),
                                      if (cookTime != null)
                                        _metaItem(
                                          icon: Icons.soup_kitchen_outlined,
                                          text:
                                              '${tr(context, 'cook')}: $cookTime',
                                        ),
                                      if (totalTime != null)
                                        _metaItem(
                                          icon: Icons.access_time_rounded,
                                          text:
                                              '${tr(context, 'total')}: $totalTime',
                                        ),
                                      _metaItem(
                                        icon: Icons.adjust_rounded,
                                        text: _servesText(r),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(context, 'recipe_nutrients_title'),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (nutrients.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _outlineColor),
                      ),
                      child: Text(
                        _isRu
                            ? 'Нутриенты не указаны.'
                            : 'Nutrients are not set.',
                        style: TextStyle(
                          color: _mutedTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: nutrients
                          .where((n) => _nutritionLabel(n.nutrient).isNotEmpty)
                          .map(
                            (n) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _outlineColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _nutritionIcon(n.nutrient),
                                    size: 15,
                                    color: _accentOrange,
                                  ),
                                  const SizedBox(width: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: _colorScheme.onSurface,
                                        fontSize: 13,
                                        height: 1.15,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              '${_nutritionLabel(n.nutrient)}: ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: _nutritionValue(n),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: _mutedTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(context, 'recipe_restrictions_title'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (restrictions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _outlineColor),
                      ),
                      child: Text(
                        tr(context, 'recipe_restrictions_empty'),
                        style: TextStyle(
                          color: _mutedTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: restrictions.map((item) {
                        final fg = _restrictionFg(item.status);
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _restrictionBg(item.status),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: fg.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trValue(context, item.key),
                                style: TextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${trValue(context, item.type)} • ${trValue(context, item.status)}',
                                style: TextStyle(
                                  color: fg.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isRu ? 'Ингредиенты' : 'Ingredients',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ingredients.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _outlineColor),
                      ),
                      child: Text(
                        _isRu ? 'Нет данных' : 'No data',
                        style: TextStyle(
                          color: _mutedTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          children: List.generate(
                            ingredients.length,
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ingredientCard(
                                ingredients[i],
                                i,
                                width: constraints.maxWidth,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isRu
                          ? 'Инструкция приготовления'
                          : 'Cooking instruction',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (r.instructionSteps.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _softCardBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _isRu
                            ? 'Шаги приготовления отсутствуют.'
                            : 'Cooking steps are not available.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: _colorScheme.onSurface,
                        ),
                      ),
                    )
                  else
                    ...List.generate(
                      r.instructionSteps.length,
                      (i) => _stepCard(r.instructionSteps[i], i),
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
    return FutureBuilder<RecipeDetails?>(
      future: future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: _screenBackground,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) {
          return Scaffold(
            backgroundColor: _screenBackground,
            body: Center(
              child: Text(
                _isRu ? 'Не удалось загрузить рецепт' : 'Failed to load recipe',
              ),
            ),
          );
        }
        return _buildDetail(snap.data!);
      },
    );
  }
}
