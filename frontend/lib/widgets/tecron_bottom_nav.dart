import "package:flutter/material.dart";

import "../theme/app_theme.dart";

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({required this.icon, required this.activeIcon, required this.label});
}

/// Floating bottom nav bar with a pill that slides smoothly between the
/// selected item, plus a subtle icon scale/crossfade on selection change.
class TecronBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<NavItem> items;
  final ValueChanged<int> onTap;

  const TecronBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: itemWidth * currentIndex,
                    width: itemWidth,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(items.length, (index) {
                      final selected = index == currentIndex;
                      final item = items[index];
                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onTap(index),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? AppColors.primaryDark : AppColors.textFaint,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedScale(
                                  duration: const Duration(milliseconds: 220),
                                  scale: selected ? 1.08 : 1.0,
                                  child: Icon(
                                    selected ? item.activeIcon : item.icon,
                                    size: 22,
                                    color: selected ? AppColors.primary : AppColors.textFaint,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(item.label),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
