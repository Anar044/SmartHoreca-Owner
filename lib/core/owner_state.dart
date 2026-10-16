import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'owner_backend.dart';

enum OwnerStage { signIn, workspaces, restaurants, shell }

class OwnerState extends ChangeNotifier {
  late final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<void> loadPreferences() async {
    try {
      final theme = await _prefs.getString('sh_owner_theme');
      themeMode = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system
      };
      language = await _prefs.getString('sh_owner_language') ?? 'Русский';
      period = await _prefs.getString('sh_owner_period') ?? 'Сегодня';
      final savedFrom = await _prefs.getString('sh_owner_custom_from');
      final savedTo = await _prefs.getString('sh_owner_custom_to');
      customFrom = savedFrom == null ? null : DateTime.tryParse(savedFrom);
      customTo = savedTo == null ? null : DateTime.tryParse(savedTo);
      if (period == 'Период' && (customFrom == null || customTo == null)) {
        period = 'Сегодня';
      }
      notifyListeners();
    } catch (_) {
      // Preferences failure cannot block sign-in or app access.
    }
  }

  ThemeMode themeMode = ThemeMode.system;
  OwnerStage stage = OwnerStage.signIn;
  int tabIndex = 0;
  String language = 'Русский';
  String period = 'Сегодня';
  DateTime? customFrom;
  DateTime? customTo;
  bool busy = false;
  bool live = false;
  String? error;
  String? dashboardError;
  bool dashboardLoading = false;
  double? lastDashboardLoadSeconds;

  String? workspaceId;
  String workspaceName = '';
  List<Map<String, dynamic>> workspaces = [];
  Map<String, dynamic>? summary;
  int _summaryGeneration = 0;

  // Session RAM cache for read-only mobile reports. Scoped by the
  // verified workspace, restaurant IDs and period supplied by each caller.
  // Never persist tenant financial data in phone preferences or across login.
  final Map<String, Map<String,dynamic>> _responseCache = {};
  final Map<String, DateTime> _responseCachedAt = {};

  Map<String,dynamic>? cachedResponse(String key, {
    Duration? maxAge,
  }) {
    final updated=_responseCachedAt[key];
    if (updated == null) return null;
    // Never expire during one session solely because user navigated away.
    // A new workspace, period, or restaurant selection gets a different key.
    // The user explicitly refreshes by pulling down.
    if (maxAge != null &&
        DateTime.now().difference(updated) > maxAge) {
      return null;
    }
    return _responseCache[key];
  }

  void rememberResponse(String key,Map<String,dynamic> value) {
    // Keep each visited report for this session; do not drop a page merely
    // because the user visited several other reports.
    if(_responseCache.length>=48 && !_responseCache.containsKey(key)) {
      final oldest=_responseCachedAt.entries.reduce((a,b)=>
        a.value.isBefore(b.value)?a:b).key;
      _responseCache.remove(oldest);
      _responseCachedAt.remove(oldest);
    }
    _responseCache[key]=value;
    _responseCachedAt[key]=DateTime.now();
  }

  void clearResponseCache() {
    _responseCache.clear();
    _responseCachedAt.clear();
  }

  List<String> availableRestaurants = [
    'Ресторан Баку', 'Jelly Park', 'Jelly Metropark'
  ];
  Set<String> selectedRestaurants = {
    'Ресторан Баку', 'Jelly Park', 'Jelly Metropark'
  };
  Map<String, String> restaurantIdsByName = {};

  Set<String> get selectedRestaurantIds => selectedRestaurants
      .map((name) => restaurantIdsByName[name] ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();

  void setTheme(ThemeMode value) {
    themeMode = value;
    unawaited(_prefs.setString('sh_owner_theme', value.name));
    notifyListeners();
  }
  void setLanguage(String value) {
    language = value;
    unawaited(_prefs.setString('sh_owner_language', value));
    notifyListeners();
  }
  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void setPeriod(String value) {
    if (value == 'Период') return;
    period = value;
    customFrom = null;
    customTo = null;
    unawaited(_prefs.setString('sh_owner_period', value));
    unawaited(_prefs.remove('sh_owner_custom_from'));
    unawaited(_prefs.remove('sh_owner_custom_to'));
    notifyListeners();
    if (live && tabIndex == 0 && stage == OwnerStage.shell) {
      unawaited(loadSummary());
    }
  }

  void setCustomPeriod(DateTime from, DateTime to) {
    var start = DateTime(from.year, from.month, from.day);
    var end = DateTime(to.year, to.month, to.day);
    if (start.isAfter(end)) {
      final swap = start;
      start = end;
      end = swap;
    }
    customFrom = start;
    customTo = end;
    period = 'Период';
    unawaited(_prefs.setString('sh_owner_period', period));
    unawaited(_prefs.setString('sh_owner_custom_from', formatDate(start)));
    unawaited(_prefs.setString('sh_owner_custom_to', formatDate(end)));
    notifyListeners();
    if (live && tabIndex == 0 && stage == OwnerStage.shell) {
      unawaited(loadSummary());
    }
  }

  Future<void> restoreSession() async {
    if (!OwnerBackend.hasSession) return;
    await loadWorkspaces();
  }

  Future<void> signIn(String email, String password) async {
    clearResponseCache();
    busy = true;
    error = null;
    notifyListeners();
    try {
      await OwnerBackend.signIn(email, password);
      await _loadWorkspacesAfterSignIn();
    } catch (e) {
      error = e is OwnerApiException ? e.message : 'Не удалось войти: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> loadWorkspaces() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _loadWorkspacesAfterSignIn();
    } catch (e) {
      error = e is OwnerApiException ? e.message : 'Ошибка загрузки доступа.';
      stage = OwnerStage.signIn;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadWorkspacesAfterSignIn() async {
    final data = await OwnerBackend.getJson('/api/mobile/v1/workspaces');
    final items = (data['workspaces'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((item) => item['mobileEligible'] == true &&
            item['status'] == 'ACTIVE')
        .toList();
    workspaces = items;
    if (items.isEmpty) {
      final accessStatus = (data['accessStatus'] ?? '').toString();
      final message = switch (accessStatus) {
        'NO_MEMBERSHIPS_IN_THIS_ENVIRONMENT' =>
          'В тестовом окружении не найдена ваша организация. '
          'Проверьте подключение Cloudflare Preview к D1 и членство в организации.',
        'NO_ACTIVE_MEMBERSHIPS' =>
          'В тестовом окружении ваша организация или учётная запись '
          'неактивна. Проверьте её статус в Smart Horeca.',
        'OWNER_OR_SYSADMIN_ROLE_REQUIRED' =>
          'У аккаунта нет роли владельца или SYSADMIN (ADMIN) '
          'в активной организации. Проверьте назначенные права.',
        _ =>
          'Нет доступной организации владельца. Проверьте роль '
          'и настройки тестовой базы Smart Horeca.',
      };
      throw OwnerApiException('OWNER_ACCESS_REQUIRED', message, 403);
    }
    if (items.length == 1) {
      await _chooseWorkspace(items.first['id'].toString());
    } else {
      stage = OwnerStage.workspaces;
    }
  }

  Future<void> chooseWorkspace(String id) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _chooseWorkspace(id);
    } catch (e) {
      error = e is OwnerApiException ? e.message : 'Не удалось выбрать организацию.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _chooseWorkspace(String id) async {
    // Explicit workspace header: no dependency on browser cookies.
    final data = await OwnerBackend.getJson(
      '/api/mobile/v1/bootstrap', workspaceId: id);
    final restaurants = (data['restaurants'] as List? ?? [])
        .whereType<Map<String, dynamic>>().toList();
    restaurantIdsByName = {};
    for (final restaurant in restaurants) {
      final id = restaurant['id'].toString();
      final name = (restaurant['name'] ?? id).toString();
      var label = name;
      if (restaurantIdsByName.containsKey(label)) {
        label = '$name · ${id.substring(0, id.length < 7 ? id.length : 7)}';
      }
      restaurantIdsByName[label] = id;
    }
    availableRestaurants = restaurantIdsByName.keys.toList();
    final prior = await _prefs.getStringList('sh_owner_depts_$id');
    selectedRestaurants = prior == null
      ? {...availableRestaurants}
      : {
          for (final entry in restaurantIdsByName.entries)
            if (prior.contains(entry.value)) entry.key
        };
    if (selectedRestaurants.isEmpty) {
      selectedRestaurants = {...availableRestaurants};
    }
    if(workspaceId!=id) clearResponseCache();
    workspaceId = id;
    workspaceName =
        (data['workspace']?['name'] ?? 'Smart Horeca').toString();
    live = true;
    summary = null;
    dashboardError = null;
    // The owner should not have to reconfirm restaurants on every login.
    // First sign-in defaults to all authorized restaurants; an explicit
    // saved selection is restored by immutable department IDs above.
    stage = availableRestaurants.isEmpty
        ? OwnerStage.restaurants
        : OwnerStage.shell;
    if (stage == OwnerStage.shell) unawaited(loadSummary());
  }

  void showRestaurants() {
    ++_summaryGeneration;
    stage = OwnerStage.restaurants;
    notifyListeners();
  }

  void previewSignIn() {
    // Explicit design preview, never a real authenticated session.
    live = false;
    workspaceId = null;
    error = null;
    stage = OwnerStage.restaurants;
    notifyListeners();
  }

  void enterPreview() {
    if (selectedRestaurants.isEmpty) return;
    if (live && workspaceId != null) {
      unawaited(_prefs.setStringList('sh_owner_depts_$workspaceId',
          selectedRestaurantIds.toList()));
    }
    stage = OwnerStage.shell;
    notifyListeners();
    if (live) loadSummary();
  }

  void selectRestaurant(String value, bool selected) {
    if (selected) {
      selectedRestaurants.add(value);
    } else {
      selectedRestaurants.remove(value);
    }
    if (live && workspaceId != null && selectedRestaurantIds.isNotEmpty) {
      unawaited(_prefs.setStringList(
          'sh_owner_depts_$workspaceId', selectedRestaurantIds.toList()));
    }
    notifyListeners();
    if (live && stage == OwnerStage.shell && tabIndex == 0 &&
        selectedRestaurantIds.isNotEmpty) {
      unawaited(loadSummary());
    }
  }

  void selectAllRestaurants(bool selected) {
    selectedRestaurants.clear();
    if (selected) selectedRestaurants.addAll(availableRestaurants);
    if (live && workspaceId != null && selectedRestaurantIds.isNotEmpty) {
      unawaited(_prefs.setStringList(
          'sh_owner_depts_$workspaceId', selectedRestaurantIds.toList()));
    }
    notifyListeners();
    if (live && stage == OwnerStage.shell && tabIndex == 0 &&
        selectedRestaurantIds.isNotEmpty) {
      unawaited(loadSummary());
    }
  }

  Future<void> loadSummary() async {
    if (!live || workspaceId == null || selectedRestaurantIds.isEmpty) return;
    final generation = ++_summaryGeneration;
    final watch = Stopwatch()..start();
    dashboardLoading = true;
    dashboardError = null;
    summary = null; // Never show stale or demonstration finance data as live.
    notifyListeners();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final to = period == 'Период'
        ? (customTo ?? today)
        : period == 'Вчера' ? today.subtract(const Duration(days: 1)) : today;
    final from = period == 'Период'
        ? (customFrom ?? to)
        : switch (period) {
            '7 дней' => to.subtract(const Duration(days: 6)),
            'Месяц' => to.subtract(const Duration(days: 29)),
            _ => to,
          };
    try {
      final result = await OwnerBackend.getJson(
        '/api/mobile/v1/summary',
        workspaceId: workspaceId!,
        departmentIds: selectedRestaurantIds,
        // Only the default "Сегодня" dashboard uses active cash sessions.
        // Explicit earlier date ranges keep their original calendar meaning.
        query: {'from': formatDate(from), 'to': formatDate(to),
          'mode': period == 'Сегодня' ? 'operational' : 'calendar'},
        retryTransient: false, // avoid repeated full-network OLAP runs
      );
      if (generation == _summaryGeneration && live && stage == OwnerStage.shell) {
        summary = result;
      }
    } catch (e) {
      if (generation == _summaryGeneration) {
        dashboardError =
            e is OwnerApiException ? e.message : 'Ошибка получения данных SH.';
      }
    } finally {
      if (generation == _summaryGeneration) {
        dashboardLoading = false;
        lastDashboardLoadSeconds = watch.elapsedMilliseconds / 1000;
        notifyListeners();
      }
    }
  }

  void setTab(int value) {
    tabIndex = value;
    notifyListeners();
    // Initial login and explicit selection changes load the dashboard.
    // Navigating tabs is presentation-only: no network I/O here.
  }

  Future<void> signOut() async {
    await OwnerBackend.signOut();
    logOutPreview();
  }

  void logOutPreview() {
    clearResponseCache();
    ++_summaryGeneration;
    live = false;
    stage = OwnerStage.signIn;
    tabIndex = 0;
    workspaceId = null;
    summary = null;
    error = null;
    notifyListeners();
  }
}

class OwnerScope extends InheritedNotifier<OwnerState> {
  const OwnerScope({super.key, required OwnerState state, required super.child})
      : super(notifier: state);

  static OwnerState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OwnerScope>();
    assert(scope != null, 'OwnerScope not found');
    return scope!.notifier!;
  }
}
