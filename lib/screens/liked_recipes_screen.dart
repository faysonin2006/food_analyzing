import 'package:flutter/material.dart';

import '../core/app_top_bar.dart';
import '../core/tr.dart';

class LikedRecipesScreen extends StatelessWidget {
  const LikedRecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenBg = isDark
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFF4D9B1);
    final panelBg = isDark
        ? Color.alphaBlend(
            cs.surfaceContainerHighest.withValues(alpha: 0.55),
            cs.surface,
          )
        : const Color(0xFFF6F6F7);
    final accent = cs.primary;

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppTopBar(title: tr(context, 'tab_liked'), actions: const []),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(34),
              bottom: Radius.circular(34),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: isDark ? 0.26 : 0.14),
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 42,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(context, 'liked_empty_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, 'liked_empty_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
