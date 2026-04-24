import 'package:flutter/material.dart';
import 'create_custom_product_button.dart';

/// Пример использования CreateCustomProductButton
class CreateCustomProductButtonExample extends StatelessWidget {
  const CreateCustomProductButtonExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пример CreateCustomProductButton'),
      ),
      body: Stack(
        children: [
          const Center(
            child: Text('Основной контент экрана'),
          ),
          // Кнопка создания продукта внизу экрана
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: CreateCustomProductButton(
              onPressed: () {
                // Открыть форму создания пользовательского продукта
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Открытие формы создания продукта...'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
