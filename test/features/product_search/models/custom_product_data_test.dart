import 'package:flutter_test/flutter_test.dart';
import 'package:food_analyzing/features/product_search/models/custom_product_data.dart';

void main() {
  group('CustomProductData', () {
    test('should create instance with required fields', () {
      final customProduct = CustomProductData(
        name: 'Test Product',
        caloriesPer100g: 250.0,
        proteinsPer100g: 10.0,
        fatsPer100g: 5.0,
        carbsPer100g: 30.0,
      );

      expect(customProduct.name, 'Test Product');
      expect(customProduct.caloriesPer100g, 250.0);
      expect(customProduct.proteinsPer100g, 10.0);
      expect(customProduct.fatsPer100g, 5.0);
      expect(customProduct.carbsPer100g, 30.0);
      expect(customProduct.brandName, isNull);
      expect(customProduct.imageFile, isNull);
    });

    test('should create instance with optional fields', () {
      final customProduct = CustomProductData(
        name: 'Test Product',
        caloriesPer100g: 250.0,
        proteinsPer100g: 10.0,
        fatsPer100g: 5.0,
        carbsPer100g: 30.0,
        brandName: 'Test Brand',
      );

      expect(customProduct.name, 'Test Product');
      expect(customProduct.brandName, 'Test Brand');
    });

    test('toJson should serialize correctly', () {
      final customProduct = CustomProductData(
        name: 'Test Product',
        caloriesPer100g: 250.0,
        proteinsPer100g: 10.0,
        fatsPer100g: 5.0,
        carbsPer100g: 30.0,
        brandName: 'Test Brand',
      );

      final json = customProduct.toJson();

      expect(json['name'], 'Test Product');
      expect(json['brandName'], 'Test Brand');
      expect(json['caloriesKcal100g'], 250.0);
      expect(json['proteins100g'], 10.0);
      expect(json['fats100g'], 5.0);
      expect(json['carbohydrates100g'], 30.0);
    });

    test('toJson should handle null brandName', () {
      final customProduct = CustomProductData(
        name: 'Test Product',
        caloriesPer100g: 250.0,
        proteinsPer100g: 10.0,
        fatsPer100g: 5.0,
        carbsPer100g: 30.0,
      );

      final json = customProduct.toJson();

      expect(json['brandName'], isNull);
    });
  });
}
