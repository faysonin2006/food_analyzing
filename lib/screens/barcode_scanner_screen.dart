import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_theme.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  bool _didPop = false;
  final TextEditingController _manualController = TextEditingController();

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';

  @override
  void dispose() {
    _manualController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _finish(String barcode) {
    if (_didPop || barcode.trim().isEmpty) return;
    _didPop = true;
    Navigator.of(context).pop(barcode.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final code in capture.barcodes) {
                  final value = code.rawValue?.trim() ?? '';
                  if (value.isNotEmpty) {
                    _finish(value);
                    return;
                  }
                }
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0, 0.28, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isRu ? 'Сканер штрихкодов' : 'Barcode Atelier',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _controller.toggleTorch,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const Icon(Icons.flashlight_on_rounded),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.34),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.atelierMint.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppTheme.atelierMint.withValues(
                                    alpha: 0.24,
                                  ),
                                ),
                              ),
                              child: Text(
                                _isRu ? 'ЖИВАЯ КАМЕРА' : 'LIVE CAMERA',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.atelierMint,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _isRu
                              ? 'Сканируй\nштрихкод продукта'
                              : 'Scan a product\nbarcode',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 0.96,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isRu
                              ? 'Держи код внутри рамки или введи его вручную ниже.'
                              : 'Center the code inside the frame or type it manually below.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _ScannerFrame(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates_outlined,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isRu
                                    ? 'Лучше всего работает при мягком фронтальном свете и полном попадании кода в рамку.'
                                    : 'Works best with even front light and the full barcode visible inside the frame.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _manualController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _finish(_manualController.text),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: _isRu
                                ? 'Или введи штрихкод вручную'
                                : 'Or enter barcode manually',
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _finish(_manualController.text),
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: Text(
                              _isRu
                                  ? 'Использовать этот штрихкод'
                                  : 'Use this barcode',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.atelierLime, width: 2),
      ),
      child: Stack(
        children: const [
          _ScannerCorner(alignment: Alignment.topLeft),
          _ScannerCorner(alignment: Alignment.topRight),
          _ScannerCorner(alignment: Alignment.bottomLeft),
          _ScannerCorner(alignment: Alignment.bottomRight),
        ],
      ),
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(14),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border(
            left: isLeft
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            top: isTop
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
