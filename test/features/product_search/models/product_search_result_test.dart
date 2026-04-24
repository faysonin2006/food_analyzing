import 'package:flutter_test/flutter_test.dart';
import 'package:food_analyzing/features/product_search/models/models.dart';

void main() {
  group('ProductSearchResult', () {
    group('fromJson', () {
      test('parses valid JSON with all fields', () {
        final json = {
          'items': [
            {
              'id': '1',
              'productName': 'Test Product',
              'brandName': 'Test Brand',
              'caloriesKcal100g': 100.0,
              'proteins100g': 10.0,
              'fats100g': 5.0,
              'carbohydrates100g': 15.0,
            }
          ],
          'page': 2,
          'hasNext': true,
          'total': 50,
        };

        final result = ProductSearchResult.fromJson(json);

        expect(result.items.length, 1);
        expect(result.items.first.productName, 'Test Product');
        expect(result.page, 2);
        expect(result.hasNext, true);
        expect(result.total, 50);
      });

      test('handles empty items list', () {
        final json = {
          'items': [],
          'page': 1,
          'hasNext': false,
          'total': 0,
        };

        final result = ProductSearchResult.fromJson(json);

        expect(result.items, isEmpty);
        expect(result.page, 1);
        expect(result.hasNext, false);
        expect(result.total, 0);
      });

      test('handles null items with default empty list', () {
        final json = {
          'page': 1,
          'hasNext': false,
          'total': 0,
        };

        final result = ProductSearchResult.fromJson(json);

        expect(result.items, isEmpty);
      });

      test('uses default values for missing fields', () {
        final json = <String, dynamic>{};

        final result = ProductSearchResult.fromJson(json);

        expect(result.items, isEmpty);
        expect(result.page, 1);
        expect(result.hasNext, false);
        expect(result.total, 0);
      });

      test('parses multiple items correctly', () {
        final json = {
          'items': [
            {'id': '1', 'productName': 'Product 1'},
            {'id': '2', 'productName': 'Product 2'},
            {'id': '3', 'productName': 'Product 3'},
          ],
          'page': 1,
          'hasNext': true,
          'total': 10,
        };

        final result = ProductSearchResult.fromJson(json);

        expect(result.items.length, 3);
        expect(result.items[0].productName, 'Product 1');
        expect(result.items[1].productName, 'Product 2');
        expect(result.items[2].productName, 'Product 3');
      });
    });

    group('toJson', () {
      test('serializes to JSON correctly', () {
        final result = ProductSearchResult(
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

        final json = result.toJson();

        expect(json['items'], isA<List>());
        expect((json['items'] as List).length, 1);
        expect(json['page'], 2);
        expect(json['hasNext'], true);
        expect(json['total'], 50);
      });

      test('serializes empty items list', () {
        const result = ProductSearchResult(
          items: [],
          page: 1,
          hasNext: false,
          total: 0,
        );

        final json = result.toJson();

        expect(json['items'], isEmpty);
        expect(json['page'], 1);
        expect(json['hasNext'], false);
        expect(json['total'], 0);
      });
    });

    group('round-trip serialization', () {
      test('fromJson and toJson are inverse operations', () {
        final originalJson = {
          'items': [
            {
              'id': '1',
              'productName': 'Test Product',
              'brandName': 'Test Brand',
              'caloriesKcal100g': 100.0,
              'proteins100g': 10.0,
              'fats100g': 5.0,
              'carbohydrates100g': 15.0,
            }
          ],
          'page': 2,
          'hasNext': true,
          'total': 50,
        };

        final result = ProductSearchResult.fromJson(originalJson);
        final serializedJson = result.toJson();

        expect(serializedJson['page'], originalJson['page']);
        expect(serializedJson['hasNext'], originalJson['hasNext']);
        expect(serializedJson['total'], originalJson['total']);
        expect((serializedJson['items'] as List).length,
            (originalJson['items'] as List).length);
      });
    });
  });
}
