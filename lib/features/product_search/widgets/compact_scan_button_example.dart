import 'package:flutter/material.dart';
import 'compact_scan_button.dart';

/// Пример использования CompactScanButton
class CompactScanButtonExample extends StatelessWidget {
  const CompactScanButtonExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пример CompactScanButton'),
      ),
      body: Stack(
        children: [
          const Center(
            child: Text('Основной контент экрана'),
          ),
          // Кнопка сканирования в правом верхнем углу
          Positioned(
            top: 16,
            right: 16,
            child: CompactScanButton(
              onPressed: () {
                // Открыть сканер штрихкода
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Открытие сканера штрихкода...'),
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
