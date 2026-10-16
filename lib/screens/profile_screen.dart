import 'package:flutter/material.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../core/owner_l10n.dart';
import '../ui/owner_components.dart';
import '../core/owner_backend.dart';
import '../core/owner_push_service.dart';
import 'owner_live_reports.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    String tr(String value) => OwnerL10n.tr(state.language, value);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Профиль'))),
      body: OwnerScreenFrame(children: [
        OwnerCard(child: Row(children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: OwnerPalette.accent(context),
            child: const Icon(Icons.person_outline, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.live ? (OwnerBackend.client.auth.currentUser?.email ?? state.workspaceName) : tr('Владелец ресторана'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(state.live ? state.workspaceName : tr('Настройки владельца'),
              style: const TextStyle(fontSize: 11)),
          ])),
        ])),
        const SizedBox(height: 12),
        OwnerCard(
          onTap: () {
            Navigator.pop(context);
            state.showRestaurants();
          },
          child: ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.store_outlined),
            title: Text(tr('Мои рестораны')),
            trailing: Text('${state.selectedRestaurants.length}'),
          ),
        ),
        const SizedBox(height: 12),
        OwnerHeading(tr('Тема оформления')),
        const SizedBox(height: 9),
        OwnerCard(child: RadioGroup<ThemeMode>(
          groupValue: state.themeMode,
          onChanged: (value) { if (value != null) state.setTheme(value); },
          child: Column(children: [
            for (final row in const [
              (ThemeMode.light, 'Светлая', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Тёмная', Icons.dark_mode_outlined),
              (ThemeMode.system, 'Автоматически', Icons.settings_brightness_outlined),
            ])
              RadioListTile<ThemeMode>(
                value: row.$1,
                title: Text(tr(row.$2)),
                secondary: Icon(row.$3),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
          ]),
        )),
        const SizedBox(height: 13),
        OwnerHeading(tr('Язык интерфейса')),
        const SizedBox(height: 8),
        OwnerCard(child: RadioGroup<String>(
          groupValue: state.language,
          onChanged: (value) {
            if (value != null) {
              // Change language without a persistent floating snackbar that
              // covers bottom navigation and check details.
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              state.setLanguage(value);
            }
          },
          child: Column(children: [
            for (final value in ['Русский', 'Azərbaycan', 'English'])
              RadioListTile<String>(
                value: value,
                title: Text(value),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
          ]),
        )),
        if (state.language != 'Русский') ...[
          const SizedBox(height: 7),
          Text(tr('Перевод остальных разделов находится в разработке'),
            style: TextStyle(fontSize: 11,
              color: OwnerPalette.muted(context))),
        ],
        const SizedBox(height: 12),
        OwnerCard(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const OwnerNotificationsScreen())),
          child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notifications_outlined), title: Text(tr('Уведомления')), trailing: const Icon(Icons.chevron_right)),
        ),
        const SizedBox(height: 9),
        OwnerCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined),
          title: Text(tr('Безопасность')),
          subtitle: Text(tr('Авторизация и биометрия подключаются отдельно')),
        )),
        const SizedBox(height: 15),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            state.signOut();
          },
          icon: const Icon(Icons.logout),
          label: Text(tr(state.live ? 'Выйти' : 'Выйти из демо')),
        ),
      ]),
    );
  }
}

class OwnerNotificationsScreen extends StatefulWidget {
  const OwnerNotificationsScreen({super.key});

  @override
  State<OwnerNotificationsScreen> createState() => _OwnerNotificationsScreenState();
}

