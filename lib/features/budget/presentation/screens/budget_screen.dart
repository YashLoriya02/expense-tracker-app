// budget_screen.dart
import 'package:expense_tracker_ai/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(activeBudgetsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudget(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Budget'),
      ),
      body: budgets.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('No budgets yet',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Set a budget to track your spending',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _BudgetCard(budget: list[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }

  void _showAddBudget(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String period = 'monthly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New Budget',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Budget name')),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Amount (₹)', prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (ctx, setState) => SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'weekly', label: Text('Weekly')),
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ButtonSegment(value: 'yearly', label: Text('Yearly')),
                ],
                selected: {period},
                onSelectionChanged: (s) => setState(() => period = s.first),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                final db = ref.read(databaseProvider);
                await db.into(db.budgets).insert(BudgetsCompanion.insert(
                      name: nameCtrl.text,
                      amount: double.parse(amountCtrl.text),
                      period: period,
                      startDate: DateTime.now(),
                    ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create Budget'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  final Budget budget;
  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return FutureBuilder<double>(
      future: db.getBudgetSpent(budget),
      builder: (ctx, snap) {
        final spent = snap.data ?? 0;
        final pct = (spent / budget.amount).clamp(0.0, 1.0);
        final isOver = spent > budget.amount;
        final color = isOver
            ? Colors.red
            : pct > 0.8
                ? Colors.orange
                : Colors.green;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(budget.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      budget.period[0].toUpperCase() +
                          budget.period.substring(1),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmt.format(spent),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w600)),
                    Text('of ${fmt.format(budget.amount)}',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: cs.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                if (isOver) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Over by ${fmt.format(spent - budget.amount)}',
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    '${fmt.format(budget.amount - spent)} remaining (${(pct * 100).toStringAsFixed(0)}% used)',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
