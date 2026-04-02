import 'package:flutter/material.dart';

class AtelierSectionIntro extends StatelessWidget {
  const AtelierSectionIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.accent,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = accent ?? cs.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 0.96,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class AtelierStatPill extends StatelessWidget {
  const AtelierStatPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AtelierHeroCard extends StatelessWidget {
  const AtelierHeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    this.pills = const [],
    this.trailing,
    this.bottom,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final List<Widget> pills;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 0.96,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, children: pills),
          ],
          if (bottom != null) ...[const SizedBox(height: 18), bottom!],
        ],
      ),
    );
  }
}

class AtelierEmptyState extends StatelessWidget {
  const AtelierEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.62),
          cs.surface,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 40, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AtelierSurfaceCard extends StatelessWidget {
  const AtelierSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.34 : 0.68),
          cs.surface,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.03),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AtelierTagChip extends StatelessWidget {
  const AtelierTagChip({
    super.key,
    required this.label,
    this.icon,
    required this.foreground,
    this.background,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  });

  final String label;
  final IconData? icon;
  final Color foreground;
  final Color? background;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class AtelierIconBadge extends StatelessWidget {
  const AtelierIconBadge({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 44,
  });

  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: accent, size: size * 0.48),
    );
  }
}

class AtelierMetricTile extends StatelessWidget {
  const AtelierMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.accent,
    this.padding = const EdgeInsets.all(16),
    this.center = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? accent;
  final EdgeInsets padding;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final highlight = accent ?? cs.primary;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.32 : 0.68,
          ),
          cs.surface,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            textAlign: center ? TextAlign.center : null,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: center ? TextAlign.center : null,
            style: TextStyle(
              color: accent == null ? cs.onSurface : highlight,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 0.96,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: center ? TextAlign.center : null,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AtelierFieldLabel extends StatelessWidget {
  const AtelierFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class AtelierSheetFrame extends StatelessWidget {
  const AtelierSheetFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, media.viewInsets.bottom + 20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.24 : 0.08,
              ),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THE ORGANIC ATELIER',
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (subtitle != null &&
                              subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onClose != null) ...[
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AtelierDialogFrame extends StatelessWidget {
  const AtelierDialogFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AtelierSurfaceCard(
        radius: 32,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THE ORGANIC ATELIER',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
