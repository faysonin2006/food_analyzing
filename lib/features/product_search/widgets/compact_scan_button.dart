import 'package:flutter/material.dart';

/// Компактная кнопка сканирования штрихкода для интерфейса поиска продуктов.
///
/// Размер: 48x48 пикселей
/// Позиция: правый верхний угол с отступом 16px от краев
/// Стиль: IconButton.filledTonal из Material Design 3
class CompactScanButton extends StatelessWidget {
  const CompactScanButton({
    super.key,
    required this.onPressed,
  });

  /// Callback, вызываемый при нажатии на кнопку
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Сканировать штрихкод',
      button: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton.filledTonal(
          onPressed: onPressed,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Сканировать штрихкод',
        ),
      ),
    );
  }
}
