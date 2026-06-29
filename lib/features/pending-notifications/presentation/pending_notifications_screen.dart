import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';

class PendingNotificationsScreen extends ConsumerStatefulWidget {
  const PendingNotificationsScreen({super.key});

  @override
  ConsumerState<PendingNotificationsScreen> createState() =>
      _PendingNotificationsScreenState();
}

class _PendingNotificationsScreenState
    extends ConsumerState<PendingNotificationsScreen> {
  String? _loadingId;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Notifications'),
      ),
      body: pending.when(
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyPendingState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return _PendingNotificationCard(
                item: item,
                isLoading: _loadingId == item.id,
                onParse: () => _parseAndOpen(item),
                onDelete: () => _delete(item),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _parseAndOpen(PendingNotification item) async {
    setState(() => _loadingId = item.id);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final prompt = '''
You are parsing an Indian bank/payment SMS into an expense tracker transaction.

Today's date: $today

SMS sender:
${item.sender ?? ''}

SMS body:
${item.body}

Return ONLY valid JSON. No markdown.

{
  "amount": <final transaction amount number or null>,
  "merchant": "<merchant/store/person/business name or short title>",
  "type": "expense|income|transfer",
  "category": "<one of: Food & Dining, Transportation, Shopping, Entertainment, Health, Education, Bills & Utilities, Groceries, Rent, Travel, Personal Care, Salary, Freelance, Investment, Gift, Other Income, Other>",
  "date": "<YYYY-MM-DD>",
  "note": "<short note from SMS or empty string>"
}
''';

    try {
      final response = await GeminiService().generateJson(
        prompt,
        maxOutputTokens: 350,
      );

      final parsed = jsonDecode(response) as Map<String, dynamic>;

      if (!mounted) return;

      context.push(
        '/add-transaction',
        extra: {
          'type': parsed['type'] ?? 'expense',
          'pendingNotificationId': item.id,
          'prefilled': {
            'amount': parsed['amount'],
            'title': parsed['merchant'] ?? 'SMS Transaction',
            'date': parsed['date'],
            'category': parsed['category'] ?? 'Other',
            'note': parsed['note'] ?? item.body,
          },
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not parse SMS: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingId = null);
    }
  }

  Future<void> _delete(PendingNotification item) async {
    await ref.read(databaseProvider).deletePendingNotification(item.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification deleted')),
    );
  }
}

class _PendingNotificationCard extends StatelessWidget {
  final PendingNotification item;
  final bool isLoading;
  final VoidCallback onParse;
  final VoidCallback onDelete;

  const _PendingNotificationCard({
    required this.item,
    required this.isLoading,
    required this.onParse,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.sms_rounded,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.sender ?? 'Unknown sender',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  DateFormat('d MMM, h:mm a').format(item.receivedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.body,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: cs.onSurface.withOpacity(0.78),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: isLoading ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: isLoading ? null : onParse,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Parse & Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPendingState extends StatelessWidget {
  const _EmptyPendingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📩', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text(
              'No pending notifications',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Credit/debit SMS alerts will appear here for review.',
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
