import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'analytics_screen.dart';
import 'analyze_screen.dart';
import 'organizer_hub_screen.dart';
import 'profile_screen.dart';
import 'recipe_search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _switchTo(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    final sideSlots = <_BottomNavSlot>[
      _BottomNavSlot(
        label: isRu ? 'Рецепты' : 'Recipes',
        icon: Icons.restaurant_menu_outlined,
        selectedIcon: Icons.restaurant_menu_rounded,
        targetIndex: 0,
      ),
      _BottomNavSlot(
        label: isRu ? 'План' : 'Plan',
        icon: Icons.dashboard_customize_outlined,
        selectedIcon: Icons.dashboard_customize_rounded,
        targetIndex: 1,
      ),
      _BottomNavSlot(
        label: isRu ? 'Аналитика' : 'Analytics',
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        targetIndex: 3,
      ),
      _BottomNavSlot(
        label: isRu ? 'Профиль' : 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        targetIndex: 4,
      ),
    ];

    final navShellColor = Color.alphaBlend(
      cs.surface.withValues(alpha: isDark ? 0.9 : 0.96),
      theme.scaffoldBackgroundColor,
    );
    final navBorderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.28 : 0.18,
    );
    final pillIdleColor = Color.alphaBlend(
      AppTheme.atelierGreen.withValues(alpha: isDark ? 0.18 : 0.1),
      cs.surface,
    );
    final centerButtonColor = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.22 : 0.1),
      cs.surfaceContainerHighest,
    );

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RecipeSearchScreen(
            isActive: _currentIndex == 0,
            onOpenOrganizerTap: () => _switchTo(1),
          ),
          OrganizerHubScreen(isActive: _currentIndex == 1),
          AnalyzeScreen(isActive: _currentIndex == 2),
          AnalyticsScreen(isActive: _currentIndex == 3),
          ProfileScreen(isActive: _currentIndex == 4),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: SizedBox(
          height: 86,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: navShellColor,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: navBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.24 : 0.05,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomPillNavItem(
                        label: sideSlots[0].label,
                        icon: sideSlots[0].icon,
                        selectedIcon: sideSlots[0].selectedIcon,
                        selected: _currentIndex == sideSlots[0].targetIndex,
                        onTap: () => _switchTo(sideSlots[0].targetIndex),
                        activeColor: AppTheme.atelierGreen,
                        idleColor: pillIdleColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BottomPillNavItem(
                        label: sideSlots[1].label,
                        icon: sideSlots[1].icon,
                        selectedIcon: sideSlots[1].selectedIcon,
                        selected: _currentIndex == sideSlots[1].targetIndex,
                        onTap: () => _switchTo(sideSlots[1].targetIndex),
                        activeColor: AppTheme.atelierGreen,
                        idleColor: pillIdleColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _BottomCenterCameraButton(
                      selected: _currentIndex == 2,
                      onTap: () => _switchTo(2),
                      color: centerButtonColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BottomPillNavItem(
                        label: sideSlots[2].label,
                        icon: sideSlots[2].icon,
                        selectedIcon: sideSlots[2].selectedIcon,
                        selected: _currentIndex == sideSlots[2].targetIndex,
                        onTap: () => _switchTo(sideSlots[2].targetIndex),
                        activeColor: AppTheme.atelierGreen,
                        idleColor: pillIdleColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BottomPillNavItem(
                        label: sideSlots[3].label,
                        icon: sideSlots[3].icon,
                        selectedIcon: sideSlots[3].selectedIcon,
                        selected: _currentIndex == sideSlots[3].targetIndex,
                        onTap: () => _switchTo(sideSlots[3].targetIndex),
                        activeColor: AppTheme.atelierGreen,
                        idleColor: pillIdleColor,
                      ),
                    ),
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

class _BottomPillNavItem extends StatelessWidget {
  const _BottomPillNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    required this.activeColor,
    required this.idleColor,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedBackground = Color.alphaBlend(
      activeColor.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.22 : 0.14,
      ),
      cs.surface,
    );
    final idleIconColor = cs.onSurfaceVariant.withValues(alpha: 0.78);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          selected: selected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected ? selectedBackground : idleColor,
              border: Border.all(
                color: selected
                    ? activeColor.withValues(alpha: 0.42)
                    : activeColor.withValues(alpha: 0.14),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: selected ? activeColor : idleIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomCenterCameraButton extends StatelessWidget {
  const _BottomCenterCameraButton({
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final iconColor = selected
        ? AppTheme.atelierGreen
        : cs.onSurfaceVariant.withValues(alpha: 0.84);
    final selectedBackground = Color.alphaBlend(
      AppTheme.atelierGreen.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
      ),
      color,
    );

    return Tooltip(
      message: Localizations.localeOf(context).languageCode == 'ru'
          ? 'Анализ'
          : 'Analyze',
      child: Semantics(
        label: Localizations.localeOf(context).languageCode == 'ru'
            ? 'Анализ'
            : 'Analyze',
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: selected ? 62 : 58,
            height: selected ? 62 : 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? selectedBackground : color,
              border: Border.all(
                color: selected
                    ? AppTheme.atelierGreen.withValues(alpha: 0.34)
                    : AppTheme.atelierGreen.withValues(alpha: 0.14),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.atelierGreen.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              selected ? Icons.camera_alt_rounded : Icons.camera_alt_outlined,
              color: iconColor,
              size: selected ? 24 : 23,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavSlot {
  const _BottomNavSlot({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.targetIndex,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int targetIndex;
}
