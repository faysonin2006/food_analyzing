import 'package:flutter/material.dart';

/// Фиксированная кнопка для создания пользовательского продукта.
///
/// Позиция: фиксированная внизу экрана
/// Стиль: FilledButton.icon из Material Design 3
/// Иконка: Icons.add_box_outlined
class CreateCustomProductButton extends StatelessWidget {
  const CreateCustomProductButton({
    super.key,
    required this.onPressed,
  });

  /// Callback, вызываемый при нажатии на кнопку
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Добавить свой продукт',
      button: true,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Добавить свой продукт'),
      ),
    );
  }
}
