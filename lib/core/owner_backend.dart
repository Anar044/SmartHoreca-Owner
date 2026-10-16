import 'dart:async';
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
      publishableKey: supabasePublishableKey,
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

  static bool _transient(int status) =>
      status == 502 || status == 503 || status == 504;

  // Both mobile and Cloudflare Functions can return a non-JSON 503 page.
  // Display the actual HTTP status without revealing HTML or private headers.
  static Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Avoid passing an upstream HTML error page into the UI.
    }
    final status = response.statusCode;
    if (data == null) {
      throw OwnerApiException(
        'HTTP_$status',
        status >= 500
            ? 'Сервер Smart Horeca временно недоступен (HTTP $status). '
              'Повторите запрос позже.'
            : 'Сервер Smart Horeca вернул неверный ответ (HTTP $status).',
        status,
      );
    }
    if (status >= 400 || data['success'] != true) {
      final serverMessage = (data['message'] ?? '').toString().trim();
      final fallback = _transient(status)
          ? 'Smart Horeca API временно недоступен (HTTP $status). '
            'Попробуйте обновить данные.'
          : status == 401
            ? 'Сессия истекла. Войдите в аккаунт заново.'
            : status == 403
              ? 'Нет доступа к выбранной организации или операции.'
              : 'Ошибка запроса Smart Horeca (HTTP $status).';
      throw OwnerApiException(
        (data['code'] ?? 'HTTP_$status').toString(),
        serverMessage.isNotEmpty ? serverMessage : fallback,
        status,
      );
    }
    return data;
  }

  static Future<Map<String, dynamic>> postJson(
    String path, {
    required String workspaceId,
    required Iterable<String> departmentIds,
    required Map<String, dynamic> payload,
  }) async {
    if (!configured) {
      throw const OwnerApiException('NOT_CONFIGURED',
          'Не настроено подключение приложения.', 503);
    }
    final token = client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const OwnerApiException('SESSION_MISSING', 'Войдите в аккаунт.', 401);
    }
    final uri = Uri.parse('$apiBase$path');
    if (uri.scheme != 'https') {
      throw const OwnerApiException(
          'HTTPS_REQUIRED', 'Требуется защищённое соединение HTTPS.', 400);
    }
    try {
      final result = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-SH-Workspace-Id': workspaceId,
        'X-SH-Department-Ids': (departmentIds.toList()..sort()).join(','),
      }, body: jsonEncode(payload)).timeout(const Duration(seconds: 120));
      // AI POST is not retried automatically: resending could create duplicate
      // messages if the server processed the first request.
      return _decodeResponse(result);
    } on TimeoutException {
      throw const OwnerApiException('API_TIMEOUT',
        'Сервер Smart Horeca не ответил вовремя. '
        'Проверьте историю диалога перед повторной отправкой.', 504);
    } on http.ClientException {
      throw const OwnerApiException('NETWORK_UNAVAILABLE',
        'Не удалось подключиться к Smart Horeca. Проверьте сеть.', 503);
    }
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    String? workspaceId,
    Iterable<String>? departmentIds,
    Map<String, String>? query,
    bool retryTransient = true,
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
    // Retry only safe, idempotent reads. 401/403 must never be treated
    // as temporary failures or bypassed; POST requests are never retried.
    final maxAttempts = retryTransient ? 3 : 1;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final result = await http.get(uri, headers: headers)
            .timeout(const Duration(seconds: 50));
        if (_transient(result.statusCode) && attempt < maxAttempts - 1) {
          await Future<void>.delayed(
            Duration(milliseconds: attempt == 0 ? 500 : 1400));
          continue;
        }
        return _decodeResponse(result);
      } on TimeoutException {
        if (attempt == maxAttempts - 1) {
          throw const OwnerApiException('API_TIMEOUT',
            'Превышено время ожидания Smart Horeca. '
            'Сервер или соединение временно недоступны.', 504);
        }
      } on http.ClientException {
        if (attempt == maxAttempts - 1) {
          throw const OwnerApiException('NETWORK_UNAVAILABLE',
            'Не удалось связаться с Smart Horeca. Проверьте сеть.', 503);
        }
      }
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 500 : 1400));
    }
    throw const OwnerApiException('RETRY_EXHAUSTED',
      'Не удалось получить данные Smart Horeca.', 503);
  }
}
