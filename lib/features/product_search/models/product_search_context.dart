/// Enum representing the context in which the product search interface is being used.
///
/// This enum identifies which section of the app is using the UnifiedProductSearchScreen:
/// - [consumed]: For adding consumed products
/// - [pantry]: For managing pantry items
/// - [shopping]: For managing shopping list items
/// - [family]: For sharing products with family members
enum ProductSearchContext {
  /// Context for consumed products section
  consumed,

  /// Context for pantry section
  pantry,

  /// Context for shopping list section
  shopping,

  /// Context for family section
  family,
}
