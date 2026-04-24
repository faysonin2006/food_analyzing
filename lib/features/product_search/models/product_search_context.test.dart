import 'package:flutter_test/flutter_test.dart';
import 'package:food_analyzing/features/product_search/models/product_search_context.dart';

void main() {
  group('ProductSearchContext', () {
    test('should have all required values', () {
      // Verify all enum values exist
      expect(ProductSearchContext.values.length, 4);
      expect(ProductSearchContext.values, contains(ProductSearchContext.consumed));
      expect(ProductSearchContext.values, contains(ProductSearchContext.pantry));
      expect(ProductSearchContext.values, contains(ProductSearchContext.shopping));
      expect(ProductSearchContext.values, contains(ProductSearchContext.family));
    });

    test('should have correct string representation', () {
      // Verify enum names
      expect(ProductSearchContext.consumed.name, 'consumed');
      expect(ProductSearchContext.pantry.name, 'pantry');
      expect(ProductSearchContext.shopping.name, 'shopping');
      expect(ProductSearchContext.family.name, 'family');
    });

    test('should be comparable', () {
      // Verify enum equality
      expect(ProductSearchContext.consumed, ProductSearchContext.consumed);
      expect(ProductSearchContext.consumed == ProductSearchContext.pantry, false);
    });

    test('should support switch statements', () {
      // Verify enum can be used in switch statements
      String getContextName(ProductSearchContext context) {
        switch (context) {
          case ProductSearchContext.consumed:
            return 'Consumed Products';
          case ProductSearchContext.pantry:
            return 'Pantry';
          case ProductSearchContext.shopping:
            return 'Shopping List';
          case ProductSearchContext.family:
            return 'Family';
        }
      }

      expect(getContextName(ProductSearchContext.consumed), 'Consumed Products');
      expect(getContextName(ProductSearchContext.pantry), 'Pantry');
      expect(getContextName(ProductSearchContext.shopping), 'Shopping List');
      expect(getContextName(ProductSearchContext.family), 'Family');
    });
  });
}
