/// Модель элемента продукта в результатах поиска
class ProductItem {
  const ProductItem({
    required this.id,
    required this.productName,
    this.brandName,
    this.imageUrl,
    this.quantity,
    this.servingSize,
    this.countriesText,
    this.caloriesKcal100g,
    this.proteins100g,
    this.fats100g,
    this.carbohydrates100g,
    this.barcode,
  });

  final String id;
  final String productName;
  final String? brandName;
  final String? imageUrl;
  final String? quantity;
  final String? servingSize;
  final String? countriesText;
  final double? caloriesKcal100g;
  final double? proteins100g;
  final double? fats100g;
  final double? carbohydrates100g;
  final String? barcode;

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      brandName: json['brandName']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      quantity: json['quantity']?.toString(),
      servingSize: json['servingSize']?.toString(),
      countriesText: json['countriesText']?.toString(),
      caloriesKcal100g: _parseDouble(json['caloriesKcal100g']),
      proteins100g: _parseDouble(json['proteins100g']),
      fats100g: _parseDouble(json['fats100g']),
      carbohydrates100g: _parseDouble(json['carbohydrates100g']),
      barcode: json['barcode']?.toString(),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productName': productName,
      'brandName': brandName,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'servingSize': servingSize,
      'countriesText': countriesText,
      'caloriesKcal100g': caloriesKcal100g,
      'proteins100g': proteins100g,
      'fats100g': fats100g,
      'carbohydrates100g': carbohydrates100g,
      'barcode': barcode,
    };
  }
}
