part of '../recipe_detail_screen.dart';

extension _RecipeDetailUi on _RecipeDetailScreenState {
  Widget _sectionHeader({required String eyebrow, required String title}) {
    return AtelierSectionIntro(
      eyebrow: eyebrow,
      title: title,
      accent: _RecipeDetailScreenState._accentOrange,
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (_isDarkTheme ? Colors.black : Colors.white).withValues(
            alpha: _isDarkTheme ? 0.52 : 0.84,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: _isDarkTheme ? iconColor : const Color(0xFF1D2432),
          size: 20,
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    _safeSetState(() => _likeBusy = true);
    final ok = await likes.toggle(widget.recipeId);
    if (!mounted) return;
    _safeSetState(() => _likeBusy = false);
    if (ok) return;
    _showFeedback(
      _isRu ? 'Не удалось обновить лайк' : 'Failed to update like',
      kind: AppFeedbackKind.error,
      preferPopup: true,
    );
  }

  Widget _metaItem({
    required IconData icon,
    required String text,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outlineColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: iconColor ?? _RecipeDetailScreenState._accentOrange,
          ),
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
      ),
    );
  }

  Widget _ingredientCard(
    IngredientItem item,
    int index, {
    required double width,
    required bool isInPantry,
  }) {
    final nameText = _ingredientNameText(item);
    final quantity = _quantityDisplay(item);
    final accent = isInPantry
        ? _RecipeDetailScreenState._accentOrange
        : _mutedTextColor.withValues(alpha: 0.8);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isInPantry
            ? _RecipeDetailScreenState._accentOrange.withValues(alpha: 0.08)
            : _softCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInPantry
              ? _RecipeDetailScreenState._accentOrange.withValues(alpha: 0.28)
              : _outlineColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isInPantry
                  ? _RecipeDetailScreenState._accentOrange.withValues(
                      alpha: 0.14,
                    )
                  : _colorScheme.surface,
              shape: BoxShape.circle,
              border: isInPantry ? null : Border.all(color: _outlineColor),
            ),
            alignment: Alignment.center,
            child: Icon(
              isInPantry
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: isInPantry ? 16 : 15,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          if (quantity != null && quantity.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                quantity,
                style: TextStyle(
                  color: isInPantry
                      ? _RecipeDetailScreenState._accentOrange
                      : _colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              nameText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: _colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isInPantry ? (_isRu ? 'Есть' : 'Have') : (_isRu ? 'Нужно' : 'Need'),
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _softCardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _outlineColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stepNo.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Color(0x6690E28A),
              fontWeight: FontWeight.w900,
              fontSize: 36,
              height: 0.9,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRu ? 'Шаг $stepNo' : 'Step $stepNo',
                  style: TextStyle(
                    color: _RecipeDetailScreenState._accentOrange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.text.trim().isEmpty
                      ? (_isRu
                            ? 'Описание шага отсутствует'
                            : 'No step description')
                      : step.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: _colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _commentInitials(String authorName) {
    final tokens = authorName
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return '?';
    }
    if (tokens.length == 1) {
      return tokens.first.substring(0, 1).toUpperCase();
    }
    return (tokens.first.substring(0, 1) + tokens.last.substring(0, 1))
        .toUpperCase();
  }

  String _commentTimestampText(DateTime? createdAt) {
    if (createdAt == null) {
      return _isRu ? 'только что' : 'just now';
    }
    final local = createdAt.toLocal();
    String pad(int value) => value.toString().padLeft(2, '0');
    if (_isRu) {
      return '${pad(local.day)}.${pad(local.month)}.${local.year} • ${pad(local.hour)}:${pad(local.minute)}';
    }
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${pad(local.day)} • ${pad(local.hour)}:${pad(local.minute)}';
  }

  Widget _commentComposer(RecipeDetails details) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _softCardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_replyTarget != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _RecipeDetailScreenState._accentOrange.withValues(
                  alpha: 0.09,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _RecipeDetailScreenState._accentOrange.withValues(
                    alpha: 0.2,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _isRu
                          ? 'Ответ для ${_replyTarget!.authorName}'
                          : 'Replying to ${_replyTarget!.authorName}',
                      style: TextStyle(
                        color: _RecipeDetailScreenState._accentOrange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelReply,
                    child: Text(_isRu ? 'Отмена' : 'Cancel'),
                  ),
                ],
              ),
            ),
          ],
          Text(
            _replyTarget == null
                ? (_isRu ? 'Оставить комментарий' : 'Leave a comment')
                : (_isRu ? 'Написать ответ' : 'Write a reply'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            focusNode: _commentFocusNode,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _isRu
                  ? 'Напишите, как у вас получился рецепт'
                  : 'Write how the recipe turned out for you',
              filled: true,
              fillColor: _cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _outlineColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _outlineColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: _RecipeDetailScreenState._accentOrange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submittingComment
                  ? null
                  : () => _submitComment(details),
              icon: Icon(
                _submittingComment ? Icons.sync_rounded : Icons.send_rounded,
              ),
              label: Text(
                _submittingComment
                    ? (_isRu ? 'Отправляем...' : 'Posting...')
                    : (_replyTarget == null
                          ? (_isRu ? 'Опубликовать' : 'Post comment')
                          : (_isRu ? 'Ответить' : 'Reply')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentCard(
    RecipeDetails details,
    RecipeComment comment, {
    int depth = 0,
  }) {
    final canReply = depth == 0;
    final likeBusy = _commentLikeBusyIds.contains(comment.id);
    final likeLabel = comment.likeCount > 0
        ? (_isRu
              ? 'Нравится ${comment.likeCount}'
              : 'Like ${comment.likeCount}')
        : (_isRu ? 'Нравится' : 'Like');
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10, left: depth == 0 ? 0 : 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softCardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outlineColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _RecipeDetailScreenState._accentOrange.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _commentInitials(comment.authorName),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: _RecipeDetailScreenState._accentOrange,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _commentTimestampText(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _mutedTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  comment.body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: _colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: likeBusy
                          ? null
                          : () => _toggleCommentLike(details, comment),
                      icon: Icon(
                        comment.likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 16,
                      ),
                      label: Text(
                        likeBusy ? (_isRu ? '...' : '...') : likeLabel,
                      ),
                    ),
                    if (canReply)
                      TextButton.icon(
                        onPressed: () => _startReply(comment),
                        icon: const Icon(Icons.reply_rounded, size: 16),
                        label: Text(_isRu ? 'Ответить' : 'Reply'),
                      ),
                  ],
                ),
              ],
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
    final pantryMatches = _pantryMatchCount(ingredients);
    final missingIngredients = _missingIngredients(ingredients);
    final category = _cleanText(r.category);
    final nutrients = _allNutrients(r);
    String nutrientDisplay(List<String> keys, String fallback) {
      for (final nutrient in nutrients) {
        final normalized = nutrient.nutrient.toLowerCase();
        if (keys.any((key) => normalized.contains(key))) {
          return _nutritionValue(nutrient);
        }
      }
      return fallback;
    }

    final caloriesDisplay = nutrientDisplay([
      'calorie',
      'калори',
    ], widget.seed?.calories?.round().toString() ?? '--');
    final proteinDisplay = nutrientDisplay([
      'protein',
      'бел',
    ], widget.seed?.protein?.toStringAsFixed(1) ?? '--');
    final fatDisplay = nutrientDisplay([
      'fat',
      'жир',
    ], widget.seed?.fat?.toStringAsFixed(1) ?? '--');
    final carbsDisplay = nutrientDisplay([
      'carb',
      'углев',
    ], widget.seed?.carbs?.toStringAsFixed(1) ?? '--');
    final restrictions = _collectRestrictionTags(r);
    final prepTime = _formatTimeText(r.times.prepTime);
    final cookTime = _formatTimeText(r.times.cookTime);
    final totalTime = _formatTimeText(r.times.totalTime);

    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              children: [
                SizedBox(
                  height: 468,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(34),
                          child: _heroImage(r),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: _topIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _topIconButton(
                          icon: isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor: isLiked
                              ? const Color(0xFFFF4F65)
                              : Colors.white,
                          onTap: _toggleLike,
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _sheetBackground.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: _outlineColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'The Organic Atelier',
                                style: TextStyle(
                                  color: _RecipeDetailScreenState._accentOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                r.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 0.98,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                category ??
                                    '${r.ingredients.length} ${_isRu ? 'ингредиентов' : 'ingredients'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _mutedTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (prepTime != null)
                                    _metaItem(
                                      icon: Icons.timer_outlined,
                                      text: '${tr(context, 'prep')}: $prepTime',
                                    ),
                                  if (cookTime != null)
                                    _metaItem(
                                      icon: Icons.soup_kitchen_outlined,
                                      text: '${tr(context, 'cook')}: $cookTime',
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
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _addingToShopping || !_pantryMatchesReady
                        ? null
                        : missingIngredients.isEmpty
                        ? null
                        : () => _addMissingToShopping(ingredients),
                    icon: Icon(
                      _addingToShopping
                          ? Icons.sync_rounded
                          : missingIngredients.isEmpty
                          ? Icons.inventory_2_rounded
                          : Icons.shopping_cart_checkout_rounded,
                    ),
                    label: Text(
                      _addingToShopping
                          ? (_isRu ? 'Добавляем...' : 'Adding...')
                          : !_pantryMatchesReady
                          ? (_isRu
                                ? 'Сверяем с кладовой...'
                                : 'Checking pantry...')
                          : missingIngredients.isEmpty
                          ? (_isRu
                                ? 'Все ингредиенты уже в кладовой'
                                : 'All ingredients are already in pantry')
                          : (_isRu
                                ? 'Выбрать ингредиенты для shopping list'
                                : 'Choose ingredients for shopping list'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tiles = [
                      AtelierMetricTile(
                        label: tr(context, 'calories'),
                        value: caloriesDisplay,
                        accent: _RecipeDetailScreenState._accentOrange,
                        center: true,
                      ),
                      AtelierMetricTile(
                        label: tr(context, 'protein'),
                        value: proteinDisplay,
                        accent: _colorScheme.primary,
                        center: true,
                      ),
                      AtelierMetricTile(
                        label: tr(context, 'fats'),
                        value: fatDisplay,
                        accent: _colorScheme.tertiary,
                        center: true,
                      ),
                      AtelierMetricTile(
                        label: tr(context, 'carbs'),
                        value: carbsDisplay,
                        center: true,
                      ),
                    ];

                    final wide = constraints.maxWidth >= 720;
                    final width = wide
                        ? (constraints.maxWidth - 36) / 4
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: tiles
                          .map((tile) => SizedBox(width: width, child: tile))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 28),
                _sectionHeader(
                  eyebrow: _isRu ? 'питательность' : 'nutrition',
                  title: tr(context, 'recipe_nutrients_title'),
                ),
                const SizedBox(height: 14),
                if (nutrients.isEmpty)
                  AtelierEmptyState(
                    icon: Icons.local_fire_department_rounded,
                    title: _isRu ? 'Нутриенты не указаны' : 'No nutrition data',
                    accent: _RecipeDetailScreenState._accentOrange,
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: nutrients
                        .where((n) => _nutritionLabel(n.nutrient).isNotEmpty)
                        .map(
                          (n) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _outlineColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _nutritionIcon(n.nutrient),
                                  size: 16,
                                  color: _RecipeDetailScreenState._accentOrange,
                                ),
                                const SizedBox(width: 7),
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
                const SizedBox(height: 28),
                _sectionHeader(
                  eyebrow: _isRu ? 'профиль' : 'profile',
                  title: _isRu ? 'Мои ограничения' : 'My restrictions',
                ),
                const SizedBox(height: 14),
                if (!_profileRestrictionsReady)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _softCardBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _outlineColor),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: _RecipeDetailScreenState._accentOrange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isRu
                                ? 'Сверяем рецепт с ограничениями из профиля...'
                                : 'Matching the recipe with your profile restrictions...',
                            style: TextStyle(
                              color: _mutedTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (restrictions.isEmpty)
                  AtelierEmptyState(
                    icon: Icons.verified_rounded,
                    title: _isRu
                        ? 'Совпадающих ограничений из профиля не найдено'
                        : 'No matching profile restrictions found',
                    accent: _RecipeDetailScreenState._accentOrange,
                  )
                else
                  Column(
                    children: restrictions.map((item) {
                      final fg = _restrictionFg(item.status);
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _restrictionBg(item.status),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: fg.withValues(alpha: 0.28)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trValue(context, item.key),
                              style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${trValue(context, item.type)} • ${trValue(context, item.status)}',
                              style: TextStyle(
                                color: fg.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 28),
                _sectionHeader(
                  eyebrow: _isRu ? 'ингредиенты' : 'ingredients',
                  title: _isRu ? 'Ингредиенты' : 'Ingredients',
                ),
                const SizedBox(height: 14),
                if (_pantryMatchesReady && ingredients.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _RecipeDetailScreenState._accentOrange
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _RecipeDetailScreenState._accentOrange
                                .withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          _isRu
                              ? 'Из кладовой: $pantryMatches из ${ingredients.length}'
                              : 'In pantry: $pantryMatches of ${ingredients.length}',
                          style: TextStyle(
                            color: _RecipeDetailScreenState._accentOrange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (ingredients.isEmpty)
                  AtelierEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: _isRu ? 'Нет данных' : 'No ingredient data',
                    accent: _RecipeDetailScreenState._accentOrange,
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
                              isInPantry: _ingredientInPantry(ingredients[i]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 28),
                _sectionHeader(
                  eyebrow: _isRu ? 'шаги' : 'steps',
                  title: _isRu
                      ? 'Инструкция приготовления'
                      : 'Cooking instruction',
                ),
                const SizedBox(height: 14),
                if (r.instructionSteps.isEmpty)
                  AtelierEmptyState(
                    icon: Icons.menu_book_rounded,
                    title: _isRu
                        ? 'Шаги приготовления отсутствуют'
                        : 'No cooking steps available',
                    accent: _RecipeDetailScreenState._accentOrange,
                  )
                else
                  ...List.generate(
                    r.instructionSteps.length,
                    (i) => _stepCard(r.instructionSteps[i], i),
                  ),
                const SizedBox(height: 28),
                _sectionHeader(
                  eyebrow: _isRu ? 'обсуждение' : 'discussion',
                  title: _isRu ? 'Комментарии' : 'Comments',
                ),
                const SizedBox(height: 14),
                _commentComposer(r),
                const SizedBox(height: 14),
                if (r.comments.isEmpty)
                  AtelierEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: _isRu ? 'Пока нет комментариев' : 'No comments yet',
                    accent: _RecipeDetailScreenState._accentOrange,
                  )
                else
                  ...List.generate(r.comments.length, (i) {
                    final comment = r.comments[i];
                    return Column(
                      children: [
                        _commentCard(r, comment),
                        ...comment.replies.map(
                          (reply) => _commentCard(r, reply, depth: 1),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
