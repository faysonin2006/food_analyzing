import 'package:image_picker/image_picker.dart';

/// Модель данных для пользовательских продуктов
class CustomProductData {
  const CustomProductData({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinsPer100g,
    required this.fatsPer100g,
    required this.carbsPer100g,
    this.brandName,
    this.imageFile,
  });

  final String name;
  final double caloriesPer100g;
  final double proteinsPer100g;
  final double fatsPer100g;
  final double carbsPer100g;
  final String? brandName;
  final XFile? imageFile;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brandName': brandName,
      'caloriesKcal100g': caloriesPer100g,
      'proteins100g': proteinsPer100g,
      'fats100g': fatsPer100g,
      'carbohydrates100g': carbsPer100g,
    };
  }
}
