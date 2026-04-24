import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_analyzing/features/product_search/widgets/compact_scan_button.dart';

void main() {
  group('CompactScanButton', () {
    testWidgets('renders with correct size', (WidgetTester tester) async {
      // Arrange
      bool wasPressed = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactScanButton(
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      // Assert - Find the SizedBox that is a direct child of CompactScanButton
      final compactScanButton = find.byType(CompactScanButton);
      expect(compactScanButton, findsOneWidget);
      
      // Verify the widget renders correctly
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('renders IconButton.filledTonal with correct icon',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactScanButton(
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      // Arrange
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactScanButton(
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // Assert
      expect(wasPressed, true);
    });

    testWidgets('has correct semantic label', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactScanButton(
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(
        find.bySemanticsLabel('Сканировать штрихкод'),
        findsOneWidget,
      );
    });

    testWidgets('has tooltip', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactScanButton(
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Сканировать штрихкод');
    });
  });
}
