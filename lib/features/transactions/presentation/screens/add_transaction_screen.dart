import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/database/app_database.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';
import '../../../../core/services/gemini_service.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String initialType;
  final Map<String, dynamic>? prefilled;
  final String? pendingNotificationId;

  const AddTransactionScreen({
    super.key,
    required this.initialType,
    this.prefilled,
    this.pendingNotificationId,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _nlpCtrl = TextEditingController();

  String _type = 'expense';
  DateTime _date = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedAccountId;
  bool _isNlpLoading = false;
  bool _isSaving = false;
  String? _prefilledCategoryName;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _tabController = TabController(length: 2, vsync: this);

    // Apply prefilled data (from receipt scanner)
    if (widget.prefilled != null) {
      final p = widget.prefilled!;
      if (p['amount'] != null) _amountCtrl.text = p['amount'].toString();
      if (p['title'] != null) _titleCtrl.text = p['title'];
      if (p['date'] != null) {
        _date = DateTime.tryParse(p['date']) ?? DateTime.now();
      }
      if (p['category'] != null) {
        _prefilledCategoryName = p['category'].toString();
      }
      if (p['note'] != null) {
        _noteCtrl.text = p['note'].toString();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _nlpCtrl.dispose();
    super.dispose();
  }

  // ── Gemini parser: "spent 450 on lunch at barbeque nation" ───────────────
  Future<void> _parseNLPInput(String input) async {
    if (input.trim().isEmpty) return;
    setState(() => _isNlpLoading = true);

    final prompt = '''
Parse this natural language expense entry and extract transaction details.
Input: "$input"
Today's date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

Respond ONLY with a valid JSON object. No markdown.
{
  "amount": <number or null>,
  "title": "<merchant/description>",
  "type": "expense|income|transfer",
  "category": "<one of: Food & Dining, Transportation, Shopping, Entertainment, Health, Education, Bills & Utilities, Groceries, Rent, Travel, Personal Care, Salary, Freelance, Investment, Gift, Other Income, Other>",
  "date": "<YYYY-MM-DD or null if not mentioned>",
  "note": "<any extra context or empty string>"
}
''';

    try {
      final text =
          await GeminiService().generateJson(prompt, maxOutputTokens: 350);
      final parsed = jsonDecode(text) as Map<String, dynamic>;

      setState(() {
        if (parsed['amount'] != null) {
          _amountCtrl.text = parsed['amount'].toString();
        }
        if (parsed['title'] != null && parsed['title'].toString().isNotEmpty) {
          _titleCtrl.text = parsed['title'].toString();
        }
        if (parsed['type'] != null) {
          final t = parsed['type'].toString();
          if (['expense', 'income', 'transfer'].contains(t)) _type = t;
        }
        if (parsed['category'] != null) {
          _prefilledCategoryName = parsed['category'].toString();
          _selectedCategoryId = null;
        }
        if (parsed['note'] != null && parsed['note'].toString().isNotEmpty) {
          _noteCtrl.text = parsed['note'].toString();
        }
        if (parsed['date'] != null && parsed['date'].toString().isNotEmpty) {
          _date =
              DateTime.tryParse(parsed['date'].toString()) ?? DateTime.now();
        }
        _tabController.animateTo(0);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gemini parse failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isNlpLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final accounts = await db.select(db.accounts).get();
      if (accounts.isEmpty) {
        throw Exception('No account found. Create an account first.');
      }

      final accountId = _selectedAccountId ??
          accounts
              .firstWhere(
                (a) => a.isDefault,
                orElse: () => accounts.first,
              )
              .id;

      await db.transaction(() async {
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
              amount: amount,
              type: _type,
              title: _titleCtrl.text.trim(),
              note: Value(
                  _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
              accountId: accountId,
              categoryId: _selectedCategoryId!,
              date: _date,
            ));

        final account = accounts.firstWhere((a) => a.id == accountId);
        final delta = switch (_type) {
          'income' => amount,
          'expense' => -amount,
          _ => 0.0,
        };

        if (delta != 0) {
          await (db.update(db.accounts)..where((a) => a.id.equals(accountId)))
              .write(
            AccountsCompanion(balance: Value(account.balance + delta)),
          );
        }

        if (widget.pendingNotificationId != null) {
          await db.deletePendingNotification(widget.pendingNotificationId!);
        }
      });

      if (mounted) {
        HapticFeedback.lightImpact();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction saved!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final accounts = ref.watch(accountsProvider);
    final categoryList = categories.value ?? [];
    final accountList = accounts.value ?? [];

    if (_selectedCategoryId == null &&
        _prefilledCategoryName != null &&
        categoryList.isNotEmpty) {
      Category? match;
      for (final c in categoryList) {
        if (c.name.toLowerCase() == _prefilledCategoryName!.toLowerCase() &&
            (_type == 'transfer' || c.type == _type)) {
          match = c;
          break;
        }
      }
      for (final c in categoryList) {
        if (match == null &&
            c.name.toLowerCase() == 'other' &&
            (_type == 'transfer' || c.type == _type)) {
          match = c;
          break;
        }
      }
      if (match != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedCategoryId == null) {
            setState(() => _selectedCategoryId = match!.id);
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${_type[0].toUpperCase()}${_type.substring(1)}'),
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          OutlinedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Type selector ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'expense',
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_upward_rounded, size: 16)),
                  ButtonSegment(
                      value: 'income',
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_downward_rounded, size: 16)),
                  ButtonSegment(
                      value: 'transfer',
                      label: Text('Transfer'),
                      icon: Icon(Icons.swap_horiz_rounded, size: 16)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _selectedCategoryId = null;
                }),
              ),
            ),

            // ── Tab bar: Form / NLP ────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                    text: 'Manual Form',
                    icon: Icon(Icons.edit_rounded, size: 16)),
                Tab(
                    text: 'Natural Language',
                    icon: Icon(Icons.auto_awesome, size: 16)),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Manual form ────────────────────────────────────────────
                  _FormTab(
                    formKey: _formKey,
                    amountCtrl: _amountCtrl,
                    titleCtrl: _titleCtrl,
                    noteCtrl: _noteCtrl,
                    type: _type,
                    date: _date,
                    selectedCategoryId: _selectedCategoryId,
                    selectedAccountId: _selectedAccountId,
                    categories: categoryList,
                    accounts: accountList,
                    onDateChanged: (d) => setState(() => _date = d),
                    onCategoryChanged: (id) =>
                        setState(() => _selectedCategoryId = id),
                    onAccountChanged: (id) =>
                        setState(() => _selectedAccountId = id),
                  ),

                  // ── NLP tab ──────────────────────────────────────────────
                  _NLPTab(
                    ctrl: _nlpCtrl,
                    isLoading: _isNlpLoading,
                    onParse: _parseNLPInput,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Form Tab ─────────────────────────────────────────────────────────────────
class _FormTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController amountCtrl, titleCtrl, noteCtrl;
  final String type;
  final DateTime date;
  final String? selectedCategoryId, selectedAccountId;
  final List<Category> categories;
  final List<Account> accounts;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onAccountChanged;

  const _FormTab({
    required this.formKey,
    required this.amountCtrl,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.type,
    required this.date,
    required this.selectedCategoryId,
    required this.selectedAccountId,
    required this.categories,
    required this.accounts,
    required this.onDateChanged,
    required this.onCategoryChanged,
    required this.onAccountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = categories.where((c) {
      if (type == 'transfer') return true;
      return c.type == type;
    }).toList();

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amount
          TextFormField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
            // style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (double.tryParse(v) == null) return 'Invalid number';
              return null;
            },
            autofocus: amountCtrl.text.isEmpty,
          ).animate().fadeIn(delay: 50.ms),

          const SizedBox(height: 16),

          // Title
          TextFormField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title / Merchant',
              prefixIcon: Icon(Icons.store_rounded),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // Date
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
            leading: const Icon(Icons.calendar_today_rounded),
            title: Text(DateFormat('EEEE, d MMM yyyy').format(date)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) onDateChanged(picked);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: accounts.any((a) => a.id == selectedAccountId)
                ? selectedAccountId
                : null,
            decoration: const InputDecoration(
              labelText: 'Account',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
            ),
            hint: Text(
                accounts.isEmpty ? 'No accounts found' : 'Default account'),
            items: accounts
                .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name),
                    ))
                .toList(),
            onChanged: accounts.isEmpty ? null : onAccountChanged,
          ).animate().fadeIn(delay: 125.ms),

          const SizedBox(height: 16),

          // Category grid
          Text('Category',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filtered.map((cat) {
              final isSelected = cat.id == selectedCategoryId;
              return FilterChip(
                label: Text('${cat.icon} ${cat.name}'),
                selected: isSelected,
                onSelected: (_) => onCategoryChanged(cat.id),
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
              );
            }).toList(),
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 16),

          // Note
          TextFormField(
            controller: noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ).animate().fadeIn(delay: 250.ms),
        ],
      ),
    );
  }
}

