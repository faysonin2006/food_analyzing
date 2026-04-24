import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../models/product_item.dart';
import 'product_card.dart';

void main() {
  group('ProductCard', () {
    testWidgets('отображает название продукта', (tester) async {
      final product = ProductItem(
        id: '1',
        productName: 'Тестовый продукт',
        caloriesKcal100g: 100,
        proteins100g: 10,
        fats100g: 5,
        carbohydrates100g: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: product,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Тестовый продукт'), findsOneWidget);
    });

    testWidgets('отображает бренд если он есть', (tester) async {
      final product = ProductItem(
        id: '1',
        productName: 'Тестовый продукт',
        brandName: 'Тестовый бренд',
        caloriesKcal100g: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: product,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Тестовый бренд'), findsOneWidget);
    });

    testWidgets('отображает калорийность', (tester) async {
      final product = ProductItem(
        id: '1',
        productName: 'Тестовый продукт',
        caloriesKcal100g: 250.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: product,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('251 ккал'), findsOneWidget);
    });

    testWidgets('отображает макронутриенты', (tester) async {
      final product = ProductItem(
        id: '1',
        productName: 'Тестовый продукт',
        proteins100g: 10.5,
        fats100g: 5.2,
        carbohydrates100g: 15.8,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: product,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Б: 10.5г'), findsOneWidget);
      expect(find.text('Ж: 5.2г'), findsOneWidget);
      expect(find.text('У: 15.8г'), findsOneWidget);
    });

    testWidgets('вызывает onTap при нажатии на карточку', (tester) async {
      var tapped = false;
      final product = ProductItem(
        id: '1',
        productName: 'Тестовый продукт',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: product,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ProductCard));
      expect(tapped, isTrue);
    });

    testWidgets('вызывает onTap при нажатии на иконку добавления', (tester) async {
      var tapped = false;
      final product = ProductItem(
        id: '1',
        productName: 'Тестовый продукт',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: product,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      expect(tapped, isTrue);
    });

    testWidgets('имеет семантическую метку с информацией о продукте', (tester) async {
      final product = ProductItem(
        id: '1',
        productName: 'Тестовый продукт',
        brandName: 'Тестовый бренд',
        caloriesKcal100g: 100,
        proteins100g: 10,
        fats100g: 5,
        carbohydrates100g: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: product,
              onTap: () {},
            ),
          ),
        ),
      );

      // Находим Semantics виджет, который содержит метку
      final semanticsFinder = find.ancestor(
        of: find.byType(Card),
        matching: find.byType(Semantics),
      );
      
      expect(semanticsFinder, findsOneWidget);
      
      final semantics = tester.widget<Semantics>(semanticsFinder);
      final label = semantics.properties.label ?? '';
      
      expect(label, contains('Продукт: Тестовый продукт'));
      expect(label, contains('бренд: Тестовый бренд'));
      expect(label, contains('калорийность: 100 килокалорий'));
      expect(label, contains('белки: 10.0 грамм'));
      expect(label, contains('жиры: 5.0 грамм'));
      expect(label, contains('углеводы: 15.0 грамм'));
    });

    testWidgets('отображает placeholder когда нет изображения', (tester) async {
      final product = ProductItem(
        id: '1',
        productName: 'Тестовый продукт',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: product,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fastfood_outlined), findsOneWidget);
    });
  });
}
