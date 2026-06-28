// ignore_for_file: deprecated_member_use

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});


  Future<void> _deleteTransaction(AppDatabase db) async {
    final txn = await (db.select(db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .getSingleOrNull();
    if (txn == null) return;

    await db.transaction(() async {
      await (db.update(db.transactions)..where((t) => t.id.equals(transactionId)))
          .write(const TransactionsCompanion(isDeleted: Value(true)));

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(txn.accountId)))
          .getSingleOrNull();

      if (account == null) return;

      final delta = switch (txn.type) {
        'income' => -txn.amount,
        'expense' => txn.amount,
        _ => 0.0,
      };

      if (delta != 0) {
        await (db.update(db.accounts)..where((a) => a.id.equals(txn.accountId)))
            .write(AccountsCompanion(balance: Value(account.balance + delta)));
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          // IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete transaction?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) {
                await _deleteTransaction(db);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: (db.select(db.transactions)
              ..where((t) => t.id.equals(transactionId)))
            .getSingleOrNull(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final txn = snap.data;
          if (txn == null) {
            return const Center(child: Text('Transaction not found'));
          }

          final isExpense = txn.type == 'expense';
          final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: (isExpense ? Colors.red : Colors.green)
                          .withOpacity(0.1),
                      child: Icon(
                        isExpense
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isExpense ? Colors.red : Colors.green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(fmt.format(txn.amount),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: isExpense ? Colors.red : Colors.green,
                        )),
                    const SizedBox(height: 10),
                    Text(txn.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(txn.date),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (txn.note != null && txn.note!.isNotEmpty) ...[
                const Text(
                  'Note',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(txn.note!),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}
