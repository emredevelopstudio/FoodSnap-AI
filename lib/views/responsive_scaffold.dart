import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'calculator_view.dart';
import 'dashboard_view.dart';
import 'fasting_view.dart';
import 'meals_history_view.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_banner_ad.dart';

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class ResponsiveScaffold extends ConsumerWidget {
  const ResponsiveScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  extended: constraints.maxWidth >= 1024,
                  minExtendedWidth: 200,
                  backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
                  indicatorColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD9E2EC),
                  onDestinationSelected: (index) {
                    ref.read(bottomNavIndexProvider.notifier).state = index;
                  },
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: Color(0xFF64748B),
                            ),
                            children: [
                              TextSpan(text: 'FoodSnap '),
                              TextSpan(
                                text: 'AI',
                                style: TextStyle(
                                  color: Color(0xFF1E88E5),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.grid_view_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      selectedIcon: Icon(Icons.grid_view_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      label: Text(context.l10n.dashboard),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.restaurant_menu_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      selectedIcon: Icon(Icons.restaurant_menu, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      label: Text(context.l10n.meals),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.hourglass_bottom_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      selectedIcon: Icon(Icons.hourglass_bottom_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      label: const Text('Fasten'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calculate_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      selectedIcon: Icon(Icons.calculate, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      label: Text(context.l10n.calculator),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: _buildBody(currentIndex),
                ),
              ],
            ),
          );
        } else {
          return Scaffold(
            body: _buildBody(currentIndex),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppBannerAd(),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                        width: 1,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: currentIndex,
                    backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
                    indicatorColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD9E2EC),
                    elevation: 0,
                    height: 68,
                    onDestinationSelected: (index) {
                      ref.read(bottomNavIndexProvider.notifier).state = index;
                    },
                    destinations: [
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        selectedIcon: Icon(Icons.grid_view_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        label: context.l10n.dashboard,
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.restaurant_menu_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        selectedIcon: Icon(Icons.restaurant_menu, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        label: context.l10n.meals,
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.hourglass_bottom_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        selectedIcon: Icon(Icons.hourglass_bottom_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        label: 'Fasten',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calculate_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        selectedIcon: Icon(Icons.calculate, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        label: context.l10n.calculator,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildBody(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return const DashboardView();
      case 1:
        return const MealsHistoryView();
      case 2:
        return const FastingView();
      case 3:
        return const CalculatorView();
      default:
        return const DashboardView();
    }
  }
}
