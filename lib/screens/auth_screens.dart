import 'package:flutter/material.dart';
import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../ui/owner_components.dart';

const bool _allowPreview = bool.fromEnvironment(
  'SH_ENABLE_DEMO', defaultValue: true);

class OwnerSignInScreen extends StatefulWidget {
  const OwnerSignInScreen({super.key});

  @override
  State<OwnerSignInScreen> createState() => _OwnerSignInScreenState();
}

class _OwnerSignInScreenState extends State<OwnerSignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool showPassword = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = OwnerPalette.isDark(context);
    final state = OwnerScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(children: [
                const SizedBox(height: 14),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: dark ? OwnerPalette.darkSurface : OwnerPalette.lightRaised,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.restaurant_menu_rounded,
                      color: OwnerPalette.accent(context), size: 40),
                ),
                const SizedBox(height: 22),
                const Text('SMART HORECA', style: TextStyle(
                    fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                Text('Owner', style: TextStyle(fontSize: 17,
                    color: OwnerPalette.accent(context), fontWeight: FontWeight.w700)),
                const SizedBox(height: 9),
                Text('Ваш бизнес всегда под контролем', style: TextStyle(
                    color: OwnerPalette.muted(context), fontSize: 13)),
                const SizedBox(height: 36),
                Align(alignment: Alignment.centerLeft, child: Text(
                    'Вход в аккаунт', style: Theme.of(context).textTheme.titleLarge)),
                const SizedBox(height: 15),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: !showPassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => showPassword = !showPassword),
                      icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(state.error!, style: const TextStyle(color: OwnerPalette.error)),
                ],
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton(
                    onPressed: state.busy ? null : () {
                      if (email.text.trim().isEmpty || password.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Введите email и пароль')));
                        return;
                      }
                      state.signIn(email.text, password.text);
                    },
                    child: state.busy
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Войти'),
                  ),
                ),
                const SizedBox(height: 12),
                if (!OwnerBackend.configured)
                  const Text('Для настоящего входа требуются настройки Supabase.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                if (_allowPreview) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: state.busy ? null : state.previewSignIn,
                    child: const Text('Посмотреть утверждённый дизайн'),
                  ),
                  const OwnerDemoNotice(),
                ],
                const SizedBox(height: 22),
                Text('Русский     •     Azərbaycan     •     English',
                    style: TextStyle(fontSize: 12,
                        color: OwnerPalette.muted(context))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class OwnerWorkspaceSelectScreen extends StatelessWidget {
  const OwnerWorkspaceSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Мои организации')),
      body: OwnerScreenFrame(children: [
        const OwnerHeading('Выберите организацию',
            caption: 'Доступны только организации вашего аккаунта.'),
        const SizedBox(height: 13),
        if (state.error != null)
          Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(state.error!,
                  style: const TextStyle(color: OwnerPalette.error))),
        for (final w in state.workspaces) ...[
          OwnerCard(
            onTap: state.busy ? null :
              () => state.chooseWorkspace(w['id'].toString()),
            child: Row(children: [
              Icon(Icons.business, color: OwnerPalette.accent(context)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                (w['name'] ?? 'Smart Horeca').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 9),
        ],
        if (state.busy) const Center(child: CircularProgressIndicator()),
      ]),
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
        child: Column(children: [
          Expanded(child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const OwnerHeading('Выберите рестораны',
                  caption: 'В приложении будут показаны данные выбранных подразделений.'),
              const SizedBox(height: 18),
              if (!state.live) const OwnerDemoNotice(),
              const SizedBox(height: 12),
              OwnerCard(child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Выбрать все'),
                subtitle: Text('Доступно: ${state.availableRestaurants.length}'),
                value: state.selectedRestaurants.length ==
                    state.availableRestaurants.length,
                onChanged: (v) => state.selectAllRestaurants(v ?? false),
              )),
              const SizedBox(height: 10),
              for (final restaurant in state.availableRestaurants) ...[
                OwnerCard(child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.storefront,
                      color: OwnerPalette.accent(context)),
                  title: Text(restaurant),
                  value: state.selectedRestaurants.contains(restaurant),
                  onChanged: (v) => state.selectRestaurant(restaurant, v ?? false),
                )),
                const SizedBox(height: 10),
              ],
            ],
          )),
          Padding(padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, height: 52,
              child: FilledButton(
                onPressed: state.selectedRestaurants.isEmpty
                    ? null : state.enterPreview,
                child: Text('Применить (${state.selectedRestaurants.length})'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