// ─── NLP Tab ──────────────────────────────────────────────────────────────────
class _NLPTab extends StatefulWidget {
  final TextEditingController ctrl;
  final bool isLoading;
  final ValueChanged<String> onParse;

  const _NLPTab({
    required this.ctrl,
    required this.isLoading,
    required this.onParse,
  });

  @override
  State<_NLPTab> createState() => _NLPTabState();
}

class _NLPTabState extends State<_NLPTab> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _isListening = false;

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );

    if (!_speechReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Speech recognition is not available on this device')),
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        widget.ctrl.text = result.recognizedWords;
        widget.ctrl.selection =
            TextSelection.collapsed(offset: widget.ctrl.text.length);
      },
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const examples = [
      'Spent 450 on lunch at Barbeque Nation',
      'Paid 2000 rent yesterday',
      'Got 50000 salary today',
      'Auto ride 80 rupees',
      'Groceries from DMart 1200',
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.secondary, size: 18),
                  const SizedBox(width: 8),
                  Text('Type or speak naturally',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: cs.secondary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Gemini will parse the amount, merchant, category and date from plain text. Speech-to-text uses the device speech recognizer.',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withOpacity(0.7)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: widget.ctrl,
          decoration: InputDecoration(
            hintText: 'e.g. Spent 450 on lunch at Barbeque Nation',
            suffixIcon: widget.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _isListening ? 'Stop listening' : 'Speak',
                        icon: Icon(_isListening
                            ? Icons.stop_circle_rounded
                            : Icons.mic_rounded),
                        onPressed: _toggleListening,
                      ),
                      IconButton(
                        tooltip: 'Parse',
                        icon: const Icon(Icons.send_rounded),
                        onPressed: () => widget.onParse(widget.ctrl.text),
                      ),
                    ],
                  ),
          ),
          maxLines: 3,
          onSubmitted: widget.onParse,
        ),
        const SizedBox(height: 20),
        Text('Try these examples:',
            style:
                TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
        const SizedBox(height: 10),
        ...examples.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(e, style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  widget.ctrl.text = e;
                  widget.onParse(e);
                },
              ),
            )),
      ],
    );
  }
}