class _OwnerNotificationsScreenState extends State<OwnerNotificationsScreen> {
  bool cash = true;
  bool sales = true;
  bool inventory = true;
  bool pushEnabled=false;
  bool pushBusy=false;
  String? pushStatus;
  Set<String> selectedKinds=OwnerPushService.kinds.toSet();

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final workspace=OwnerScope.of(context).workspaceId;
      final enabled=await OwnerPushService.isEnabled();
      final kinds=workspace==null
        ?OwnerPushService.kinds.toSet()
        :await OwnerPushService.selectedKinds(workspace);
      if (mounted) {
        setState((){
          pushEnabled=enabled;
          selectedKinds=kinds;
        });
      }
    });
  }

  Future<void> _togglePush(bool enabled) async {
    final state=OwnerScope.of(context);
    if(state.workspaceId==null)return;
    setState((){pushBusy=true;pushStatus=null;});
    try{
      if(enabled){
        await OwnerPushService.enable(
          state.workspaceId!,state.selectedRestaurantIds);
      }else{
        await OwnerPushService.disable();
      }
      if(!mounted)return;
      setState((){
        pushEnabled=enabled;
        pushStatus=enabled
          ?'Push включён для выбранных ресторанов.'
          :'Push-уведомления отключены на этом телефоне.';
      });
    }catch(e){
      if(!mounted)return;
      setState((){
        pushStatus=e is OwnerApiException
          ?e.message
          :'Не удалось изменить настройки уведомлений.';
      });
    }finally{
      if(mounted)setState(()=>pushBusy=false);
    }
  }

  Future<void> _toggleKind(String kind,bool checked) async {
    final state=OwnerScope.of(context);
    final workspace=state.workspaceId;
    if(workspace==null)return;
    final next={...selectedKinds};
    if(checked){next.add(kind);}else{next.remove(kind);}
    setState((){pushBusy=true;pushStatus=null;});
    try{
      await OwnerPushService.updateKinds(
        workspace,state.selectedRestaurantIds,next);
      if(!mounted)return;
      setState((){
        selectedKinds=next;
        pushStatus=pushEnabled
          ?'Настройки уведомлений сохранены на сервере.'
          :'Выбор сохранён. Push пока выключен.';
      });
    }catch(e){
      if(!mounted)return;
      setState((){
        pushStatus=e is OwnerApiException
          ?e.message:'Не удалось сохранить выбранные события.';
      });
    }finally{
      if(mounted)setState(()=>pushBusy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state=OwnerScope.of(context);
    if(state.live){
      return Scaffold(
        appBar:AppBar(title:const Text('Уведомления')),
        body:OwnerScreenFrame(children:[
          const OwnerHeading('События касс',
            caption:'Push на экран телефона, включая закрытое приложение'),
          const SizedBox(height:12),
          OwnerCard(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              SwitchListTile(
                contentPadding:EdgeInsets.zero,
                title:const Text('Push от Smart Horeca Owner'),
                subtitle:Text(OwnerPushService.configured
                  ?'Для ${state.selectedRestaurantIds.length} выбранных ресторанов'
                  :'Ожидает настройки Firebase для Android'),
                value:pushEnabled,
                onChanged:pushBusy||!OwnerPushService.configured
                  ?null:_togglePush,
              ),
              if(pushBusy)const LinearProgressIndicator(),
              if(pushStatus!=null)...[
                const SizedBox(height:8),
                Text(pushStatus!,style:TextStyle(fontSize:12,
                  color:OwnerPalette.muted(context))),
              ],
              const SizedBox(height:8),
              const Divider(),
              const Text('Какие события отправляются',
                style:TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:8),
              for(final event in const [
                ('DISCOUNT_APPLIED','Применена скидка'),
                ('DISCOUNT_REMOVED','Удалена скидка'),
                ('PRECHECK_CANCELLED','Отменён пречек'),
                ('ITEM_REMOVED','Удалено блюдо'),
                ('RECEIPT_STORNO','Сторнирован чек'),
              ])
                CheckboxListTile(
                  dense:true,
                  contentPadding:EdgeInsets.zero,
                  controlAffinity:ListTileControlAffinity.leading,
                  title:Text(event.$2),
                  subtitle:Text(selectedKinds.contains(event.$1)
                    ?'Получать уведомления'
                    :'Не уведомлять'),
                  value:selectedKinds.contains(event.$1),
                  onChanged:pushBusy?null:(value)=>
                    _toggleKind(event.$1,value==true),
                ),
              const SizedBox(height:8),
              Text('События должны поступать из кассового плагина. '
                'Приложение не создаёт уведомления по догадкам.',
                style:TextStyle(fontSize:11,
                  color:OwnerPalette.muted(context))),
            ],
          )),
          const SizedBox(height:14),
          OwnerCard(
            onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
              builder:(_)=>const OwnerLiveReportScreen(
                title:'Складские предупреждения',
                kind:'notifications'))),
            child:const ListTile(
              contentPadding:EdgeInsets.zero,
              leading:Icon(Icons.inventory_2_outlined),
              title:Text('Складские предупреждения'),
              trailing:Icon(Icons.chevron_right),
            )),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления'), actions: [
        IconButton(
          tooltip: 'Настройки',
          onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true,
            builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
              return SafeArea(child: Padding(padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Подписки на уведомления', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SwitchListTile(title: const Text('Кассовые смены'), value: cash,
                    onChanged: (v) { setState(() => cash = v); setSheetState(() {}); }),
                  SwitchListTile(title: const Text('Продажи'), value: sales,
                    onChanged: (v) { setState(() => sales = v); setSheetState(() {}); }),
                  SwitchListTile(title: const Text('Остатки на складах'), value: inventory,
                    onChanged: (v) { setState(() => inventory = v); setSheetState(() {}); }),
                  Text('Демо: переключатели пока не подключены к push-серверу.',
                    style: TextStyle(fontSize: 11, color: OwnerPalette.muted(ctx))),
                ]),
              ));
            }),
          ),
          icon: const Icon(Icons.tune),
        ),
      ]),
      body: OwnerScreenFrame(children: [
        const OwnerHeading('Последние события', caption: 'Push-уведомления подключим после серверной интеграции'),
        const SizedBox(height: 12),
        for (final e in const [
          (Icons.trending_down, 'Снижение выручки', 'Jelly Park • на 25% ниже вчерашнего дня'),
          (Icons.inventory_2_outlined, 'Низкий остаток', 'Помидоры • Основной склад'),
          (Icons.wallet, 'Смена закрыта', 'Касса 1 • Ресторан Баку'),
        ]) ...[
          OwnerCard(
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(e.$2),
                content: Text('${e.$3}\n\nДемо события. Данные не получены из API.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(e.$1, color: OwnerPalette.accent(context)),
              title: Text(e.$2),
              subtitle: Text(e.$3, style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}
