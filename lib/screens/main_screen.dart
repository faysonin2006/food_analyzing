import 'dart:ui';

import 'package:flutter/material.dart';
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
  int _activeSlot = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final slots = [
      _NavSlot(
        label: isRu ? 'Рецепты' : 'Recipes',
        icon: Icons.restaurant_menu_outlined,
        selectedIcon: Icons.restaurant_menu_rounded,
        targetIndex: 0,
      ),
      _NavSlot(
        label: isRu ? 'План' : 'Organizer',
        icon: Icons.dashboard_customize_outlined,
        selectedIcon: Icons.dashboard_customize_rounded,
        targetIndex: 1,
      ),
      _NavSlot(
        label: isRu ? 'Анализ' : 'Analyze',
        icon: Icons.camera_alt_outlined,
        selectedIcon: Icons.camera_alt_rounded,
        targetIndex: 2,
      ),
      _NavSlot(
        label: isRu ? 'Профиль' : 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        targetIndex: 3,
      ),
    ];
    final activeColor = cs.primary;
    final idleColor = cs.onSurfaceVariant.withValues(alpha: isDark ? 0.9 : 0.8);
    final navBackground = Color.alphaBlend(
      cs.surface.withValues(alpha: isDark ? 0.82 : 0.88),
      theme.scaffoldBackgroundColor,
    );
    final navBorder = cs.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.18);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RecipeSearchScreen(
            onOpenOrganizerTap: () {
              setState(() {
                _currentIndex = 1;
                _activeSlot = 1;
              });
            },
          ),
          const OrganizerHubScreen(),
          const AnalyzeScreen(),
          ProfileScreen(isActive: _currentIndex == 3),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 82,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: navBackground,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: navBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(slots.length, (slotIndex) {
                  final slot = slots[slotIndex];
                  return _IconNavItem(
                    selected: _activeSlot == slotIndex,
                    label: slot.label,
                    icon: slot.icon,
                    selectedIcon: slot.selectedIcon,
                    activeColor: activeColor,
                    idleColor: idleColor,
                    onTap: () {
                      setState(() {
                        _activeSlot = slotIndex;
                        _currentIndex = slot.targetIndex;
                      });
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconNavItem extends StatelessWidget {
  const _IconNavItem({
    required this.selected,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.activeColor,
    required this.idleColor,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color activeColor;
  final Color idleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: selected ? theme.colorScheme.onPrimary : idleColor,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 17 : 12,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? activeColor : Colors.transparent,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 21,
              color: selected ? theme.colorScheme.onPrimary : idleColor,
            ),
            const SizedBox(height: 3),
            Text(label.toUpperCase(), style: labelStyle),
          ],
        ),
      ),
    );
  }
}

class _NavSlot {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int targetIndex;

  const _NavSlot({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.targetIndex,
  });
}
