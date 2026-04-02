import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../repositories/app_repository.dart';
part "profile/profile_ui.dart";

class _WeightHistoryEntry {
  const _WeightHistoryEntry({required this.date, required this.weight});

  final DateTime date;
  final double weight;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': date.toIso8601String(),
    'weight': weight,
  };

  factory _WeightHistoryEntry.fromJson(Map<String, dynamic> json) {
    return _WeightHistoryEntry(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _WeightDayPoint {
  const _WeightDayPoint({required this.date, required this.weight});

  final DateTime date;
  final double? weight;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isActive = false});

  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  static const String _weightHistoryStoragePrefix = 'profile_weight_history_v1';
  static const String _weightPeriodStorageKey = 'profile_weight_period_days_v1';
  static const int _weightHistoryChartDays = 7;
  static const int _weightHistoryRetainDays = 120;

  final AppRepository repository = AppRepository.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _profile;
  List<_WeightHistoryEntry> _weightHistory = const [];
  int _selectedWeightPeriodDays = 7;
  int? _selectedWeightPointIndex;
  bool _isLoadingProfile = true;
  bool _isFetchingProfile = false;
  File? _profileAvatarFile;
  DateTime? _lastAutoRefreshAt;

  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  String? _selectedGender;
  String? _selectedActivity;
  String? _selectedGoal;
  Set<String> _selectedDietPrefs = <String>{};
  Set<String> _selectedAllergies = <String>{};
  Set<String> _selectedHealthConditions = <String>{};

  static const List<String> _knownProfileTokensByLength = <String>[
    'INSULIN_RESISTANCE',
    'HIGH_CHOLESTEROL',
    'DIABETES_TYPE_1',
    'DIABETES_TYPE_2',
    'LACTOSE_FREE',
    'GLUTEN_FREE',
    'KIDNEY_DISEASE',
    'CELIAC_DISEASE',
    'PESCATARIAN',
    'TREE_NUTS',
    'SHELLFISH',
    'HYPERTENSION',
    'VEGETARIAN',
    'PREGNANCY',
    'LACTOSE',
    'PEANUTS',
    'MUSTARD',
    'OMNIVORE',
    'GASTRITIS',
    'SESAME',
    'VEGAN',
    'KOSHER',
    'HALAL',
    'PALEO',
    'KETO',
    'GLUTEN',
    'EGGS',
    'SOY',
    'FISH',
    'GOUT',
  ];

  static const Map<String, String> _profileAliases = <String, String>{
    'TYPE_1_DIABETES': 'DIABETES_TYPE_1',
    'TYPE_2_DIABETES': 'DIABETES_TYPE_2',
  };

  @override
  bool get wantKeepAlive => true;

  bool get _isRu => AppScope.settingsOf(context).locale.languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  bool get _isDarkTheme => _theme.brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dobController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _restoreWeightChartPreferences();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      final now = DateTime.now();
      final canRefresh =
          _lastAutoRefreshAt == null ||
          now.difference(_lastAutoRefreshAt!) > const Duration(seconds: 2);

      if (canRefresh && !_isFetchingProfile) {
        _lastAutoRefreshAt = now;
        _refreshProfile();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Color _blendWithSurface(Color color, [double opacity = 0.12]) {
    return Color.alphaBlend(color.withValues(alpha: opacity), _cs.surface);
  }

  int? _readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double? _readDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _getTargetCalories(Map<String, dynamic>? p) {
    if (p == null) return null;
    return _readInt(p['targetCaloriesPerDay']) ??
        _readInt(p['target_calories_per_day']) ??
        _readInt(p['targetCalories']) ??
        _readInt(p['dailyCalories']);
  }

  String _getCaloriesDisplayText(Map<String, dynamic>? p) {
    final cals = _getTargetCalories(p);
    if (cals == null) return tr(context, 'calculating');
    return _isRu ? '$cals ккал' : '$cals kcal';
  }

  String _enumLabel(String? raw) => trValue(context, raw);

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
      }
    }
    if (value is num) {
      final epoch = value.toInt();
      if (epoch > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(epoch).toLocal();
      }
      if (epoch > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(epoch * 1000).toLocal();
      }
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _weightDayKey(DateTime date) => _formatDate(_dateOnly(date));

  String _weightHistoryStorageKey([Map<String, dynamic>? profileSource]) {
    final source = profileSource ?? _profile;
    final email = (source?['email'] ?? '').toString().trim().toLowerCase();
    final suffix = email.isEmpty
        ? 'default'
        : email.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${_weightHistoryStoragePrefix}_$suffix';
  }

  List<_WeightHistoryEntry> _normalizeWeightHistory(
    Iterable<_WeightHistoryEntry> entries,
  ) {
    final byDay = <String, _WeightHistoryEntry>{};
    for (final entry in entries) {
      if (!entry.weight.isFinite || entry.weight <= 0) continue;
      byDay[_weightDayKey(entry.date)] = _WeightHistoryEntry(
        date: _dateOnly(entry.date),
        weight: entry.weight,
      );
    }

    final normalized = byDay.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));

    if (normalized.length <= _weightHistoryRetainDays) {
      return normalized;
    }
    return normalized.sublist(
      normalized.length - _weightHistoryRetainDays,
      normalized.length,
    );
  }

  Future<void> _saveWeightHistoryEntries(
    List<_WeightHistoryEntry> entries, {
    Map<String, dynamic>? profileSource,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _weightHistoryStorageKey(profileSource),
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _loadWeightHistory({Map<String, dynamic>? profileSource}) async {
    final source = profileSource ?? _profile;
    if (source == null) {
      if (!mounted) return;
      setState(() => _weightHistory = const []);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _weightHistoryStorageKey(source);
    final raw = prefs.getString(key);

    var entries = <_WeightHistoryEntry>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          entries = _normalizeWeightHistory(
            decoded.whereType<Map>().map(
              (entry) => _WeightHistoryEntry.fromJson(
                Map<String, dynamic>.from(entry),
              ),
            ),
          );
        }
      } catch (_) {}
    }

    final profileWeight = _readDouble(source['weight']);
    if (entries.isEmpty && profileWeight != null && profileWeight > 0) {
      entries = _normalizeWeightHistory([
        _WeightHistoryEntry(date: DateTime.now(), weight: profileWeight),
      ]);
      await _saveWeightHistoryEntries(entries, profileSource: source);
    }

    if (!mounted) return;
    setState(() => _weightHistory = entries);
  }

  Future<void> _recordWeightHistoryEntry(
    double weight, {
    DateTime? date,
    bool updateProfileWeight = false,
  }) async {
    if (!weight.isFinite || weight <= 0) return;
    final entries = _normalizeWeightHistory([
      ..._weightHistory,
      _WeightHistoryEntry(date: date ?? DateTime.now(), weight: weight),
    ]);
    if (mounted) {
      setState(() {
        _weightHistory = entries;
        if (updateProfileWeight) {
          _profile = <String, dynamic>{...?_profile, 'weight': weight};
        }
      });
    }
    await _saveWeightHistoryEntries(entries);
  }

  _WeightHistoryEntry? _latestWeightEntry() {
    if (_weightHistory.isEmpty) return null;
    return _weightHistory.last;
  }

  double? _currentWeightValue() =>
      _latestWeightEntry()?.weight ?? _readDouble(_profile?['weight']);

  List<_WeightDayPoint> _weightSeries({int days = _weightHistoryChartDays}) {
    final today = _dateOnly(DateTime.now());
    final byDay = <String, _WeightHistoryEntry>{
      for (final entry in _weightHistory) _weightDayKey(entry.date): entry,
    };
    return [
      for (var offset = days - 1; offset >= 0; offset--)
        () {
          final day = today.subtract(Duration(days: offset));
          final entry = byDay[_weightDayKey(day)];
          return _WeightDayPoint(date: day, weight: entry?.weight);
        }(),
    ];
  }

  String _weekdayLabel(DateTime day) {
    const ru = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final index = day.weekday - 1;
    return (_isRu ? ru : en)[index.clamp(0, 6)];
  }

  String _weightChartLabel(DateTime day, int index, int total) {
    if (total <= 7) return _weekdayLabel(day);

    final step = total <= 30 ? 5 : 15;
    final shouldShow =
        index == 0 ||
        index == total - 1 ||
        index == total ~/ 2 ||
        index % step == 0;
    if (!shouldShow) return '';

    final dayText = day.day.toString().padLeft(2, '0');
    final monthText = day.month.toString().padLeft(2, '0');
    return '$dayText/$monthText';
  }

  String _weightTooltipDate(DateTime day) {
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  double _chartXForIndex(int index, int count, double width) {
    if (count <= 1) return width / 2;
    return width * (index / (count - 1));
  }

  int _chartIndexForDx(double dx, int count, double width) {
    if (count <= 1 || width <= 0) return 0;
    final ratio = (dx / width).clamp(0.0, 1.0);
    return (ratio * (count - 1)).round().clamp(0, count - 1);
  }

  Future<void> _restoreWeightChartPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPeriod = prefs.getInt(_weightPeriodStorageKey);
    if (savedPeriod != null &&
        const {7, 30, 90}.contains(savedPeriod) &&
        mounted) {
      setState(() => _selectedWeightPeriodDays = savedPeriod);
    }
  }

  void _setSelectedWeightPeriodDays(int days) {
    if (_selectedWeightPeriodDays == days) return;
    setState(() {
      _selectedWeightPeriodDays = days;
      _selectedWeightPointIndex = null;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_weightPeriodStorageKey, days);
    });
  }

  void _setSelectedWeightPointIndex(int? index) {
    setState(() => _selectedWeightPointIndex = index);
  }

  Future<void> _promptTodayWeightEntry() async {
    final initialWeight = _currentWeightValue() ?? 70;
    final controller = TextEditingController(
      text: initialWeight == initialWeight.roundToDouble()
          ? initialWeight.toStringAsFixed(0)
          : initialWeight.toStringAsFixed(1),
    );
    var submitting = false;

    final enteredWeight = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => AtelierSheetFrame(
            title: _isRu ? 'Вес на сегодня' : 'Today weight',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AtelierFieldLabel(_isRu ? 'Вес, кг' : 'Weight, kg'),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: _isRu ? 'Например, 72.4' : 'For example, 72.4',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : () {
                            final parsed = double.tryParse(
                              controller.text.trim().replaceAll(',', '.'),
                            );
                            if (parsed == null || parsed <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isRu
                                        ? 'Введи корректный вес'
                                        : 'Enter a valid weight',
                                  ),
                                ),
                              );
                              return;
                            }
                            setSheetState(() => submitting = true);
                            Navigator.of(sheetContext).pop(parsed);
                          },
                    icon: const Icon(Icons.monitor_weight_rounded),
                    label: Text(_isRu ? 'Сохранить вес' : 'Save weight'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (enteredWeight == null) return;

    await _recordWeightHistoryEntry(enteredWeight, updateProfileWeight: true);

    var synced = false;
    try {
      synced = await repository.updateProfile({'weight': enteredWeight});
    } catch (_) {
      synced = false;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? (_isRu ? 'Вес сохранён' : 'Weight saved')
              : (_isRu ? 'Вес сохранён локально' : 'Weight saved locally'),
        ),
        backgroundColor: synced ? _cs.secondary : _cs.tertiary,
      ),
    );

    if (synced) {
      await _loadProfile();
    }
  }

  String _dateOfBirthLabel() {
    final raw =
        _profile?['dateOfBirth'] ??
        _profile?['date_of_birth'] ??
        _profile?['birthDate'] ??
        _profile?['birth_date'];
    final date = _tryParseDate(raw);
    if (date == null) return _isRu ? 'Не указана' : 'Not set';
    return _formatDate(date);
  }

  String? _resolveAvatarUrl() {
    final values = <dynamic>[
      _profile?['avatarUrl'],
      _profile?['avatar_url'],
      _profile?['avatar'],
      _profile?['photoUrl'],
      _profile?['photo_url'],
      _profile?['imageUrl'],
      _profile?['image_url'],
    ];

    for (final value in values) {
      final url = value?.toString().trim();
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String _normalizeEnumToken(String raw) {
    return raw
        .split('.')
        .last
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _resolveKnownProfileToken(String raw) {
    final normalized = _normalizeEnumToken(raw);
    if (normalized.isEmpty) return '';

    for (final entry in _profileAliases.entries) {
      if (normalized == entry.key || normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    for (final token in _knownProfileTokensByLength) {
      if (normalized == token || normalized.contains(token)) {
        return token;
      }
    }

    return '';
  }

  String _extractProfileTagToken(dynamic value) {
    if (value == null) return '';

    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return '';

      final idMatch = RegExp(
        r'\bid\s*[:=]\s*"?([A-Za-z0-9._-]+)"?',
        caseSensitive: false,
      ).firstMatch(raw);
      if (idMatch != null) {
        final extracted = idMatch.group(1);
        if (extracted != null && extracted.trim().isNotEmpty) {
          return _resolveKnownProfileToken(extracted);
        }
      }

      if (raw.startsWith('{') && raw.endsWith('}')) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return _extractProfileTagToken(decoded);
          }
        } catch (_) {}
      }

      final bracketIndex = raw.indexOf('(');
      if (bracketIndex > 0) {
        final beforeBracket = raw.substring(0, bracketIndex).trim();
        final resolvedBefore = _resolveKnownProfileToken(beforeBracket);
        if (resolvedBefore.isNotEmpty) return resolvedBefore;
      }

      return _resolveKnownProfileToken(raw);
    }

    if (value is Map) {
      final rawToken =
          value['id'] ??
          value['name'] ??
          value['key'] ??
          value['value'] ??
          value['code'];
      if (rawToken == null) return '';
      return _resolveKnownProfileToken(rawToken.toString());
    }

    return _resolveKnownProfileToken(value.toString());
  }

  Set<String> _profileTagSet(dynamic value) {
    if (value is! List) return <String>{};
    final result = <String>{};
    for (final item in value) {
      final token = _extractProfileTagToken(item);
      if (token.isNotEmpty) result.add(token);
    }
    return result;
  }

  List<String> _profileTags(dynamic value) {
    if (value is! List) return const <String>[];
    final tags = <String>[];
    final seen = <String>{};

    for (final item in value) {
      final token = _extractProfileTagToken(item);
      if (token.isEmpty || !seen.add(token)) continue;
      tags.add(_enumLabel(token));
    }

    return tags;
  }

  double? _calculateBmi(int? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null) return null;
    if (heightCm <= 0 || weightKg <= 0) return null;
    final m = heightCm / 100.0;
    final bmi = weightKg / (m * m);
    if (!bmi.isFinite) return null;
    return bmi;
  }

  String _bmiStateLabel(double bmi) {
    if (bmi < 18.5) return tr(context, 'bmi_state_low');
    if (bmi < 25) return tr(context, 'bmi_state_normal');
    if (bmi < 30) return tr(context, 'bmi_state_elevated');
    return tr(context, 'bmi_state_high');
  }

  Future<void> _loadProfile() async {
    if (_isFetchingProfile) return;
    _isFetchingProfile = true;
    setState(() => _isLoadingProfile = true);
    final profile = await repository.getProfile();
    if (!mounted) {
      _isFetchingProfile = false;
      return;
    }

    setState(() {
      if (profile != null) {
        _profile = profile;
      }
      _isLoadingProfile = false;
    });
    await _loadWeightHistory(profileSource: profile ?? _profile);
    _isFetchingProfile = false;
  }

  Future<void> _refreshProfile() async {
    await _loadProfile();
  }

  Future<XFile?> _pickImageFile(ImageSource source) async {
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = await Permission.photos.request();
      if (!status.isGranted && Platform.isAndroid) {
        status = await Permission.storage.request();
      }
    }

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'permission_denied'))),
        );
      }
      return null;
    }

    return _picker.pickImage(source: source, imageQuality: 100);
  }

  Future<void> _pickProfileAvatar(ImageSource source) async {
    final image = await _pickImageFile(source);
    if (image == null || !mounted) return;

    setState(() => _profileAvatarFile = File(image.path));

    final success = await repository.uploadAvatar(image);
    if (!mounted) return;

    if (success) {
      await _loadProfile();
      if (!mounted) return;
      setState(() => _profileAvatarFile = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, 'profile_saved'))));
    } else {
      setState(() => _profileAvatarFile = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, 'error'))));
    }
  }

  DateTime _defaultDobDate() {
    final now = DateTime.now();
    return DateTime(now.year - 20, now.month, now.day);
  }

  DateTime _parseDob(String? raw) {
    final parsed = _tryParseDate(raw);
    return parsed ?? _defaultDobDate();
  }

  Future<void> _pickDateOfBirth(
    BuildContext sheetContext,
    void Function(void Function()) setModalState,
  ) async {
    final initial = _parseDob(_dobController.text);
    final firstDate = DateTime(1900, 1, 1);
    final lastDate = DateTime.now();

    final selected = await showDatePicker(
      context: sheetContext,
      initialDate: initial.isBefore(firstDate)
          ? firstDate
          : (initial.isAfter(lastDate) ? lastDate : initial),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selected == null) return;
    setModalState(() => _dobController.text = _formatDate(selected));
  }

  Future<void> _saveProfile(BuildContext sheetContext) async {
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final messenger = ScaffoldMessenger.of(context);
      final profileSavedLabel = tr(context, 'profile_saved');
      final saveErrorLabel = tr(context, 'save_error');

      final profileData = <String, dynamic>{
        if (_heightController.text.isNotEmpty &&
            int.tryParse(_heightController.text) != null)
          'height': int.parse(_heightController.text),
        if (_weightController.text.isNotEmpty &&
            double.tryParse(_weightController.text) != null)
          'weight': double.parse(_weightController.text),
        if (_selectedGender != null) 'gender': _selectedGender,
        if (_dobController.text.isNotEmpty) 'dateOfBirth': _dobController.text,
        if (_selectedActivity != null) 'activityLevel': _selectedActivity,
        if (_selectedGoal != null) 'goalType': _selectedGoal,
        'allergies': _selectedAllergies.toList(),
        'dietPreferences': _selectedDietPrefs.toList(),
        'healthConditions': _selectedHealthConditions.toList(),
        if (_nameController.text.trim().isNotEmpty)
          'name': _nameController.text.trim(),
      };

      final success = await repository.updateProfile(profileData);
      if (!mounted) return;

      if (success) {
        final mergedProfile = <String, dynamic>{...?_profile, ...profileData};
        setState(() {
          _profile = mergedProfile;
        });
        final weight = _readDouble(profileData['weight']);
        if (weight != null && weight > 0) {
          await _recordWeightHistoryEntry(weight);
        }
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(profileSavedLabel),
            backgroundColor: _cs.secondary,
          ),
        );
        await _loadProfile();
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(saveErrorLabel), backgroundColor: _cs.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final errorLabel = tr(context, 'error');
      messenger.showSnackBar(
        SnackBar(content: Text('$errorLabel: $e'), backgroundColor: _cs.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenBg = _theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppTopBar(
        title: tr(context, 'tab_profile'),
        actions: [
          AppTopAction(
            icon: Icons.refresh_rounded,
            tooltip: _isRu ? 'Обновить' : 'Refresh',
            onPressed: _refreshProfile,
          ),
          AppTopAction(
            icon: Icons.settings_rounded,
            tooltip: tr(context, 'settings'),
            onPressed: () => showAppSettingsSheet(context),
          ),
          AppTopAction(
            icon: Icons.logout_rounded,
            tooltip: tr(context, 'logout'),
            destructive: true,
            onPressed: () async {
              await repository.logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [_buildProfileCard()],
        ),
      ),
    );
  }
}
