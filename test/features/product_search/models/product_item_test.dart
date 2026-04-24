import 'package:flutter_test/flutter_test.dart';
import 'package:food_analyzing/features/product_search/models/models.dart';

void main() {
  group('ProductItem', () {
    group('fromJson', () {
      test('parses valid JSON with all fields', () {
        final json = {
          'id': '123',
          'productName': 'Test Product',
          'brandName': 'Test Brand',
          'imageUrl': 'https://example.com/image.jpg',
          'quantity': '500g',
          'servingSize': '100g',
          'countriesText': 'Russia',
          'caloriesKcal100g': 250.5,
          'proteins100g': 10.2,
          'fats100g': 5.8,
          'carbohydrates100g': 30.1,
          'barcode': '1234567890123',
        };

        final item = ProductItem.fromJson(json);

        expect(item.id, '123');
        expect(item.productName, 'Test Product');
        expect(item.brandName, 'Test Brand');
        expect(item.imageUrl, 'https://example.com/image.jpg');
        expect(item.quantity, '500g');
        expect(item.servingSize, '100g');
        expect(item.countriesText, 'Russia');
        expect(item.caloriesKcal100g, 250.5);
        expect(item.proteins100g, 10.2);
        expect(item.fats100g, 5.8);
        expect(item.carbohydrates100g, 30.1);
        expect(item.barcode, '1234567890123');
      });

      test('handles missing optional fields', () {
        final json = {
          'id': '123',
          'productName': 'Test Product',
        };

        final item = ProductItem.fromJson(json);

        expect(item.id, '123');
        expect(item.productName, 'Test Product');
        expect(item.brandName, isNull);
        expect(item.imageUrl, isNull);
        expect(item.quantity, isNull);
        expect(item.servingSize, isNull);
        expect(item.countriesText, isNull);
        expect(item.caloriesKcal100g, isNull);
        expect(item.proteins100g, isNull);
        expect(item.fats100g, isNull);
        expect(item.carbohydrates100g, isNull);
        expect(item.barcode, isNull);
      });

      test('handles empty id and productName', () {
        final json = <String, dynamic>{};

        final item = ProductItem.fromJson(json);

        expect(item.id, '');
        expect(item.productName, '');
      });

      test('converts numeric types to strings for text fields', () {
        final json = {
          'id': 123,
          'productName': 456,
          'brandName': 789,
          'quantity': 100,
        };

        final item = ProductItem.fromJson(json);

        expect(item.id, '123');
        expect(item.productName, '456');
        expect(item.brandName, '789');
        expect(item.quantity, '100');
      });

      test('parses integer nutrition values as doubles', () {
        final json = {
          'id': '1',
          'productName': 'Test',
          'caloriesKcal100g': 100,
          'proteins100g': 10,
          'fats100g': 5,
          'carbohydrates100g': 15,
        };

        final item = ProductItem.fromJson(json);

        expect(item.caloriesKcal100g, 100.0);
        expect(item.proteins100g, 10.0);
        expect(item.fats100g, 5.0);
        expect(item.carbohydrates100g, 15.0);
      });

      test('parses string nutrition values as doubles', () {
        final json = {
          'id': '1',
          'productName': 'Test',
          'caloriesKcal100g': '100.5',
          'proteins100g': '10.2',
          'fats100g': '5.8',
          'carbohydrates100g': '15.3',
        };

        final item = ProductItem.fromJson(json);

        expect(item.caloriesKcal100g, 100.5);
        expect(item.proteins100g, 10.2);
        expect(item.fats100g, 5.8);
        expect(item.carbohydrates100g, 15.3);
      });

      test('handles invalid nutrition values as null', () {
        final json = {
          'id': '1',
          'productName': 'Test',
          'caloriesKcal100g': 'invalid',
          'proteins100g': 'not a number',
          'fats100g': '',
          'carbohydrates100g': null,
        };

        final item = ProductItem.fromJson(json);

        expect(item.caloriesKcal100g, isNull);
        expect(item.proteins100g, isNull);
        expect(item.fats100g, isNull);
        expect(item.carbohydrates100g, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        const item = ProductItem(
          id: '123',
          productName: 'Test Product',
          brandName: 'Test Brand',
          imageUrl: 'https://example.com/image.jpg',
          quantity: '500g',
          servingSize: '100g',
          countriesText: 'Russia',
          caloriesKcal100g: 250.5,
          proteins100g: 10.2,
          fats100g: 5.8,
          carbohydrates100g: 30.1,
          barcode: '1234567890123',
        );

        final json = item.toJson();

        expect(json['id'], '123');
        expect(json['productName'], 'Test Product');
        expect(json['brandName'], 'Test Brand');
        expect(json['imageUrl'], 'https://example.com/image.jpg');
        expect(json['quantity'], '500g');
        expect(json['servingSize'], '100g');
        expect(json['countriesText'], 'Russia');
        expect(json['caloriesKcal100g'], 250.5);
        expect(json['proteins100g'], 10.2);
        expect(json['fats100g'], 5.8);
        expect(json['carbohydrates100g'], 30.1);
        expect(json['barcode'], '1234567890123');
      });

      test('serializes null optional fields', () {
        const item = ProductItem(
          id: '123',
          productName: 'Test Product',
        );

        final json = item.toJson();

        expect(json['id'], '123');
        expect(json['productName'], 'Test Product');
        expect(json['brandName'], isNull);
        expect(json['imageUrl'], isNull);
        expect(json['quantity'], isNull);
        expect(json['servingSize'], isNull);
        expect(json['countriesText'], isNull);
        expect(json['caloriesKcal100g'], isNull);
        expect(json['proteins100g'], isNull);
        expect(json['fats100g'], isNull);
        expect(json['carbohydrates100g'], isNull);
        expect(json['barcode'], isNull);
      });
    });

    group('round-trip serialization', () {
      test('fromJson and toJson are inverse operations', () {
        final originalJson = {
          'id': '123',
          'productName': 'Test Product',
          'brandName': 'Test Brand',
          'imageUrl': 'https://example.com/image.jpg',
          'quantity': '500g',
          'servingSize': '100g',
          'countriesText': 'Russia',
          'caloriesKcal100g': 250.5,
          'proteins100g': 10.2,
          'fats100g': 5.8,
          'carbohydrates100g': 30.1,
          'barcode': '1234567890123',
        };

        final item = ProductItem.fromJson(originalJson);
        final serializedJson = item.toJson();

        expect(serializedJson['id'], originalJson['id']);
        expect(serializedJson['productName'], originalJson['productName']);
        expect(serializedJson['brandName'], originalJson['brandName']);
        expect(serializedJson['imageUrl'], originalJson['imageUrl']);
        expect(serializedJson['quantity'], originalJson['quantity']);
        expect(serializedJson['servingSize'], originalJson['servingSize']);
        expect(serializedJson['countriesText'], originalJson['countriesText']);
        expect(serializedJson['caloriesKcal100g'],
            originalJson['caloriesKcal100g']);
        expect(serializedJson['proteins100g'], originalJson['proteins100g']);
        expect(serializedJson['fats100g'], originalJson['fats100g']);
        expect(serializedJson['carbohydrates100g'],
            originalJson['carbohydrates100g']);
        expect(serializedJson['barcode'], originalJson['barcode']);
      });
    });

    group('_parseDouble', () {
      test('parses double values', () {
        final json = {
          'id': '1',
          'productName': 'Test',
          'caloriesKcal100g': 100.5,
        };

        final item = ProductItem.fromJson(json);

        expect(item.caloriesKcal100g, 100.5);
      });

      test('parses integer values', () {
        final json = {
          'id': '1',
          'productName': 'Test',
          'caloriesKcal100g': 100,
        };

        final item = ProductItem.fromJson(json);

        expect(item.caloriesKcal100g, 100.0);
      });

      test('parses string numeric values', () {
        final json = {
          'id': '1',
          'productName': 'Test',
          'caloriesKcal100g': '100.5',
        };

        final item = ProductItem.fromJson(json);

        expect(item.caloriesKcal100g, 100.5);
      });

      test('returns null for invalid values', () {
        final json = {
          'id': '1',
          'productName': 'Test',
          'caloriesKcal100g': 'invalid',
        };

        final item = ProductItem.fromJson(json);

        expect(item.caloriesKcal100g, isNull);
      });

      test('returns null for null values', () {
        final json = {
          'id': '1',
          'productName': 'Test',
          'caloriesKcal100g': null,
        };

        final item = ProductItem.fromJson(json);

        expect(item.caloriesKcal100g, isNull);
      });
    });
  });
}
