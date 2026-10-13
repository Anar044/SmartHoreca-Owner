import 'package:flutter/material.dart';

enum OwnerStage { signIn, restaurants, shell }

class OwnerState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  OwnerStage stage = OwnerStage.signIn;
  int tabIndex = 0;
  String language = 'Русский';
  String period = 'Сегодня';

  final List<String> availableRestaurants = const [
    'Ресторан Баку',
    'Jelly Park',
    'Jelly Metropark',
  ];
  final Set<String> selectedRestaurants = {
    'Ресторан Баку',
    'Jelly Park',
    'Jelly Metropark',
  };

  void setTheme(ThemeMode next) {
    themeMode = next;
    notifyListeners();
  }

  void setLanguage(String value) {
    language = value;
    notifyListeners();
  }

  void setPeriod(String value) {
    period = value;
    notifyListeners();
  }

  void showRestaurants() {
    stage = OwnerStage.restaurants;
    notifyListeners();
  }

  void previewSignIn() {
    // DESIGN PREVIEW ONLY. This deliberately does not perform authentication.
    stage = OwnerStage.restaurants;
    notifyListeners();
  }

  void enterPreview() {
    if (selectedRestaurants.isEmpty) return;
    stage = OwnerStage.shell;
    notifyListeners();
  }

  void selectRestaurant(String value, bool selected) {
    if (selected) {
      selectedRestaurants.add(value);
    } else {
      selectedRestaurants.remove(value);
    }
    notifyListeners();
  }

  void selectAllRestaurants(bool selected) {
    selectedRestaurants.clear();
    if (selected) selectedRestaurants.addAll(availableRestaurants);
    notifyListeners();
  }

  void setTab(int value) {
    tabIndex = value;
    notifyListeners();
  }

  void logOutPreview() {
    stage = OwnerStage.signIn;
    tabIndex = 0;
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
