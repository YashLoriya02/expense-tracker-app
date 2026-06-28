import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String apiKeyPrefsKey = 'gemini_api_key';
  static const String defaultModel = 'gemini-3.1-flash-lite';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(apiKeyPrefsKey)?.trim();
    if (key == null || key.isEmpty) return null;

    return key;
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiKeyPrefsKey, key.trim());
  }

  Future<bool> isConfigured() async => (await getApiKey()) != null;

  Future<String> generateJson(
    String prompt, {
    String model = defaultModel,
    int maxOutputTokens = 700,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null) {
      throw StateError(
        'Gemini API key is not configured. Please add it in Settings.',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ],
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': maxOutputTokens,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    final text = parts
        ?.map(
            (p) => p is Map<String, dynamic> ? p['text']?.toString() ?? '' : '')
        .join('\n')
        .trim();

    if (text == null || text.isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    return extractJson(text);
  }

  static String extractJson(String text) {
    var cleaned = text.replaceAll(RegExp(r'```json|```'), '').trim();
    final firstObject = cleaned.indexOf('{');
    final firstArray = cleaned.indexOf('[');

    if (firstObject == -1 && firstArray == -1) return cleaned;

    final startsWithArray =
        firstArray != -1 && (firstObject == -1 || firstArray < firstObject);
    final start = startsWithArray ? firstArray : firstObject;
    final endChar = startsWithArray ? ']' : '}';
    final end = cleaned.lastIndexOf(endChar);

    if (end > start) cleaned = cleaned.substring(start, end + 1);
    return cleaned.trim();
  }
}
