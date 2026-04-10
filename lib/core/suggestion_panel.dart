import 'package:flutter/material.dart';

import 'food_suggestions.dart';

class AtelierSuggestionPanel extends StatelessWidget {
  const AtelierSuggestionPanel({
    super.key,
    required this.suggestions,
    required this.onSelected,
    required this.isRu,
  });

  final List<SuggestionOption> suggestions;
  final ValueChanged<SuggestionOption> onSelected;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.38 : 0.74),
            cs.surface,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: suggestions.length > 4 ? 320 : double.infinity,
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            primary: false,
            shrinkWrap: true,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: cs.outlineVariant.withValues(alpha: 0.28),
            ),
            itemBuilder: (context, index) => _SuggestionTile(
              option: suggestions[index],
              isRu: isRu,
              onTap: () => onSelected(suggestions[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.option,
    required this.isRu,
    required this.onTap,
  });

  final SuggestionOption option;
  final bool isRu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _accentColor(option.source, cs);
    final subtitle = option.secondaryText?.trim() ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(_iconFor(option.source), size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.primaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _sourceLabel(option.source, isRu: isRu),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(SuggestionSource source) {
    return switch (source) {
      SuggestionSource.pantry => Icons.inventory_2_rounded,
      SuggestionSource.shopping => Icons.shopping_basket_rounded,
      SuggestionSource.history => Icons.history_rounded,
      SuggestionSource.keyword => Icons.flash_on_rounded,
      SuggestionSource.catalog => Icons.auto_awesome_rounded,
    };
  }

  Color _accentColor(SuggestionSource source, ColorScheme cs) {
    return switch (source) {
      SuggestionSource.pantry => const Color(0xFF1E8E5A),
      SuggestionSource.shopping => cs.secondary,
      SuggestionSource.history => cs.tertiary,
      SuggestionSource.keyword => const Color(0xFFE27A22),
      SuggestionSource.catalog => cs.primary,
    };
  }

  String _sourceLabel(SuggestionSource source, {required bool isRu}) {
    return switch (source) {
      SuggestionSource.pantry => isRu ? 'Кладовая' : 'Pantry',
      SuggestionSource.shopping => isRu ? 'Список' : 'Shopping',
      SuggestionSource.history => isRu ? 'История' : 'History',
      SuggestionSource.keyword => isRu ? 'Быстро' : 'Quick',
      SuggestionSource.catalog => isRu ? 'Каталог' : 'Catalog',
    };
  }
}
