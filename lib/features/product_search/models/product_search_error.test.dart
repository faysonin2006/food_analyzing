import 'package:flutter_test/flutter_test.dart';
import 'product_search_error.dart';

void main() {
  group('ProductSearchError', () {
    test('enum contains all expected error types', () {
      expect(ProductSearchError.values.length, 6);
      expect(ProductSearchError.values, contains(ProductSearchError.networkError));
      expect(ProductSearchError.values, contains(ProductSearchError.emptyResults));
      expect(ProductSearchError.values, contains(ProductSearchError.invalidQuery));
      expect(ProductSearchError.values, contains(ProductSearchError.barcodeNotFound));
      expect(ProductSearchError.values, contains(ProductSearchError.scannerError));
      expect(ProductSearchError.values, contains(ProductSearchError.cacheError));
    });
  });

  group('ProductSearchException', () {
    test('creates exception with required fields', () {
      const exception = ProductSearchException(
        error: ProductSearchError.networkError,
        message: 'Network connection failed',
      );

      expect(exception.error, ProductSearchError.networkError);
      expect(exception.message, 'Network connection failed');
      expect(exception.details, isNull);
    });

    test('creates exception with optional details', () {
      const exception = ProductSearchException(
        error: ProductSearchError.barcodeNotFound,
        message: 'Product not found',
        details: 'Barcode: 1234567890',
      );

      expect(exception.error, ProductSearchError.barcodeNotFound);
      expect(exception.message, 'Product not found');
      expect(exception.details, 'Barcode: 1234567890');
    });

    test('toString returns formatted message without details', () {
      const exception = ProductSearchException(
        error: ProductSearchError.invalidQuery,
        message: 'Query is too short',
      );

      expect(exception.toString(), 'ProductSearchException: Query is too short');
    });

    test('toString returns formatted message with details', () {
      const exception = ProductSearchException(
        error: ProductSearchError.cacheError,
        message: 'Cache operation failed',
        details: 'Cache is full',
      );

      expect(
        exception.toString(),
        'ProductSearchException: Cache operation failed (Cache is full)',
      );
    });

    test('exception implements Exception interface', () {
      const exception = ProductSearchException(
        error: ProductSearchError.scannerError,
        message: 'Scanner initialization failed',
      );

      expect(exception, isA<Exception>());
    });

    test('all error types can be used in exceptions', () {
      for (final errorType in ProductSearchError.values) {
        final exception = ProductSearchException(
          error: errorType,
          message: 'Test message for ${errorType.name}',
        );

        expect(exception.error, errorType);
        expect(exception.message, contains(errorType.name));
      }
    });
  });
}
