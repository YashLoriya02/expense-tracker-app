import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';

class BudgetOverviewStrip extends ConsumerWidget {
  const BudgetOverviewStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(activeBudgetsProvider);
    final db = ref.watch(databaseProvider);

    return budgets.when(
      data: (list) {
        if (list.isEmpty) {
          return InkWell(
            onTap: () => context.go('/budget'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Set a budget to track spending')),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length + 1,
            itemBuilder: (ctx, i) {
              if (i == list.length) {
                return _AddBudgetChip(onTap: () => context.go('/budget'));
              }
              final budget = list[i];
              return FutureBuilder<double>(
                future: db.getBudgetSpent(budget),
                builder: (_, snap) {
                  final spent = snap.data ?? 0;
                  final rawPct = budget.amount <= 0 ? 0.0 : spent / budget.amount;
                  final pct = rawPct.clamp(0.0, 1.0);
                  final color = rawPct > 1 ? Colors.red : rawPct > 0.8 ? Colors.orange : Colors.green;
                  final fmt = NumberFormat.compact(locale: 'en_IN');

                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.3)),
                      color: color.withOpacity(0.06),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(budget.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('₹${fmt.format(spent)} / ₹${fmt.format(budget.amount)}', style: TextStyle(fontSize: 11, color: color)),
                        const Spacer(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: color.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${(rawPct * 100).toStringAsFixed(0)}% used', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AddBudgetChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBudgetChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
