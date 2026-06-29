import 'package:expense_tracker_ai/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:expense_tracker_ai/features/budget/presentation/screens/budget_screen.dart';
import 'package:expense_tracker_ai/features/goals/presentation/screens/goals_screen.dart';
import 'package:expense_tracker_ai/features/insights/presentation/screens/insights_screen.dart';
import 'package:expense_tracker_ai/features/pending-notifications/presentation/pending_notifications_screen.dart';
import 'package:expense_tracker_ai/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:expense_tracker_ai/features/transactions/presentation/screens/transaction_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../shared/widgets/main_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(
            path: '/transactions',
            builder: (_, __) => const TransactionsScreen()),
        GoRoute(path: '/budget', builder: (_, __) => const BudgetScreen()),
        GoRoute(path: '/accounts', builder: (_, __) => const AccountsScreen()),
        GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
      ],
    ),
    // GoRoute(
    //   path: '/add-transaction',
    //   builder: (context, state) {
    //     final extra = state.extra as Map<String, dynamic>?;
    //     return AddTransactionScreen(
    //       initialType: extra?['type'] ?? 'expense',
    //       prefilled: extra?['prefilled'],
    //     );
    //   },
    // ),

    GoRoute(
      path: '/add-transaction',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;

        return AddTransactionScreen(
          initialType: extra?['type'] ?? 'expense',
          prefilled: extra?['prefilled'],
          pendingNotificationId: extra?['pendingNotificationId'],
        );
      },
    ),

    GoRoute(
      path: '/transaction/:id',
      builder: (context, state) => TransactionDetailScreen(
        transactionId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/goals', builder: (_, __) => const GoalsScreen()),
    GoRoute(path: '/scanner', builder: (_, __) => const ScannerScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(
      path: '/pending-notifications',
      builder: (_, __) => const PendingNotificationsScreen(),
    ),
  ],
);
