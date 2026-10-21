import 'package:flutter/material.dart';
import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../core/owner_l10n.dart';
import '../ui/owner_components.dart';
import '../ui/owner_brand.dart';

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
    final state = OwnerScope.of(context);
    String tr(String ru) => OwnerL10n.tr(state.language, ru);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(children: [
                const SizedBox(height: 14),
                const OwnerBrandMark(size: 96),
                const SizedBox(height: 22),
                const Text('SMART HORECA', style: TextStyle(
                    fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                Text('Owner', style: TextStyle(fontSize: 17,
                    color: OwnerPalette.accent(context), fontWeight: FontWeight.w700)),
                const SizedBox(height: 9),
                Text(tr('Ваш бизнес всегда под контролем'), style: TextStyle(
                    color: OwnerPalette.muted(context), fontSize: 13)),
                const SizedBox(height: 36),
                Align(alignment: Alignment.centerLeft, child: Text(
                    tr('Вход в аккаунт'), style: Theme.of(context).textTheme.titleLarge)),
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
                    labelText: tr('Пароль'),
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
                  if (OwnerBackend.hasSession) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: state.busy ? null : state.loadWorkspaces,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить загрузку организаций'),
                    ),
                  ],
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
                        : Text(tr('Войти')),
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
                    child: Text(tr('Посмотреть утверждённый дизайн')),
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

class OwnerRestaurantSelectScreen extends StatefulWidget {
  const OwnerRestaurantSelectScreen({super.key});
  @override
  State<OwnerRestaurantSelectScreen> createState() => _OwnerRestaurantSelectScreenState();
}

class _OwnerRestaurantSelectScreenState extends State<OwnerRestaurantSelectScreen> {
  String _filter='all';
  String _query='';
  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    final visible=state.availableRestaurants.where((label) {
      final id=state.restaurantIdsByName[label];
      final evidence=state.departmentEvidence[id];
      if(_query.isNotEmpty && !label.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if(_filter=='working') return evidence?.evidenceOfWork==true;
      if(_filter=='unverified') return evidence!=null && !evidence.evidenceOfWork;
      return true;
    }).toList();
    String tr(String ru) => OwnerL10n.tr(state.language, ru);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Выбор ресторанов'))),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const OwnerHeading('Выберите рестораны',
                  caption: 'В приложении будут показаны данные выбранных подразделений.'),
              const SizedBox(height: 18),
              if (!state.live) const OwnerDemoNotice(),
              if (state.live) ...[
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: Text(
                    'Признаки работы: продажи за последние 30 дней, '
                    'группы и кассы.',
                    style: TextStyle(fontSize: 12,
                      color: OwnerPalette.muted(context)),
                  )),
                  IconButton(
                    tooltip: 'Обновить признаки работы',
                    onPressed: state.activityLoading
                      ? null : () => state.loadRestaurantActivity(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ]),
                if(state.activityLoading) const LinearProgressIndicator(),
                if(state.activityWarning!=null)
                  Padding(padding:const EdgeInsets.symmetric(vertical:7),
                    child:Text(state.activityWarning!,
                      style:TextStyle(fontSize:12,
                        color:OwnerPalette.muted(context)))),
                const SizedBox(height: 7),
                TextField(
                  onChanged:(v)=>setState(()=>_query=v.trim()),
                  decoration:const InputDecoration(
                    prefixIcon:Icon(Icons.search_rounded),
                    hintText:'Найти подразделение',
                    isDense:true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing:7,runSpacing:7,children:[
                  ChoiceChip(label:const Text('Все'),
                    selected:_filter=='all',showCheckmark:false,
                    onSelected:(_)=>setState(()=>_filter='all')),
                  ChoiceChip(label:const Text('С признаками работы'),
                    selected:_filter=='working',showCheckmark:false,
                    onSelected:(_)=>setState(()=>_filter='working')),
                  ChoiceChip(label:const Text('Без подтверждения'),
                    selected:_filter=='unverified',showCheckmark:false,
                    onSelected:(_)=>setState(()=>_filter='unverified')),
                ]),
                if(state.departmentEvidence.values.any((x)=>x.evidenceOfWork))
                  Align(alignment:Alignment.centerRight,
                    child:TextButton.icon(
                      onPressed:state.selectRestaurantsWithEvidence,
                      icon:const Icon(Icons.done_all_rounded,size:17),
                      label:const Text('Выбрать с признаками работы'),
                    )),
              ],
              const SizedBox(height: 12),
              OwnerCard(child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Выбрать все')),
                subtitle: Text('${tr('Доступно')}: ${state.availableRestaurants.length}'),
                value: state.selectedRestaurants.length ==
                    state.availableRestaurants.length,
                onChanged: (v) => state.selectAllRestaurants(v ?? false),
              )),
              const SizedBox(height: 10),
              if(visible.isEmpty) const Padding(
                padding:EdgeInsets.symmetric(vertical:14),
                child:Text('В этом фильтре подразделения не найдены.'),
              ),
              for (final restaurant in visible) ...[
                Builder(builder:(context) {
                  final id=state.restaurantIdsByName[restaurant];
                  final info=state.departmentEvidence[id];
                  return OwnerCard(child: CheckboxListTile(
                    contentPadding:EdgeInsets.zero,
                    secondary:Icon(
                      info?.activity=='SALES_CONFIRMED'
                        ? Icons.trending_up_rounded
                        : info?.evidenceOfWork==true
                          ? Icons.point_of_sale_rounded
                          : Icons.storefront_outlined,
                      color:info?.activity=='SALES_CONFIRMED'
                        ? OwnerPalette.green
                        : OwnerPalette.accent(context)),
                    title:Text(restaurant),
                    subtitle:info==null ? null:Padding(
                      padding:const EdgeInsets.only(top:3),
                      child:Column(
                        crossAxisAlignment:CrossAxisAlignment.start,
                        children:[
                          Text(info.shortStatus,
                            style:const TextStyle(fontSize:12)),
                          Text(info.topologySummary,
                            style:TextStyle(fontSize:11,
                              color:OwnerPalette.muted(context))),
                          if(info.recentRevenue!=null)
                            Text('Выручка за 30 дней: '
                              '${info.recentRevenue!.toStringAsFixed(2)} AZN',
                              style:TextStyle(fontSize:11,
                                color:OwnerPalette.muted(context))),
                        ],
                      ),
                    ),
                    value:state.selectedRestaurants.contains(restaurant),
                    onChanged:(v)=>state.selectRestaurant(restaurant,v??false),
                  ));
                }),
                const SizedBox(height: 10),
              ],
            ],
          )),
          Padding(padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, height: 52,
              child: FilledButton(
                onPressed: state.selectedRestaurants.isEmpty
                    ? null : state.enterPreview,
                child: Text('${tr('Применить')} (${state.selectedRestaurants.length})'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
