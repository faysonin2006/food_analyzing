import 'dart:ui';

import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(86);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final shellColor = Color.alphaBlend(
      cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.74 : 0.9),
      cs.surface,
    );
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.65 : 0.55,
    );

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: shellColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface.withValues(alpha: 0.92),
                          height: 1.02,
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppTopAction extends StatelessWidget {
  const AppTopAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final normalBg = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.22 : 0.12),
      cs.surface,
    );
    final destructiveBg = Color.alphaBlend(
      cs.error.withValues(alpha: isDark ? 0.28 : 0.14),
      cs.surface,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          fixedSize: const Size(38, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: destructive ? destructiveBg : normalBg,
          foregroundColor: destructive ? cs.error : cs.primary,
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
