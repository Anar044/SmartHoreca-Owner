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
  bool busy = false;
  bool live = false;
  String? error;
  String? dashboardError;
  bool dashboardLoading = false;

  String? workspaceId;
  String workspaceName = '';
  List<Map<String, dynamic>> workspaces = [];
  Map<String, dynamic>? summary;
  int _summaryGeneration = 0;

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
  void setPeriod(String value) {
    period = value;
    unawaited(_prefs.setString('sh_owner_period', value));
    notifyListeners();
    // Reports refresh themselves for the selected CHAIN/period. Do not
    // duplicate their request with a hidden dashboard OLAP request.
    if (live && tabIndex == 0 && stage == OwnerStage.shell) {
      unawaited(loadSummary());
    }
  }

  Future<void> restoreSession() async {
    if (!OwnerBackend.hasSession) return;
    await loadWorkspaces();
  }

  Future<void> signIn(String email, String password) async {
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
    dashboardLoading = true;
    dashboardError = null;
    summary = null; // Never show stale or demonstration finance data as live.
    notifyListeners();
    final now = DateTime.now();
    String fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final to = period == 'Вчера' ? now.subtract(const Duration(days: 1)) : now;
    final from = switch (period) {
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
        query: {'from': fmt(from), 'to': fmt(to),
          'mode': period == 'Сегодня' ? 'operational' : 'calendar'},
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
        notifyListeners();
      }
    }
  }

  void setTab(int value) {
    final changed = tabIndex != value;
    tabIndex = value;
    notifyListeners();
    // Refresh dashboard once when returning from a report's date selection.
    if (changed && value == 0 && live && stage == OwnerStage.shell) {
      unawaited(loadSummary());
    }
  }

  Future<void> signOut() async {
    await OwnerBackend.signOut();
    logOutPreview();
  }

  void logOutPreview() {
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
