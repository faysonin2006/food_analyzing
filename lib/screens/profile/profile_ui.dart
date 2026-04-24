part of '../profile_screen.dart';

extension _ProfileScreenUi on _ProfileScreenState {
  String _formatWeightValue(double value) {
    final whole = (value - value.roundToDouble()).abs() < 0.001;
    return whole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  Widget _buildEditorFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: _cs.onSurface,
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildEditorSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color accent,
    required Widget child,
  }) {
    return AtelierSurfaceCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AtelierIconBadge(icon: icon, accent: accent, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _cs.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricPickerValueCard({
    String? caption,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: _blendWithSurface(accent, _isDarkTheme ? 0.26 : 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          if (caption != null && caption.trim().isNotEmpty) ...[
            Text(
              caption,
              style: TextStyle(
                color: _cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 0.95,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightPeriodSelector({required Color accent}) {
    final periods = [7, 30, 90];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final days in periods)
          ChoiceChip(
            label: Text(_isRu ? '$days дн.' : '${days}d'),
            selected: _selectedWeightPeriodDays == days,
            showCheckmark: false,
            onSelected: (_) {
              _setSelectedWeightPeriodDays(days);
            },
            selectedColor: _blendWithSurface(accent, _isDarkTheme ? 0.3 : 0.16),
            backgroundColor: _cs.surfaceContainerHighest.withValues(
              alpha: _isDarkTheme ? 0.28 : 0.7,
            ),
            side: BorderSide(
              color: accent.withValues(
                alpha: _selectedWeightPeriodDays == days ? 0.36 : 0.16,
              ),
            ),
            labelStyle: TextStyle(
              color: _selectedWeightPeriodDays == days
                  ? accent
                  : _cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  Widget _buildWeightChartTooltip({
    required String title,
    required String value,
    required Color accent,
  }) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 168),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            _cs.surface.withValues(alpha: _isDarkTheme ? 0.9 : 0.96),
            _cs.surfaceContainerHighest,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cs.outlineVariant.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkTheme ? 0.24 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _cs.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPickerDeltaChip({
    required String label,
    required VoidCallback onPressed,
    required Color accent,
  }) {
    return ActionChip(
      avatar: Icon(Icons.flash_on_rounded, size: 16, color: accent),
      label: Text(label),
      onPressed: onPressed,
      side: BorderSide(color: accent.withValues(alpha: 0.14)),
      backgroundColor: _blendWithSurface(accent, _isDarkTheme ? 0.2 : 0.08),
      labelStyle: TextStyle(color: accent, fontWeight: FontWeight.w800),
    );
  }

  Widget _buildMetricPickerPresetChip({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
    required Color accent,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPressed(),
      selectedColor: _blendWithSurface(accent, _isDarkTheme ? 0.32 : 0.16),
      side: BorderSide(color: accent.withValues(alpha: 0.16)),
      labelStyle: TextStyle(
        color: selected ? accent : _cs.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildMetricPickerStepper({
    required String value,
    required Color accent,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
    required String decreaseLabel,
    required String increaseLabel,
  }) {
    return Column(
      children: [
        _buildMetricPickerValueCard(value: value, accent: accent),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDecrease,
                icon: const Icon(Icons.remove_rounded),
                label: Text(
                  decreaseLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onIncrease,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  increaseLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<int?> _showHeightPickerDialog({
    required String title,
    required int min,
    required int max,
    required int initialValue,
    required String unit,
  }) async {
    int selected = initialValue.clamp(min, max);

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AtelierDialogFrame(
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricPickerStepper(
                value: '$selected $unit',
                accent: _cs.primary,
                onDecrease: selected > min
                    ? () => setDialogState(() => selected -= 1)
                    : null,
                onIncrease: selected < max
                    ? () => setDialogState(() => selected += 1)
                    : null,
                decreaseLabel: _isRu ? '−1 см' : '−1 cm',
                increaseLabel: _isRu ? '+1 см' : '+1 cm',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [('−10', -10), ('−5', -5), ('+5', 5), ('+10', 10)]
                    .map((entry) {
                      final next = (selected + entry.$2).clamp(min, max);
                      return _buildMetricPickerDeltaChip(
                        label: '${entry.$1} $unit',
                        accent: _cs.primary,
                        onPressed: () => setDialogState(() => selected = next),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <int>[160, 170, 180, 190]
                    .where((value) => value >= min && value <= max)
                    .map(
                      (value) => _buildMetricPickerPresetChip(
                        label: '$value $unit',
                        selected: selected == value,
                        accent: _cs.primary,
                        onPressed: () => setDialogState(() => selected = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr(context, 'cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: Text(_isRu ? 'Выбрать' : 'Select'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<double?> _showWeightPickerDialog({
    required String title,
    required double min,
    required double max,
    required double step,
    required double initialValue,
    required String unit,
  }) async {
    double selected = (((initialValue.clamp(min, max)) / step).round() * step)
        .toDouble();

    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AtelierDialogFrame(
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricPickerStepper(
                value: '${_formatWeightValue(selected)} $unit',
                accent: _cs.secondary,
                onDecrease: selected > min
                    ? () => setDialogState(() {
                        selected = (selected - step).clamp(min, max).toDouble();
                      })
                    : null,
                onIncrease: selected < max
                    ? () => setDialogState(() {
                        selected = (selected + step).clamp(min, max).toDouble();
                      })
                    : null,
                decreaseLabel: _isRu ? '−0.5 кг' : '−0.5 kg',
                increaseLabel: _isRu ? '+0.5 кг' : '+0.5 kg',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [('−5', -5.0), ('−1', -1.0), ('+1', 1.0), ('+5', 5.0)]
                    .map((entry) {
                      final next = (selected + entry.$2)
                          .clamp(min, max)
                          .toDouble();
                      return _buildMetricPickerDeltaChip(
                        label: '${entry.$1} $unit',
                        accent: _cs.secondary,
                        onPressed: () => setDialogState(() => selected = next),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <double>[55, 65, 75, 85, 95]
                    .where((value) => value >= min && value <= max)
                    .map(
                      (value) => _buildMetricPickerPresetChip(
                        label: '${_formatWeightValue(value)} $unit',
                        selected: (selected - value).abs() < 0.001,
                        accent: _cs.secondary,
                        onPressed: () => setDialogState(() => selected = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr(context, 'cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: Text(_isRu ? 'Выбрать' : 'Select'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickHeight(
    BuildContext sheetContext,
    void Function(void Function()) setModalState,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final current =
        _readInt(_heightController.text) ??
        _readInt(_profile?['height']) ??
        170;
    final selected = await _showHeightPickerDialog(
      title: tr(context, 'height_cm'),
      min: 130,
      max: 220,
      initialValue: current,
      unit: _isRu ? 'см' : 'cm',
    );
    if (selected == null || !sheetContext.mounted) return;
    setModalState(() => _heightController.text = selected.toString());
  }

  Future<void> _pickWeight(
    BuildContext sheetContext,
    void Function(void Function()) setModalState,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final current =
        _readDouble(_weightController.text) ??
        _readDouble(_profile?['weight']) ??
        70.0;
    final selected = await _showWeightPickerDialog(
      title: tr(context, 'weight_kg'),
      min: 35,
      max: 180,
      step: 0.5,
      initialValue: current,
      unit: _isRu ? 'кг' : 'kg',
    );
    if (selected == null || !sheetContext.mounted) return;
    setModalState(() => _weightController.text = _formatWeightValue(selected));
  }

  void _showEditProfileDialog() {
    _nameController.text = _profile?['name']?.toString() ?? '';
    _dobController.text =
        _dateOfBirthLabel() == (_isRu ? 'Не указана' : 'Not set')
        ? ''
        : _dateOfBirthLabel();
    _heightController.text = _readInt(_profile?['height'])?.toString() ?? '';
    final initialWeight = _readDouble(_profile?['weight']);
    _weightController.text = initialWeight == null
        ? ''
        : _formatWeightValue(initialWeight);

    _selectedGender = _profile?['gender']?.toString();
    _selectedActivity = _profile?['activityLevel']?.toString();
    _selectedGoal = _profile?['goalType']?.toString();

    _selectedDietPrefs = _profileTagSet(
      _profile?['dietPreferences'] ?? _profile?['diet_preferences'],
    );
    _selectedAllergies = _profileTagSet(_profile?['allergies']);
    _selectedHealthConditions = _profileTagSet(
      _profile?['healthConditions'] ?? _profile?['health_conditions'],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: StatefulBuilder(
          builder: (context, setModalState) => AtelierSheetFrame(
            title: tr(context, 'edit_profile_title'),
            subtitle: _isRu
                ? 'Обнови ключевые данные, чтобы рекомендации и цели оставались точными.'
                : 'Refresh the essentials so your targets and recommendations stay accurate.',
            onClose: () => Navigator.pop(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEditorSectionCard(
                  icon: Icons.person_rounded,
                  title: _isRu ? 'Личные данные' : 'Personal details',
                  subtitle: _isRu
                      ? 'Имя, дата рождения и пол для персональных рекомендаций.'
                      : 'Name, birthday, and gender for more personal guidance.',
                  accent: _cs.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditorFieldLabel(tr(context, 'name')),
                      TextField(
                        controller: _nameController,
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: InputDecoration(
                          hintText: _isRu ? 'Ваше имя' : 'Your name',
                          prefixIcon: Icon(Icons.person, color: _cs.primary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildEditorFieldLabel(tr(context, 'date_of_birth')),
                      TextField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: () => _pickDateOfBirth(context, setModalState),
                        decoration: InputDecoration(
                          hintText: _isRu ? 'Выберите дату' : 'Choose a date',
                          prefixIcon: Icon(
                            Icons.cake_rounded,
                            color: _cs.primary,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_rounded),
                            onPressed: () =>
                                _pickDateOfBirth(context, setModalState),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildEditorFieldLabel(tr(context, 'gender')),
                      _buildDropdownField(
                        tr(context, 'gender'),
                        ['MALE', 'FEMALE'],
                        _selectedGender,
                        (value) => setModalState(() => _selectedGender = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildEditorSectionCard(
                  icon: Icons.straighten_rounded,
                  title: _isRu ? 'Параметры тела' : 'Body metrics',
                  subtitle: _isRu
                      ? 'Рост и вес нужны для точных калорий и БЖУ.'
                      : 'Height and weight keep calories and macros accurate.',
                  accent: _cs.secondary,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEditorFieldLabel(tr(context, 'height_cm')),
                            TextField(
                              controller: _heightController,
                              onTapOutside: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: false,
                                  ),
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText: _isRu
                                    ? 'Например, 175'
                                    : 'For example, 175',
                                prefixIcon: Icon(
                                  Icons.height,
                                  color: _cs.secondary,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.tune_rounded),
                                  onPressed: () =>
                                      _pickHeight(context, setModalState),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEditorFieldLabel(tr(context, 'weight_kg')),
                            TextField(
                              controller: _weightController,
                              onTapOutside: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9,.]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText: _isRu
                                    ? 'Например, 75,3'
                                    : 'For example, 75.3',
                                prefixIcon: Icon(
                                  Icons.monitor_weight_rounded,
                                  color: _cs.secondary,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.tune_rounded),
                                  onPressed: () =>
                                      _pickWeight(context, setModalState),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildEditorSectionCard(
                  icon: Icons.tune_rounded,
                  title: _isRu ? 'Режим и цель' : 'Routine and goal',
                  subtitle: _isRu
                      ? 'Это влияет на дневную норму и рекомендации.'
                      : 'These drive your daily targets and recommendations.',
                  accent: _cs.tertiary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditorFieldLabel(tr(context, 'activity_level')),
                      _buildDropdownField(
                        tr(context, 'activity_level'),
                        [
                          'SEDENTARY',
                          'LIGHTLY_ACTIVE',
                          'MODERATELY_ACTIVE',
                          'VERY_ACTIVE',
                          'EXTRA_ACTIVE',
                        ],
                        _selectedActivity,
                        (value) =>
                            setModalState(() => _selectedActivity = value),
                      ),
                      const SizedBox(height: 16),
                      _buildEditorFieldLabel(tr(context, 'goal_type')),
                      _buildDropdownField(
                        tr(context, 'goal_type'),
                        ['LOSE_WEIGHT', 'MAINTAIN_WEIGHT', 'GAIN_MUSCLE'],
                        _selectedGoal,
                        (value) => setModalState(() => _selectedGoal = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildEditorSectionCard(
                  icon: Icons.restaurant_menu_rounded,
                  title: tr(context, 'diet_preferences'),
                  subtitle: _isRu
                      ? 'Выбери образ питания, чтобы лента и советы были релевантнее.'
                      : 'Pick how you eat so feeds and tips stay relevant.',
                  accent: _cs.primary,
                  child: _buildMultiSelectCard(
                    tr(context, 'diet_preferences'),
                    [
                      'VEGETARIAN',
                      'VEGAN',
                      'PESCATARIAN',
                      'KETO',
                      'PALEO',
                      'HALAL',
                      'KOSHER',
                      'GLUTEN_FREE',
                      'LACTOSE_FREE',
                      'OMNIVORE',
                    ],
                    _selectedDietPrefs,
                    (item, selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedDietPrefs.add(item);
                        } else {
                          _selectedDietPrefs.remove(item);
                        }
                      });
                    },
                    showTitle: false,
                  ),
                ),
                const SizedBox(height: 16),
                _buildEditorSectionCard(
                  icon: Icons.warning_amber_rounded,
                  title: tr(context, 'allergies'),
                  subtitle: _isRu
                      ? 'Отмеченные аллергены будут подсвечиваться в анализе.'
                      : 'Marked allergens will be highlighted in analysis.',
                  accent: _cs.error,
                  child: _buildMultiSelectCard(
                    tr(context, 'allergies'),
                    [
                      'GLUTEN',
                      'LACTOSE',
                      'TREE_NUTS',
                      'PEANUTS',
                      'EGGS',
                      'SOY',
                      'FISH',
                      'SHELLFISH',
                      'MUSTARD',
                      'SESAME',
                    ],
                    _selectedAllergies,
                    (item, selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedAllergies.add(item);
                        } else {
                          _selectedAllergies.remove(item);
                        }
                      });
                    },
                    showTitle: false,
                  ),
                ),
                const SizedBox(height: 16),
                _buildEditorSectionCard(
                  icon: Icons.health_and_safety_rounded,
                  title: tr(context, 'health_conditions'),
                  subtitle: _isRu
                      ? 'Это поможет корректнее считать цели и фильтровать еду.'
                      : 'This helps tune targets and food filtering more carefully.',
                  accent: _cs.tertiary,
                  child: _buildMultiSelectCard(
                    tr(context, 'health_conditions'),
                    [
                      'DIABETES_TYPE_1',
                      'DIABETES_TYPE_2',
                      'INSULIN_RESISTANCE',
                      'GASTRITIS',
                      'HYPERTENSION',
                      'HIGH_CHOLESTEROL',
                      'PREGNANCY',
                      'GOUT',
                      'KIDNEY_DISEASE',
                      'CELIAC_DISEASE',
                    ],
                    _selectedHealthConditions,
                    (item, selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedHealthConditions.add(item);
                        } else {
                          _selectedHealthConditions.remove(item);
                        }
                      });
                    },
                    showTitle: false,
                  ),
                ),
                const SizedBox(height: 20),
                AtelierSurfaceCard(
                  radius: 24,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(tr(context, 'cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                          ),
                          onPressed: () => _saveProfile(context),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(tr(context, 'save')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileSummarySheet({
    required String title,
    required IconData icon,
    required Color accent,
    required List<String> values,
    required String emptyText,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AtelierSheetFrame(
        title: title,
        onClose: () => Navigator.pop(context),
        child: values.isEmpty
            ? AtelierEmptyState(icon: icon, title: emptyText, accent: accent)
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: values
                    .map(
                      (value) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _blendWithSurface(
                            accent,
                            _isDarkTheme ? 0.26 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            color: _cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  void _showAccountStatusSheet({
    required String goal,
    required String activity,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AtelierSheetFrame(
        title: _isRu ? 'Состояние профиля' : 'Profile status',
        onClose: () => Navigator.pop(context),
        child: Column(
          children: [
            _buildProfileMetricCard(
              icon: Icons.flag_rounded,
              label: _isRu ? 'Цель' : 'Goal',
              value: goal,
              accent: _cs.primary,
            ),
            const SizedBox(height: 12),
            _buildProfileMetricCard(
              icon: Icons.bolt_rounded,
              label: tr(context, 'activity_level'),
              value: activity,
              accent: _cs.tertiary,
            ),
            const SizedBox(height: 12),
            _buildProfileMetricCard(
              icon: Icons.local_fire_department_rounded,
              label: tr(context, 'target_calories'),
              value: _getCaloriesDisplayText(_profile),
              accent: _cs.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        hintText: _isRu ? 'Выберите вариант' : 'Choose an option',
        filled: true,
        fillColor: _cs.surface.withValues(alpha: _isDarkTheme ? 0.42 : 0.78),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: _cs.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _cs.primary.withValues(alpha: 0.55)),
        ),
        prefixIcon: Icon(Icons.unfold_more_rounded, color: _cs.primary),
      ),
      initialValue: selected,
      isExpanded: true,
      items: items
          .map(
            (value) => DropdownMenuItem<String>(
              value: value,
              child: Text(_enumLabel(value)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildMultiSelectCard(
    String title,
    List<String> items,
    Set<String> selectedItems,
    Function(String, bool) onToggle, {
    bool showTitle = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => FilterChip(
                  label: Text(_enumLabel(item)),
                  selected: selectedItems.contains(item),
                  onSelected: (selected) => onToggle(item, selected),
                  selectedColor: _blendWithSurface(
                    _cs.primary,
                    _isDarkTheme ? 0.3 : 0.15,
                  ),
                  backgroundColor: _cs.surface.withValues(
                    alpha: _isDarkTheme ? 0.42 : 0.78,
                  ),
                  side: BorderSide(
                    color: _cs.outlineVariant.withValues(alpha: 0.28),
                  ),
                  checkmarkColor: _cs.primary,
                  labelStyle: TextStyle(
                    color: _cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildProfileSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    required Color accent,
  }) {
    final cs = _cs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _blendWithSurface(
                      accent,
                      _isDarkTheme ? 0.34 : 0.14,
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTagsWrap(
    List<String> tags, {
    required String emptyText,
    required Color accent,
  }) {
    final cs = _cs;
    if (tags.isEmpty) {
      return Text(
        emptyText,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _blendWithSurface(accent, _isDarkTheme ? 0.26 : 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Text(
                t,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildProfileMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    final cs = _cs;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blendWithSurface(accent, _isDarkTheme ? 0.26 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileVitalTile({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color accent,
  }) {
    final cs = _cs;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _blendWithSurface(accent, _isDarkTheme ? 0.34 : 0.18),
            _blendWithSurface(accent, _isDarkTheme ? 0.18 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: _isDarkTheme ? 0.14 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: _isDarkTheme ? 0.2 : 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileHeroChip({
    required IconData icon,
    required String text,
    required Color accent,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.sizeOf(context).width - 64;
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : fallbackWidth;
        final chipMaxWidth = availableWidth.clamp(120.0, 220.0).toDouble();

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: chipMaxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _blendWithSurface(accent, _isDarkTheme ? 0.24 : 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    String? trailing,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final color = accent ?? _cs.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing,
                style: TextStyle(
                  color: _cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right_rounded, color: _cs.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final cs = _cs;
    const accentPrimary = AppTheme.atelierGreen;
    const accentSecondary = AppTheme.atelierHoney;
    const accentMuted = Color(0xFF6E8C56);
    final height = _readInt(_profile?['height']);
    final weight = _readDouble(_profile?['weight']);
    final bmi = _calculateBmi(height, weight);

    final name = (_profile?['name'] ?? tr(context, 'profile_no_name'))
        .toString()
        .trim();
    final email = (_profile?['email'] ?? '').toString().trim();
    final goal = _enumLabel(_profile?['goalType']?.toString());
    final activity = _enumLabel(_profile?['activityLevel']?.toString());
    final heroNameFontSize = name.length >= 38
        ? 16.0
        : name.length >= 28
        ? 18.0
        : name.length >= 20
        ? 22.0
        : 26.0;
    final heroNameLineHeight = name.length >= 28 ? 1.12 : 1.05;
    final heroNameLetterSpacing = name.length >= 28 ? -0.4 : -0.2;

    final avatarUrl = _resolveAvatarUrl();
    final ImageProvider? avatarImage = _profileAvatarFile != null
        ? FileImage(_profileAvatarFile!)
        : (avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null);

    final allergies = _profileTags(_profile?['allergies']);
    final diets = _profileTags(
      _profile?['dietPreferences'] ?? _profile?['diet_preferences'],
    );
    final health = _profileTags(
      _profile?['healthConditions'] ?? _profile?['health_conditions'],
    );
    final weightSeries = _weightSeries(days: _selectedWeightPeriodDays);
    final loggedWeights = weightSeries
        .where((point) => point.weight != null)
        .map((point) => point.weight!)
        .toList();
    final minLoggedWeight = loggedWeights.isEmpty
        ? null
        : loggedWeights.reduce(math.min);
    final maxLoggedWeight = loggedWeights.isEmpty
        ? null
        : loggedWeights.reduce(math.max);
    final currentWeight = _currentWeightValue() ?? weight;
    final averageLoggedWeight = loggedWeights.isEmpty
        ? null
        : loggedWeights.reduce((a, b) => a + b) / loggedWeights.length;
    final selectedWeightIndex = _selectedWeightPointIndex?.clamp(
      0,
      weightSeries.length - 1,
    );
    double? firstLoggedWeight;
    double? lastLoggedWeight;
    for (final point in weightSeries) {
      if (point.weight == null) continue;
      firstLoggedWeight ??= point.weight;
      lastLoggedWeight = point.weight;
    }
    final rangeDelta =
        loggedWeights.length >= 2 &&
            firstLoggedWeight != null &&
            lastLoggedWeight != null
        ? lastLoggedWeight - firstLoggedWeight
        : null;
    final rangeWeightSpread = minLoggedWeight != null && maxLoggedWeight != null
        ? maxLoggedWeight - minLoggedWeight
        : null;
    final weightTrendAccent = rangeDelta == null || rangeDelta.abs() < 0.05
        ? accentMuted
        : rangeDelta > 0
        ? accentSecondary
        : accentPrimary;
    final weightTrendText = rangeDelta == null
        ? (_isRu
              ? 'Добавь несколько измерений'
              : 'Log a few days to see the trend')
        : rangeDelta.abs() < 0.05
        ? (_isRu
              ? 'Вес пока без заметных изменений'
              : 'Weight is holding steady')
        : rangeDelta > 0
        ? (_isRu
              ? '+${_formatWeightValue(rangeDelta.abs())} кг за $_selectedWeightPeriodDays дн.'
              : '+${_formatWeightValue(rangeDelta.abs())} kg in $_selectedWeightPeriodDays days')
        : (_isRu
              ? '-${_formatWeightValue(rangeDelta.abs())} кг за $_selectedWeightPeriodDays дн.'
              : '-${_formatWeightValue(rangeDelta.abs())} kg in $_selectedWeightPeriodDays days');

    Widget heroInfoCard({
      required IconData icon,
      required String label,
      required String value,
      required Color accent,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _cs.surface.withValues(alpha: _isDarkTheme ? 0.5 : 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accent.withValues(alpha: _isDarkTheme ? 0.24 : 0.16),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: _isDarkTheme ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 22,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: _cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _blendWithSurface(accentPrimary, _isDarkTheme ? 0.34 : 0.14),
                _blendWithSurface(accentSecondary, _isDarkTheme ? 0.22 : 0.1),
                _blendWithSurface(
                  AppTheme.atelierLime,
                  _isDarkTheme ? 0.14 : 0.16,
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The Organic Atelier',
                style: TextStyle(
                  color: accentPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoadingProfile)
                const LinearProgressIndicator(minHeight: 6)
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _blendWithSurface(
                          accentPrimary,
                          _isDarkTheme ? 0.3 : 0.15,
                        ),
                        _cs.surface.withValues(
                          alpha: _isDarkTheme ? 0.58 : 0.88,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: accentPrimary.withValues(
                        alpha: _isDarkTheme ? 0.32 : 0.2,
                      ),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: heroNameFontSize,
                          fontWeight: FontWeight.w900,
                          height: heroNameLineHeight,
                          letterSpacing: heroNameLetterSpacing,
                          color: _cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email.isEmpty
                            ? (_isRu ? 'Почта не указана' : 'Email not set')
                            : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _pickProfileAvatar(ImageSource.gallery),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 132,
                        height: 132,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentPrimary.withValues(
                                      alpha: _isDarkTheme ? 0.48 : 0.26,
                                    ),
                                    width: 2.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: _isDarkTheme ? 0.22 : 0.08,
                                      ),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: ClipOval(
                                    child: ColoredBox(
                                      color: _cs.surfaceContainerHighest
                                          .withValues(
                                            alpha: _isDarkTheme ? 0.88 : 0.95,
                                          ),
                                      child: avatarImage == null
                                          ? Center(
                                              child: Icon(
                                                Icons.person_rounded,
                                                size: 60,
                                                color: accentPrimary.withValues(
                                                  alpha: 0.94,
                                                ),
                                              ),
                                            )
                                          : Image(
                                              image: avatarImage,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                    _blendWithSurface(
                                      accentPrimary,
                                      _isDarkTheme ? 0.3 : 0.14,
                                    ),
                                    _cs.surface,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _cs.surface,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.photo_camera_rounded,
                                  size: 18,
                                  color: accentPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          heroInfoCard(
                            icon: Icons.local_fire_department_rounded,
                            label: _isRu ? 'Калории' : 'Calories',
                            value: _getCaloriesDisplayText(_profile),
                            accent: accentPrimary,
                          ),
                          const SizedBox(height: 10),
                          heroInfoCard(
                            icon: Icons.flag_rounded,
                            label: _isRu ? 'Цель' : 'Goal',
                            value: goal,
                            accent: accentSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(62),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _showEditProfileDialog,
                    icon: const Icon(Icons.edit_rounded, size: 22),
                    label: Text(
                      tr(context, 'edit_profile'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final cards = [
              _buildProfileVitalTile(
                icon: Icons.height_rounded,
                label: tr(context, 'height_cm'),
                value: height?.toString() ?? (_isRu ? 'Не указано' : 'Not set'),
                accent: accentPrimary,
              ),
              _buildProfileVitalTile(
                icon: Icons.monitor_weight_rounded,
                label: tr(context, 'weight_kg'),
                value:
                    (weight == null ? null : _formatWeightValue(weight)) ??
                    (_isRu ? 'Не указано' : 'Not set'),
                accent: accentSecondary,
              ),
              _buildProfileVitalTile(
                icon: Icons.bolt_rounded,
                label: tr(context, 'activity_level'),
                value: activity,
                accent: accentMuted,
              ),
              _buildProfileVitalTile(
                icon: Icons.favorite_rounded,
                label: tr(context, 'bmi_label'),
                value: bmi == null
                    ? (_isRu ? 'Не указано' : 'Not set')
                    : bmi.toStringAsFixed(1),
                subtitle: bmi == null ? null : _bmiStateLabel(bmi),
                accent: cs.error,
              ),
            ];

            if (!wide) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: List.generate(cards.length * 2 - 1, (index) {
                if (index.isOdd) return const SizedBox(width: 12);
                return Expanded(child: cards[index ~/ 2]);
              }),
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final progressCard = AtelierSurfaceCard(
              padding: const EdgeInsets.all(22),
              radius: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRu ? 'Динамика веса' : 'Weight Progress',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currentWeight == null ? '--' : _formatWeightValue(currentWeight)} ${_isRu ? 'кг' : 'kg'}',
                    style: TextStyle(
                      color: accentPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weightTrendText,
                    style: TextStyle(
                      color: weightTrendAccent,
                      fontWeight: FontWeight.w700,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildWeightPeriodSelector(accent: accentPrimary),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildProfileHeroChip(
                        icon: Icons.show_chart_rounded,
                        text: averageLoggedWeight == null
                            ? (_isRu
                                  ? 'Среднее появится позже'
                                  : 'Average will appear soon')
                            : (_isRu
                                  ? 'Среднее ${_formatWeightValue(averageLoggedWeight)} кг'
                                  : 'Average ${_formatWeightValue(averageLoggedWeight)} kg'),
                        accent: accentPrimary,
                      ),
                      _buildProfileHeroChip(
                        icon: Icons.swap_vert_rounded,
                        text: rangeWeightSpread == null
                            ? (_isRu
                                  ? 'Диапазон ещё не посчитан'
                                  : 'Range is not ready yet')
                            : (_isRu
                                  ? 'Диапазон ${_formatWeightValue(rangeWeightSpread)} кг'
                                  : 'Range ${_formatWeightValue(rangeWeightSpread)} kg'),
                        accent: accentSecondary,
                      ),
                      _buildProfileHeroChip(
                        icon: Icons.event_available_rounded,
                        text: _isRu
                            ? '${loggedWeights.length}/${weightSeries.length} дней отмечено'
                            : '${loggedWeights.length}/${weightSeries.length} days logged',
                        accent: accentMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: Container(
                      key: ValueKey('weight-chart-$_selectedWeightPeriodDays'),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _blendWithSurface(
                              accentPrimary,
                              _isDarkTheme ? 0.24 : 0.1,
                            ),
                            _blendWithSurface(
                              accentSecondary,
                              _isDarkTheme ? 0.14 : 0.07,
                            ),
                            _blendWithSurface(
                              accentMuted,
                              _isDarkTheme ? 0.12 : 0.05,
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: accentPrimary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        children: [
                          TweenAnimationBuilder<double>(
                            key: ValueKey(
                              'weight-chart-animation-$_selectedWeightPeriodDays',
                            ),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (context, progress, _) => SizedBox(
                              height: 164,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildWeightChartYAxis(weightSeries),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final width = constraints.maxWidth;
                                        final tooltipWidth = math.min(
                                          166.0,
                                          width,
                                        );
                                        final tooltipLeft =
                                            selectedWeightIndex == null
                                            ? 0.0
                                            : (_chartXForIndex(
                                                        selectedWeightIndex,
                                                        weightSeries.length,
                                                        width,
                                                      ) -
                                                      tooltipWidth / 2)
                                                  .clamp(
                                                    0.0,
                                                    math.max(
                                                      0.0,
                                                      width - tooltipWidth,
                                                    ),
                                                  )
                                                  .toDouble();

                                        void selectAtOffset(
                                          Offset localPosition,
                                        ) {
                                          _setSelectedWeightPointIndex(
                                            _chartIndexForDx(
                                              localPosition.dx,
                                              weightSeries.length,
                                              width,
                                            ),
                                          );
                                        }

                                        return GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (details) =>
                                              selectAtOffset(
                                                details.localPosition,
                                              ),
                                          onHorizontalDragStart: (details) =>
                                              selectAtOffset(
                                                details.localPosition,
                                              ),
                                          onHorizontalDragUpdate: (details) =>
                                              selectAtOffset(
                                                details.localPosition,
                                              ),
                                          child: Stack(
                                            children: [
                                              CustomPaint(
                                                painter:
                                                    _WeightSparklinePainter(
                                                      points: weightSeries,
                                                      progress: progress,
                                                      selectedIndex:
                                                          selectedWeightIndex,
                                                      lineColor: accentPrimary,
                                                      fillColor: accentPrimary
                                                          .withValues(
                                                            alpha: 0.22,
                                                          ),
                                                      todayColor:
                                                          accentSecondary,
                                                      gridColor: cs
                                                          .outlineVariant
                                                          .withValues(
                                                            alpha: 0.22,
                                                          ),
                                                      inactiveColor: cs
                                                          .outlineVariant
                                                          .withValues(
                                                            alpha: 0.42,
                                                          ),
                                                      selectionColor:
                                                          accentSecondary,
                                                    ),
                                                child: const SizedBox.expand(),
                                              ),
                                              if (selectedWeightIndex != null)
                                                Positioned(
                                                  left: tooltipLeft,
                                                  top: 0,
                                                  width: tooltipWidth,
                                                  child: _buildWeightChartTooltip(
                                                    title: _weightTooltipDate(
                                                      weightSeries[selectedWeightIndex]
                                                          .date,
                                                    ),
                                                    value:
                                                        weightSeries[selectedWeightIndex]
                                                                .weight ==
                                                            null
                                                        ? (_isRu
                                                              ? 'Нет записи'
                                                              : 'No entry')
                                                        : '${_formatWeightValue(weightSeries[selectedWeightIndex].weight!)} ${_isRu ? 'кг' : 'kg'}',
                                                    accent: accentPrimary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 64),
                            child: _buildWeightChartAxisLabels(weightSeries),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _promptTodayWeightEntry,
                      icon: const Icon(Icons.monitor_weight_rounded),
                      label: Text(
                        _isRu ? 'Отметить вес сегодня' : 'Log today weight',
                      ),
                    ),
                  ),
                ],
              ),
            );

            final goalsCard = AtelierSurfaceCard(
              padding: const EdgeInsets.all(22),
              radius: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRu ? 'Активные цели' : 'Active Goals',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildProfileMetricCard(
                    icon: Icons.flag_rounded,
                    label: _isRu ? 'Главная цель' : 'Primary goal',
                    value: goal,
                    accent: accentPrimary,
                  ),
                  const SizedBox(height: 12),
                  _buildProfileMetricCard(
                    icon: Icons.local_fire_department_rounded,
                    label: tr(context, 'target_calories'),
                    value: _getCaloriesDisplayText(_profile),
                    accent: accentSecondary,
                  ),
                  const SizedBox(height: 12),
                  _buildProfileMetricCard(
                    icon: Icons.bolt_rounded,
                    label: tr(context, 'activity_level'),
                    value: activity,
                    accent: accentMuted,
                  ),
                ],
              ),
            );

            if (constraints.maxWidth < 820) {
              return Column(
                children: [progressCard, const SizedBox(height: 16), goalsCard],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: progressCard),
                const SizedBox(width: 16),
                Expanded(child: goalsCard),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _buildProfileSectionCard(
          icon: Icons.eco_rounded,
          title: tr(context, 'diet_preferences'),
          accent: accentPrimary,
          child: _buildProfileTagsWrap(
            diets,
            emptyText: _isRu ? 'Не выбрано' : 'Not selected',
            accent: accentPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildProfileSectionCard(
          icon: Icons.warning_amber_rounded,
          title: tr(context, 'allergies'),
          accent: cs.error,
          child: _buildProfileTagsWrap(
            allergies,
            emptyText: _isRu ? 'Не выбрано' : 'Not selected',
            accent: cs.error,
          ),
        ),
        const SizedBox(height: 12),
        _buildProfileSectionCard(
          icon: Icons.health_and_safety_rounded,
          title: tr(context, 'health_conditions'),
          accent: accentMuted,
          child: _buildProfileTagsWrap(
            health,
            emptyText: _isRu ? 'Не выбрано' : 'Not selected',
            accent: accentMuted,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isRu ? 'Настройки аккаунта' : 'Account Settings',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        AtelierSurfaceCard(
          padding: EdgeInsets.zero,
          radius: 28,
          child: Column(
            children: [
              _buildSettingsRow(
                icon: Icons.person_outline_rounded,
                title: _isRu ? 'Личные данные' : 'Personal Information',
                onTap: _showEditProfileDialog,
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.24),
              ),
              _buildSettingsRow(
                icon: Icons.restaurant_rounded,
                title: _isRu ? 'Пищевые предпочтения' : 'Dietary Preferences',
                trailing: diets.isEmpty ? null : diets.first,
                onTap: () => _showProfileSummarySheet(
                  title: _isRu ? 'Пищевые предпочтения' : 'Dietary preferences',
                  icon: Icons.restaurant_rounded,
                  accent: _cs.primary,
                  values: diets,
                  emptyText: _isRu ? 'Предпочтения не выбраны' : 'No diets set',
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.24),
              ),
              _buildSettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: _isRu ? 'Состояния здоровья' : 'Health Conditions',
                trailing: health.isEmpty ? null : health.first,
                onTap: () => _showProfileSummarySheet(
                  title: _isRu ? 'Состояния здоровья' : 'Health conditions',
                  icon: Icons.health_and_safety_rounded,
                  accent: _cs.error,
                  values: health,
                  emptyText: _isRu
                      ? 'Состояния не выбраны'
                      : 'No conditions selected',
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.24),
              ),
              _buildSettingsRow(
                icon: Icons.settings_suggest_rounded,
                title: tr(context, 'settings'),
                onTap: () => showAppSettingsSheet(context),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.24),
              ),
              _buildSettingsRow(
                icon: Icons.verified_user_rounded,
                title: _isRu ? 'Статус профиля' : 'Profile status',
                trailing: _isRu ? 'Активен' : 'Active',
                onTap: () =>
                    _showAccountStatusSheet(goal: goal, activity: activity),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<int> _weightAxisIndices(int total) {
    if (total <= 1) return const [0];
    if (total <= 7) return List<int>.generate(total, (index) => index);
    if (total <= 30) {
      final indices = <int>{0, total ~/ 3, (total * 2) ~/ 3, total - 1};
      return indices.toList()..sort();
    }
    final indices = <int>{0, total ~/ 2, total - 1};
    return indices.toList()..sort();
  }

  List<double> _weightYAxisTicks(List<_WeightDayPoint> weightSeries) {
    final values = weightSeries
        .where((point) => point.weight != null)
        .map((point) => point.weight!)
        .toList(growable: false);
    if (values.isEmpty) {
      return const [0, 0, 0];
    }
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final padding = math.max((maxValue - minValue) * 0.35, 0.6);
    final low = minValue - padding;
    final high = maxValue + padding;
    final mid = (low + high) / 2;
    return [high, mid, low];
  }

  Widget _buildWeightChartYAxis(List<_WeightDayPoint> weightSeries) {
    final labels = _weightYAxisTicks(
      weightSeries,
    ).map((value) => _formatWeightValue(value)).toList(growable: false);
    return Container(
      width: 52,
      height: 164,
      padding: const EdgeInsets.only(top: 12, bottom: 14, right: 10),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: _cs.outlineVariant.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: labels
            .map(
              (label) => Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: _cs.onSurfaceVariant.withValues(alpha: 0.84),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildWeightChartAxisLabels(List<_WeightDayPoint> weightSeries) {
    return SizedBox(
      height: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final indices = _weightAxisIndices(weightSeries.length);
          final labelWidth = weightSeries.length <= 7 ? 42.0 : 58.0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final index in indices)
                Positioned(
                  left:
                      (_chartXForIndex(index, weightSeries.length, width) -
                              labelWidth / 2)
                          .clamp(0.0, math.max(0.0, width - labelWidth))
                          .toDouble(),
                  width: labelWidth,
                  child: SizedBox(
                    height: 18,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _weightChartLabel(
                          weightSeries[index].date,
                          index,
                          weightSeries.length,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Path _buildWeightInterpolatedPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;

  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) {
    path.lineTo(points.first.dx, points.first.dy);
    return path;
  }

  if (points.length == 2) {
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  for (var i = 0; i < points.length - 1; i++) {
    final previous = i == 0 ? points[i] : points[i - 1];
    final current = points[i];
    final next = points[i + 1];
    final following = i + 2 < points.length ? points[i + 2] : next;

    final controlPoint1 = Offset(
      current.dx + (next.dx - previous.dx) / 6,
      current.dy + (next.dy - previous.dy) / 6,
    );
    final controlPoint2 = Offset(
      next.dx - (following.dx - current.dx) / 6,
      next.dy - (following.dy - current.dy) / 6,
    );
    final segmentMinY = math.min(current.dy, next.dy);
    final segmentMaxY = math.max(current.dy, next.dy);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy.clamp(segmentMinY, segmentMaxY).toDouble(),
      controlPoint2.dx,
      controlPoint2.dy.clamp(segmentMinY, segmentMaxY).toDouble(),
      next.dx,
      next.dy,
    );
  }

  return path;
}

class _WeightSparklinePainter extends CustomPainter {
  const _WeightSparklinePainter({
    required this.points,
    required this.progress,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.todayColor,
    required this.gridColor,
    required this.inactiveColor,
    required this.selectionColor,
  });

  final List<_WeightDayPoint> points;
  final double progress;
  final int? selectedIndex;
  final Color lineColor;
  final Color fillColor;
  final Color todayColor;
  final Color gridColor;
  final Color inactiveColor;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const topPadding = 12.0;
    const bottomPadding = 14.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartBottom = size.height - bottomPadding;
    final today = DateTime.now();

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = topPadding + chartHeight * (i / 2);
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final values = points
        .where((point) => point.weight != null)
        .map((point) => point.weight!)
        .toList();

    double xFor(int index) {
      return points.length == 1
          ? size.width / 2
          : (size.width / points.length) * (index + 0.5);
    }

    final todayIndex = points.indexWhere(
      (point) =>
          point.date.year == today.year &&
          point.date.month == today.month &&
          point.date.day == today.day,
    );
    if (todayIndex >= 0) {
      final x = xFor(todayIndex);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 14, topPadding - 2, 28, chartHeight + 10),
          const Radius.circular(18),
        ),
        Paint()..color = todayColor.withValues(alpha: 0.08),
      );
    }

    if (values.isEmpty) {
      final dotPaint = Paint()
        ..color = inactiveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      for (var i = 0; i < points.length; i++) {
        canvas.drawCircle(Offset(xFor(i), chartBottom - 8), 4, dotPaint);
      }
      return;
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final padding = math.max((maxValue - minValue) * 0.35, 0.6);
    final low = minValue - padding;
    final high = maxValue + padding;
    final range = math.max(high - low, 1.0);

    final plotPoints = <(int index, Offset offset)>[];
    for (var i = 0; i < points.length; i++) {
      final weight = points[i].weight;
      final x = xFor(i);
      if (weight == null) {
        canvas.drawCircle(
          Offset(x, chartBottom - 8),
          4,
          Paint()
            ..color = inactiveColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        continue;
      }
      final normalized = (weight - low) / range;
      final y = chartBottom - normalized * chartHeight;
      plotPoints.add((i, Offset(x, y)));
    }

    if (plotPoints.isEmpty) return;

    final linePath = _buildWeightInterpolatedPath(
      plotPoints.map((point) => point.$2).toList(),
    );

    if (plotPoints.length >= 2) {
      final areaPath = Path.from(linePath)
        ..lineTo(plotPoints.last.$2.dx, chartBottom)
        ..lineTo(plotPoints.first.$2.dx, chartBottom)
        ..close();
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height),
      );
      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fillColor.withValues(alpha: 0.9),
              fillColor.withValues(alpha: 0.03),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );

      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor.withValues(alpha: 0.24)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 3.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    for (final point in plotPoints) {
      if (point.$2.dx > size.width * progress.clamp(0.0, 1.0)) {
        continue;
      }
      final isToday =
          points[point.$1].date.year == today.year &&
          points[point.$1].date.month == today.month &&
          points[point.$1].date.day == today.day;
      if (isToday) {
        canvas.drawCircle(
          point.$2,
          8,
          Paint()..color = todayColor.withValues(alpha: 0.22),
        );
      }
      canvas.drawCircle(
        point.$2,
        5.2,
        Paint()..color = Colors.white.withValues(alpha: 0.94),
      );
      canvas.drawCircle(
        point.$2,
        3.4,
        Paint()..color = isToday ? todayColor : lineColor,
      );
    }

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      (int index, Offset offset)? selectedPoint;
      for (final point in plotPoints) {
        if (point.$1 == selectedIndex) {
          selectedPoint = point;
          break;
        }
      }
      if (selectedPoint != null &&
          selectedPoint.$2.dx <= size.width * progress.clamp(0.0, 1.0)) {
        canvas.drawLine(
          Offset(selectedPoint.$2.dx, topPadding),
          Offset(selectedPoint.$2.dx, chartBottom),
          Paint()
            ..color = selectionColor.withValues(alpha: 0.28)
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          selectedPoint.$2,
          10,
          Paint()..color = selectionColor.withValues(alpha: 0.18),
        );
        canvas.drawCircle(
          selectedPoint.$2,
          6,
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );
        canvas.drawCircle(selectedPoint.$2, 4, Paint()..color = selectionColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightSparklinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.todayColor != todayColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.selectionColor != selectionColor;
  }
}
