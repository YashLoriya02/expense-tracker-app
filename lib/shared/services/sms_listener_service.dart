import 'dart:convert';
import 'dart:developer';

import 'package:expense_tracker_ai/core/router/app_router.dart';
import 'package:expense_tracker_ai/core/services/gemini_service.dart';
import 'package:flutter/rendering.dart';
import 'package:telephony/telephony.dart';

final Telephony telephony = Telephony.instance;

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  _parseAndLogMessage(message, isBackground: true);
}

Future<void> _handleSms(SmsMessage message) async {
  final body = message.body ?? '';

  final prompt = '''
You are parsing an SMS.

SMS:
$body

Return ONLY valid JSON.

{
  "amount": <final payable/grand total number or null>,
  "merchant": "<store/restaurant/business name or null>",
  "type": "expense|income|transfer",
  "category": "<one of: Food & Dining, Transportation, Shopping, Entertainment, Health, Education, Bills & Utilities, Groceries, Rent, Travel, Personal Care, Other>",
  "date": "<YYYY-MM-DD>",
  "note": ""
}
''';

  try {
    final response = await GeminiService().generateJson(prompt);

    final parsed = jsonDecode(response);

    appRouter.push(
      '/add-transaction',
      extra: {
        'type': parsed['type'] ?? 'expense',
        'prefilled': {
          'amount': parsed['amount'],
          'title': parsed['merchant'],
          'date': parsed['date'],
          'category': parsed['category'],
          'note': parsed['note'] ?? '',
        }
      },
    );
  } catch (e) {
    debugPrint('SMS Gemini parse failed: $e');
  }
}

void _parseAndLogMessage(
  SmsMessage message, {
  bool isBackground = false,
}) {
  final sender = message.address ?? "";
  final body = message.body ?? "";
  final date = message.date ?? 0;

  debugPrint("====================================");
  debugPrint(isBackground ? "BACKGROUND SMS" : "FOREGROUND SMS");
  debugPrint("Sender : $sender");
  debugPrint("Date   : ${DateTime.fromMillisecondsSinceEpoch(date)}");
  debugPrint("Body   : $body");
  debugPrint("====================================");
}

class SmsListenerService {
  static Future<void> initialize() async {
    final permissions = await telephony.requestPhoneAndSmsPermissions;

    if (permissions != true) {
      log("SMS Permission denied");
      return;
    }

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        _parseAndLogMessage(message);
        _handleSms(message);
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );

    log("SMS Listener Started");
  }
}
