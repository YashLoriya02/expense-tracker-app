import 'package:expense_tracker_ai/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final goalsStream = db.select(db.goals).watch();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoal(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
      body: StreamBuilder<List<Goal>>(
        stream: goalsStream,
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final goals = snap.data!;
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No goals yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Set savings goals and track your progress',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: goals.length,
            itemBuilder: (ctx, i) => _GoalCard(goal: goals[i]),
          );
        },
      ),
    );
  }

  void _showAddGoal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    String emoji = '🎯';

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
            const Text('New Goal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Goal name (e.g. Vacation to Goa)')),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Target Amount (₹)', prefixText: '₹ '),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || targetCtrl.text.isEmpty) return;
                final db = ref.read(databaseProvider);
                await db.into(db.goals).insert(GoalsCompanion.insert(
                      name: nameCtrl.text,
                      icon: emoji,
                      color: '#4CAF50',
                      targetAmount: double.parse(targetCtrl.text),
                    ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final pct = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(goal.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Target: ${fmt.format(goal.targetAmount)}',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.6),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: cs.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(Colors.green),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fmt.format(goal.currentAmount),
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600)),
                Text(
                    '${fmt.format(goal.targetAmount - goal.currentAmount)} to go',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.6), fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
