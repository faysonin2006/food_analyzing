import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/app_theme.dart';
import '../core/atelier_ui.dart';
import '../core/tr.dart';
import '../repositories/app_repository.dart';
import '../services/api_service.dart';
import '../features/likes/likes.dart';
import 'recipe_models.dart';
part "recipe_detail/recipe_detail_ui.dart";

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
  static const Color _accentOrange = AppTheme.atelierGreen;
  static const int _minIngredientTokenLength = 3;
  static const int _minIngredientPrefixMatchLength = 5;
  static const int _maxIngredientPrefixExtraChars = 3;
  static const Map<String, String> _restrictionAliases = <String, String>{
    'TYPE_1_DIABETES': 'DIABETES_TYPE_1',
    'TYPE_2_DIABETES': 'DIABETES_TYPE_2',
    'GLUTEN_FREE': 'GLUTEN',
    'LACTOSE_FREE': 'LACTOSE',
    'DAIRY_FREE': 'LACTOSE',
    'KETOGENIC': 'KETO',
  };
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
  late final Future<RecipeDetails?> future;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final Set<int> _commentLikeBusyIds = <int>{};
  RecipeDetails? _detailsOverride;
  RecipeComment? _replyTarget;
  bool _likeBusy = false;
  bool _addingToShopping = false;
  bool _submittingComment = false;
  bool _pantryMatchesReady = false;
  bool _profileRestrictionsReady = false;
  Set<String> _pantryNames = const {};
  Set<String> _profileDietKeys = const {};
  Set<String> _profileAllergyKeys = const {};
  Set<String> _profileHealthKeys = const {};

  static const List<String> _placeholders = [
    'assets/images/recipe_placeholder1.png',
    'assets/images/recipe_placeholder2.png',
  ];

  @override
  void initState() {
    super.initState();
    likes.addListener(_onLikesChanged);
    future = repository.getRecipeDetails(
      recipeId: widget.recipeId,
      seedSummary: widget.seed,
    );
    likes.ensureLoaded();
    _loadPantryMatches();
    _loadProfileRestrictions();
  }

  @override
  void dispose() {
    likes.removeListener(_onLikesChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  ThemeData get _theme => Theme.of(context);

  ColorScheme get _colorScheme => _theme.colorScheme;

  bool get _isDarkTheme => _theme.brightness == Brightness.dark;

  Color get _screenBackground => _theme.scaffoldBackgroundColor;

  Color get _sheetBackground =>
      _isDarkTheme ? _colorScheme.surface : const Color(0xFFF2F1EC);

  Color get _cardBackground =>
      _isDarkTheme ? _colorScheme.surfaceContainer : Colors.white;

  Color get _softCardBackground => _isDarkTheme
      ? _colorScheme.surfaceContainerHighest
      : const Color(0xFFF5F4EF);

  Color get _outlineColor => _isDarkTheme
      ? _colorScheme.outlineVariant.withValues(alpha: 0.55)
      : const Color(0xFFD8D0C5);

  Color get _mutedTextColor => _isDarkTheme
      ? _colorScheme.onSurfaceVariant
      : Colors.black.withValues(alpha: 0.62);

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  String get _feedbackSource => _isRu ? 'Рецепт' : 'Recipe';

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showFeedback(
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
      source: _feedbackSource,
      preferPopup: preferPopup,
      addToInbox: addToInbox,
    );
  }

  void _onLikesChanged() {
    _safeSetState(() {});
  }

  Future<void> _submitComment(RecipeDetails baseDetails) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      _showFeedback(
        _isRu ? 'Введите комментарий' : 'Enter a comment',
        kind: AppFeedbackKind.error,
        preferPopup: true,
        addToInbox: false,
      );
      return;
    }
    if (_submittingComment) return;

    _safeSetState(() => _submittingComment = true);
    try {
      final comment = await repository.addRecipeComment(
        recipeId: widget.recipeId,
        text: text,
        parentCommentId: _replyTarget?.id,
      );
      if (!mounted) return;
      final current = _detailsOverride ?? baseDetails;
      _commentController.clear();
      _commentFocusNode.unfocus();
      _safeSetState(() {
        _detailsOverride = current.copyWith(
          comments: _appendCommentToTree(current.comments, comment),
        );
        _replyTarget = null;
        _submittingComment = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _safeSetState(() => _submittingComment = false);
      final message = error.statusCode == 401
          ? (_isRu
                ? 'Войдите, чтобы оставить комментарий'
                : 'Log in to leave a comment')
          : error.message;
      _showFeedback(
        message,
        kind: AppFeedbackKind.error,
        preferPopup: true,
        addToInbox: false,
      );
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() => _submittingComment = false);
      _showFeedback(
        _isRu ? 'Не удалось отправить комментарий' : 'Failed to post comment',
        kind: AppFeedbackKind.error,
        preferPopup: true,
        addToInbox: false,
      );
    }
  }

  void _startReply(RecipeComment comment) {
    _safeSetState(() => _replyTarget = comment);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    _safeSetState(() => _replyTarget = null);
  }

  Future<void> _toggleCommentLike(
    RecipeDetails baseDetails,
    RecipeComment comment,
  ) async {
    if (_commentLikeBusyIds.contains(comment.id)) return;
    _safeSetState(() => _commentLikeBusyIds.add(comment.id));
    try {
      final updated = await repository.setRecipeCommentLike(
        recipeId: widget.recipeId,
        commentId: comment.id,
        liked: !comment.likedByMe,
      );
      if (!mounted) return;
      final current = _detailsOverride ?? baseDetails;
      _safeSetState(() {
        _detailsOverride = current.copyWith(
          comments: _updateCommentInTree(current.comments, updated),
        );
        _commentLikeBusyIds.remove(comment.id);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _safeSetState(() => _commentLikeBusyIds.remove(comment.id));
      final message = error.statusCode == 401
          ? (_isRu
                ? 'Войдите, чтобы ставить лайки комментариям'
                : 'Log in to like comments')
          : error.message;
      _showFeedback(
        message,
        kind: AppFeedbackKind.error,
        preferPopup: true,
        addToInbox: false,
      );
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() => _commentLikeBusyIds.remove(comment.id));
      _showFeedback(
        _isRu
            ? 'Не удалось обновить лайк комментария'
            : 'Failed to update comment like',
        kind: AppFeedbackKind.error,
        preferPopup: true,
        addToInbox: false,
      );
    }
  }

  List<RecipeComment> _appendCommentToTree(
    List<RecipeComment> comments,
    RecipeComment newComment,
  ) {
    if (newComment.parentCommentId == null) {
      return [
        ...comments.where((item) => item.id != newComment.id),
        newComment,
      ];
    }
    return comments
        .map((item) {
          if (item.id != newComment.parentCommentId) {
            return item;
          }
          final replies = [
            ...item.replies.where((reply) => reply.id != newComment.id),
            newComment,
          ];
          return item.copyWith(replies: replies, replyCount: replies.length);
        })
        .toList(growable: false);
  }

  List<RecipeComment> _updateCommentInTree(
    List<RecipeComment> comments,
    RecipeComment updatedComment,
  ) {
    return comments
        .map((item) {
          if (item.id == updatedComment.id) {
            return item.copyWith(
              parentCommentId: updatedComment.parentCommentId,
              authorName: updatedComment.authorName,
              body: updatedComment.body,
              createdAt: updatedComment.createdAt,
              likeCount: updatedComment.likeCount,
              likedByMe: updatedComment.likedByMe,
              replyCount: item.replies.isNotEmpty
                  ? item.replies.length
                  : updatedComment.replyCount,
            );
          }
          if (item.replies.isEmpty) {
            return item;
          }
          final replies = _updateCommentInTree(item.replies, updatedComment);
          return item.copyWith(replies: replies, replyCount: replies.length);
        })
        .toList(growable: false);
  }

  Future<void> _loadPantryMatches() async {
    try {
      final pantryItems = await repository.getPantryItems();
      if (!mounted) return;
      final names = pantryItems
          .map((item) => _normalizeIngredientText(item['name']?.toString()))
          .where((value) => value.isNotEmpty)
          .toSet();
      _safeSetState(() {
        _pantryNames = names;
        _pantryMatchesReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() => _pantryMatchesReady = true);
    }
  }

  Future<void> _loadProfileRestrictions() async {
    try {
      final profile = await repository.getProfile();
      if (!mounted) return;
      _safeSetState(() {
        _profileDietKeys = _profileTagSet(
          profile?['dietPreferences'] ?? profile?['diet_preferences'],
        );
        _profileAllergyKeys = _profileTagSet(profile?['allergies']);
        _profileHealthKeys = _profileTagSet(
          profile?['healthConditions'] ?? profile?['health_conditions'],
        );
        _profileRestrictionsReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() => _profileRestrictionsReady = true);
    }
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

  String _normalizeFractionSlash(String text) {
    return text.replaceAllMapped(
      RegExp(r'(\d+)\s*/\s*(\d+)'),
      (m) => '${m.group(1)}⁄${m.group(2)}',
    );
  }

  String? _quantityDisplay(IngredientItem item) {
    String? quantity = _cleanText(item.quantityText);
    if (quantity == null) {
      final qValue = item.quantityValue;
      if (qValue == null) return null;
      if ((qValue - qValue.roundToDouble()).abs() < 0.0000001) {
        quantity = qValue.round().toString();
      } else {
        var text = qValue.toStringAsFixed(4);
        text = text.replaceFirst(RegExp(r'0+$'), '');
        text = text.replaceFirst(RegExp(r'\.$'), '');
        quantity = text;
      }
    }

    final unit = _cleanText(item.unit);
    if (unit != null && unit.isNotEmpty) {
      final normalized = quantity.toLowerCase();
      final unitNormalized = unit.toLowerCase();
      if (!normalized.contains(unitNormalized)) {
        quantity = '$quantity $unit';
      }
    }

    return quantity;
  }

  bool _startsWithNumber(String text) {
    final normalized = text.replaceAll('⁄', '/');
    final m = RegExp(
      r'^\s*[-+]?\d+(?:[.,]\d+)?(?:\s+\d+/\d+|/\d+)?\b',
    ).firstMatch(normalized);
    return m != null;
  }

  String _collapseDuplicateLeadingNumber(String text) {
    final normalized = text.replaceAll('⁄', '/');
    final match = RegExp(
      r'^\s*([-+]?\d+(?:[.,]\d+)?(?:\s+\d+/\d+|/\d+)?)\s+'
      r'([-+]?\d+(?:[.,]\d+)?(?:\s+\d+/\d+|/\d+)?)\b',
    ).firstMatch(normalized);
    if (match == null) return text;

    final a = match.group(1)!.trim().replaceAll(',', '.');
    final b = match.group(2)!.trim().replaceAll(',', '.');
    if (a != b) return text;

    return normalized.replaceFirst(
      RegExp(r'^\s*' + RegExp.escape(match.group(1)!) + r'\s+'),
      '',
    );
  }

  String _normalizeSpaces(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _ingredientLineText(IngredientItem item) {
    final quantity = _quantityDisplay(item);
    final raw = _cleanText(item.rawText);
    var text =
        raw ??
        _cleanText(item.ingredient) ??
        [
          _cleanText(item.unit),
          _cleanText(item.ingredient),
        ].whereType<String>().join(' ');

    text = _normalizeSpaces(text);
    text = _collapseDuplicateLeadingNumber(text);

    if (quantity != null && !_startsWithNumber(text)) {
      text = '$quantity $text'.trim();
    }

    text = _normalizeFractionSlash(_normalizeSpaces(text));
    return text.isEmpty ? '-' : text;
  }

  String _ingredientNameText(IngredientItem item) {
    final ingredient = _cleanText(item.ingredient);
    final note = _cleanText(item.note);
    if (ingredient != null && ingredient.isNotEmpty) {
      if (note != null && note.isNotEmpty) {
        return '$ingredient, $note';
      }
      return ingredient;
    }

    final quantity = _quantityDisplay(item);
    final line = _ingredientLineText(item);
    var cleaned = line.replaceFirst(
      RegExp('^\\s*${RegExp.escape(quantity ?? '')}\\s*'),
      '',
    );
    final unit = _cleanText(item.unit);
    if (unit != null && unit.isNotEmpty) {
      cleaned = cleaned.replaceFirst(
        RegExp('^\\s*${RegExp.escape(unit)}\\s*', caseSensitive: false),
        '',
      );
    }
    cleaned = _normalizeSpaces(cleaned);
    return cleaned.isEmpty ? line : cleaned;
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

  String _normalizeRestrictionKey(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    final normalized = raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return _restrictionAliases[normalized] ?? normalized;
  }

  String _extractProfileTagToken(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      return _normalizeRestrictionKey(value);
    }
    if (value is Map) {
      final rawToken =
          value['id'] ??
          value['name'] ??
          value['key'] ??
          value['value'] ??
          value['code'];
      return _normalizeRestrictionKey(rawToken?.toString());
    }
    return _normalizeRestrictionKey(value.toString());
  }

  Set<String> _profileTagSet(dynamic value) {
    if (value is! List) return <String>{};
    final result = <String>{};
    for (final item in value) {
      final token = _extractProfileTagToken(item);
      if (token.isNotEmpty) {
        result.add(token);
      }
    }
    return result;
  }

  bool _matchesProfileRestriction(String key, String type) {
    final normalizedKey = _normalizeRestrictionKey(key);
    if (normalizedKey.isEmpty) return false;
    final normalizedType = _normalizeRestrictionKey(type);

    if (normalizedType.contains('DIET')) {
      return _profileDietKeys.contains(normalizedKey);
    }
    if (normalizedType.contains('ALLERGY')) {
      return _profileAllergyKeys.contains(normalizedKey);
    }
    if (normalizedType.contains('HEALTH') ||
        normalizedType.contains('CONDITION')) {
      return _profileHealthKeys.contains(normalizedKey);
    }

    return _profileDietKeys.contains(normalizedKey) ||
        _profileAllergyKeys.contains(normalizedKey) ||
        _profileHealthKeys.contains(normalizedKey);
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
      _normalizeIngredientText(item.rawText),
      _normalizeIngredientText(_ingredientNameText(item)),
      _normalizeIngredientText(_ingredientLineText(item)),
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

  int _pantryMatchCount(List<IngredientItem> ingredients) =>
      ingredients.where(_ingredientInPantry).length;

  List<IngredientItem> _missingIngredients(List<IngredientItem> ingredients) =>
      ingredients.where((item) => !_ingredientInPantry(item)).toList();

  double? _shoppingQuantityValue(IngredientItem item) {
    if (item.quantityValue != null) {
      return item.quantityValue;
    }
    final text = item.quantityText?.trim().replaceAll(',', '.');
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  Map<String, dynamic> _shoppingPayloadForIngredient(IngredientItem item) {
    final payload = <String, dynamic>{
      'name': _ingredientNameText(item).trim(),
      'quantity': _shoppingQuantityValue(item),
      'unit': _cleanText(item.unit),
    };
    payload.removeWhere(
      (key, value) =>
          value == null || (value is String && value.trim().isEmpty),
    );
    return payload;
  }

  Future<List<IngredientItem>?> _pickIngredientsForShopping(
    List<IngredientItem> ingredients,
  ) {
    final selected = List<bool>.filled(ingredients.length, true);
    return showModalBottomSheet<List<IngredientItem>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedCount = selected.where((value) => value).length;

            Widget ingredientRow(int index) {
              final item = ingredients[index];
              final isSelected = selected[index];
              final quantity = _quantityDisplay(item);
              final name = _ingredientNameText(item);

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setSheetState(() => selected[index] = !isSelected),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _accentOrange.withValues(alpha: 0.08)
                        : _softCardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? _accentOrange.withValues(alpha: 0.28)
                          : _outlineColor,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: isSelected,
                        activeColor: _accentOrange,
                        onChanged: (value) => setSheetState(
                          () => selected[index] = value ?? false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: _colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (quantity != null && quantity.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                quantity,
                                style: TextStyle(
                                  color: _mutedTextColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return AtelierSheetFrame(
              title: _isRu ? 'Выберите ингредиенты' : 'Choose ingredients',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isRu
                              ? 'Выбрано: $selectedCount из ${ingredients.length}'
                              : 'Selected: $selectedCount of ${ingredients.length}',
                          style: TextStyle(
                            color: _mutedTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          for (var i = 0; i < selected.length; i++) {
                            selected[i] = true;
                          }
                        }),
                        child: Text(_isRu ? 'Все' : 'All'),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          for (var i = 0; i < selected.length; i++) {
                            selected[i] = false;
                          }
                        }),
                        child: Text(_isRu ? 'Снять' : 'None'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    ingredients.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ingredientRow(index),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(_isRu ? 'Отмена' : 'Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: selectedCount == 0
                              ? null
                              : () => Navigator.of(sheetContext).pop([
                                  for (var i = 0; i < ingredients.length; i++)
                                    if (selected[i]) ingredients[i],
                                ]),
                          child: Text(_isRu ? 'Добавить' : 'Add selected'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addMissingToShopping(List<IngredientItem> ingredients) async {
    if (_addingToShopping) return;
    final missingIngredients = _missingIngredients(ingredients);
    if (missingIngredients.isEmpty) {
      _showFeedback(
        _isRu
            ? 'Все ингредиенты уже есть в кладовой'
            : 'All ingredients are already in the pantry',
        kind: AppFeedbackKind.info,
        preferPopup: true,
        addToInbox: false,
      );
      return;
    }

    final selectedIngredients = await _pickIngredientsForShopping(
      missingIngredients,
    );
    if (!mounted ||
        selectedIngredients == null ||
        selectedIngredients.isEmpty) {
      return;
    }

    _safeSetState(() => _addingToShopping = true);
    var addedCount = 0;
    for (final ingredient in selectedIngredients) {
      final payload = _shoppingPayloadForIngredient(ingredient);
      if ((payload['name']?.toString().trim() ?? '').isEmpty) {
        continue;
      }
      final result = await repository.createShoppingItem(payload);
      if (result != null) {
        addedCount++;
      }
    }
    if (!mounted) return;
    _safeSetState(() => _addingToShopping = false);

    _showFeedback(
      _isRu
          ? 'В shopping list добавлено: $addedCount'
          : 'Added to shopping list: $addedCount',
      kind: AppFeedbackKind.success,
    );
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
        if (!_matchesProfileRestriction(key, type)) continue;
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
      final type = c.type.trim().isEmpty ? 'CONSTRAINT' : c.type;
      if (!_matchesProfileRestriction(key, type)) continue;
      out.add(
        _RestrictionTag(
          key: key,
          type: type,
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
        final details = _detailsOverride ?? snap.data!;
        return _buildDetail(details);
      },
    );
  }
}
