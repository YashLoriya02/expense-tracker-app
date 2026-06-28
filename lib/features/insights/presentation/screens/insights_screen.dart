// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/gemini_service.dart';

final aiInsightsProvider =
    FutureProvider.autoDispose<List<AIInsight>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // Gemini should be called only once per day.
  final cachedJson = await db.getDailyAiInsightsJson(now);
  if (cachedJson != null && cachedJson.trim().isNotEmpty) {
    try {
      final List cachedInsights = jsonDecode(cachedJson) as List;
      return cachedInsights
          .map((i) => AIInsight.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  debugPrint(
    "Insight data not saved in local DB, generating response using LLM...",
  );

  // Gather last 3 months of data only when there is no cache for today.
  final List<Map<String, dynamic>> monthData = [];
  for (int i = 2; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final totals = await db.getMonthlyTotals(month);
    final breakdown = await db.getCategoryBreakdown(month);
    monthData.add({
      'month': DateFormat('MMM yyyy').format(month),
      'income': totals['income'],
      'expense': totals['expense'],
      'savings': totals['savings'],
      'topCategories': breakdown.take(5).toList(),
    });
  }

  // Build prompt for Gemini
  final prompt = '''
  Analyze this person's expense data for the last 3 months and provide 4-5 specific, 
  actionable financial insights. Every figure/amount is in INR (₹). Be concise and specific.

  Data: ${jsonEncode(monthData)}

  Respond ONLY with a JSON array (no markdown) in this format:
  [
    {
      "type": "warning|tip|achievement|trend",
      "title": "Short title",
      "body": "2-3 sentence insight with specific numbers",
      "action": "Optional action text"
    }
  ]
  ''';

  try {
    final text =
        await GeminiService().generateJson(prompt, maxOutputTokens: 900);
    final List insights = jsonDecode(text) as List;
    final parsedInsights = insights
        .map((i) => AIInsight.fromJson(i as Map<String, dynamic>))
        .toList();

    await db.saveDailyAiInsightsJson(
      date: now,
      insights: parsedInsights.map((i) => i.toJson()).toList(),
    );

    return parsedInsights;
  } catch (e) {
    debugPrint('AI insights generation failed: $e');
    // Fall through to offline fallback insights.
  }

  // Fallback static insights if API fails/key not set.
  // Do not cache this fallback, otherwise adding a Gemini key later the same day
  // would still show the fallback until tomorrow.
  return [
    AIInsight(
      type: 'tip',
      title: 'Set up your Gemini API key',
      body:
          'Add your Gemini API key in Settings to unlock AI-powered spending insights tailored to your patterns.',
      action: 'Go to Settings',
    ),
    AIInsight(
      type: 'trend',
      title: 'Track for better insights',
      body:
          'Add at least 2 weeks of transactions for the AI to identify meaningful spending patterns.',
    ),
  ];
});

class AIInsight {
  final String type; // warning | tip | achievement | trend
  final String title;
  final String body;
  final String? action;

  AIInsight({
    required this.type,
    required this.title,
    required this.body,
    this.action,
  });

  factory AIInsight.fromJson(Map<String, dynamic> j) => AIInsight(
        type: j['type'] ?? 'tip',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        action: j['action'],
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'body': body,
        if (action != null) 'action': action,
      };
}

// ─── Insights Screen ───────────────────────────────────────────────────────────
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final month = DateTime(today.year, today.month, 1);
    final breakdown = ref.watch(categoryBreakdownProvider(month));
    final insights = ref.watch(aiInsightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(aiInsightsProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── AI Insights section ────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('AI Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              // color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Insights are refreshed once a day to reduce API usage.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.72),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          insights.when(
            data: (list) => Column(
              children: list
                  .asMap()
                  .entries
                  .map((e) => _InsightCard(insight: e.value)
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: e.key * 80))
                      .slideX(begin: 0.05))
                  .toList(),
            ),
            loading: () => const _InsightSkeleton(),
            error: (e, _) => Text('Could not load insights: $e'),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ── Spending breakdown chart ───────────────────────────────────────
          const Text('This month by category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          breakdown.when(
            data: (cats) => cats.isEmpty
                ? const _EmptyState()
                : _CategoryPieChart(categories: cats),
            loading: () => const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // ── Monthly trend ─────────────────────────────────────────────────
          const Text('3-month trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _MonthlyTrendChart(ref: ref),
        ],
      ),
    );
  }
}

// ─── Insight Card ──────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final AIInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (color, icon) = switch (insight.type) {
      'warning' => (Colors.orange, Icons.warning_amber_rounded),
      'achievement' => (Colors.green, Icons.emoji_events_rounded),
      'trend' => (cs.primary, Icons.trending_up_rounded),
      _ => (Colors.blue, Icons.lightbulb_outline_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(insight.body,
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.75),
                        height: 1.4)),
                if (insight.action != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: insight.action! == "Go to Settings"
                        ? () => context.push("/settings")
                        : null,
                    child: Text(
                      insight.action!,
                      style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pie Chart ─────────────────────────────────────────────────────────────────
class _CategoryPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  const _CategoryPieChart({required this.categories});

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total =
        widget.categories.fold(0.0, (s, c) => s + (c['amount'] as double));

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections:
                  widget.categories.take(6).toList().asMap().entries.map((e) {
                final i = e.key;
                final cat = e.value;
                final pct = (cat['amount'] as double) / total * 100;
                final isTouched = i == _touchedIndex;
                return PieChartSectionData(
                  value: cat['amount'] as double,
                  title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                  radius: isTouched ? 70 : 56,
                  color: HexColor.fromHex(cat['color'] as String),
                  titleStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                );
              }).toList(),
              sectionsSpace: 3,
              centerSpaceRadius: 48,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.categories.take(6).map((cat) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: HexColor.fromHex(cat['color'] as String),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('${cat['icon']} ${cat['name']}',
                    style: const TextStyle(fontSize: 12)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Monthly trend chart ────────────────────────────────────────────────────────
class _MonthlyTrendChart extends ConsumerWidget {
  final WidgetRef ref;
  const _MonthlyTrendChart({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final today = DateTime.now();
    final currentMonth = DateTime(today.year, today.month, 1);
    final months = [
      DateTime(currentMonth.year, currentMonth.month - 2, 1),
      DateTime(currentMonth.year, currentMonth.month - 1, 1),
      currentMonth,
    ];

    final totalsProviders =
        months.map((m) => ref.watch(monthlyTotalsProvider(m))).toList();
    final allLoaded = totalsProviders.every((p) => p.hasValue);

    if (!allLoaded) {
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
    }

    final data = totalsProviders.map((p) => p.value!).toList();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          barGroups: List.generate(3, (i) {
            final income = data[i]['income'] ?? 0.0;
            final expense = data[i]['expense'] ?? 0.0;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                    toY: income,
                    color: Colors.green,
                    width: 12,
                    borderRadius: BorderRadius.circular(4)),
                BarChartRodData(
                    toY: expense,
                    color: Colors.red,
                    width: 12,
                    borderRadius: BorderRadius.circular(4)),
              ],
              barsSpace: 4,
            );
          }),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) => Text(
                  DateFormat('MMM').format(months[val.toInt()]),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (val, _) => Text(
                  '₹${(val / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color:
                  Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// ─── Skeletons / Empty ─────────────────────────────────────────────────────────
class _InsightSkeleton extends StatelessWidget {
  const _InsightSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 90,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1.5.seconds,
              color: Theme.of(context).colorScheme.surface.withOpacity(0.4),
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Text('📊', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Add transactions to see your spending breakdown'),
          ],
        ),
      ),
    );
  }
}
