import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (path: '/', label: 'Home', icon: Icons.home_rounded),
    (
      path: '/transactions',
      label: 'Transactions',
      icon: Icons.receipt_long_rounded
    ),
    (path: '/budget', label: 'Budget', icon: Icons.pie_chart_rounded),
    (
      path: '/accounts',
      label: 'Accounts',
      icon: Icons.account_balance_wallet_rounded
    ),
    (path: '/insights', label: 'Insights', icon: Icons.insights_rounded),
  ];

  int _tabIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final idx = _tabs.indexWhere((t) => t.path == loc);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _tabIndex(context);

    return Scaffold(
      body: child,
      floatingActionButton: currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/add-transaction'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
              elevation: 2,
            ).animate().scale(delay: 300.ms, duration: 200.ms)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}
