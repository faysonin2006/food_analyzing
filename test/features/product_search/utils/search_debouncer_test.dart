import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_analyzing/features/product_search/product_search.dart';

void main() {
  group('SearchDebouncer', () {
    late SearchDebouncer debouncer;

    setUp(() {
      debouncer = SearchDebouncer(delay: const Duration(milliseconds: 300));
    });

    tearDown(() {
      debouncer.dispose();
    });

    test('should delay action execution by specified duration', () async {
      // Arrange
      var executed = false;
      void action() {
        executed = true;
      }

      // Act
      debouncer.call(action);

      // Assert - action should not be executed immediately
      expect(executed, false);

      // Wait for less than delay
      await Future.delayed(const Duration(milliseconds: 200));
      expect(executed, false);

      // Wait for the remaining time
      await Future.delayed(const Duration(milliseconds: 150));
      expect(executed, true);
    });

    test('should cancel previous timer when called multiple times', () async {
      // Arrange
      var executionCount = 0;
      void action() {
        executionCount++;
      }

      // Act - call multiple times rapidly
      debouncer.call(action);
      await Future.delayed(const Duration(milliseconds: 100));
      debouncer.call(action);
      await Future.delayed(const Duration(milliseconds: 100));
      debouncer.call(action);

      // Wait for the final delay to complete
      await Future.delayed(const Duration(milliseconds: 350));

      // Assert - action should be executed only once (the last call)
      expect(executionCount, 1);
    });

    test('should execute action only after delay without new calls', () async {
      // Arrange
      var executed = false;
      void action() {
        executed = true;
      }

      // Act - rapid calls
      debouncer.call(action);
      await Future.delayed(const Duration(milliseconds: 50));
      debouncer.call(action);
      await Future.delayed(const Duration(milliseconds: 50));
      debouncer.call(action);

      // Assert - not executed yet
      expect(executed, false);

      // Wait for full delay after last call
      await Future.delayed(const Duration(milliseconds: 350));
      expect(executed, true);
    });

    test('should cancel timer on dispose', () async {
      // Arrange
      var executed = false;
      void action() {
        executed = true;
      }

      // Act
      debouncer.call(action);
      debouncer.dispose();

      // Wait for what would have been the delay
      await Future.delayed(const Duration(milliseconds: 350));

      // Assert - action should not be executed
      expect(executed, false);
    });

    test('should handle multiple dispose calls safely', () {
      // Act & Assert - should not throw
      expect(() {
        debouncer.dispose();
        debouncer.dispose();
      }, returnsNormally);
    });

    test('should work with different delay durations', () async {
      // Arrange
      final shortDebouncer = SearchDebouncer(
        delay: const Duration(milliseconds: 100),
      );
      var executed = false;
      void action() {
        executed = true;
      }

      // Act
      shortDebouncer.call(action);

      // Assert - not executed immediately
      expect(executed, false);

      // Wait for the shorter delay
      await Future.delayed(const Duration(milliseconds: 150));
      expect(executed, true);

      // Cleanup
      shortDebouncer.dispose();
    });

    test('should execute different actions correctly', () async {
      // Arrange
      var firstExecuted = false;
      var secondExecuted = false;

      void firstAction() {
        firstExecuted = true;
      }

      void secondAction() {
        secondExecuted = true;
      }

      // Act - first action is cancelled by second
      debouncer.call(firstAction);
      await Future.delayed(const Duration(milliseconds: 100));
      debouncer.call(secondAction);

      // Wait for delay
      await Future.delayed(const Duration(milliseconds: 350));

      // Assert - only second action should execute
      expect(firstExecuted, false);
      expect(secondExecuted, true);
    });

    test('should allow reuse after dispose', () async {
      // Arrange
      var executed = false;
      void action() {
        executed = true;
      }

      // Act
      debouncer.call(action);
      debouncer.dispose();

      // Create new debouncer
      final newDebouncer = SearchDebouncer(
        delay: const Duration(milliseconds: 300),
      );
      newDebouncer.call(action);

      // Wait for delay
      await Future.delayed(const Duration(milliseconds: 350));

      // Assert
      expect(executed, true);

      // Cleanup
      newDebouncer.dispose();
    });
  });
}
