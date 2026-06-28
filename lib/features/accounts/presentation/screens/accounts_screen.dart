import 'package:drift/drift.dart' hide Column;
import 'package:expense_tracker_ai/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';
import '../../../../core/theme/app_theme.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _showAddAccountDialog(
      BuildContext context, AppDatabase db) async {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    var type = 'cash';

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Account name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'credit', child: Text('Credit Card')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(
                      value: 'investment', child: Text('Investment')),
                ],
                onChanged: (v) => setDialogState(() => type = v ?? 'cash'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Opening balance',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final name = nameCtrl.text.trim();
    final balance = double.tryParse(balanceCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account name is required')),
        );
      }
      return;
    }

    final existing = await db.select(db.accounts).get();
    final colorByType = {
      'cash': '#4CAF50',
      'bank': '#2196F3',
      'credit': '#9C27B0',
      'upi': '#00BCD4',
      'investment': '#FF9800',
    };
    final iconByType = {
      'cash': 'wallet',
      'bank': 'bank',
      'credit': 'credit_card',
      'upi': 'phone',
      'investment': 'trending_up',
    };

    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            name: name,
            type: type,
            balance: Value(balance),
            color: colorByType[type] ?? '#607D8B',
            icon: iconByType[type] ?? 'wallet',
            isDefault: Value(existing.isEmpty),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    double totalBalance = 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: accounts.when(
        data: (list) {
          totalBalance = list.fold(0, (s, a) => s + a.balance);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Net worth card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Balance',
                        style: TextStyle(
                            color: cs.onPrimaryContainer.withOpacity(0.7))),
                    const SizedBox(height: 8),
                    Text(
                      fmt.format(totalBalance),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Across ${list.length} accounts',
                        style: TextStyle(
                            color: cs.onPrimaryContainer.withOpacity(0.6),
                            fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('My Accounts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...list.map((acc) => _AccountCard(account: acc)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  const _AccountCard({required this.account});

  static const _typeIcons = {
    'cash': Icons.wallet_rounded,
    'bank': Icons.account_balance_rounded,
    'credit': Icons.credit_card_rounded,
    'upi': Icons.phone_android_rounded,
    'investment': Icons.trending_up_rounded,
  };

  // Future<void> _showAddAccountDialog(BuildContext context, AppDatabase db) async {
  //   final nameCtrl = TextEditingController();
  //   final balanceCtrl = TextEditingController(text: '0');
  //   var type = 'cash';

  //   final saved = await showDialog<bool>(
  //     context: context,
  //     builder: (_) => StatefulBuilder(
  //       builder: (context, setDialogState) => AlertDialog(
  //         title: const Text('Add Account'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextField(
  //               controller: nameCtrl,
  //               decoration: const InputDecoration(labelText: 'Account name'),
  //               textCapitalization: TextCapitalization.words,
  //             ),
  //             const SizedBox(height: 12),
  //             DropdownButtonFormField<String>(
  //               value: type,
  //               decoration: const InputDecoration(labelText: 'Type'),
  //               items: const [
  //                 DropdownMenuItem(value: 'cash', child: Text('Cash')),
  //                 DropdownMenuItem(value: 'bank', child: Text('Bank')),
  //                 DropdownMenuItem(value: 'credit', child: Text('Credit Card')),
  //                 DropdownMenuItem(value: 'upi', child: Text('UPI')),
  //                 DropdownMenuItem(value: 'investment', child: Text('Investment')),
  //               ],
  //               onChanged: (v) => setDialogState(() => type = v ?? 'cash'),
  //             ),
  //             const SizedBox(height: 12),
  //             TextField(
  //               controller: balanceCtrl,
  //               keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
  //               decoration: const InputDecoration(
  //                 labelText: 'Opening balance',
  //                 prefixIcon: Icon(Icons.currency_rupee_rounded),
  //               ),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context, false),
  //             child: const Text('Cancel'),
  //           ),
  //           FilledButton(
  //             onPressed: () => Navigator.pop(context, true),
  //             child: const Text('Save'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );

  //   if (saved != true) return;

  //   final name = nameCtrl.text.trim();
  //   final balance = double.tryParse(balanceCtrl.text.trim()) ?? 0;
  //   if (name.isEmpty) {
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Account name is required')),
  //       );
  //     }
  //     return;
  //   }

  //   final existing = await db.select(db.accounts).get();
  //   final colorByType = {
  //     'cash': '#4CAF50',
  //     'bank': '#2196F3',
  //     'credit': '#9C27B0',
  //     'upi': '#00BCD4',
  //     'investment': '#FF9800',
  //   };
  //   final iconByType = {
  //     'cash': 'wallet',
  //     'bank': 'bank',
  //     'credit': 'credit_card',
  //     'upi': 'phone',
  //     'investment': 'trending_up',
  //   };

  //   await db.into(db.accounts).insert(
  //         AccountsCompanion.insert(
  //           name: name,
  //           type: type,
  //           balance: Value(balance),
  //           color: colorByType[type] ?? '#607D8B',
  //           icon: iconByType[type] ?? 'wallet',
  //           isDefault: Value(existing.isEmpty),
  //         ),
  //       );
  // }

  @override
  Widget build(BuildContext context) {
    final color = HexColor.fromHex(account.color);
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          radius: 24,
          child: Icon(
              _typeIcons[account.type] ?? Icons.account_balance_wallet_rounded,
              color: color),
        ),
        title: Row(
          children: [
            Text(account.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (account.isDefault) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Default',
                    style: TextStyle(fontSize: 10, color: Colors.green)),
              ),
            ],
          ],
        ),
        subtitle:
            Text(account.type[0].toUpperCase() + account.type.substring(1)),
        trailing: Text(
          fmt.format(account.balance),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: account.balance >= 0 ? null : Colors.red,
          ),
        ),
      ),
    );
  }
}
