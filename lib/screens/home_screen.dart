import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final apiService = ApiService();
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;


  String? _selectedGender;
  String? _selectedActivity;
  String? _selectedGoal;
  Set<String> _selectedDietPrefs = {};
  Set<String> _selectedAllergies = {};
  Set<String> _selectedHealthConditions = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadProfile();
  }
  int? _readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
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
    return cals != null ? '$cals ккал/день' : 'Рассчитывается…';
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _dobController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.storage,
    ].request();
    if (!statuses[Permission.camera]!.isGranted ||
        !statuses[Permission.storage]!.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Разрешения нужны для камеры и галереи!')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    await _requestPermissions();
    try {
      final image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      print('Ошибка выбора фото: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    final profile = await apiService.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _analyzeFood() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    final analysisId = await apiService.startFoodAnalysis(XFile(_selectedImage!.path));

    if (analysisId == null || !mounted) {
      setState(() => _isAnalyzing = false);
      return;
    }

    print('📝 Получен ID анализа: $analysisId');

    await _pollAnalysisResult(analysisId);

    if (mounted) {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _pollAnalysisResult(String analysisId) async {
    int attempts = 0;
    const maxAttempts = 30;

    print('🔄 Начинаем поллинг ID: $analysisId');

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));

      final result = await apiService.getAnalysisResult(analysisId);
      if (result != null) {
        final status = result['status']?.toString() ?? 'UNKNOWN';
        final dishName = result['dish_name']?.toString() ?? 'нет';
        print('📊 Попытка ${attempts + 1}: $status | Блюдо: $dishName');

        if (status == 'COMPLETED' &&
            result['dish_name'] != null &&
            result['dish_name'].toString().isNotEmpty &&
            result['calories'] != null) {

          print('✅ ✅ ✅ ПОЛНЫЙ результат: ${result['dish_name']}');
          if (mounted) {
            setState(() => _analysisResult = result);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${result['dish_name']} | ${result['calories']} ккал'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        if (status == 'FAILED') {
          print('❌ Анализ провалился');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ Ошибка AI анализа')),
            );
          }
          return;
        }
      } else {
        print('📭 Нет ответа от сервера');
      }

      attempts++;
    }

    print('⏰ ✅ Поллинг завершён — таймаут');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Анализ завершён, но данные не загрузились'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍎 Анализатор Еды'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProfile),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await apiService.logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileCard(),
              const SizedBox(height: 24),
              _buildImagePickerCard(),
              const SizedBox(height: 24),
              _buildAnalyzeButton(),
              const SizedBox(height: 24),
              if (_analysisResult != null) _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.white]),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: _profile?['avatarUrl'] != null
                      ? NetworkImage(_profile!['avatarUrl'])
                      : null,
                  child: _profile?['avatarUrl'] == null
                      ? Icon(Icons.person, size: 60, color: Colors.orange.shade300)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isLoadingProfile) ...[
              Text(
                _profile?['name'] ?? 'Без имени',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
              Text(
                _profile?['email'] ?? '',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              _buildStatRow('Рост', '${_profile?['height'] ?? '?'} см', Icons.height),
              _buildStatRow(
                  'Вес', '${_profile?['weight']?.toStringAsFixed(1) ?? '?'} кг', Icons.fitness_center),
              _buildStatRow('Цель', _getGoalText(_profile?['goalType']), Icons.flag),
              _buildStatRow(
                'Калории',
                _getCaloriesDisplayText(_profile),
                Icons.local_fire_department,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _buildStatCard('Активность', _getActivityText(_profile?['activityLevel']))),
                  Expanded(child: _buildStatCard('Пол', _getGenderText(_profile?['gender']))),
                ],
              ),

              if (_profile?['allergies'] != null && (_profile!['allergies'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildListCard('Аллергии', _profile!['allergies']),
              ],
              if (_profile?['dietPreferences'] != null && (_profile!['dietPreferences'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildListCard('Диета', _profile!['dietPreferences']),
              ],
              if (_profile?['healthConditions'] != null && (_profile!['healthConditions'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildListCard('Здоровье', _profile!['healthConditions']),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('Редактировать профиль'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.image_search, size: 80, color: Colors.orange.shade300),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_selectedImage!, height: 240, fit: BoxFit.cover),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerButton('📱 Галерея', Icons.photo_library, () => _pickImage(ImageSource.gallery)),
                _buildPickerButton('📷 Камера', Icons.camera_alt, () => _pickImage(ImageSource.camera)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        onPressed: _selectedImage != null && !_isAnalyzing ? _analyzeFood : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
        ),
        child: _isAnalyzing
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('🤖 AI анализирует...', style: TextStyle(fontSize: 18)),
          ],
        )
            : const Text(
          '🚀 НАЧАТЬ АНАЛИЗ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _analysisResult;
    if (result == null) return const SizedBox.shrink();

    final dishName = result['dish_name']?.toString() ?? 'Неизвестное блюдо';
    final status = result['status']?.toString() ?? 'UNKNOWN';
    final calories = result['calories']?.toStringAsFixed(0) ?? '?';
    final protein = result['protein']?.toStringAsFixed(1) ?? '?';
    final fats = result['fats']?.toStringAsFixed(1) ?? '?';
    final carbs = result['carbs']?.toStringAsFixed(1) ?? '?';
    final imageUrl = result['image_url']?.toString() ?? result['imageUrl']?.toString();

    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: status == 'COMPLETED'
          ? Colors.green.shade50
          : status == 'FAILED'
          ? Colors.red.shade50
          : Colors.orange.shade50,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: status == 'COMPLETED'
                ? [Colors.green.shade50, Colors.white]
                : [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: status == 'COMPLETED'
                    ? Colors.green
                    : status == 'FAILED'
                    ? Colors.red
                    : Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == 'COMPLETED'
                    ? Icons.check_circle
                    : status == 'FAILED'
                    ? Icons.error
                    : Icons.hourglass_empty,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              dishName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              status == 'COMPLETED' ? '✅ Анализ завершен' : '⏳ В процессе...',
              style: TextStyle(
                fontSize: 14,
                color: status == 'COMPLETED'
                    ? Colors.green[700]
                    : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(child: _buildNutrientCard('🔥 Калории', '$calories ккал', Icons.local_fire_department)),
                Expanded(child: _buildNutrientCard('💪 Белки', '$protein г', Icons.fitness_center)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildNutrientCard('🥑 Жиры', '$fats г', Icons.donut_large)),
                Expanded(child: _buildNutrientCard('🍞 Углеводы', '$carbs г', Icons.bakery_dining)),
              ],
            ),
            const SizedBox(height: 24),

            if (result['extra_info'] != null && result['extra_info'].toString().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Дополнительно',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result['extra_info'].toString(),
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            if (status == 'COMPLETED')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedImage != null ? _analyzeFood : null,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('🔄 Анализировать еще'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.orange.shade600, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: Colors.orange.shade600, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ]),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildListCard(String title, List<dynamic> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: items.map((item) => Chip(
              label: Text(item.toString(), style: TextStyle(fontSize: 12)),
              backgroundColor: Colors.orange.shade100,
            )).toList(),
          ),
        ],
      ),
    );
  }

  String _getActivityText(dynamic activity) =>
      activity?.toString().split('.').last.replaceAll('_', ' ').toUpperCase() ?? '?';

  String _getGoalText(dynamic goal) =>
      goal?.toString().split('.').last.replaceAll('_', ' ').toUpperCase() ?? '?';

  String _getGenderText(dynamic gender) => gender?.toString().split('.').last ?? '?';

  Widget _buildPickerButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.orange.shade600),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(BuildContext context) async {
    Navigator.pop(context);

    try {
      final profileData = <String, dynamic>{
        if (_heightController.text.isNotEmpty && int.tryParse(_heightController.text) != null)
          'height': int.parse(_heightController.text),
        if (_weightController.text.isNotEmpty && double.tryParse(_weightController.text) != null)
          'weight': double.parse(_weightController.text),
        if (_selectedGender != null) 'gender': _selectedGender,
        if (_dobController.text.isNotEmpty) 'dateOfBirth': _dobController.text,
        if (_selectedActivity != null) 'activityLevel': _selectedActivity,
        if (_selectedGoal != null) 'goalType': _selectedGoal,
        'allergies': _selectedAllergies.toList(),
        'dietPreferences': _selectedDietPrefs.toList(),
        'healthConditions': _selectedHealthConditions.toList(),
        if (_nameController.text.trim().isNotEmpty) 'name': _nameController.text.trim(),
      };

      final success = await apiService.updateProfile(profileData);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Профиль сохранен!'), backgroundColor: Colors.green),
        );
        _loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Ошибка сохранения'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildDropdownField(String label, List<String> items, String? selected, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(Icons.arrow_drop_down, color: Colors.orange),
      ),
      value: selected,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value.replaceAll('_', ' ').toUpperCase()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildMultiSelectCard(String title, List<String> items, Set<String> selectedItems, Function(String, bool) onToggle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) => FilterChip(
                label: Text(item.replaceAll('_', ' ')),
                selected: selectedItems.contains(item),
                onSelected: (selected) => onToggle(item, selected),
                selectedColor: Colors.orange.shade100,
                checkmarkColor: Colors.orange.shade700,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    _nameController.text = _profile?['name'] ?? '';
    _dobController.text = _profile?['dateOfBirth']?.toString().split('T')[0] ?? '';
    _heightController.text = _profile?['height']?.toString() ?? '';
    _weightController.text = _profile?['weight']?.toString() ?? '';

    _selectedGender = _profile?['gender']?.toString();
    _selectedActivity = _profile?['activityLevel']?.toString();
    _selectedGoal = _profile?['goalType']?.toString();

    _selectedDietPrefs = (_profile?['dietPreferences'] as List?)?.cast<String>().toSet() ?? {};
    _selectedAllergies = (_profile?['allergies'] as List?)?.cast<String>().toSet() ?? {};
    _selectedHealthConditions = (_profile?['healthConditions'] as List?)?.cast<String>().toSet() ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Text('Редактировать профиль', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Имя',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.person, color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _dobController,
                    decoration: InputDecoration(
                      labelText: 'Дата рождения (ГГГГ-ММ-ДД)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.cake, color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownField('Пол', ['MALE', 'FEMALE'], _selectedGender, (value) {
                    setModalState(() => _selectedGender = value);
                  }),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          decoration: InputDecoration(
                            labelText: 'Рост (см)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.height, color: Colors.orange),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          decoration: InputDecoration(
                            labelText: 'Вес (кг)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.fitness_center, color: Colors.orange),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownField(
                    'Уровень активности',
                    ['SEDENTARY', 'LIGHTLY_ACTIVE', 'MODERATELY_ACTIVE', 'VERY_ACTIVE', 'EXTRA_ACTIVE'],
                    _selectedActivity,
                        (value) {
                      setModalState(() => _selectedActivity = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownField(
                    'Цель',
                    ['LOSE_WEIGHT', 'MAINTAIN_WEIGHT', 'GAIN_MUSCLE'],
                    _selectedGoal,
                        (value) {
                      setModalState(() => _selectedGoal = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.orange.shade700, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Цель калорий в день',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _getCaloriesDisplayText(_profile) ?? 'Будет рассчитано автоматически',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildMultiSelectCard(
                    'Диетические предпочтения',
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
                      'OMNIVORE'
                    ],
                    _selectedDietPrefs,
                        (item, selected) {
                      setModalState(() {
                        if (selected) _selectedDietPrefs.add(item);
                        else _selectedDietPrefs.remove(item);
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildMultiSelectCard(
                    'Аллергии',
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
                      'SESAME'
                    ],
                    _selectedAllergies,
                        (item, selected) {
                      setModalState(() {
                        if (selected) _selectedAllergies.add(item);
                        else _selectedAllergies.remove(item);
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildMultiSelectCard(
                    'Состояния здоровья',
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
                      'CELIAC_DISEASE'
                    ],
                    _selectedHealthConditions,
                        (item, selected) {
                      setModalState(() {
                        if (selected) _selectedHealthConditions.add(item);
                        else _selectedHealthConditions.remove(item);
                      });
                    },
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена'),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _saveProfile(context),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
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
}
