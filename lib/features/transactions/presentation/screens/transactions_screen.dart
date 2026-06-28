// Transactions Screen
// ignore_for_file: deprecated_member_use

import 'package:expense_tracker_ai/features/transactions/domain/transaction_range_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';

enum HistoryPreset {
  today,
  week,
  month,
  year,
  custom,
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  HistoryPreset _preset = HistoryPreset.month;

  String _type = 'all';
  String _search = '';

  late DateTime _start;
  late DateTime _end;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = TransactionRangeFilter(
      start: _start,
      end: _end,
      type: _type,
      query: _search,
    );

    final txns = ref.watch(transactionsByRangeProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: Column(
        children: [
          _HeaderSection(
            preset: _preset,
            start: _start,
            end: _end,
            onPresetSelected: _setPreset,
            onPreviousMonth: _goPreviousMonth,
            onNextMonth: _goNextMonth,
            onPickCustomRange: _pickCustomRange,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search transactions',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          SizedBox(height: 3),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: ['all', 'expense', 'income', 'transfer'].map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f[0].toUpperCase() + f.substring(1)),
                    selected: _type == f,
                    onSelected: (_) => setState(() => _type = f),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: txns.when(
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyTransactionsState(
                    preset: _preset,
                    start: _start,
                    end: _end,
                  );
                }

                final income = list
                    .where((t) => t.type == 'income')
                    .fold<double>(0, (sum, t) => sum + t.amount);

                final expense = list
                    .where((t) => t.type == 'expense')
                    .fold<double>(0, (sum, t) => sum + t.amount);

                final grouped = _groupByDate(list);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    _SummaryCards(
                      income: income,
                      expense: expense,
                      net: income - expense,
                    ),
                    const SizedBox(height: 16),
                    ...grouped.entries.map((entry) {
                      final date = DateTime.parse(entry.key);
                      final transactions = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 8,
                              bottom: 8,
                              left: 4,
                            ),
                            child: Text(
                              _formatGroupDate(date),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                            ),
                          ),
                          ...transactions.map(
                            (txn) => _TransactionTile(
                              txn: txn,
                              onTap: () =>
                                  context.push('/transaction/${txn.id}'),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _setPreset(HistoryPreset preset) {
    final now = DateTime.now();

    setState(() {
      _preset = preset;

      switch (preset) {
        case HistoryPreset.today:
          _start = DateTime(now.year, now.month, now.day);
          _end = DateTime(now.year, now.month, now.day);
          break;

        case HistoryPreset.week:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          _start = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          _end = DateTime(now.year, now.month, now.day);
          break;

        case HistoryPreset.month:
          _start = DateTime(now.year, now.month, 1);
          _end = DateTime(now.year, now.month + 1, 0);
          break;

        case HistoryPreset.year:
          _start = DateTime(now.year, 1, 1);
          _end = DateTime(now.year, 12, 31);
          break;

        case HistoryPreset.custom:
          break;
      }
    });

    if (preset == HistoryPreset.custom) {
      _pickCustomRange();
    }
  }

  void _goPreviousMonth() {
    final previous = DateTime(_start.year, _start.month - 1, 1);

    setState(() {
      _preset = HistoryPreset.month;
      _start = DateTime(previous.year, previous.month, 1);
      _end = DateTime(previous.year, previous.month + 1, 0);
    });
  }

  void _goNextMonth() {
    final next = DateTime(_start.year, _start.month + 1, 1);

    setState(() {
      _preset = HistoryPreset.month;
      _start = DateTime(next.year, next.month, 1);
      _end = DateTime(next.year, next.month + 1, 0);
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );

    if (picked == null) return;

    setState(() {
      _preset = HistoryPreset.custom;
      _start = picked.start;
      _end = picked.end;
    });
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> txns) {
    final grouped = <String, List<Transaction>>{};

    for (final txn in txns) {
      final key = DateFormat('yyyy-MM-dd').format(txn.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(txn);
    }

    return grouped;
  }

  String _formatGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final current = DateTime(date.year, date.month, date.day);

    if (current == today) return 'Today';
    if (current == yesterday) return 'Yesterday';

    return DateFormat('d MMMM yyyy').format(date);
  }
}

class _HeaderSection extends StatelessWidget {
  final HistoryPreset preset;
  final DateTime start;
  final DateTime end;
  final ValueChanged<HistoryPreset> onPresetSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickCustomRange;

  const _HeaderSection({
    required this.preset,
    required this.start,
    required this.end,
    required this.onPresetSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickCustomRange,
  });

  @override
  Widget build(BuildContext context) {
    final rangeText = _rangeText();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rangeText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _PresetChip(
                  label: 'Today',
                  selected: preset == HistoryPreset.today,
                  onTap: () => onPresetSelected(HistoryPreset.today),
                ),
                _PresetChip(
                  label: 'Week',
                  selected: preset == HistoryPreset.week,
                  onTap: () => onPresetSelected(HistoryPreset.week),
                ),
                _PresetChip(
                  label: 'Month',
                  selected: preset == HistoryPreset.month,
                  onTap: () => onPresetSelected(HistoryPreset.month),
                ),
                _PresetChip(
                  label: 'Year',
                  selected: preset == HistoryPreset.year,
                  onTap: () => onPresetSelected(HistoryPreset.year),
                ),
                _PresetChip(
                  label: 'Custom',
                  selected: preset == HistoryPreset.custom,
                  onTap: onPickCustomRange,
                ),
              ],
            ),
          ),
          if (preset == HistoryPreset.month) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: onPreviousMonth,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat('MMMM yyyy').format(start),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: onNextMonth,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _rangeText() {
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    if (sameDay) {
      return DateFormat('d MMMM yyyy').format(start);
    }

    return '${DateFormat('d MMM yyyy').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final double income;
  final double expense;
  final double net;

  const _SummaryCards({
    required this.income,
    required this.expense,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Income',
            amount: income,
            icon: Icons.south_west_rounded,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Expense',
            amount: expense,
            icon: Icons.north_east_rounded,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Net',
            amount: net,
            icon: Icons.account_balance_wallet_rounded,
            color: net >= 0 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmt.format(amount),
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final Transaction txn;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.txn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final isExpense = txn.type == 'expense';
    final isIncome = txn.type == 'income';

    final color = isExpense
        ? Colors.red
        : isIncome
            ? Colors.green
            : Theme.of(context).colorScheme.primary;

    final icon = isExpense
        ? Icons.arrow_upward_rounded
        : isIncome
            ? Icons.arrow_downward_rounded
            : Icons.sync_alt_rounded;

    final prefix = isExpense
        ? '-'
        : isIncome
            ? '+'
            : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          txn.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(DateFormat('d MMM, h:mm a').format(txn.date)),
        trailing: Text(
          '$prefix${fmt.format(txn.amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  final HistoryPreset preset;
  final DateTime start;
  final DateTime end;

  const _EmptyTransactionsState({
    required this.preset,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    final text = switch (preset) {
      HistoryPreset.today => 'No transactions today',
      HistoryPreset.week => 'No transactions this week',
      HistoryPreset.month =>
        'No transactions in ${DateFormat('MMMM yyyy').format(start)}',
      HistoryPreset.year => 'No transactions in ${start.year}',
      HistoryPreset.custom => 'No transactions in selected range',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧾', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing the date range or clearing filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
