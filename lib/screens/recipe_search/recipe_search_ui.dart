part of '../recipe_search_screen.dart';

extension _RecipeSearchScreenUi on _RecipeSearchScreenState {
  Widget _recipeImage(
    String? image,
    int recipeId, {
    required double width,
    required double height,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(18)),
  }) {
    final fallback = _pickPlaceholder(recipeId);
    final bad = _isBadImageUrl(image);
    return ClipRRect(
      borderRadius: borderRadius,
      child: bad
          ? Image.asset(
              fallback,
              width: width,
              height: height,
              fit: BoxFit.cover,
            )
          : Image.network(
              image!.trim(),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.asset(
                fallback,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
    );
  }

  Widget _topChromeButton({
    required Widget child,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final shellColor = Color.alphaBlend(
      _cs.surfaceContainerHighest.withValues(alpha: _isDarkTheme ? 0.3 : 0.72),
      _theme.scaffoldBackgroundColor,
    );

    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: shellColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _cs.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void syncState(VoidCallback fn) {
              _safeSetState(fn);
              setSheetState(() {});
            }

            Widget choiceChip({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return FilterChip(
                selected: selected,
                backgroundColor: Color.alphaBlend(
                  _cs.surfaceContainerHighest.withValues(
                    alpha: _isDarkTheme ? 0.78 : 0.92,
                  ),
                  _cs.surface,
                ),
                selectedColor: _cs.primary.withValues(
                  alpha: _isDarkTheme ? 0.24 : 0.16,
                ),
                checkmarkColor: _cs.primary,
                side: BorderSide(
                  color: selected
                      ? _cs.primary.withValues(alpha: 0.34)
                      : _cs.outlineVariant.withValues(alpha: 0.45),
                ),
                label: Text(
                  label,
                  style: _theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? _cs.primary : _cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onSelected: (_) => onTap(),
              );
            }

            return AtelierSheetFrame(
              title: _isRu ? 'Фильтры рецептов' : 'Recipe filters',
              onClose: () => Navigator.of(sheetContext).maybePop(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: keywordCtrl,
                    onTapOutside: (_) => _dismissKeyboard(),
                    onChanged: (value) => syncState(() {
                      final typed = value.trim().toLowerCase();
                      final selected = (selectedKeyword ?? '')
                          .trim()
                          .toLowerCase();
                      if (typed.isEmpty || typed != selected) {
                        selectedKeyword = null;
                      }
                    }),
                    decoration: InputDecoration(
                      labelText: _isRu ? 'Ключевое слово' : 'Keyword',
                      hintText: _isRu
                          ? 'Например: курица, паста, суп'
                          : 'For example: chicken, pasta, soup',
                      prefixIcon: const Icon(Icons.tag_rounded),
                    ),
                  ),
                  if ((selectedKeyword ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InputChip(
                          backgroundColor: Color.alphaBlend(
                            _cs.primary.withValues(
                              alpha: _isDarkTheme ? 0.2 : 0.12,
                            ),
                            _cs.surface,
                          ),
                          side: BorderSide(
                            color: _cs.primary.withValues(alpha: 0.24),
                          ),
                          label: Text(
                            _keywordLabel(selectedKeyword!.trim()),
                            style: _theme.textTheme.bodyMedium?.copyWith(
                              color: _cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          selected: true,
                          onPressed: null,
                          onDeleted: () => syncState(() {
                            selectedKeyword = null;
                            keywordCtrl.clear();
                          }),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    _isRu ? 'Популярные варианты' : 'Popular options',
                    style: _theme.textTheme.titleMedium?.copyWith(
                      color: _cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _activeQuickKeywords
                        .map(
                          (k) => choiceChip(
                            label: _keywordLabel(k),
                            selected: selectedKeyword == k,
                            onTap: () => syncState(() => _applyKeyword(k)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _dropdown(
                    hint: tr(context, 'diet_filter'),
                    value: diet,
                    items: diets,
                    labelBuilder: _dietLabel,
                    onChanged: (v) => syncState(() => diet = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => syncState(() {
                            diet = null;
                            selectedKeyword = null;
                            keywordCtrl.clear();
                          }),
                          child: Text(_isRu ? 'Сбросить' : 'Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _searchFromFirstPage();
                          },
                          icon: const Icon(Icons.search_rounded),
                          label: Text(tr(context, 'find')),
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

  Widget _buildTopBlock() {
    final cs = _cs;
    final likedCount = likes.entries.length;

    final shellColor = Color.alphaBlend(
      cs.surface.withValues(alpha: _isDarkTheme ? 0.22 : 0.72),
      _theme.scaffoldBackgroundColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: _isDarkTheme ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.spa_rounded, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Organic Atelier',
                    style: _theme.textTheme.titleLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            _topChromeButton(
              tooltip: _isRu ? 'Лайкнутые рецепты' : 'Liked recipes',
              onTap: _openLikedRecipes,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    likedCount > 0
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: likedCount > 0
                        ? const Color(0xFFFF4F65)
                        : cs.onSurfaceVariant,
                  ),
                  if (likedCount > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4F65),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          likedCount > 99 ? '99+' : '$likedCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _topChromeButton(
              tooltip: _isRu ? 'Уведомления' : 'Notifications',
              onTap: () => showAppInboxSheet(context),
              child: AnimatedBuilder(
                animation: AppFeedbackCenter.instance,
                builder: (_, _) {
                  final unread = AppFeedbackCenter.instance.unreadCount;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        unread > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                        size: 20,
                        color: unread > 0 ? cs.primary : cs.onSurfaceVariant,
                      ),
                      if (unread > 0)
                        Positioned(
                          top: -6,
                          right: -7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: TextStyle(
                                color: cs.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            _topChromeButton(
              tooltip: tr(context, 'settings'),
              onTap: () => showAppSettingsSheet(context),
              child: Icon(
                Icons.settings_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextFieldTapRegion(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: shellColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.16),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: titleCtrl,
                        focusNode: _titleFocusNode,
                        onTap: _refreshSearchSuggestions,
                        onTapOutside: (_) => _dismissKeyboard(),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchFromFirstPage(),
                        decoration: InputDecoration(
                          hintText: _isRu
                              ? 'Введите блюдо или ингредиент'
                              : 'Enter a dish or ingredient',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          ),
                          suffixIcon: IconButton(
                            tooltip: _isRu ? 'Искать' : 'Search',
                            onPressed: loading ? null : _searchFromFirstPage,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _topChromeButton(
                      tooltip: _isRu ? 'Фильтры' : 'Filters',
                      onTap: _openFiltersSheet,
                      child: Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_searchSuggestions.isNotEmpty)
                AtelierSuggestionPanel(
                  suggestions: _searchSuggestions,
                  isRu: _isRu,
                  onSelected: (option) => _applySearchSuggestion(option),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(RecipeSummary recipe) {
    final totalTime = _totalTimeLabel(recipe);
    final isLiked = likes.isLiked(recipe.id);
    final caloriesText = recipe.calories == null
        ? '--'
        : '${recipe.calories!.round()} ${tr(context, 'kcal')}';
    final timeText = totalTime ?? (_isRu ? 'Не указано' : 'Not set');
    final proteinText = recipe.protein == null
        ? '--'
        : '${recipe.protein!.toStringAsFixed(recipe.protein! >= 10 ? 0 : 1)} ${_isRu ? 'г' : 'g'}';
    final fatText = recipe.fat == null
        ? '--'
        : '${recipe.fat!.toStringAsFixed(recipe.fat! >= 10 ? 0 : 1)} ${_isRu ? 'г' : 'g'}';
    final carbsText = recipe.carbs == null
        ? '--'
        : '${recipe.carbs!.toStringAsFixed(recipe.carbs! >= 10 ? 0 : 1)} ${_isRu ? 'г' : 'g'}';

    Widget metaChip(IconData icon, String text) {
      return AtelierTagChip(icon: icon, label: text, foreground: _cs.primary);
    }

    Widget searchReasonChip(String reason) {
      final normalized = reason.trim().toLowerCase();
      final (icon, label, color) = switch (normalized) {
        'title' => (
          Icons.title_rounded,
          _isRu ? 'По названию' : 'Title match',
          _cs.primary,
        ),
        'ingredient' => (
          Icons.restaurant_menu_rounded,
          _isRu ? 'По ингредиенту' : 'Ingredient match',
          _cs.secondary,
        ),
        'category' => (
          Icons.category_rounded,
          _isRu ? 'По категории' : 'Category match',
          _cs.tertiary,
        ),
        'fuzzy' => (
          Icons.auto_fix_high_rounded,
          _isRu ? 'Похоже на запрос' : 'Fuzzy match',
          const Color(0xFFE27A22),
        ),
        _ => (Icons.search_rounded, reason, _cs.primary),
      };
      return AtelierTagChip(
        icon: icon,
        label: label,
        foreground: color,
        background: color.withValues(alpha: _isDarkTheme ? 0.18 : 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );
    }

    Widget macroTile(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _isDarkTheme ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RecipeDetailScreen(recipeId: recipe.id, seed: recipe),
          ),
        );
      },
      child: AtelierSurfaceCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: _recipeImage(
                    recipe.image,
                    recipe.id,
                    width: double.infinity,
                    height: 188,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                Positioned(
                  top: 24,
                  right: 24,
                  child: IconButton(
                    onPressed: () => _toggleLike(recipe.id),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(42, 42),
                      backgroundColor: _cs.surfaceContainerLowest.withValues(
                        alpha: _isDarkTheme ? 0.82 : 0.92,
                      ),
                    ),
                    icon: Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isLiked
                          ? const Color(0xFFFF4F65)
                          : _cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if ((recipe.category ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.category!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (recipe.searchMatchReasons.where((reason) {
                    final normalized = reason.trim().toLowerCase();
                    return normalized != 'text_match';
                  }).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recipe.searchMatchReasons
                          .where((reason) {
                            final normalized = reason.trim().toLowerCase();
                            return normalized != 'text_match';
                          })
                          .take(3)
                          .map(searchReasonChip)
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      metaChip(Icons.access_time_rounded, timeText),
                      metaChip(
                        Icons.local_fire_department_rounded,
                        caloriesText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      macroTile(
                        _isRu ? 'Белки' : 'Protein',
                        proteinText,
                        _cs.primary,
                      ),
                      const SizedBox(width: 8),
                      macroTile(
                        _isRu ? 'Жиры' : 'Fats',
                        fatText,
                        _cs.secondary,
                      ),
                      const SizedBox(width: 8),
                      macroTile(
                        _isRu ? 'Углеводы' : 'Carbs',
                        carbsText,
                        _cs.tertiary,
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

  Widget _buildSearchHistorySection() {
    if (_historyLoading && _searchHistory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }
    if (_searchHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _isRu ? 'История поиска' : 'Search history',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _cs.onSurface.withValues(alpha: 0.86),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _clearSearchHistory,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text(_isRu ? 'Очистить' : 'Clear'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _searchHistory
              .map(
                (entry) => InputChip(
                  onPressed: () => _applySearchHistoryEntry(entry),
                  onDeleted: () => _deleteSearchHistoryEntry(entry.id),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      entry.displayText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRecommended() {
    if (loading && results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (searched && results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            _isRu ? 'Ничего не найдено' : 'Nothing found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final recipe in results) ...[
          _buildRecipeCard(recipe),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildPaginationControls() {
    if (!searched || results.isEmpty) return const SizedBox.shrink();
    if (!hasNextPage && currentPage <= 1 && (totalPages ?? 1) <= 1) {
      return const SizedBox.shrink();
    }
    final pageLabel = totalPages != null && totalPages! > 0
        ? (_isRu
              ? 'Страница $currentPage из $totalPages'
              : 'Page $currentPage of $totalPages')
        : (_isRu ? 'Страница $currentPage' : 'Page $currentPage');
    const controlHeight = 44.0;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: controlHeight,
            height: controlHeight,
            child: OutlinedButton(
              onPressed: (loading || currentPage <= 1) ? null : _goPrevPage,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const StadiumBorder(),
              ),
              child: const Icon(Icons.chevron_left_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: loading ? null : _openPageJump,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                constraints: const BoxConstraints(minHeight: controlHeight),
                decoration: BoxDecoration(
                  color: _cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pageLabel,
                      style: TextStyle(
                        color: _cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: _cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: controlHeight,
            height: controlHeight,
            child: FilledButton(
              onPressed: (loading || !hasNextPage) ? null : _goNextPage,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const StadiumBorder(),
              ),
              child: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required String Function(String) labelBuilder,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      dropdownColor: _cs.surface,
      style: _theme.textTheme.bodyLarge?.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(labelText: hint),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(tr(context, 'any'))),
        ...items.map(
          (e) =>
              DropdownMenuItem<String?>(value: e, child: Text(labelBuilder(e))),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
