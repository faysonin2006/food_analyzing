import 'package:flutter/material.dart';
import '../models/product_item.dart';
import 'search_results_list.dart';

/// Пример использования виджета SearchResultsList
class SearchResultsListExample extends StatefulWidget {
  const SearchResultsListExample({super.key});

  @override
  State<SearchResultsListExample> createState() =>
      _SearchResultsListExampleState();
}

class _SearchResultsListExampleState extends State<SearchResultsListExample> {
  bool _isLoading = false;
  List<ProductItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMockData();
  }

  void _loadMockData() {
    setState(() {
      _isLoading = true;
    });

    // Имитация загрузки данных
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _items = [
          const ProductItem(
            id: '1',
            productName: 'Молоко 3.2%',
            brandName: 'Простоквашино',
            caloriesKcal100g: 60,
            proteins100g: 2.9,
            fats100g: 3.2,
            carbohydrates100g: 4.7,
          ),
          const ProductItem(
            id: '2',
            productName: 'Хлеб белый',
            brandName: 'Хлебный дом',
            caloriesKcal100g: 265,
            proteins100g: 7.6,
            fats100g: 3.2,
            carbohydrates100g: 50.1,
          ),
        ];
      });
    });
  }

  void _handleItemTap(ProductItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Выбран продукт: ${item.productName}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пример SearchResultsList'),
      ),
      body: SearchResultsList(
        items: _items,
        onItemTap: _handleItemTap,
        isLoading: _isLoading,
      ),
    );
  }
}
