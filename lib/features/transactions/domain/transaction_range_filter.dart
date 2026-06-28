class TransactionRangeFilter {
  final DateTime start;
  final DateTime end;
  final String type; // all | expense | income | transfer
  final String query;

  const TransactionRangeFilter({
    required this.start,
    required this.end,
    this.type = 'all',
    this.query = '',
  });

  DateTime get normalizedStart => DateTime(start.year, start.month, start.day);

  DateTime get normalizedEnd =>
      DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

  @override
  bool operator ==(Object other) {
    return other is TransactionRangeFilter &&
        other.normalizedStart.millisecondsSinceEpoch ==
            normalizedStart.millisecondsSinceEpoch &&
        other.normalizedEnd.millisecondsSinceEpoch ==
            normalizedEnd.millisecondsSinceEpoch &&
        other.type == type &&
        other.query.trim().toLowerCase() == query.trim().toLowerCase();
  }

  @override
  int get hashCode => Object.hash(
        normalizedStart.millisecondsSinceEpoch,
        normalizedEnd.millisecondsSinceEpoch,
        type,
        query.trim().toLowerCase(),
      );
}
