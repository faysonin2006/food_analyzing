import 'package:flutter_test/flutter_test.dart';
import 'package:food_analyzing/features/product_search/models/models.dart';

void main() {
  group('ProductSearchResult and ProductItem integration', () {
    test('parses API response structure correctly', () {
      // Simulating a typical API response
      final apiResponse = {
        'items': [
          {
            'id': '1',
            'productName': 'Молоко',
            'brandName': 'Простоквашино',
            'imageUrl': 'https://example.com/milk.jpg',
            'quantity': '1л',
            'servingSize': '100мл',
            'countriesText': 'Россия',
            'caloriesKcal100g': 64.0,
            'proteins100g': 3.2,
            'fats100g': 3.6,
            'carbohydrates100g': 4.7,
            'barcode': '4607025392010',
          },
          {
            'id': '2',
            'productName': 'Хлеб белый',
            'brandName': 'Каравай',
            'caloriesKcal100g': 266.0,
            'proteins100g': 7.6,
            'fats100g': 3.2,
            'carbohydrates100g': 50.1,
          },
        ],
        'page': 1,
        'hasNext': true,
        'total': 25,
      };

      final result = ProductSearchResult.fromJson(apiResponse);

      expect(result.items.length, 2);
      expect(result.page, 1);
      expect(result.hasNext, true);
      expect(result.total, 25);

      // Verify first product
      final milk = result.items[0];
      expect(milk.productName, 'Молоко');
      expect(milk.brandName, 'Простоквашино');
      expect(milk.caloriesKcal100g, 64.0);
      expect(milk.proteins100g, 3.2);
      expect(milk.barcode, '4607025392010');

      // Verify second product
      final bread = result.items[1];
      expect(bread.productName, 'Хлеб белый');
      expect(bread.brandName, 'Каравай');
      expect(bread.caloriesKcal100g, 266.0);
      expect(bread.barcode, isNull);
    });

    test('handles empty search results', () {
      final apiResponse = {
        'items': [],
        'page': 1,
        'hasNext': false,
        'total': 0,
      };

      final result = ProductSearchResult.fromJson(apiResponse);

      expect(result.items, isEmpty);
      expect(result.page, 1);
      expect(result.hasNext, false);
      expect(result.total, 0);
    });

    test('serializes and deserializes complete search result', () {
      final original = ProductSearchResult(
        items: [
          const ProductItem(
            id: '1',
            productName: 'Test Product',
            brandName: 'Test Brand',
            caloriesKcal100g: 100.0,
            proteins100g: 10.0,
            fats100g: 5.0,
            carbohydrates100g: 15.0,
          ),
        ],
        page: 2,
        hasNext: true,
        total: 50,
      );

      final json = original.toJson();
      final deserialized = ProductSearchResult.fromJson(json);

      expect(deserialized.items.length, original.items.length);
      expect(deserialized.page, original.page);
      expect(deserialized.hasNext, original.hasNext);
      expect(deserialized.total, original.total);
      expect(deserialized.items.first.productName,
          original.items.first.productName);
    });
  });
}
