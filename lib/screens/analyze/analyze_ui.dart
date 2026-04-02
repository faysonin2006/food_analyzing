part of '../analyze_screen.dart';

extension _AnalyzeScreenUi on _AnalyzeScreenState {
  Widget _buildSectionIntro({
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: _AnalyzeScreenState._accentOrange,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 0.96,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: _cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Future<void> _openQuestionsPicker() async {
    var localQuery = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filtered = _filterQuestionPresets(localQuery);
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.88,
              minChildSize: 0.55,
              maxChildSize: 0.95,
              builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(context, 'analysis_questions_title'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _blendWithSurface(
                              _cs.primary,
                              _isDarkTheme ? 0.3 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedQuestionIds.length}/${_AnalyzeScreenState._maxSelectedQuestions}',
                            style: TextStyle(
                              color: _cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (value) =>
                          setSheetState(() => localQuery = value),
                      decoration: InputDecoration(
                        hintText: tr(context, 'analysis_questions_search_hint'),
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                tr(context, 'analysis_questions_no_matches'),
                                style: TextStyle(color: _cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (_, index) {
                                final item = filtered[index];
                                final selected = _selectedQuestionIds.contains(
                                  item.id,
                                );
                                return CheckboxListTile(
                                  value: selected,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  title: Text(item.text(_isRu)),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    _toggleQuestionSelection(item.id, value);
                                    setSheetState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImagePickerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _blendWithSurface(_AnalyzeScreenState._accentOrange, 0.16),
            _blendWithSurface(AppTheme.atelierLime, 0.2),
            _blendWithSurface(AppTheme.atelierHoney, 0.08),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Organic Atelier',
            style: TextStyle(
              color: _AnalyzeScreenState._accentOrange,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRu ? 'AI-анализ\nпо фото' : 'AI analysis\nfrom a photo',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 0.94,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isRu
                ? 'Загрузи блюдо, добавь фокусные вопросы и получи редакционный разбор, который можно сразу сохранить в журнал питания.'
                : 'Upload a dish, add focused questions, and get an editorial breakdown you can save straight into your meal journal.',
            style: TextStyle(
              color: _cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _selectedImage != null
                ? ClipRRect(
                    key: const ValueKey('selected_image'),
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      children: [
                        Image.file(
                          _selectedImage!,
                          width: double.infinity,
                          height: 320,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 18,
                          left: 18,
                          child: AtelierTagChip(
                            icon: Icons.auto_awesome_rounded,
                            label: _isRu ? 'AI готов' : 'AI Ready',
                            foreground: const Color(0xFF00390A),
                            background: const Color(0xFF9DF197),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey('placeholder'),
                    width: double.infinity,
                    height: 320,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: _cs.outlineVariant.withValues(alpha: 0.46),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _blendWithSurface(
                            _AnalyzeScreenState._accentOrange,
                            0.18,
                          ),
                          _blendWithSurface(AppTheme.atelierLime, 0.14),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 70,
                          color: _AnalyzeScreenState._accentOrangeDeep,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tr(context, 'photo_not_selected'),
                          style: TextStyle(
                            color: _cs.onSurfaceVariant.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(tr(context, 'gallery')),
                  onPressed: () => _pickAnalysisImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(tr(context, 'camera')),
                  onPressed: () => _pickAnalysisImage(ImageSource.camera),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsCard() {
    return AtelierSurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIntro(
            eyebrow: _isRu ? 'вопросы' : 'questions',
            title: tr(context, 'analysis_questions_core_title'),
            subtitle: _isRu
                ? 'Выбери важные вопросы, чтобы AI дал более полезный и точный разбор.'
                : 'Pick the questions that matter so the AI answer becomes more precise and useful.',
          ),
          const SizedBox(height: 12),
          ..._coreQuestionPresets.map((item) {
            final selected = _selectedQuestionIds.contains(item.id);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected,
              activeColor: _AnalyzeScreenState._accentOrange,
              checkColor: Colors.white,
              title: Text(item.text(_isRu)),
              onChanged: (v) {
                if (v == null) return;
                _toggleQuestionSelection(item.id, v);
              },
            );
          }),
          if (_selectedQuestionIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedQuestionIds
                  .map(
                    (id) => AtelierTagChip(
                      label: _questionTextById(id),
                      foreground: _AnalyzeScreenState._accentOrangeDeep,
                      background: _blendWithSurface(
                        _AnalyzeScreenState._accentOrange,
                        0.14,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _openQuestionsPicker,
              icon: const Icon(Icons.tune_rounded),
              label: Text(tr(context, 'analysis_questions_open_search')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _AnalyzeScreenState._accentOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _cs.surfaceContainerHighest,
          disabledForegroundColor: _cs.onSurfaceVariant,
        ),
        onPressed: (_selectedImage == null || _isAnalyzing)
            ? null
            : _analyzeFood,
        icon: Icon(
          _isAnalyzing ? Icons.sync_rounded : Icons.auto_awesome_rounded,
        ),
        label: Text(
          _isAnalyzing
              ? tr(context, 'analyzing')
              : tr(context, 'start_analysis'),
        ),
      ),
    );
  }

  Widget _buildNutrientCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blendWithSurface(_AnalyzeScreenState._accentOrange, 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _AnalyzeScreenState._accentOrangeDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _analysisResult;
    if (result == null) return const SizedBox.shrink();

    final dishName = _historyDishName(result);
    final calories = result['calories']?.toString() ?? '-';
    final protein = result['protein']?.toString() ?? '-';
    final fats = result['fats']?.toString() ?? '-';
    final carbs = result['carbs']?.toString() ?? '-';
    final extraInfo = _analysisExtraInfo(result);
    final alreadySaved = _analysisAlreadySaved(result);
    final healthScore = _analysisHealthScore(result);
    final scoreLabel = healthScore == null
        ? null
        : healthScore >= 80
        ? (_isRu ? 'Высокая польза' : 'High Benefit')
        : healthScore >= 60
        ? (_isRu ? 'Нормальный баланс' : 'Balanced')
        : (_isRu ? 'Есть вопросы' : 'Needs Attention');
    final scoreNote = healthScore == null
        ? null
        : healthScore >= 80
        ? (_isRu
              ? 'ИИ считает, что блюдо хорошо вписывается в твой текущий режим.'
              : 'AI considers this meal a strong fit for your current routine.')
        : healthScore >= 60
        ? (_isRu
              ? 'ИИ видит приемлемый вариант, но советует смотреть на состав и порцию.'
              : 'AI sees this as acceptable, but portion and composition still matter.')
        : (_isRu
              ? 'ИИ считает блюдо спорным по пользе для твоих целей.'
              : 'AI considers this meal questionable for your current goals.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: SizedBox(
            width: double.infinity,
            height: 420,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_selectedImage != null)
                  Image.file(_selectedImage!, fit: BoxFit.cover)
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _blendWithSurface(
                            _AnalyzeScreenState._accentOrange,
                            0.22,
                          ),
                          _blendWithSurface(AppTheme.atelierLime, 0.22),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 18,
                  left: 18,
                  child: AtelierTagChip(
                    icon: Icons.auto_awesome_rounded,
                    label: _isRu ? 'AI проанализировал' : 'AI Analyzed',
                    foreground: const Color(0xFF00390A),
                    background: const Color(0xFF9DF197),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dishName,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 0.96,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isRu
                                    ? 'Домашний анализ • Сейчас'
                                    : 'Home kitchen analysis • Just now',
                                style: TextStyle(
                                  color: _cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              calories,
                              style: TextStyle(
                                color: _AnalyzeScreenState._accentOrange,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                height: 0.92,
                              ),
                            ),
                            Text(
                              tr(context, 'kcal').toUpperCase(),
                              style: TextStyle(
                                color: _cs.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                              ),
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
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AtelierMetricTile(
                label: tr(context, 'protein'),
                value: '$protein g',
                accent: _cs.primary,
                center: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AtelierMetricTile(
                label: tr(context, 'carbs'),
                value: '$carbs g',
                accent: _cs.secondary,
                center: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AtelierMetricTile(
                label: tr(context, 'fats'),
                value: '$fats g',
                accent: _cs.tertiary,
                center: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final insightCard = AtelierSurfaceCard(
              padding: const EdgeInsets.all(22),
              radius: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AtelierIconBadge(
                        icon: Icons.psychology_rounded,
                        accent: _AnalyzeScreenState._accentOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isRu
                              ? 'Nutritionist Insights'
                              : 'Nutritionist Insights',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    extraInfo.isEmpty
                        ? (_isRu
                              ? 'Снимок выглядит сбалансированным: можно использовать его как опорный meal log и уточнить ингредиенты позже.'
                              : 'The snapshot looks balanced: you can use it as a strong meal log and refine the ingredients later.')
                        : extraInfo,
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: 1.38,
                    ),
                  ),
                  if (_selectedQuestionIds.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedQuestionIds
                          .map(
                            (id) => AtelierTagChip(
                              label: _questionTextById(id),
                              foreground: _AnalyzeScreenState._accentOrangeDeep,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            );

            if (healthScore == null) {
              return insightCard;
            }

            final scoreCard = AtelierSurfaceCard(
              padding: const EdgeInsets.all(22),
              radius: 30,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: CircularProgressIndicator(
                            value: healthScore / 100,
                            strokeWidth: 10,
                            color: _cs.primary,
                            backgroundColor: _cs.surfaceContainerHighest,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$healthScore',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                height: 0.92,
                              ),
                            ),
                            Text(
                              _isRu ? 'Оценка пользы' : 'Health Score',
                              style: TextStyle(
                                color: _cs.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AtelierTagChip(
                    label: scoreLabel!,
                    foreground: healthScore >= 80
                        ? _cs.secondary
                        : healthScore >= 60
                        ? _cs.primary
                        : _cs.error,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scoreNote!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            );

            if (constraints.maxWidth < 860) {
              return Column(
                children: [insightCard, const SizedBox(height: 16), scoreCard],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: insightCard),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: scoreCard),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: alreadySaved || _isSavingMeal
                ? null
                : _saveAnalysisAsMeal,
            icon: Icon(
              alreadySaved
                  ? Icons.check_circle_rounded
                  : Icons.bookmark_add_rounded,
            ),
            label: Text(
              alreadySaved
                  ? (_isRu
                        ? 'Уже сохранено в журнал питания'
                        : 'Already saved to meal journal')
                  : (_isSavingMeal
                        ? (_isRu ? 'Сохраняем...' : 'Saving...')
                        : (_isRu
                              ? 'Сохранить в журнал питания'
                              : 'Save to Meal Journal')),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _pickAnalysisImage(ImageSource.camera),
            icon: const Icon(Icons.add_a_photo_rounded),
            label: Text(_isRu ? 'Новый снимок' : 'New Scan'),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryPhoto(Map<String, dynamic> item, {double size = 72}) {
    final photoValue =
        item['photo'] ??
        item['photo_url'] ??
        item['imagePath'] ??
        item['image_path'] ??
        item['image_url'];

    final path = photoValue?.toString().trim() ?? '';
    if (path.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _blendWithSurface(_AnalyzeScreenState._accentOrange, 0.12),
        ),
        child: Icon(
          Icons.photo_rounded,
          color: _AnalyzeScreenState._accentOrangeDeep,
        ),
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: _blendWithSurface(_AnalyzeScreenState._accentOrange, 0.12),
            child: Icon(
              Icons.broken_image_rounded,
              color: _AnalyzeScreenState._accentOrangeDeep,
            ),
          ),
        ),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _blendWithSurface(_AnalyzeScreenState._accentOrange, 0.12),
        ),
        child: Icon(
          Icons.image_not_supported_rounded,
          color: _AnalyzeScreenState._accentOrangeDeep,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
    );
  }

  Widget _buildHistoryItemCard(Map<String, dynamic> item) {
    final cs = _cs;
    final dish = _historyDishName(item);
    final date = _formatHistoryDate(_historyDate(item));
    final statusRaw = _historyStatusRaw(item);
    final statusLabel = _historyStatusLabelForItem(item);
    final statusColor = _historyStatusColor(statusRaw, cs);
    final calories = _historyCalories(item);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openHistoryDetails(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _blendWithSurface(_AnalyzeScreenState._accentOrange, 0.06),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            _buildHistoryPhoto(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (calories != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _blendWithSurface(
                              cs.tertiary,
                              _isDarkTheme ? 0.26 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${calories.round()} ${tr(context, 'kcal')}',
                            style: TextStyle(
                              color: cs.tertiary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: tr(context, 'delete_from_history'),
                  onPressed: () => _deleteHistoryItem(item),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: cs.error,
                  ),
                  splashRadius: 20,
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openHistoryDetails(Map<String, dynamic> item) {
    final dish = _historyDishName(item);
    final calories = _historyCalories(item);
    final protein = item['protein']?.toString() ?? '-';
    final fats = item['fats']?.toString() ?? '-';
    final carbs = item['carbs']?.toString() ?? '-';
    final extraInfo = _analysisExtraInfo(item);
    final errorMessage = _analysisErrorMessage(item);
    final healthScore = _analysisHealthScore(item);
    final canSave = _analysisCanBeSaved(item);
    final alreadySaved = _analysisAlreadySaved(item);
    final isFood = _analysisFoodDetected(item);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              dish,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Center(child: _buildHistoryPhoto(item, size: 220)),
            const SizedBox(height: 16),
            if (!isFood && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _blendWithSurface(_cs.error, 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    color: _cs.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ] else ...[
              _buildNutrientCard(
                tr(context, 'calories'),
                calories == null
                    ? '-'
                    : '${calories.round()} ${tr(context, 'kcal')}',
                Icons.local_fire_department_rounded,
              ),
              const SizedBox(height: 8),
              _buildNutrientCard(
                tr(context, 'protein'),
                protein,
                Icons.fitness_center_rounded,
              ),
              const SizedBox(height: 8),
              _buildNutrientCard(
                tr(context, 'fats'),
                fats,
                Icons.opacity_rounded,
              ),
              const SizedBox(height: 8),
              _buildNutrientCard(
                tr(context, 'carbs'),
                carbs,
                Icons.grain_rounded,
              ),
              if (healthScore != null) ...[
                const SizedBox(height: 12),
                _buildNutrientCard(
                  _isRu ? 'Оценка пользы' : 'Health Score',
                  '$healthScore/100',
                  Icons.favorite_rounded,
                ),
              ],
              if (extraInfo.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _blendWithSurface(
                      _AnalyzeScreenState._accentOrange,
                      0.06,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(extraInfo),
                ),
              ],
            ],
            if (canSave || alreadySaved) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: alreadySaved
                      ? null
                      : () => _saveAnalysisItemAsMeal(item),
                  icon: Icon(
                    alreadySaved
                        ? Icons.check_circle_rounded
                        : Icons.restaurant_menu_rounded,
                  ),
                  label: Text(
                    alreadySaved
                        ? (_isRu
                              ? 'Уже добавлено в съеденное'
                              : 'Already added to eaten food')
                        : (_isRu
                              ? 'Добавить в съеденное'
                              : 'Add to eaten food'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisHistoryCard() {
    final cs = _cs;

    return AtelierSurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIntro(
            eyebrow: _isRu ? 'история' : 'history',
            title: tr(context, 'analysis_history_title'),
            subtitle: _isRu
                ? 'Последние AI-разборы, чтобы быстро вернуться к прошлым блюдам.'
                : 'Recent AI sessions so you can jump back into previous dishes.',
          ),
          const SizedBox(height: 12),
          if (_isHistoryLoading)
            const Center(child: CircularProgressIndicator())
          else if (_analysisHistory.isEmpty)
            Text(
              tr(context, 'analysis_history_empty'),
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            Column(
              children: _analysisHistory
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildHistoryItemCard(item),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
