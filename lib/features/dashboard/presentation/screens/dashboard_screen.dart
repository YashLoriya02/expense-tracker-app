import 'package:expense_tracker_ai/features/dashboard/presentation/widgets/budget_overview_strip.dart';
import 'package:expense_tracker_ai/features/dashboard/presentation/widgets/recent_transactions_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/dashboard_providers.dart';
import '../widgets/greeting_header.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final month = DateTime(today.year, today.month, 1);
    final monthTotals = ref.watch(monthlyTotalsProvider(month));
    final recentTxns = ref.watch(recentTransactionsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            pinned: false,
            title: const GreetingHeader(),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Scan Receipt',
                onPressed: () => context.push('/scanner'),
              ),
              // IconButton(
              //   icon: const Icon(Icons.notifications_outlined),
              //   onPressed: () {},
              // ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                monthTotals
                    .when(
                      data: (totals) => _BalanceCard(totals: totals),
                      loading: () => const _BalanceCardSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                    )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.1),

                const SizedBox(height: 16),

                monthTotals.when(
                  data: (totals) => Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          label: 'Income',
                          amount: totals['income'] ?? 0,
                          icon: Icons.arrow_downward_rounded,
                          color: Colors.green,
                          isIncome: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SummaryCard(
                          label: 'Expenses',
                          amount: totals['expense'] ?? 0,
                          icon: Icons.arrow_upward_rounded,
                          color: Colors.red,
                          isIncome: false,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),
                  loading: () => const Row(
                    children: [
                      Expanded(child: _SmallCardSkeleton()),
                      SizedBox(width: 12),
                      Expanded(child: _SmallCardSkeleton()),
                    ],
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 20),

                // ─── Quick actions ─────────────────────────────────────────────
                _QuickActions(),

                const SizedBox(height: 20),

                // ─── Budget strip ──────────────────────────────────────────────
                const Text('Budgets',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const BudgetOverviewStrip(),

                const SizedBox(height: 20),

                // ─── Recent transactions ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                recentTxns.when(
                  data: (txns) => RecentTransactionsList(
                      transactions: txns.take(10).toList()),
                  loading: () => const _TransactionListSkeleton(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Balance Card ──────────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final Map<String, double> totals;
  const _BalanceCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final savings = totals['savings'] ?? 0;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net Savings this month',
            style:
                TextStyle(color: cs.onPrimary.withOpacity(0.8), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(savings),
            style: TextStyle(
              color: cs.onPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(
                label: 'Saved',
                value: savings > 0
                    ? '${((savings / (totals['income'] ?? 1)) * 100).toStringAsFixed(0)}%'
                    : '0%',
                icon: Icons.savings_outlined,
                color: cs.onPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 16),
        const SizedBox(width: 4),
        Text('$label: ',
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Quick Actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        label: 'Add Expense',
        icon: Icons.remove_circle_outline,
        color: Colors.red,
        type: 'expense'
      ),
      (
        label: 'Add Income',
        icon: Icons.add_circle_outline,
        color: Colors.green,
        type: 'income'
      ),
      (
        label: 'Add Transfer',
        icon: Icons.swap_horiz_rounded,
        color: Colors.blue,
        type: 'transfer'
      ),
      (
        label: 'Scan Document',
        icon: Icons.document_scanner_rounded,
        color: Colors.orange,
        type: 'scan'
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map(
            (a) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _QuickActionBtn(
                  label: a.label,
                  icon: a.icon,
                  color: a.color,
                  onTap: () {
                    if (a.type == 'scan') {
                      context.push('/scanner');
                    } else {
                      context.push('/add-transaction', extra: {'type': a.type});
                    }
                  },
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              textAlign: TextAlign.center,
              label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeletons ─────────────────────────────────────────────────────────────────
class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _SmallCardSkeleton extends StatelessWidget {
  const _SmallCardSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _TransactionListSkeleton extends StatelessWidget {
  const _TransactionListSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        5,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
