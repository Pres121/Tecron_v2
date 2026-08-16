import "package:flutter/material.dart";

import "../services/app_state.dart";
import "../theme/app_theme.dart";
import "../widgets/tecron_bottom_nav.dart";
import "connection_screen.dart";
import "history_screen.dart";
import "home_tab.dart";
import "settings_screen.dart";

const _navItems = [
  NavItem(icon: Icons.bolt_outlined, activeIcon: Icons.bolt_rounded, label: "Home"),
  NavItem(icon: Icons.bluetooth_outlined, activeIcon: Icons.bluetooth_rounded, label: "Connection"),
  NavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: "History"),
  NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: "Settings"),
];

/// Post-auth app shell: owns the bottom nav and the PageView that all four
/// tabs live in. Tapping a nav item animates the PageView to that page
/// (slide transition); swiping between pages works too and keeps the nav
/// bar's sliding pill indicator in sync.
class DashboardScreen extends StatefulWidget {
  final AppState appState;

  const DashboardScreen({super.key, required this.appState});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Invisible header with logo + notifications
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  // Logo (text-based to keep asset-free)
                  Row(
                    children: const [
                      Icon(Icons.bolt_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text("Tecron", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const Spacer(),
                  // Notification icon
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary),
                    tooltip: "Notifications",
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  const HomeTab(),
                  const ConnectionScreen(),
                  const HistoryScreen(),
                  SettingsScreen(appState: widget.appState),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: TecronBottomNav(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: _onNavTap,
      ),
    );
  }
}
