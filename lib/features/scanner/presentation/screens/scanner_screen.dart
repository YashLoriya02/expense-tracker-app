import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../core/services/gemini_service.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  ScannedReceiptData? _result;
  String rawText = '';

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _picker = ImagePicker();

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _isProcessing = true;
      _result = null;
    });

    await _processImage(File(picked.path));
  }

  Future<void> _processImage(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final raw = recognizedText.text;

      ScannedReceiptData parsed;
      try {
        parsed = await _parseReceiptTextWithGemini(raw);
      } catch (_) {
        parsed = _parseReceiptText(raw);
      }

      setState(() {
        rawText = raw;
        _result = parsed;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    }
  }

  Future<ScannedReceiptData> _parseReceiptTextWithGemini(String text) async {
    if (text.trim().isEmpty) throw Exception('No OCR text found.');

    final prompt = '''
You are parsing OCR text from an Indian receipt/bill.
Extract the most likely transaction details.

OCR text:
$text

Respond ONLY with a valid JSON object. No markdown.
{
  "amount": <final payable/grand total number or null>,
  "merchant": "<store/restaurant/business name or null>",
  "date": "<YYYY-MM-DD or null>",
  "category": "<one of: Food & Dining, Transportation, Shopping, Entertainment, Health, Education, Bills & Utilities, Groceries, Rent, Travel, Personal Care, Other>",
  "note": "<short note or empty string>"
}
''';

    final response =
        await GeminiService().generateJson(prompt, maxOutputTokens: 350);
    final parsed = jsonDecode(response) as Map<String, dynamic>;

    final amountValue = parsed['amount'];
    final amount = amountValue is num
        ? amountValue.toDouble()
        : double.tryParse(amountValue?.toString().replaceAll(',', '') ?? '');

    return ScannedReceiptData(
      amount: amount,
      merchant: parsed['merchant']?.toString(),
      date: parsed['date'] == null
          ? DateTime.now()
          : DateTime.tryParse(parsed['date'].toString()) ?? DateTime.now(),
      category: parsed['category']?.toString().isNotEmpty == true
          ? parsed['category'].toString()
          : 'Other',
      note: parsed['note']?.toString(),
      rawText: text,
    );
  }

  ScannedReceiptData _parseReceiptText(String text) {
    // ── Smart receipt parser ─────────────────────────────────────────────────
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    double? amount;
    String? merchant;
    DateTime? date;
    String? category;

    // Amount: look for total/grand total/amount due patterns
    final totalPatterns = [
      RegExp(
          r'(?:total|grand total|amount due|net amount|to pay)[:\s]*[₹Rs.]?\s*([\d,]+\.?\d*)',
          caseSensitive: false),
      RegExp(r'[₹Rs.]\s*([\d,]+\.?\d*)\s*$', multiLine: true),
      RegExp(r'(\d{1,6}[.,]\d{2})\s*$', multiLine: true),
    ];

    for (final pattern in totalPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)!.replaceAll(',', '');
        amount = double.tryParse(raw);
        if (amount != null && amount > 0) break;
      }
    }

    // Merchant: usually the first non-empty, non-number line
    for (final line in lines.take(5)) {
      if (line.length > 3 &&
          !RegExp(r'^\d+$').hasMatch(line) &&
          !line.contains('GST')) {
        merchant = line;
        break;
      }
    }

    // Date
    final datePatterns = [
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})'),
      RegExp(
          r'(\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+\d{4})',
          caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        // Try to parse
        try {
          final raw = match.group(1)!;
          // simple DD/MM/YYYY
          final parts = raw.split(RegExp(r'[/\-\s]'));
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              date = DateTime(year < 100 ? 2000 + year : year, month, day);
            }
          }
        } catch (_) {}
        break;
      }
    }
    date ??= DateTime.now();

    // Category inference from merchant name / keywords
    category = _inferCategory(text, merchant ?? '');

    return ScannedReceiptData(
      amount: amount,
      merchant: merchant,
      date: date,
      category: category,
      note: '',
      rawText: text,
    );
  }

  String _inferCategory(String text, String merchant) {
    final lower = (text + ' ' + merchant).toLowerCase();
    if (RegExp(
            r'restaurant|cafe|bistro|pizza|burger|food|dining|swiggy|zomato|hotel')
        .hasMatch(lower)) {
      return 'Food & Dining';
    }
    if (RegExp(r'uber|ola|rapido|petrol|fuel|metro|bus|taxi|auto')
        .hasMatch(lower)) {
      return 'Transportation';
    }
    if (RegExp(r'amazon|flipkart|myntra|shopping|mall|store').hasMatch(lower)) {
      return 'Shopping';
    }
    if (RegExp(r'medical|pharmacy|hospital|clinic|doctor|apollo|health')
        .hasMatch(lower)) {
      return 'Health';
    }
    if (RegExp(r'electricity|water|gas|broadband|internet|recharge|bill')
        .hasMatch(lower)) {
      return 'Bills & Utilities';
    }
    if (RegExp(r'grocery|vegetables|supermarket|dmart|bigbasket|blinkit')
        .hasMatch(lower)) {
      return 'Groceries';
    }
    return 'Other';
  }

  void _useData() {
    if (_result == null) return;
    context.pushReplacement('/add-transaction', extra: {
      'type': 'expense',
      'prefilled': {
        'amount': _result!.amount,
        'title': _result!.merchant,
        'date': _result!.date?.toIso8601String(),
        'category': _result!.category,
        'receiptPath': _imageFile?.path,
        'note': _result!.note,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero description ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: cs.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Receipt Scanner',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary)),
                          const SizedBox(height: 4),
                          Text(
                            'Snap your bill; OCR reads text and Gemini auto-fills amount, merchant, date and category.',
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.1),

              const SizedBox(height: 24),

              // ── Image preview ──────────────────────────────────────────────────
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _imageFile!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ).animate().fadeIn(),

              const SizedBox(height: 16),

              // ── Pick image buttons ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),

              // ── Processing indicator ───────────────────────────────────────────
              if (_isProcessing) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Reading receipt...',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                  ),
                ),
              ],

              // ── Result ────────────────────────────────────────────────────────
              if (_result != null) ...[
                const SizedBox(height: 24),
                _ResultCard(data: _result!),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _useData,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use this data'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ).animate().fadeIn().scale(),
              ],

              // ── Manual entry fallback ──────────────────────────────────────────
              if (!_isProcessing && _imageFile != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context
                      .push('/add-transaction', extra: {'type': 'expense'}),
                  child: const Text('Enter manually instead'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Result card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final ScannedReceiptData data;
  const _ResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Detected from receipt',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
                ),
              ],
            ),
            const Divider(height: 24),
            _Row(
              label: 'Amount',
              value: data.amount != null
                  ? '₹${data.amount!.toStringAsFixed(2)}'
                  : 'Not found',
              found: data.amount != null,
            ),
            _Row(
              label: 'Merchant',
              value: data.merchant ?? 'Not found',
              found: data.merchant != null,
            ),
            _Row(
              label: 'Date',
              value: data.date != null
                  ? '${data.date!.day}/${data.date!.month}/${data.date!.year}'
                  : 'Not found',
              found: data.date != null,
            ),
            _Row(
              label: 'Category',
              value: data.category ?? 'Other',
              found: true,
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool found;
  const _Row({required this.label, required this.value, required this.found});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 13)),
          ),
          Icon(
            found ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 16,
            color: found ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: found ? FontWeight.w600 : FontWeight.w400,
                color: found
                    ? null
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ────────────────────────────────────────────────────────────────
class ScannedReceiptData {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  final String? category;
  final String? note;
  final String rawText;

  ScannedReceiptData({
    this.amount,
    this.merchant,
    this.date,
    this.category,
    this.note,
    required this.rawText,
  });
}
