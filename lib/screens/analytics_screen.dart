import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../repositories/app_repository.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  static const String _analyticsPeriodStorageKey = 'analytics_period_days_v1';

  final AppRepository repository = AppRepository.instance;

  bool _loading = true;
  bool _isRefreshingRange = false;
  Map<String, dynamic>? _daily;
  Map<String, dynamic>? _weekly;
  Map<String, dynamic>? _macros;
  List<Map<String, dynamic>> _meals = const [];
  int _selectedPeriodDays = 7;
  int? _selectedCaloriePointIndex;
  int? _selectedMacroPointIndex;
  bool _showProteinTrend = true;
  bool _showFatTrend = true;
  bool _showCarbTrend = true;
  late final AnimationController _chartAnimationController;
  late final Animation<double> _chartAnimation;

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  bool get _isDark => _theme.brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _chartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.easeOutCubic,
    );
    _restorePreferencesAndLoad();
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final initialLoad = _daily == null && _weekly == null && _macros == null;
    setState(() {
      _loading = initialLoad;
      _isRefreshingRange = !initialLoad;
    });
    final rangeStart = _rangeStart();
    final rangeEnd = _rangeEnd();
    final results = await Future.wait<Object?>([
      repository.getDailyAnalytics(),
      repository.getWeeklyAnalytics(dateFrom: rangeStart, dateTo: rangeEnd),
      repository.getMacroSummary(dateFrom: rangeStart, dateTo: rangeEnd),
      repository.getMeals(dateFrom: rangeStart, dateTo: rangeEnd),
    ]);
    if (!mounted) return;
    setState(() {
      _daily = results[0] as Map<String, dynamic>?;
      _weekly = results[1] as Map<String, dynamic>?;
      _macros = results[2] as Map<String, dynamic>?;
      _meals = (results[3] as List).cast<Map<String, dynamic>>();
      _loading = false;
      _isRefreshingRange = false;
    });
    _chartAnimationController.forward(from: 0);
  }

  Future<void> _restorePreferencesAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPeriod = prefs.getInt(_analyticsPeriodStorageKey);
    if (savedPeriod != null &&
        const {7, 30, 90}.contains(savedPeriod) &&
        mounted) {
      setState(() => _selectedPeriodDays = savedPeriod);
    }
    await _load();
  }

  Future<void> _setSelectedPeriodDays(int days) async {
    if (_selectedPeriodDays == days) return;
    setState(() {
      _selectedPeriodDays = days;
      _selectedCaloriePointIndex = null;
      _selectedMacroPointIndex = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_analyticsPeriodStorageKey, days);
    await _load();
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) => _toDouble(value).round();

  String _formatWhole(num value) {
    final rounded = value.round();
    return rounded.toString();
  }

  String _formatOneDecimal(num value) {
    final normalized = value.toDouble();
    if (normalized == normalized.roundToDouble()) {
      return normalized.toInt().toString();
    }
    return normalized.toStringAsFixed(1);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _rangeEnd() => _dateOnly(DateTime.now());

  DateTime _rangeStart() =>
      _rangeEnd().subtract(Duration(days: _selectedPeriodDays - 1));

  String _dateKey(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _periodChipLabel(int days) => _isRu ? '$days дн.' : '${days}d';

  double _chartXForIndex(int index, int count, double width) {
    if (count <= 1) return width / 2;
    return width * (index / (count - 1));
  }

  int _chartIndexForDx(double dx, int count, double width) {
    if (count <= 1 || width <= 0) return 0;
    final ratio = (dx / width).clamp(0.0, 1.0);
    return (ratio * (count - 1)).round().clamp(0, count - 1);
  }

  String _chartTooltipDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  void _toggleMacroVisibility(String key) {
    final selectedCount = <bool>[
      _showProteinTrend,
      _showFatTrend,
      _showCarbTrend,
    ].where((selected) => selected).length;

    setState(() {
      switch (key) {
        case 'protein':
          if (_showProteinTrend && selectedCount == 1) return;
          _showProteinTrend = !_showProteinTrend;
          break;
        case 'fat':
          if (_showFatTrend && selectedCount == 1) return;
          _showFatTrend = !_showFatTrend;
          break;
        case 'carb':
          if (_showCarbTrend && selectedCount == 1) return;
          _showCarbTrend = !_showCarbTrend;
          break;
      }
    });
    _chartAnimationController.forward(from: 0);
  }

  String _axisLabelForDate(DateTime date, int index, int total) {
    if (total <= 7) {
      const ru = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return (_isRu ? ru : en)[date.weekday - 1];
    }

    final step = total <= 30 ? 5 : 15;
    final shouldShow =
        index == 0 ||
        index == total - 1 ||
        index == total ~/ 2 ||
        index % step == 0;
    if (!shouldShow) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  DateTime? _parseItemDate(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed == null ? null : _dateOnly(parsed.toLocal());
  }

  List<_CaloriePoint> _buildCaloriePointsFromAnalytics(
    List<dynamic> rawPoints, {
    required DateTime start,
    required int days,
  }) {
    final totals = <String, double>{};
    for (final raw in rawPoints) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final date = _parseItemDate(item['date']);
      if (date == null) continue;
      totals.update(
        _dateKey(date),
        (value) => value + _toDouble(item['calories']),
        ifAbsent: () => _toDouble(item['calories']),
      );
    }

    return List.generate(days, (index) {
      final day = start.add(Duration(days: index));
      return _CaloriePoint(
        date: day,
        label: _axisLabelForDate(day, index, days),
        value: totals[_dateKey(day)] ?? 0,
      );
    });
  }

  List<_MacroDayPoint> _buildMacroDayPoints({
    required List<Map<String, dynamic>> meals,
    required DateTime start,
    required int days,
  }) {
    final totals = <String, ({double proteins, double fats, double carbs})>{};
    for (final meal in meals) {
      final date = _parseItemDate(
        meal['eatenAt'] ?? meal['createdAt'] ?? meal['created_at'],
      );
      if (date == null) continue;
      final key = _dateKey(date);
      final current = totals[key] ?? (proteins: 0.0, fats: 0.0, carbs: 0.0);
      totals[key] = (
        proteins: current.proteins + _toDouble(meal['proteins']),
        fats: current.fats + _toDouble(meal['fats']),
        carbs: current.carbs + _toDouble(meal['carbs']),
      );
    }

    return List.generate(days, (index) {
      final day = start.add(Duration(days: index));
      final values =
          totals[_dateKey(day)] ?? (proteins: 0.0, fats: 0.0, carbs: 0.0);
      return _MacroDayPoint(
        date: day,
        label: _axisLabelForDate(day, index, days),
        proteins: values.proteins,
        fats: values.fats,
        carbs: values.carbs,
      );
    });
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color? color,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:
            color ??
            Color.alphaBlend(
              _cs.surfaceContainerHighest.withValues(
                alpha: _isDark ? 0.34 : 0.76,
              ),
              _cs.surface,
            ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _cs.outlineVariant.withValues(alpha: _isDark ? 0.36 : 0.5),
        ),
      ),
      child: child,
    );
  }

  Widget _chartTooltip({
    required String title,
    required List<(Color color, String text)> rows,
  }) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 170),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            _cs.surface.withValues(alpha: _isDark ? 0.88 : 0.96),
            _cs.surfaceContainerHighest,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cs.outlineVariant.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.24 : 0.08),
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
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            for (final row in rows) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: row.$1,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      row.$2,
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              if (row != rows.last) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _animatedPeriodPane({required String id, required Widget child}) {
    return AnimatedSwitcher(
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
      child: KeyedSubtree(
        key: ValueKey('$id-$_selectedPeriodDays'),
        child: child,
      ),
    );
  }

  Widget _sectionHeader({
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
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: _cs.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: _cs.onSurfaceVariant.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [7, 30, 90];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final days in periods)
          ChoiceChip(
            label: Text(_periodChipLabel(days)),
            selected: _selectedPeriodDays == days,
            showCheckmark: false,
            onSelected: _loading || _isRefreshingRange
                ? null
                : (_) => _setSelectedPeriodDays(days),
            selectedColor: _cs.primary.withValues(alpha: 0.16),
            side: BorderSide(
              color:
                  (_selectedPeriodDays == days
                          ? _cs.primary
                          : _cs.outlineVariant)
                      .withValues(alpha: 0.28),
            ),
            backgroundColor: _cs.surfaceContainerHighest.withValues(
              alpha: _isDark ? 0.28 : 0.7,
            ),
            labelStyle: TextStyle(
              color: _selectedPeriodDays == days
                  ? _cs.primary
                  : _cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  Widget _heroPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendPill({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _consistencyScore(List<_CaloriePoint> points, double averageCalories) {
    if (points.isEmpty || averageCalories <= 0) return 0;
    final deviation =
        points
            .map((point) => (point.value - averageCalories).abs())
            .reduce((a, b) => a + b) /
        points.length;
    final ratio = deviation / averageCalories;
    return (100 - ratio * 100).clamp(0, 100).toDouble();
  }

  String _macroMoodLabel({
    required double proteinShare,
    required double fatShare,
    required double carbShare,
  }) {
    final shares = [proteinShare, fatShare, carbShare]..sort();
    if ((shares.last - shares.first) < 0.12) {
      return _isRu
          ? 'Сбалансированное распределение макросов'
          : 'Balanced macro split';
    }
    if (proteinShare >= fatShare && proteinShare >= carbShare) {
      return _isRu ? 'Акцент на белке' : 'Protein-forward balance';
    }
    if (carbShare >= proteinShare && carbShare >= fatShare) {
      return _isRu ? 'Углеводы доминируют' : 'Carb-led balance';
    }
    return _isRu ? 'Более плотный жировой профиль' : 'Fat-forward balance';
  }

  Widget _buildMacroBalanceBar({
    required double proteinShare,
    required double fatShare,
    required double carbShare,
  }) {
    final segments = [
      (
        label: _isRu ? 'Белки' : 'Protein',
        share: proteinShare,
        color: _cs.primary,
      ),
      (label: _isRu ? 'Жиры' : 'Fat', share: fatShare, color: _cs.secondary),
      (
        label: _isRu ? 'Углеводы' : 'Carbs',
        share: carbShare,
        color: _cs.tertiary,
      ),
    ].where((segment) => segment.share > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 16,
            color: _cs.outlineVariant.withValues(alpha: 0.14),
            child: Row(
              children: [
                for (final segment in segments)
                  Expanded(
                    flex: math.max(1, (segment.share * 100).round()),
                    child: Container(color: segment.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final segment in segments)
              _trendPill(
                icon: Icons.circle,
                label: segment.label,
                value: '${_formatWhole(segment.share * 100)}%',
                accent: segment.color,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyRhythmCard(
    List<_CaloriePoint> points,
    double averageCalories,
  ) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = math.max(
      points.map((point) => point.value).reduce(math.max),
      1.0,
    );
    final consistency = _consistencyScore(points, averageCalories);
    final rhythmAccent = consistency >= 76
        ? _cs.primary
        : consistency >= 58
        ? _cs.secondary
        : _cs.tertiary;
    final rhythmLabel = consistency >= 76
        ? (_isRu ? 'Ровный ритм' : 'Steady rhythm')
        : consistency >= 58
        ? (_isRu ? 'Небольшие колебания' : 'Light swings')
        : (_isRu ? 'Период был неровным' : 'Volatile range');

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRu ? 'Ритм периода' : 'Period rhythm',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rhythmLabel,
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _heroPill(
                icon: Icons.multiline_chart_rounded,
                label:
                    '${_formatWhole(consistency)}% ${_isRu ? 'стабильности' : 'stability'}',
                color: rhythmAccent,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 148,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatWhole(point.value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _cs.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor:
                                    0.18 + (point.value / maxValue) * 0.82,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        _cs.primary.withValues(alpha: 0.92),
                                        _cs.secondary.withValues(alpha: 0.72),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _cs.primary.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            point.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _cs.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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

  Widget _kpiCard({
    required IconData icon,
    required String title,
    required String value,
    required String note,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _cs.onSurfaceVariant.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroLegend({
    required String label,
    required String value,
    required String share,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            share,
            style: TextStyle(
              color: _cs.onSurfaceVariant.withValues(alpha: 0.84),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyCard({
    required String title,
    required String value,
    required String note,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 0.95,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.24,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHero({
    required int dailyCalories,
    required int mealsCount,
    required int expiringSoonCount,
    required int usedPantryCount,
    required double averageCalories,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _cs.primary.withValues(alpha: _isDark ? 0.26 : 0.14),
            _cs.secondary.withValues(alpha: _isDark ? 0.18 : 0.1),
            _cs.tertiary.withValues(alpha: _isDark ? 0.24 : 0.12),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -10,
            child: Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                color: _cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -18,
            left: -14,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: _cs.tertiary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRu ? 'Аналитика Atelier' : 'Atelier Analytics',
                style: TextStyle(
                  color: _cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRu
                    ? 'История\nтвоего питания'
                    : 'The story\nof your nutrition',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 0.98,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isRu
                    ? 'Смотри дневной ритм, недельную кривую и баланс макросов в одном спокойном дашборде.'
                    : 'Read your daily rhythm, weekly curve, and macro balance in one calm dashboard.',
                style: TextStyle(
                  color: _cs.onSurfaceVariant.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                  height: 1.28,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroPill(
                    icon: Icons.local_fire_department_rounded,
                    label: '$dailyCalories ${_isRu ? 'ккал' : 'kcal'}',
                    color: _cs.primary,
                  ),
                  _heroPill(
                    icon: Icons.restaurant_rounded,
                    label: _isRu
                        ? '$mealsCount приемов пищи'
                        : '$mealsCount meals',
                    color: _cs.secondary,
                  ),
                  _heroPill(
                    icon: Icons.inventory_2_rounded,
                    label: _isRu
                        ? '$expiringSoonCount скоро истекает'
                        : '$expiringSoonCount expiring',
                    color: _cs.tertiary,
                  ),
                  _heroPill(
                    icon: Icons.auto_graph_rounded,
                    label: _isRu
                        ? '${_formatWhole(averageCalories)} среднее за день'
                        : '${_formatWhole(averageCalories)} avg / day',
                    color: _cs.error,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  final width = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: _storyCard(
                          title: _isRu ? 'Использовано' : 'Used',
                          value: '$usedPantryCount',
                          note: _isRu
                              ? 'Продуктов из кладовой за неделю.'
                              : 'Pantry items used throughout the week.',
                          accent: _cs.primary,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _storyCard(
                          title: _isRu ? 'Темп' : 'Rhythm',
                          value: averageCalories >= 1800
                              ? (_isRu ? 'Плотный' : 'High')
                              : averageCalories >= 1200
                              ? (_isRu ? 'Ровный' : 'Balanced')
                              : (_isRu ? 'Легкий' : 'Light'),
                          note: _isRu
                              ? 'Оценка недельной интенсивности питания.'
                              : 'A read on your weekly nutrition intensity.',
                          accent: _cs.tertiary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTodayGrid({
    required int dailyCalories,
    required int mealsCount,
    required int expiringSoonCount,
    required int usedPantryCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 420
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: cardWidth,
              child: _kpiCard(
                icon: Icons.local_fire_department_rounded,
                title: _isRu ? 'Калории сегодня' : 'Calories today',
                value: '$dailyCalories',
                note: _isRu ? 'Текущий дневной объем' : 'Current daily volume',
                accent: _cs.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _kpiCard(
                icon: Icons.restaurant_rounded,
                title: _isRu ? 'Приемы пищи' : 'Meals',
                value: '$mealsCount',
                note: _isRu ? 'Записи за день' : 'Logged for today',
                accent: _cs.secondary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _kpiCard(
                icon: Icons.warning_amber_rounded,
                title: _isRu ? 'Скоро истекает' : 'Expiring soon',
                value: '$expiringSoonCount',
                note: _isRu ? 'Нужно использовать' : 'Needs attention',
                accent: _cs.tertiary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _kpiCard(
                icon: Icons.inventory_2_outlined,
                title: _isRu ? 'Использовано' : 'Used in range',
                value: '$usedPantryCount',
                note: _isRu
                    ? 'Из кладовой за выбранный период'
                    : 'From pantry in selected range',
                accent: _cs.error,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeeklyChart(
    List<_CaloriePoint> points,
    double weeklyCalories,
    double averageCalories,
  ) {
    if (points.isEmpty) {
      return _glassCard(
        child: Text(
          _isRu
              ? 'Пока нет точек за выбранный период.'
              : 'No data points yet for the selected range.',
          style: TextStyle(
            color: _cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final peakPoint = points.reduce((a, b) => a.value >= b.value ? a : b);
    final lowPoint = points.reduce((a, b) => a.value <= b.value ? a : b);
    final deltaFromStart = points.length < 2
        ? 0.0
        : points.last.value - points.first.value;
    final trendAccent = deltaFromStart >= 0 ? _cs.secondary : _cs.primary;
    final selectedIndex = _selectedCaloriePointIndex?.clamp(
      0,
      points.length - 1,
    );

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRu ? 'Калорийность по дням' : 'Calories by day',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRu
                          ? '${_formatWhole(weeklyCalories)} ккал за период'
                          : '${_formatWhole(weeklyCalories)} kcal in range',
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _heroPill(
                icon: deltaFromStart >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                label: _isRu
                    ? '${deltaFromStart >= 0 ? '+' : '-'}${_formatWhole(deltaFromStart.abs())} ккал к старту'
                    : '${deltaFromStart >= 0 ? '+' : '-'}${_formatWhole(deltaFromStart.abs())} kcal vs start',
                color: trendAccent,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _cs.primary.withValues(alpha: _isDark ? 0.22 : 0.11),
                  _cs.secondary.withValues(alpha: _isDark ? 0.12 : 0.06),
                  _cs.surface.withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(
                color: _cs.outlineVariant.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 196,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final tooltipWidth = math.min(160.0, width);
                      final tooltipLeft = selectedIndex == null
                          ? 0.0
                          : (_chartXForIndex(
                                      selectedIndex,
                                      points.length,
                                      width,
                                    ) -
                                    tooltipWidth / 2)
                                .clamp(0.0, math.max(0.0, width - tooltipWidth))
                                .toDouble();

                      void selectAtOffset(Offset localPosition) {
                        setState(() {
                          _selectedCaloriePointIndex = _chartIndexForDx(
                            localPosition.dx,
                            points.length,
                            width,
                          );
                        });
                      }

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) =>
                            selectAtOffset(details.localPosition),
                        onHorizontalDragStart: (details) =>
                            selectAtOffset(details.localPosition),
                        onHorizontalDragUpdate: (details) =>
                            selectAtOffset(details.localPosition),
                        child: Stack(
                          children: [
                            AnimatedBuilder(
                              animation: _chartAnimation,
                              builder: (context, _) => CustomPaint(
                                painter: _WeeklyLineChartPainter(
                                  values: points.map((e) => e.value).toList(),
                                  averageValue: averageCalories,
                                  progress: _chartAnimation.value,
                                  selectedIndex: selectedIndex,
                                  lineColor: _cs.primary,
                                  fillColor: _cs.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  dotColor: _cs.secondary,
                                  guideColor: _cs.outlineVariant.withValues(
                                    alpha: 0.22,
                                  ),
                                  averageGuideColor: _cs.tertiary.withValues(
                                    alpha: 0.5,
                                  ),
                                  barColor: _cs.primary.withValues(alpha: 0.12),
                                  selectionColor: _cs.secondary,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            if (selectedIndex != null)
                              Positioned(
                                left: tooltipLeft,
                                top: 0,
                                width: tooltipWidth,
                                child: _chartTooltip(
                                  title: _chartTooltipDate(
                                    points[selectedIndex].date,
                                  ),
                                  rows: [
                                    (
                                      _cs.primary,
                                      '${_formatWhole(points[selectedIndex].value)} ${_isRu ? 'ккал' : 'kcal'}',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final point in points)
                      Expanded(
                        child: Text(
                          point.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _cs.onSurfaceVariant,
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _trendPill(
                icon: Icons.calendar_view_week_rounded,
                label: _isRu ? 'НЕДЕЛЯ' : 'WEEK',
                value:
                    '${_formatWhole(weeklyCalories)} ${_isRu ? 'ккал' : 'kcal'}',
                accent: _cs.primary,
              ),
              _trendPill(
                icon: Icons.horizontal_rule_rounded,
                label: _isRu ? 'СРЕДНЕЕ' : 'AVERAGE',
                value:
                    '${_formatWhole(averageCalories)} ${_isRu ? 'ккал' : 'kcal'}',
                accent: _cs.secondary,
              ),
              _trendPill(
                icon: Icons.north_east_rounded,
                label: _isRu ? 'ПИК' : 'PEAK',
                value:
                    '${_formatWhole(peakPoint.value)} ${_isRu ? 'ккал' : 'kcal'}',
                accent: _cs.tertiary,
              ),
              _trendPill(
                icon: Icons.south_east_rounded,
                label: _isRu ? 'МИНИМУМ' : 'LOW',
                value:
                    '${_formatWhole(lowPoint.value)} ${_isRu ? 'ккал' : 'kcal'}',
                accent: _cs.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSection({
    required double proteins,
    required double fats,
    required double carbs,
  }) {
    final total = proteins + fats + carbs;
    final proteinShare = total <= 0 ? 0.0 : proteins / total;
    final fatShare = total <= 0 ? 0.0 : fats / total;
    final carbShare = total <= 0 ? 0.0 : carbs / total;
    final moodLabel = _macroMoodLabel(
      proteinShare: proteinShare,
      fatShare: fatShare,
      carbShare: carbShare,
    );

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isRu ? 'Баланс макросов' : 'Macro balance',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            _isRu
                ? 'Наглядное распределение белков, жиров и углеводов.'
                : 'Visual split of proteins, fats, and carbohydrates.',
            style: TextStyle(
              color: _cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final chart = SizedBox(
                width: compact ? 180 : 200,
                height: compact ? 180 : 200,
                child: CustomPaint(
                  painter: _MacroDonutPainter(
                    proteinShare: proteinShare,
                    fatShare: fatShare,
                    carbShare: carbShare,
                    proteinColor: _cs.primary,
                    fatColor: _cs.secondary,
                    carbColor: _cs.tertiary,
                    trackColor: _cs.outlineVariant.withValues(alpha: 0.18),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRu ? 'Всего' : 'Total',
                          style: TextStyle(
                            color: _cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatWhole(total)} ${_isRu ? 'г' : 'g'}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              final legends = Expanded(
                child: Column(
                  children: [
                    _macroLegend(
                      label: _isRu ? 'Белки' : 'Proteins',
                      value:
                          '${_formatOneDecimal(proteins)} ${_isRu ? 'г' : 'g'}',
                      share: '${_formatWhole(proteinShare * 100)}%',
                      color: _cs.primary,
                    ),
                    const SizedBox(height: 10),
                    _macroLegend(
                      label: _isRu ? 'Жиры' : 'Fats',
                      value: '${_formatOneDecimal(fats)} ${_isRu ? 'г' : 'g'}',
                      share: '${_formatWhole(fatShare * 100)}%',
                      color: _cs.secondary,
                    ),
                    const SizedBox(height: 10),
                    _macroLegend(
                      label: _isRu ? 'Углеводы' : 'Carbs',
                      value: '${_formatOneDecimal(carbs)} ${_isRu ? 'г' : 'g'}',
                      share: '${_formatWhole(carbShare * 100)}%',
                      color: _cs.tertiary,
                    ),
                  ],
                ),
              );

              if (compact) {
                return Column(
                  children: [chart, const SizedBox(height: 18), legends],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [chart, const SizedBox(width: 18), legends],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            moodLabel,
            style: TextStyle(
              color: _cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _buildMacroBalanceBar(
            proteinShare: proteinShare,
            fatShare: fatShare,
            carbShare: carbShare,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroTrendSection(List<_MacroDayPoint> points) {
    if (points.isEmpty) {
      return _glassCard(
        child: Text(
          _isRu
              ? 'Пока нет данных для графика БЖУ по дням.'
              : 'No daily macro data yet.',
          style: TextStyle(
            color: _cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final proteinAvg =
        points.map((point) => point.proteins).reduce((a, b) => a + b) /
        points.length;
    final fatAvg =
        points.map((point) => point.fats).reduce((a, b) => a + b) /
        points.length;
    final carbAvg =
        points.map((point) => point.carbs).reduce((a, b) => a + b) /
        points.length;
    final activeDays = points.where((point) => point.total > 0).length;
    final selectedIndex = _selectedMacroPointIndex?.clamp(0, points.length - 1);
    final toggleItems = [
      (
        key: 'protein',
        label: _isRu ? 'Белки' : 'Protein',
        selected: _showProteinTrend,
        color: _cs.primary,
      ),
      (
        key: 'fat',
        label: _isRu ? 'Жиры' : 'Fat',
        selected: _showFatTrend,
        color: _cs.secondary,
      ),
      (
        key: 'carb',
        label: _isRu ? 'Углеводы' : 'Carbs',
        selected: _showCarbTrend,
        color: _cs.tertiary,
      ),
    ];

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRu ? 'Макросы по дням' : 'Daily macro flow',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRu
                          ? 'Белки, жиры и углеводы по каждому дню выбранного периода.'
                          : 'Proteins, fats, and carbs for each day in the selected range.',
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _heroPill(
                icon: Icons.insights_rounded,
                label: _isRu
                    ? '$activeDays активных дней'
                    : '$activeDays active days',
                color: _cs.secondary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in toggleItems)
                FilterChip(
                  label: Text(item.label),
                  selected: item.selected,
                  showCheckmark: false,
                  selectedColor: item.color.withValues(alpha: 0.16),
                  backgroundColor: _cs.surfaceContainerHighest.withValues(
                    alpha: _isDark ? 0.28 : 0.7,
                  ),
                  side: BorderSide(
                    color: item.color.withValues(
                      alpha: item.selected ? 0.4 : 0.18,
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: item.selected ? item.color : _cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (_) => _toggleMacroVisibility(item.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _cs.secondary.withValues(alpha: _isDark ? 0.18 : 0.08),
                  _cs.tertiary.withValues(alpha: _isDark ? 0.12 : 0.06),
                  _cs.surface.withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(
                color: _cs.outlineVariant.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final tooltipWidth = math.min(170.0, width);
                      final tooltipLeft = selectedIndex == null
                          ? 0.0
                          : (_chartXForIndex(
                                      selectedIndex,
                                      points.length,
                                      width,
                                    ) -
                                    tooltipWidth / 2)
                                .clamp(0.0, math.max(0.0, width - tooltipWidth))
                                .toDouble();

                      void selectAtOffset(Offset localPosition) {
                        setState(() {
                          _selectedMacroPointIndex = _chartIndexForDx(
                            localPosition.dx,
                            points.length,
                            width,
                          );
                        });
                      }

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) =>
                            selectAtOffset(details.localPosition),
                        onHorizontalDragStart: (details) =>
                            selectAtOffset(details.localPosition),
                        onHorizontalDragUpdate: (details) =>
                            selectAtOffset(details.localPosition),
                        child: Stack(
                          children: [
                            AnimatedBuilder(
                              animation: _chartAnimation,
                              builder: (context, _) => CustomPaint(
                                painter: _MacroTrendChartPainter(
                                  points: points,
                                  progress: _chartAnimation.value,
                                  selectedIndex: selectedIndex,
                                  showProtein: _showProteinTrend,
                                  showFat: _showFatTrend,
                                  showCarb: _showCarbTrend,
                                  proteinColor: _cs.primary,
                                  fatColor: _cs.secondary,
                                  carbColor: _cs.tertiary,
                                  guideColor: _cs.outlineVariant.withValues(
                                    alpha: 0.2,
                                  ),
                                  selectionColor: _cs.secondary,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            if (selectedIndex != null)
                              Positioned(
                                left: tooltipLeft,
                                top: 0,
                                width: tooltipWidth,
                                child: _chartTooltip(
                                  title: _chartTooltipDate(
                                    points[selectedIndex].date,
                                  ),
                                  rows: [
                                    if (_showProteinTrend)
                                      (
                                        _cs.primary,
                                        '${_isRu ? 'Белки' : 'Protein'}: ${_formatOneDecimal(points[selectedIndex].proteins)} ${_isRu ? 'г' : 'g'}',
                                      ),
                                    if (_showFatTrend)
                                      (
                                        _cs.secondary,
                                        '${_isRu ? 'Жиры' : 'Fat'}: ${_formatOneDecimal(points[selectedIndex].fats)} ${_isRu ? 'г' : 'g'}',
                                      ),
                                    if (_showCarbTrend)
                                      (
                                        _cs.tertiary,
                                        '${_isRu ? 'Углеводы' : 'Carbs'}: ${_formatOneDecimal(points[selectedIndex].carbs)} ${_isRu ? 'г' : 'g'}',
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final point in points)
                      Expanded(
                        child: Text(
                          point.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _cs.onSurfaceVariant,
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _trendPill(
                icon: Icons.fitness_center_rounded,
                label: _isRu ? 'БЕЛКИ/ДЕНЬ' : 'PROTEIN/DAY',
                value: '${_formatOneDecimal(proteinAvg)} ${_isRu ? 'г' : 'g'}',
                accent: _cs.primary,
              ),
              _trendPill(
                icon: Icons.opacity_rounded,
                label: _isRu ? 'ЖИРЫ/ДЕНЬ' : 'FAT/DAY',
                value: '${_formatOneDecimal(fatAvg)} ${_isRu ? 'г' : 'g'}',
                accent: _cs.secondary,
              ),
              _trendPill(
                icon: Icons.grain_rounded,
                label: _isRu ? 'УГЛЕВОДЫ/ДЕНЬ' : 'CARBS/DAY',
                value: '${_formatOneDecimal(carbAvg)} ${_isRu ? 'г' : 'g'}',
                accent: _cs.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightPanels({
    required int dailyCalories,
    required int mealsCount,
    required int expiringSoonCount,
    required int usedPantryCount,
  }) {
    final fiberStreak = mealsCount >= 3 ? 5 : 3;
    final gap = expiringSoonCount > 0
        ? (_isRu ? 'магний и витамин D' : 'Magnesium and Vitamin D')
        : (_isRu ? 'стабильность гидратации' : 'Hydration consistency');

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final first = Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cs.secondaryContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AtelierIconBadge(
                icon: Icons.auto_awesome_rounded,
                accent: _cs.onSecondaryContainer,
              ),
              const SizedBox(height: 18),
              Text(
                _isRu ? 'Серия по клетчатке' : 'High Fiber Streak',
                style: TextStyle(
                  color: _cs.onSecondaryContainer,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isRu
                    ? 'Ты держишь плотный пищевой ритм уже $fiberStreak дней подряд. Использование кладовой и журнал приёмов пищи сейчас хорошо совпадают.'
                    : 'You have kept a dense food rhythm for $fiberStreak days in a row. Pantry usage and meal log are lining up well.',
                style: TextStyle(
                  color: _cs.onSecondaryContainer.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );

        final second = Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              _cs.surfaceContainerHighest.withValues(
                alpha: _isDark ? 0.42 : 0.88,
              ),
              _cs.surface,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isRu ? 'Дефицит микронутриентов' : 'Micronutrient Gap',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.error_outline_rounded,
                    color: _cs.tertiary,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _isRu
                    ? 'Сейчас внимание стоит держать на $gap. За день: $dailyCalories ккал, из кладовой использовано: $usedPantryCount.'
                    : 'Keep an eye on $gap. Daily calories: $dailyCalories, pantry items used: $usedPantryCount.',
                style: TextStyle(
                  color: _cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }

        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildBiometricGrid({
    required int mealsCount,
    required int expiringSoonCount,
    required int usedPantryCount,
  }) {
    final tiles = [
      (
        Icons.monitor_weight_rounded,
        _isRu ? 'Использовано из кладовой' : 'Used Pantry',
        '$usedPantryCount',
        _isRu ? 'позиций за период' : 'items in range',
        _cs.primary,
      ),
      (
        Icons.bedtime_rounded,
        _isRu ? 'Записано приёмов пищи' : 'Meals Logged',
        '$mealsCount',
        _isRu ? 'сегодня' : 'today',
        _cs.tertiary,
      ),
      (
        Icons.directions_run_rounded,
        _isRu ? 'Итого за период' : 'Range Total',
        _formatWhole(_toDouble(_weekly?['totalCalories'])),
        _isRu ? 'ккал' : 'kcal',
        _cs.secondary,
      ),
      (
        Icons.water_drop_rounded,
        _isRu ? 'Скоро истекает' : 'Expiring Soon',
        '$expiringSoonCount',
        _isRu ? 'требует внимания' : 'need attention',
        _cs.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 720
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles.map((entry) {
            return SizedBox(
              width: width,
              child: AtelierSurfaceCard(
                padding: const EdgeInsets.all(18),
                radius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(entry.$1, color: entry.$5),
                    const SizedBox(height: 14),
                    Text(
                      entry.$2.toUpperCase(),
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.$3,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 0.94,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.$4,
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rangeStart = _rangeStart();
    final dailyCalories = _toInt(_daily?['totalCalories']);
    final mealsCount = _toInt(_daily?['mealsCount']);
    final expiringSoonCount = _toInt(_daily?['expiringSoonCount']);
    final weeklyCalories = _toDouble(_weekly?['totalCalories']);
    final usedPantryCount = _toInt(_weekly?['usedPantryItemsCount']);
    final proteins = _toDouble(_macros?['proteins']);
    final fats = _toDouble(_macros?['fats']);
    final carbs = _toDouble(_macros?['carbohydrates']);

    final rawPoints =
        (_weekly?['dailyCalories'] as List?)?.cast<dynamic>() ?? const [];
    final points = _buildCaloriePointsFromAnalytics(
      rawPoints,
      start: rangeStart,
      days: _selectedPeriodDays,
    );
    final macroDayPoints = _buildMacroDayPoints(
      meals: _meals,
      start: rangeStart,
      days: _selectedPeriodDays,
    );
    final averageCalories = points.isEmpty
        ? 0.0
        : points.map((e) => e.value).reduce((a, b) => a + b) / points.length;

    return Scaffold(
      backgroundColor: _theme.scaffoldBackgroundColor,
      appBar: AppTopBar(
        title: _isRu ? 'Аналитика' : 'Analytics',
        actions: [
          AppTopAction(
            icon: Icons.refresh_rounded,
            onPressed: _load,
            tooltip: _isRu ? 'Обновить' : 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            _sectionHeader(
              eyebrow: _isRu
                  ? 'срез за $_selectedPeriodDays дней'
                  : '$_selectedPeriodDays-day performance',
              title: _isRu ? 'Инсайты по питанию' : 'Metabolic Insights',
              subtitle: _isRu
                  ? 'Смотри калории, БЖУ и ритм питания на диапазоне ${(const {7: "недели", 30: "месяца", 90: "квартала"})[_selectedPeriodDays] ?? "периода"}.'
                  : 'Track calories, macros, and nutrition rhythm across the selected range.',
            ),
            const SizedBox(height: 18),
            _buildPeriodSelector(),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _isRefreshingRange
                    ? const Padding(
                        key: ValueKey('analytics-refreshing'),
                        padding: EdgeInsets.only(bottom: 14),
                        child: LinearProgressIndicator(minHeight: 4),
                      )
                    : const SizedBox.shrink(key: ValueKey('analytics-idle')),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  final chartCard = Expanded(
                    flex: 8,
                    child: _animatedPeriodPane(
                      id: 'weekly-chart',
                      child: _buildWeeklyChart(
                        points,
                        weeklyCalories,
                        averageCalories,
                      ),
                    ),
                  );
                  final macroCard = Expanded(
                    flex: 4,
                    child: _animatedPeriodPane(
                      id: 'macro-balance',
                      child: _buildMacroSection(
                        proteins: proteins,
                        fats: fats,
                        carbs: carbs,
                      ),
                    ),
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        _animatedPeriodPane(
                          id: 'weekly-chart',
                          child: _buildWeeklyChart(
                            points,
                            weeklyCalories,
                            averageCalories,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _animatedPeriodPane(
                          id: 'macro-balance',
                          child: _buildMacroSection(
                            proteins: proteins,
                            fats: fats,
                            carbs: carbs,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [chartCard, const SizedBox(width: 16), macroCard],
                  );
                },
              ),
              const SizedBox(height: 16),
              _animatedPeriodPane(
                id: 'weekly-rhythm',
                child: _buildWeeklyRhythmCard(points, averageCalories),
              ),
              const SizedBox(height: 16),
              _animatedPeriodPane(
                id: 'macro-trend-${_showProteinTrend ? 1 : 0}${_showFatTrend ? 1 : 0}${_showCarbTrend ? 1 : 0}',
                child: _buildMacroTrendSection(macroDayPoints),
              ),
              const SizedBox(height: 20),
              _buildInsightPanels(
                dailyCalories: dailyCalories,
                mealsCount: mealsCount,
                expiringSoonCount: expiringSoonCount,
                usedPantryCount: usedPantryCount,
              ),
              const SizedBox(height: 20),
              _buildBiometricGrid(
                mealsCount: mealsCount,
                expiringSoonCount: expiringSoonCount,
                usedPantryCount: usedPantryCount,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaloriePoint {
  final DateTime date;
  final String label;
  final double value;

  const _CaloriePoint({
    required this.date,
    required this.label,
    required this.value,
  });
}

class _MacroDayPoint {
  final DateTime date;
  final String label;
  final double proteins;
  final double fats;
  final double carbs;

  const _MacroDayPoint({
    required this.date,
    required this.label,
    required this.proteins,
    required this.fats,
    required this.carbs,
  });

  double get total => proteins + fats + carbs;
}

Path _buildInterpolatedChartPath(List<Offset> points) {
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

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      next.dx,
      next.dy,
    );
  }

  return path;
}

class _WeeklyLineChartPainter extends CustomPainter {
  final List<double> values;
  final double averageValue;
  final double progress;
  final int? selectedIndex;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;
  final Color guideColor;
  final Color averageGuideColor;
  final Color barColor;
  final Color selectionColor;

  const _WeeklyLineChartPainter({
    required this.values,
    required this.averageValue,
    required this.progress,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
    required this.guideColor,
    required this.averageGuideColor,
    required this.barColor,
    required this.selectionColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = math.max(values.reduce(math.max), 1.0);
    final minValue = math.min(values.reduce(math.min), 0.0);
    final range = math.max(maxValue - minValue, 1.0);
    const topPadding = 12.0;
    const bottomPadding = 14.0;
    final height = size.height - topPadding - bottomPadding;
    final width = size.width;

    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = topPadding + height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(width, y), guidePaint);
    }

    final averageY =
        topPadding + height - ((averageValue - minValue) / range) * height;
    final averagePaint = Paint()
      ..color = averageGuideColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashWidth = 7.0;
    const dashGap = 5.0;
    var dashStart = 0.0;
    while (dashStart < width) {
      canvas.drawLine(
        Offset(dashStart, averageY),
        Offset(math.min(dashStart + dashWidth, width), averageY),
        averagePaint,
      );
      dashStart += dashWidth + dashGap;
    }

    final points = <Offset>[];
    final columnPaint = Paint()..color = barColor;
    final columnWidth = values.length <= 1
        ? width * 0.22
        : width / (values.length * 1.95);
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? width / 2
          : width * (i / (values.length - 1));
      final normalized = (values[i] - minValue) / range;
      final y = topPadding + height - normalized * height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - columnWidth / 2, y, columnWidth, size.height - y),
          const Radius.circular(999),
        ),
        columnPaint,
      );
      points.add(Offset(x, y));
    }

    final linePath = _buildInterpolatedChartPath(points);

    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor.withValues(alpha: 0.9),
          fillColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, size.height));

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height),
    );
    canvas.drawPath(areaPath, fillPaint);

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.26)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(linePath, glowPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    for (final point in points) {
      canvas.drawCircle(
        point,
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawCircle(point, 3, Paint()..color = dotColor);
    }
    canvas.restore();

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length &&
        points[selectedIndex!].dx <= width * progress.clamp(0.0, 1.0)) {
      final selected = points[selectedIndex!];
      canvas.drawLine(
        Offset(selected.dx, topPadding),
        Offset(selected.dx, size.height - bottomPadding),
        Paint()
          ..color = selectionColor.withValues(alpha: 0.28)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        selected,
        10,
        Paint()..color = selectionColor.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        selected,
        6,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawCircle(selected, 4, Paint()..color = selectionColor);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.averageValue != averageValue ||
        oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.averageGuideColor != averageGuideColor ||
        oldDelegate.barColor != barColor ||
        oldDelegate.selectionColor != selectionColor;
  }
}

class _MacroTrendChartPainter extends CustomPainter {
  const _MacroTrendChartPainter({
    required this.points,
    required this.progress,
    required this.selectedIndex,
    required this.showProtein,
    required this.showFat,
    required this.showCarb,
    required this.proteinColor,
    required this.fatColor,
    required this.carbColor,
    required this.guideColor,
    required this.selectionColor,
  });

  final List<_MacroDayPoint> points;
  final double progress;
  final int? selectedIndex;
  final bool showProtein;
  final bool showFat;
  final bool showCarb;
  final Color proteinColor;
  final Color fatColor;
  final Color carbColor;
  final Color guideColor;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const topPadding = 12.0;
    const bottomPadding = 14.0;
    final height = size.height - topPadding - bottomPadding;
    final width = size.width;
    final maxValue = math.max(
      1.0,
      points
          .map(
            (point) =>
                math.max(point.proteins, math.max(point.fats, point.carbs)),
          )
          .reduce(math.max),
    );

    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = topPadding + height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(width, y), guidePaint);
    }

    double xFor(int index) =>
        points.length == 1 ? width / 2 : width * (index / (points.length - 1));

    double yFor(double value) =>
        topPadding + height - (value / maxValue) * height;

    void drawSeries(List<double> values, Color color) {
      final seriesPoints = <Offset>[];
      for (var i = 0; i < values.length; i++) {
        seriesPoints.add(Offset(xFor(i), yFor(values[i])));
      }

      final path = _buildInterpolatedChartPath(seriesPoints);

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      for (final point in seriesPoints) {
        canvas.drawCircle(
          point,
          3.5,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
        canvas.drawCircle(point, 2, Paint()..color = color);
      }
    }

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height),
    );
    if (showProtein) {
      drawSeries(points.map((point) => point.proteins).toList(), proteinColor);
    }
    if (showFat) {
      drawSeries(points.map((point) => point.fats).toList(), fatColor);
    }
    if (showCarb) {
      drawSeries(points.map((point) => point.carbs).toList(), carbColor);
    }
    canvas.restore();

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      final selectedX = xFor(selectedIndex!);
      if (selectedX <= width * progress.clamp(0.0, 1.0)) {
        canvas.drawLine(
          Offset(selectedX, topPadding),
          Offset(selectedX, size.height - bottomPadding),
          Paint()
            ..color = selectionColor.withValues(alpha: 0.28)
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MacroTrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.showProtein != showProtein ||
        oldDelegate.showFat != showFat ||
        oldDelegate.showCarb != showCarb ||
        oldDelegate.proteinColor != proteinColor ||
        oldDelegate.fatColor != fatColor ||
        oldDelegate.carbColor != carbColor ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.selectionColor != selectionColor;
  }
}

class _MacroDonutPainter extends CustomPainter {
  const _MacroDonutPainter({
    required this.proteinShare,
    required this.fatShare,
    required this.carbShare,
    required this.proteinColor,
    required this.fatColor,
    required this.carbColor,
    required this.trackColor,
  });

  final double proteinShare;
  final double fatShare;
  final double carbShare;
  final Color proteinColor;
  final Color fatColor;
  final Color carbColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.22;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - stroke / 2, track);

    final shares = [
      (proteinShare, proteinColor),
      (fatShare, fatColor),
      (carbShare, carbColor),
    ];

    var start = -math.pi / 2;
    for (final (share, color) in shares) {
      if (share <= 0) continue;
      final sweep = share * math.pi * 2;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter other) {
    return proteinShare != other.proteinShare ||
        fatShare != other.fatShare ||
        carbShare != other.carbShare ||
        proteinColor != other.proteinColor ||
        fatColor != other.fatColor ||
        carbColor != other.carbColor ||
        trackColor != other.trackColor;
  }
}
