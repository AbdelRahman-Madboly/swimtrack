// MainScreen - app shell with bottom navigation bar and 3 tabs.
// Uses IndexedStack to keep all tabs alive when switching.

import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'settings_tab.dart';

/// Main screen - holds Home, History, and Settings tabs.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _switchToSettings() {
    setState(() => _currentIndex = 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all tabs alive - no rebuild when switching
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeTab(),
          HistoryTab(onGoToSettings: _switchToSettings),
          const SettingsTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: SwimTrackColors.card,
        border: Border(
          top: BorderSide(color: SwimTrackColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.pool_outlined,
                activeIcon: Icons.pool,
                label: 'Home',
                isActive: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'History',
                isActive: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                isActive: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single bottom nav bar item with icon + label.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final bool     isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? SwimTrackColors.primary : SwimTrackColors.textHint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: SwimTrackTextStyles.tiny(color: color),
            ),
          ],
        ),
      ),
    );
  }
}