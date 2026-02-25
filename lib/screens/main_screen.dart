import 'dart:ui';

import 'package:flutter/material.dart';
import 'analyze_screen.dart';
import 'liked_recipes_screen.dart';
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

  static const List<_NavSlot> _slots = [
    _NavSlot(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      targetIndex: 0,
    ),
    _NavSlot(
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
      targetIndex: 1,
    ),
    _NavSlot(
      icon: Icons.camera_alt_outlined,
      selectedIcon: Icons.camera_alt_rounded,
      targetIndex: 2,
    ),
    _NavSlot(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      targetIndex: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = cs.primary;
    final idleColor = cs.onSurfaceVariant.withValues(alpha: isDark ? 0.9 : 0.8);
    final navBackground = Color.alphaBlend(
      cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.78 : 0.9),
      cs.surface,
    );
    final navBorder = cs.outlineVariant.withValues(alpha: isDark ? 0.6 : 0.5);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RecipeSearchScreen(
            onOpenProfileTap: () {
              setState(() {
                _currentIndex = 3;
                _activeSlot = 3;
              });
            },
          ),
          const LikedRecipesScreen(),
          const AnalyzeScreen(),
          ProfileScreen(isActive: _currentIndex == 3),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              height: 74,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: navBackground,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: navBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_slots.length, (slotIndex) {
                  final slot = _slots[slotIndex];
                  return _IconNavItem(
                    selected: _activeSlot == slotIndex,
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
    required this.icon,
    required this.selectedIcon,
    required this.activeColor,
    required this.idleColor,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final Color activeColor;
  final Color idleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Icon(
          selected ? selectedIcon : icon,
          size: 26,
          color: selected ? activeColor : idleColor,
        ),
      ),
    );
  }
}

class _NavSlot {
  final IconData icon;
  final IconData selectedIcon;
  final int targetIndex;

  const _NavSlot({
    required this.icon,
    required this.selectedIcon,
    required this.targetIndex,
  });
}
