import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../database/app_database.dart';

class ExportService {
  static String _stamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  Future<File> exportExcel(AppDatabase db) async {
    final transactions = await (db.select(db.transactions)..where((t) => t.isDeleted.equals(false))).get();
    final accounts = await db.select(db.accounts).get();
    final categories = await db.select(db.categories).get();

    final accountById = {for (final a in accounts) a.id: a};
    final categoryById = {for (final c in categories) c.id: c};

    final book = Excel.createExcel();
    final sheet = book['Transactions'];
    book.setDefaultSheet('Transactions');

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Title'),
      TextCellValue('Amount'),
      TextCellValue('Category'),
      TextCellValue('Account'),
      TextCellValue('Note'),
    ]);

    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    for (final t in sorted) {
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(t.date)),
        TextCellValue(t.type),
        TextCellValue(t.title),
        DoubleCellValue(t.amount),
        TextCellValue(categoryById[t.categoryId]?.name ?? ''),
        TextCellValue(accountById[t.accountId]?.name ?? ''),
        TextCellValue(t.note ?? ''),
      ]);
    }

    final summary = book['Summary'];
    final now = DateTime.now();
    final totals = await db.getMonthlyTotals(DateTime(now.year, now.month, 1));
    summary.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    summary.appendRow([TextCellValue('Income this month'), DoubleCellValue(totals['income'] ?? 0)]);
    summary.appendRow([TextCellValue('Expense this month'), DoubleCellValue(totals['expense'] ?? 0)]);
    summary.appendRow([TextCellValue('Savings this month'), DoubleCellValue(totals['savings'] ?? 0)]);
    summary.appendRow([TextCellValue('Transactions'), IntCellValue(transactions.length)]);
    summary.appendRow([TextCellValue('Accounts'), IntCellValue(accounts.length)]);

    final bytes = book.save();
    if (bytes == null) throw Exception('Could not generate Excel file.');

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'expense_tracker_export_${_stamp()}.xlsx'));
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> createJsonBackup(AppDatabase db) async {
    final data = {
      'createdAt': DateTime.now().toIso8601String(),
      'schemaVersion': db.schemaVersion,
      'accounts': (await db.select(db.accounts).get()).map((e) => e.toJson()).toList(),
      'categories': (await db.select(db.categories).get()).map((e) => e.toJson()).toList(),
      'transactions': (await db.select(db.transactions).get()).map((e) => e.toJson()).toList(),
      'budgets': (await db.select(db.budgets).get()).map((e) => e.toJson()).toList(),
      'goals': (await db.select(db.goals).get()).map((e) => e.toJson()).toList(),
      'debts': (await db.select(db.debts).get()).map((e) => e.toJson()).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'expense_tracker_backup_${_stamp()}.json'));
    await file.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
    return file;
  }

  Future<File> exportAndShareExcel(AppDatabase db) async {
    final file = await exportExcel(db);
    await SharePlus.instance.share(
      ShareParams(
        text: 'Expense Tracker Excel export',
        files: [XFile(file.path)],
      ),
    );
    return file;
  }
}
