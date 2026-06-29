// import 'dart:convert';
// import 'dart:developer';

// import 'package:expense_tracker_ai/core/router/app_router.dart';
// import 'package:expense_tracker_ai/core/services/gemini_service.dart';
// import 'package:flutter/rendering.dart';
// import 'package:telephony/telephony.dart';

// final Telephony telephony = Telephony.instance;

// @pragma('vm:entry-point')
// Future<void> backgroundMessageHandler(SmsMessage message) async {
//   _parseAndLogMessage(message, isBackground: true);
// }

// Future<void> _handleSms(SmsMessage message) async {
//   final body = message.body ?? '';

//   final prompt = '''
// You are parsing an SMS.

// SMS:
// $body

// Return ONLY valid JSON.

// {
//   "amount": <final payable/grand total number or null>,
//   "merchant": "<store/restaurant/business name or null>",
//   "type": "expense|income|transfer",
//   "category": "<one of: Food & Dining, Transportation, Shopping, Entertainment, Health, Education, Bills & Utilities, Groceries, Rent, Travel, Personal Care, Other>",
//   "date": "<YYYY-MM-DD>",
//   "note": ""
// }
// ''';

//   try {
//     final response = await GeminiService().generateJson(prompt);

//     final parsed = jsonDecode(response);

//     appRouter.push(
//       '/add-transaction',
//       extra: {
//         'type': parsed['type'] ?? 'expense',
//         'prefilled': {
//           'amount': parsed['amount'],
//           'title': parsed['merchant'],
//           'date': parsed['date'],
//           'category': parsed['category'],
//           'note': parsed['note'] ?? '',
//         }
//       },
//     );
//   } catch (e) {
//     debugPrint('SMS Gemini parse failed: $e');
//   }
// }

// void _parseAndLogMessage(
//   SmsMessage message, {
//   bool isBackground = false,
// }) {
//   final sender = message.address ?? "";
//   final body = message.body ?? "";
//   final date = message.date ?? 0;

// debugPrint("====================================");
// debugPrint(isBackground ? "BACKGROUND SMS" : "FOREGROUND SMS");
// debugPrint("Sender : $sender");
// debugPrint("Date   : ${DateTime.fromMillisecondsSinceEpoch(date)}");
// debugPrint("Body   : $body");
// debugPrint("====================================");
// }

// class SmsListenerService {
//   static Future<void> initialize() async {
//     final permissions = await telephony.requestPhoneAndSmsPermissions;

//     if (permissions != true) {
//       debugPrint("SMS Permission denied");
//       return;
//     }

//     telephony.listenIncomingSms(
//       onNewMessage: (SmsMessage message) {
//         _parseAndLogMessage(message);
//         _handleSms(message);
//       },
//       onBackgroundMessage: backgroundMessageHandler,
//       listenInBackground: true,
//     );

//     debugPrint("SMS Listener Started");
//   }
// }

import 'dart:async';
import 'dart:ui';

import 'package:expense_tracker_ai/core/database/app_database.dart';
import 'package:flutter/widgets.dart';
import 'package:telephony/telephony.dart';

final Telephony telephony = Telephony.instance;

class PendingSmsEvent {
  final String? sender;
  final String body;
  final DateTime receivedAt;

  PendingSmsEvent({
    required this.sender,
    required this.body,
    required this.receivedAt,
  });
}

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final db = AppDatabase();

  try {
    await SmsListenerService.storeIncomingSms(
      db: db,
      message: message,
      isBackground: true,
    );
  } catch (e) {
    debugPrint('Background SMS store failed: $e');
  } finally {
    await db.close();
  }
}

class SmsListenerService {
  static final StreamController<PendingSmsEvent> _foregroundSmsController =
      StreamController<PendingSmsEvent>.broadcast();

  static Stream<PendingSmsEvent> get foregroundPendingSmsStream =>
      _foregroundSmsController.stream;

  static Future<void> initialize(AppDatabase db) async {
    final permissions = await telephony.requestSmsPermissions;

    if (permissions != true) {
      debugPrint('SMS permission denied');
      return;
    }

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        debugPrint("====================================");
        debugPrint("Sender : ${message.address}");
        debugPrint(
            "Date   : ${DateTime.fromMillisecondsSinceEpoch(message.date ?? 0)}");
        debugPrint("Body   : ${message.body}");
        debugPrint("====================================");

        final inserted = await storeIncomingSms(
          db: db,
          message: message,
          isBackground: false,
        );

        if (inserted) {
          final body = message.body ?? '';
          final receivedAt = DateTime.fromMillisecondsSinceEpoch(
            message.date ?? DateTime.now().millisecondsSinceEpoch,
          );

          _foregroundSmsController.add(
            PendingSmsEvent(
              sender: message.address,
              body: body,
              receivedAt: receivedAt,
            ),
          );
        }
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );

    debugPrint('SMS listener started');
  }

  static Future<bool> storeIncomingSms({
    required AppDatabase db,
    required SmsMessage message,
    required bool isBackground,
  }) async {
    final sender = message.address;
    final body = message.body ?? '';

    final receivedAt = DateTime.fromMillisecondsSinceEpoch(
      message.date ?? DateTime.now().millisecondsSinceEpoch,
    );

    final inserted = await db.insertPendingSmsNotification(
      sender: sender,
      body: body,
      receivedAt: receivedAt,
    );

    debugPrint(
      inserted
          ? '${isBackground ? "Background" : "Foreground"} transaction SMS saved'
          : '${isBackground ? "Background" : "Foreground"} SMS ignored',
    );

    return inserted;
  }
}
