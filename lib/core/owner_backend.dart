import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerApiException implements Exception {
  final String code;
  final String message;
  final int status;
  const OwnerApiException(this.code, this.message, this.status);

  @override
  String toString() => message;
}

class OwnerBackend {
  static const apiBase = String.fromEnvironment(
    'SH_API_BASE_URL', defaultValue: 'https://smarthoreca.pages.dev');
  static const supabaseUrl = String.fromEnvironment('SH_SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SH_SUPABASE_PUBLISHABLE_KEY');

  static bool get configured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!configured) return;
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static bool get hasSession =>
      configured && client.auth.currentSession != null;

  static Future<void> signIn(String email, String password) async {
    if (!configured) {
      throw const OwnerApiException(
        'NOT_CONFIGURED', 'Авторизация приложения ещё не настроена.', 503);
    }
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  static Future<void> signOut() async {
    if (configured) await client.auth.signOut();
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    String? workspaceId,
    Iterable<String>? departmentIds,
    Map<String, String>? query,
  }) async {
    if (!configured) {
      throw const OwnerApiException('NOT_CONFIGURED',
          'Не настроено подключение приложения.', 503);
    }
    final token = client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const OwnerApiException('SESSION_MISSING', 'Войдите в аккаунт.', 401);
    }
    final uri = Uri.parse('$apiBase$path')
        .replace(queryParameters: query?.isEmpty == true ? null : query);
    if (uri.scheme != 'https') {
      throw const OwnerApiException(
          'HTTPS_REQUIRED', 'Требуется защищённое соединение HTTPS.', 400);
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (workspaceId != null && workspaceId.isNotEmpty) {
      headers['X-SH-Workspace-Id'] = workspaceId;
    }
    if (departmentIds != null) {
      final ids = departmentIds.where((x) => x.isNotEmpty).toList()..sort();
      if (ids.isNotEmpty) headers['X-SH-Department-Ids'] = ids.join(',');
    }
    final response = await http.get(uri, headers: headers).timeout(
          const Duration(seconds: 50),
        );
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      data = decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      throw const OwnerApiException(
          'INVALID_JSON', 'Сервер вернул неверный ответ.', 502);
    }
    if (response.statusCode >= 400 || data['success'] != true) {
      throw OwnerApiException(
        (data['code'] ?? 'HTTP_${response.statusCode}').toString(),
        (data['message'] ?? 'Ошибка загрузки данных.').toString(),
        response.statusCode,
      );
    }
    return data;
  }
}
