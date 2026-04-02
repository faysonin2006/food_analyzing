import 'dart:ui';

import 'package:flutter/material.dart';

import 'network_monitor.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final shellColor = Color.alphaBlend(
      cs.surface.withValues(alpha: isDark ? 0.72 : 0.82),
      theme.scaffoldBackgroundColor,
    );
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.34 : 0.18,
    );

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: shellColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.22 : 0.04,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THE ORGANIC ATELIER',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedBuilder(
                      animation: NetworkMonitor.instance,
                      builder: (context, _) {
                        if (NetworkMonitor.instance.isOnline) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              cs.error.withValues(alpha: isDark ? 0.24 : 0.12),
                              cs.surface,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: cs.error.withValues(alpha: 0.38),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 14,
                                color: cs.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'OFFLINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: cs.error,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
            borderRadius: BorderRadius.circular(999),
          ),
          backgroundColor: destructive ? destructiveBg : normalBg,
          foregroundColor: destructive ? cs.error : cs.primary,
          side: BorderSide(
            color: (destructive ? cs.error : cs.primary).withValues(
              alpha: isDark ? 0.18 : 0.12,
            ),
          ),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 19),
      ),
    );
  }
}
