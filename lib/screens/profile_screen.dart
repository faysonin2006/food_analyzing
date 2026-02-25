import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_top_bar.dart';
import '../core/app_scope.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isActive = false});

  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _profile;
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
    return _isRu ? '$cals ккал/день' : '$cals kcal/day';
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
    final profile = await apiService.getProfile();
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

    return _picker.pickImage(source: source, imageQuality: 85);
  }

  Future<void> _pickProfileAvatar(ImageSource source) async {
    final image = await _pickImageFile(source);
    if (image == null || !mounted) return;

    setState(() => _profileAvatarFile = File(image.path));

    final success = await apiService.uploadAvatar(image);
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
    Navigator.pop(sheetContext);

    try {
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

      final success = await apiService.updateProfile(profileData);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'profile_saved')),
            backgroundColor: _cs.secondary,
          ),
        );
        await _loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'save_error')),
            backgroundColor: _cs.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr(context, 'error')}: $e'),
          backgroundColor: _cs.error,
        ),
      );
    }
  }

  void _showEditProfileDialog() {
    _nameController.text = _profile?['name']?.toString() ?? '';
    _dobController.text =
        _dateOfBirthLabel() == (_isRu ? 'Не указана' : 'Not set')
        ? ''
        : _dateOfBirthLabel();
    _heightController.text = _profile?['height']?.toString() ?? '';
    _weightController.text = _profile?['weight']?.toString() ?? '';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setModalState) => Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: _cs.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Text(
                    tr(context, 'edit_profile_title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: tr(context, 'name'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.person, color: _cs.primary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: () => _pickDateOfBirth(context, setModalState),
                    decoration: InputDecoration(
                      labelText: tr(context, 'date_of_birth'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.cake_rounded, color: _cs.primary),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month_rounded),
                        onPressed: () =>
                            _pickDateOfBirth(context, setModalState),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownField(
                    tr(context, 'gender'),
                    ['MALE', 'FEMALE'],
                    _selectedGender,
                    (value) => setModalState(() => _selectedGender = value),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          decoration: InputDecoration(
                            labelText: tr(context, 'height_cm'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(Icons.height, color: _cs.primary),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          decoration: InputDecoration(
                            labelText: tr(context, 'weight_kg'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(
                              Icons.fitness_center,
                              color: _cs.primary,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

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
                    (value) => setModalState(() => _selectedActivity = value),
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownField(
                    tr(context, 'goal_type'),
                    ['LOSE_WEIGHT', 'MAINTAIN_WEIGHT', 'GAIN_MUSCLE'],
                    _selectedGoal,
                    (value) => setModalState(() => _selectedGoal = value),
                  ),
                  const SizedBox(height: 16),

                  _buildMultiSelectCard(
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
                  ),
                  const SizedBox(height: 16),

                  _buildMultiSelectCard(
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
                  ),
                  const SizedBox(height: 16),

                  _buildMultiSelectCard(
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
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(tr(context, 'cancel')),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _saveProfile(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cs.primary,
                            foregroundColor: _cs.onPrimary,
                          ),
                          child: Text(tr(context, 'save')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(Icons.arrow_drop_down, color: _cs.primary),
      ),
      initialValue: selected,
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
    Function(String, bool) onToggle,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
                      checkmarkColor: _cs.primary,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blendWithSurface(accent, _isDarkTheme ? 0.26 : 0.08),
        borderRadius: BorderRadius.circular(12),
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
            maxLines: 1,
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

  Widget _buildProfileCard() {
    final cs = _cs;
    const accentPrimary = Color(0xFFF1A62B);
    const accentSecondary = Color(0xFFE69220);
    const accentMuted = Color(0xFFC7A56A);
    final height = _readInt(_profile?['height']);
    final weight = _readDouble(_profile?['weight']);
    final bmi = _calculateBmi(height, weight);

    final name = (_profile?['name'] ?? tr(context, 'profile_no_name'))
        .toString()
        .trim();
    final email = (_profile?['email'] ?? '').toString().trim();
    final goal = _enumLabel(_profile?['goalType']?.toString());
    final activity = _enumLabel(_profile?['activityLevel']?.toString());
    final gender = _enumLabel(_profile?['gender']?.toString());
    final dob = _dateOfBirthLabel();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _blendWithSurface(accentPrimary, _isDarkTheme ? 0.28 : 0.12),
                  _blendWithSurface(
                    accentSecondary,
                    _isDarkTheme ? 0.22 : 0.07,
                  ),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: _blendWithSurface(
                            accentPrimary,
                            _isDarkTheme ? 0.34 : 0.16,
                          ),
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 52,
                                  color: accentPrimary.withValues(alpha: 0.8),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: accentPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.photo_camera_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              onPressed: () =>
                                  _pickProfileAvatar(ImageSource.gallery),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoadingProfile)
                            const LinearProgressIndicator(minHeight: 6)
                          else ...[
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              email.isEmpty
                                  ? (_isRu
                                        ? 'Почта не указана'
                                        : 'Email not set')
                                  : email,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildProfileMetricCard(
                      icon: Icons.local_fire_department_rounded,
                      label: tr(context, 'target_calories'),
                      value: _getCaloriesDisplayText(_profile),
                      accent: accentMuted,
                    ),
                    _buildProfileMetricCard(
                      icon: Icons.flag_rounded,
                      label: tr(context, 'goal_type'),
                      value: goal,
                      accent: accentPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(tr(context, 'edit_profile')),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildProfileMetricCard(
                icon: Icons.height_rounded,
                label: tr(context, 'height_cm'),
                value: height?.toString() ?? (_isRu ? 'Не указано' : 'Not set'),
                accent: accentPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildProfileMetricCard(
                icon: Icons.monitor_weight_rounded,
                label: tr(context, 'weight_kg'),
                value:
                    weight?.toStringAsFixed(1) ??
                    (_isRu ? 'Не указано' : 'Not set'),
                accent: accentSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildProfileMetricCard(
                icon: Icons.wc_rounded,
                label: tr(context, 'gender'),
                value: gender,
                accent: accentMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildProfileMetricCard(
                icon: Icons.bolt_rounded,
                label: tr(context, 'activity_level'),
                value: activity,
                accent: accentPrimary,
              ),
            ),
          ],
        ),

        if (bmi != null) ...[
          const SizedBox(height: 10),
          _buildProfileMetricCard(
            icon: Icons.favorite_rounded,
            label: tr(context, 'bmi_label'),
            value: '${bmi.toStringAsFixed(1)} · ${_bmiStateLabel(bmi)}',
            accent: cs.error,
          ),
        ],

        const SizedBox(height: 10),
        _buildProfileMetricCard(
          icon: Icons.cake_rounded,
          label: tr(context, 'date_of_birth'),
          value: dob,
          accent: accentSecondary,
        ),

        const SizedBox(height: 12),
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
        const SizedBox(height: 10),
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
        const SizedBox(height: 10),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenBg = _isDarkTheme
        ? _theme.scaffoldBackgroundColor
        : const Color(0xFFF4D9B1);
    final panelBg = _isDarkTheme
        ? Color.alphaBlend(
            _cs.surfaceContainerHighest.withValues(alpha: 0.56),
            _cs.surface,
          )
        : const Color(0xFFF6F6F7);

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppTopBar(
        title: tr(context, 'tab_profile'),
        actions: [
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
              await apiService.logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Container(
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
                bottom: Radius.circular(34),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isDarkTheme ? 0.24 : 0.06,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
                bottom: Radius.circular(34),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: _buildProfileCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
