import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import 'export_service.dart';

class DriveBackupService {
  static const _driveFileScope = 'https://www.googleapis.com/auth/drive.file';

  Future<String> backupToDrive(AppDatabase db) async {
    final backupFile = await ExportService().createJsonBackup(db);
    final signIn = GoogleSignIn.instance;
    await signIn.initialize();

    GoogleSignInAccount? account;
    try {
      account = await signIn.attemptLightweightAuthentication();
    } catch (_) {
      account = null;
    }

    account ??= await signIn.authenticate();

    var authorization = await account.authorizationClient
        .authorizationForScopes([_driveFileScope]);
    authorization ??=
        await account.authorizationClient.authorizeScopes([_driveFileScope]);

    final accessToken = authorization.accessToken;
    if (accessToken.isEmpty)
      throw Exception('Google Drive authorization failed.');

    final boundary = 'expense_tracker_${DateTime.now().millisecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': backupFile.uri.pathSegments.last,
      'mimeType': 'application/json',
    });

    final body = <int>[];
    void addString(String value) => body.addAll(utf8.encode(value));

    addString('--$boundary\r\n');
    addString('Content-Type: application/json; charset=UTF-8\r\n\r\n');
    addString(metadata);
    addString('\r\n--$boundary\r\n');
    addString('Content-Type: application/json\r\n\r\n');
    body.addAll(await backupFile.readAsBytes());
    addString('\r\n--$boundary--');

    final response = await http.post(
      Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Drive backup failed ${response.statusCode}: ${response.body}');
    }

    final uploaded = jsonDecode(response.body) as Map<String, dynamic>;
    return uploaded['name']?.toString() ?? backupFile.uri.pathSegments.last;
  }
}
