import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'owner_voice_recording.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'owner_session_policy.dart';

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
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
        persistSession: true,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static bool get hasSession =>
      configured && client.auth.currentSession != null;

  static Future<String>? _refreshInFlight;

  /// Supabase Flutter restores the last persisted session before it has
  /// necessarily refreshed its expired access token on cold iOS launch.
  /// Coalesce concurrent refresh requests (dashboard, AI, notifications).
  static Future<String> freshAccessToken({bool forceRefresh = false}) async {
    if (!configured) {
      throw const OwnerApiException('NOT_CONFIGURED',
          'Не настроено подключение приложения.', 503);
    }
    final session = client.auth.currentSession;
    if (session == null) {
      throw const OwnerApiException('SESSION_MISSING',
          'Войдите в аккаунт.', 401);
    }
    if (!forceRefresh && !ownerSessionNeedsRenewal(
        isExpired: session.isExpired,
        expiresAt: session.expiresAt,
        nowSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000)) {
      return session.accessToken;
    }
    if (_refreshInFlight != null) return _refreshInFlight!;
    final future = () async {
      try {
        final refreshed = (await client.auth.refreshSession()).session;
        final token = refreshed?.accessToken;
        if (token == null || token.isEmpty) {
          throw const OwnerApiException('SESSION_REFRESH_REQUIRED',
              'Не удалось подтвердить сессию. Попробуйте обновить данные.', 401);
        }
        return token;
      } on OwnerApiException {
        rethrow;
      } on AuthException catch (e) {
        // Invalid refresh credentials genuinely require another login.
        // Network failures must not erase the previously persisted session.
        final reason=e.message.toLowerCase();
        if (reason.contains('invalid refresh token') ||
            reason.contains('refresh token not found') ||
            reason.contains('session not found')) {
          throw const OwnerApiException('SESSION_RELOGIN_REQUIRED',
              'Срок действия авторизации завершился. Войдите повторно.', 401);
        }
        throw const OwnerApiException('SESSION_REFRESH_UNAVAILABLE',
            'Не удалось обновить авторизацию. Проверьте соединение и повторите.',
            503);
      } catch (_) {
        throw const OwnerApiException('SESSION_REFRESH_UNAVAILABLE',
            'Не удалось обновить авторизацию. Проверьте соединение и повторите.',
            503);
      }
    }();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

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
            ? 'Сервис Smart Horeca временно недоступен. '
              'Повторите запрос позже.'
            : 'Не удалось получить данные. Попробуйте позже.',
        status,
      );
    }
    if (status >= 400 || data['success'] != true) {
      final serverMessage = (data['message'] ?? '').toString().trim();
      final fallback = _transient(status)
          ? 'Сервис Smart Horeca временно недоступен. '
            'Попробуйте обновить данные.'
          : status == 401
            ? 'Сессия истекла. Войдите в аккаунт заново.'
            : status == 403
              ? 'Нет доступа к выбранной организации или операции.'
              : 'Не удалось выполнить запрос. Попробуйте позже.';
      throw OwnerApiException(
        (data['code'] ?? 'HTTP_$status').toString(),
        serverMessage.isNotEmpty &&
        !RegExp(r'HTTP|REST_API|Supabase|Cloudflare|D1|Exception|traceback|stacktrace|sql|endpoint', caseSensitive: false)
          .hasMatch(serverMessage)
            ? serverMessage : fallback,
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
    final token = await freshAccessToken();
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

  /// Explicitly recorded, format-checked WAV is uploaded through the owner's
  /// authenticated connection. Do not infer the language from UI/phone locale.
  static Future<String> transcribeVoice(String audioPath) async {
    if (!configured) {
      throw const OwnerApiException('NOT_CONFIGURED',
        'Не настроено подключение приложения.', 503);
    }
    final uri = Uri.parse('$apiBase/api/ai-assistant-transcribe');
    if (uri.scheme != 'https') {
      throw const OwnerApiException(
        'HTTPS_REQUIRED', 'Требуется защищённое соединение HTTPS.', 400);
    }
    if (!await OwnerVoiceRecording.hasValidWavFile(audioPath)) {
      throw const OwnerApiException('INVALID_WAV_RECORDING',
        'Аудиозапись повреждена или слишком короткая. Запишите вопрос ещё раз.',
        422);
    }
    final token = await freshAccessToken();
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'audio', audioPath,
        filename: 'owner-question.wav',
        contentType: MediaType('audio', 'wav')));
      final streamed = await request.send()
        .timeout(const Duration(seconds: 65));
      final response = await http.Response.fromStream(streamed);
      final data = _decodeResponse(response);
      final text = (data['text'] ?? '').toString().trim();
      if (text.isEmpty) {
        throw const OwnerApiException('EMPTY_TRANSCRIPT',
          'Голосовой вопрос не распознан. Попробуйте ещё раз.', 422);
      }
      return text;
    } on OwnerApiException catch (e) {
      final reason = e.message.toLowerCase();
      if (reason.contains('audio file might be corrupted') ||
          reason.contains('unsupported audio') ||
          reason.contains('invalid audio file')) {
        throw const OwnerApiException('INVALID_AUDIO_FORMAT',
          'Сервис не смог прочитать запись. Попробуйте записать вопрос ещё раз.',
          422);
      }
      rethrow;
    } on TimeoutException {
      throw const OwnerApiException('TRANSCRIBE_TIMEOUT',
        'Распознавание речи заняло слишком много времени. Попробуйте ещё раз.',
        504);
    } on http.ClientException {
      throw const OwnerApiException('TRANSCRIBE_NETWORK',
        'Не удалось отправить аудио для распознавания. Проверьте сеть.', 503);
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
    var token = await freshAccessToken();
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
    // Refresh once on 401 for safe reads. 403 is an actual permission denial,
    // never retried. POST is never replayed (it may create an AI message).
    final maxTransientAttempts = retryTransient ? 3 : 1;
    var transientAttempts = 0;
    var renewedAfter401 = false;
    while (true) {
      try {
        final result = await http.get(uri, headers: headers)
            .timeout(const Duration(seconds: 50));
        if (result.statusCode == 401 && !renewedAfter401) {
          renewedAfter401 = true;
          token = await freshAccessToken(forceRefresh: true);
          headers['Authorization'] = 'Bearer $token';
          continue;
        }
        if (_transient(result.statusCode) &&
            transientAttempts < maxTransientAttempts - 1) {
          await Future<void>.delayed(Duration(
            milliseconds: transientAttempts == 0 ? 500 : 1400));
          transientAttempts++;
          continue;
        }
        return _decodeResponse(result);
      } on TimeoutException {
        if (transientAttempts >= maxTransientAttempts - 1) {
          throw const OwnerApiException('API_TIMEOUT',
            'Превышено время ожидания Smart Horeca. '
            'Сервер или соединение временно недоступны.', 504);
        }
      } on http.ClientException {
        if (transientAttempts >= maxTransientAttempts - 1) {
          throw const OwnerApiException('NETWORK_UNAVAILABLE',
            'Не удалось связаться с Smart Horeca. Проверьте сеть.', 503);
        }
      }
      await Future<void>.delayed(Duration(
        milliseconds: transientAttempts == 0 ? 500 : 1400));
      transientAttempts++;
    }
  }
}
