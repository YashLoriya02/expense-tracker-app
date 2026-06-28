import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

class Accounts extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get type => text()(); // cash | bank | credit | upi | investment
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get color => text()();
  TextColumn get icon => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get color => text()();
  TextColumn get type => text()(); // expense | income | transfer
  TextColumn get parentId => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // expense | income | transfer
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get toAccountId => text().nullable()(); // for transfers
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get receiptPath => text().nullable()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringConfig => text().nullable()(); // JSON
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get locationName => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable()(); // null = all categories
  RealColumn get amount => real()();
  TextColumn get period => text()(); // weekly | monthly | yearly
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get alertEnabled => boolean().withDefault(const Constant(true))();
  RealColumn get alertThreshold =>
      real().withDefault(const Constant(0.8))(); // 80%
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Goals extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get color => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get linkedAccountId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Debts extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get personName => text()();
  TextColumn get personContact => text().nullable()();
  TextColumn get type => text()(); // owe | owed  (I owe them | they owe me)
  RealColumn get amount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(
    tables: [Accounts, Categories, Transactions, Budgets, Goals, Debts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultData();
          await _ensureAiInsightCacheTable();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _ensureAiInsightCacheTable();
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'expense_tracker_db');
  }

  Future<void> _seedDefaultData() async {
    // Default accounts
    await into(accounts).insert(AccountsCompanion.insert(
      name: 'Cash',
      type: 'cash',
      color: '#4CAF50',
      icon: 'wallet',
      isDefault: const Value(true),
    ));
    await into(accounts).insert(AccountsCompanion.insert(
      name: 'Bank Account',
      type: 'bank',
      color: '#2196F3',
      icon: 'bank',
    ));
    await into(accounts).insert(AccountsCompanion.insert(
      name: 'Credit Card',
      type: 'credit',
      color: '#9C27B0',
      icon: 'credit_card',
    ));

    // Default expense categories
    final expenseCategories = [
      ('Food & Dining', '🍔', '#FF5722'),
      ('Transportation', '🚗', '#FF9800'),
      ('Shopping', '🛍️', '#E91E63'),
      ('Entertainment', '🎬', '#9C27B0'),
      ('Health', '💊', '#F44336'),
      ('Education', '📚', '#3F51B5'),
      ('Bills & Utilities', '⚡', '#607D8B'),
      ('Groceries', '🛒', '#8BC34A'),
      ('Rent', '🏠', '#795548'),
      ('Travel', '✈️', '#00BCD4'),
      ('Personal Care', '💅', '#FF4081'),
      ('Other', '📌', '#9E9E9E'),
    ];

    for (final cat in expenseCategories) {
      await into(categories).insert(CategoriesCompanion.insert(
        name: cat.$1,
        icon: cat.$2,
        color: cat.$3,
        type: 'expense',
      ));
    }

    // Default income categories
    final incomeCategories = [
      ('Salary', '💼', '#4CAF50'),
      ('Freelance', '💻', '#00BCD4'),
      ('Investment', '📈', '#FF9800'),
      ('Gift', '🎁', '#E91E63'),
      ('Other Income', '💰', '#8BC34A'),
    ];

    for (final cat in incomeCategories) {
      await into(categories).insert(CategoriesCompanion.insert(
        name: cat.$1,
        icon: cat.$2,
        color: cat.$3,
        type: 'income',
      ));
    }
  }

  // ─── AI insight cache ─────────────────────────────────────────────────────

  String _dailyAiInsightCacheKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _ensureAiInsightCacheTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ai_insight_cache (
        cache_date TEXT PRIMARY KEY,
        insights_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<String?> getDailyAiInsightsJson(DateTime date) async {
    await _ensureAiInsightCacheTable();

    final rows = await customSelect(
      'SELECT insights_json FROM ai_insight_cache WHERE cache_date = ? LIMIT 1',
      variables: [Variable.withString(_dailyAiInsightCacheKey(date))],
      readsFrom: const {},
    ).get();

    if (rows.isEmpty) return null;
    return rows.first.read<String>('insights_json');
  }

  Future<void> saveDailyAiInsightsJson({
    required DateTime date,
    required List<Map<String, dynamic>> insights,
  }) async {
    await _ensureAiInsightCacheTable();

    final nowIso = DateTime.now().toIso8601String();
    final key = _dailyAiInsightCacheKey(date);
    await customStatement(
      '''
      INSERT OR REPLACE INTO ai_insight_cache
        (cache_date, insights_json, created_at, updated_at)
      VALUES
        (?, ?, COALESCE((SELECT created_at FROM ai_insight_cache WHERE cache_date = ?), ?), ?)
      ''',
      [key, jsonEncode(insights), key, nowIso, nowIso],
    );
  }

  // ─── Transaction queries ───────────────────────────────────────────────────

  Stream<List<Transaction>> watchRecentTransactions({int limit = 50}) {
    return (select(transactions)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsByMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return (select(transactions)
          ..where((t) =>
              t.isDeleted.equals(false) & t.date.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<Map<String, double>> getMonthlyTotals(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final rows = await (select(transactions)
          ..where((t) =>
              t.isDeleted.equals(false) & t.date.isBetweenValues(start, end)))
        .get();

    double income = 0, expense = 0;
    for (final row in rows) {
      if (row.type == 'income') income += row.amount;
      if (row.type == 'expense') expense += row.amount;
    }
    return {'income': income, 'expense': expense, 'savings': income - expense};
  }

  Future<List<Map<String, dynamic>>> getCategoryBreakdown(
      DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final txns = await (select(transactions)
          ..where((t) =>
              t.isDeleted.equals(false) &
              t.type.equals('expense') &
              t.date.isBetweenValues(start, end)))
        .get();

    final cats = await select(categories).get();
    final catMap = {for (final c in cats) c.id: c};

    final Map<String, double> totals = {};
    for (final txn in txns) {
      totals[txn.categoryId] = (totals[txn.categoryId] ?? 0) + txn.amount;
    }

    return totals.entries.map((e) {
      final cat = catMap[e.key];
      return {
        'categoryId': e.key,
        'name': cat?.name ?? 'Unknown',
        'icon': cat?.icon ?? '📌',
        'color': cat?.color ?? '#9E9E9E',
        'amount': e.value,
      };
    }).toList()
      ..sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
  }

  // ─── Budget queries ────────────────────────────────────────────────────────

  Stream<List<Budget>> watchActiveBudgets() {
    return (select(budgets)..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
        .watch();
  }

  Future<double> getBudgetSpent(Budget budget) async {
    final now = DateTime.now();
    DateTime start;
    switch (budget.period) {
      case 'weekly':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'yearly':
        start = DateTime(now.year, 1, 1);
        break;
      default: // monthly
        start = DateTime(now.year, now.month, 1);
    }

    var query = select(transactions)
      ..where((t) =>
          t.isDeleted.equals(false) &
          t.type.equals('expense') &
          t.date.isBiggerOrEqualValue(start));

    if (budget.categoryId != null) {
      query = query..where((t) => t.categoryId.equals(budget.categoryId!));
    }

    final rows = await query.get();
    return rows.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  Stream<List<Transaction>> watchTransactionsByRange(
    DateTime start,
    DateTime end, {
    String type = 'all',
    String search = '',
  }) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd =
        DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

    final query = select(transactions)
      ..where(
        (t) =>
            t.isDeleted.equals(false) &
            t.date.isBetweenValues(normalizedStart, normalizedEnd),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);

    if (type != 'all') {
      query.where((t) => t.type.equals(type));
    }

    final trimmedSearch = search.trim();

    if (trimmedSearch.isNotEmpty) {
      final numericSearch = double.tryParse(
        trimmedSearch.replaceAll(RegExp(r'[^0-9.]'), ''),
      );

      query.where((t) {
        final textSearch = t.title.like('%$trimmedSearch%') |
            t.note.like('%$trimmedSearch%') |
            t.type.like('%$trimmedSearch%');

        if (numericSearch == null) {
          return textSearch;
        }

        final amountSearch = t.amount.isBetweenValues(
          numericSearch,
          numericSearch + 0.999999,
        );

        return textSearch | amountSearch;
      });
    }

    return query.watch();
  }

  Stream<Map<String, double>> watchMonthlyTotals(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);

    final query = select(transactions)
      ..where(
        (t) => t.isDeleted.equals(false) & t.date.isBetweenValues(start, end),
      );

    return query.watch().map((rows) {
      double income = 0;
      double expense = 0;

      for (final row in rows) {
        if (row.type == 'income') income += row.amount;
        if (row.type == 'expense') expense += row.amount;
      }

      return {
        'income': income,
        'expense': expense,
        'savings': income - expense,
      };
    });
  }
}
