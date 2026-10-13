import 'package:flutter/material.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../ui/owner_components.dart';

class OwnerSignInScreen extends StatelessWidget {
  const OwnerSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = OwnerPalette.isDark(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: dark ? OwnerPalette.darkSurface : OwnerPalette.lightRaised,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.restaurant_menu_rounded, color: OwnerPalette.accent(context), size: 40),
                  ),
                  const SizedBox(height: 22),
                  const Text('SMART HORECA', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  Text('Owner', style: TextStyle(fontSize: 17, color: OwnerPalette.accent(context), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 9),
                  Text('Ваш бизнес всегда под контролем', style: TextStyle(color: OwnerPalette.muted(context), fontSize: 13)),
                  const SizedBox(height: 36),
                  Align(alignment: Alignment.centerLeft, child: Text('Вход в аккаунт', style: Theme.of(context).textTheme.titleLarge)),
                  const SizedBox(height: 15),
                  const TextField(
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: [AutofillHints.email],
                    decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: 12),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Пароль', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 13),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Подключение авторизации — отдельный этап'),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => OwnerScope.of(context).previewSignIn(),
                      child: const Text('Посмотреть утверждённый дизайн'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const OwnerDemoNotice(),
                  const SizedBox(height: 22),
                  Text('Русский     •     Azərbaycan     •     English',
                      style: TextStyle(fontSize: 12, color: OwnerPalette.muted(context))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OwnerRestaurantSelectScreen extends StatelessWidget {
  const OwnerRestaurantSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор ресторанов')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const OwnerHeading('Выберите рестораны',
                      caption: 'В приложении будут показаны данные выбранных подразделений.'),
                  const SizedBox(height: 18),
                  const OwnerDemoNotice(),
                  const SizedBox(height: 16),
                  OwnerCard(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Выбрать все'),
                      subtitle: Text('Доступно: ${state.availableRestaurants.length}'),
                      value: state.selectedRestaurants.length == state.availableRestaurants.length,
                      onChanged: (value) => state.selectAllRestaurants(value ?? false),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final restaurant in state.availableRestaurants) ...[
                    OwnerCard(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(Icons.storefront, color: OwnerPalette.accent(context)),
                        title: Text(restaurant),
                        value: state.selectedRestaurants.contains(restaurant),
                        onChanged: (value) => state.selectRestaurant(restaurant, value ?? false),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: state.selectedRestaurants.isEmpty ? null : state.enterPreview,
                  child: Text('Применить (${state.selectedRestaurants.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
