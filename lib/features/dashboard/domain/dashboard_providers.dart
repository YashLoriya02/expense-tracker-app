import 'package:expense_tracker_ai/features/transactions/domain/transaction_range_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';

// ─── Database provider ─────────────────────────────────────────────────────────
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final monthlyTotalsProvider =
    StreamProvider.family<Map<String, double>, DateTime>(
  (ref, month) {
    return ref.watch(databaseProvider).watchMonthlyTotals(month);
  },
);

// ─── Recent transactions ────────────────────────────────────────────────────────
final recentTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(databaseProvider).watchRecentTransactions(),
);

// ─── Transactions by month ─────────────────────────────────────────────────────
final transactionsByMonthProvider =
    StreamProvider.family<List<Transaction>, DateTime>(
  (ref, month) => ref.watch(databaseProvider).watchTransactionsByMonth(month),
);

// ─── Category breakdown ────────────────────────────────────────────────────────
final categoryBreakdownProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>(
  (ref, month) => ref.watch(databaseProvider).getCategoryBreakdown(month),
);

// ─── Active budgets ────────────────────────────────────────────────────────────
final activeBudgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(databaseProvider).watchActiveBudgets(),
);

// ─── All accounts ─────────────────────────────────────────────────────────────
final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref
      .watch(databaseProvider)
      .select(ref.watch(databaseProvider).accounts)
      .watch(),
);

// ─── All categories ────────────────────────────────────────────────────────────
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref
      .watch(databaseProvider)
      .select(ref.watch(databaseProvider).categories)
      .watch(),
);

final transactionsByRangeProvider =
    StreamProvider.family<List<Transaction>, TransactionRangeFilter>(
  (ref, filter) {
    return ref.watch(databaseProvider).watchTransactionsByRange(
          filter.normalizedStart,
          filter.normalizedEnd,
          type: filter.type,
          search: filter.query,
        );
  },
);
