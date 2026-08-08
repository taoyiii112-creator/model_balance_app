import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/usage_screen.dart';
import 'services/notification_service.dart';
import 'state/balance_state.dart';

class ModelBalanceApp extends StatefulWidget {
  const ModelBalanceApp({super.key, this.state});

  /// 测试时可注入替身状态。
  final BalanceState? state;

  @override
  State<ModelBalanceApp> createState() => _ModelBalanceAppState();
}

class _ModelBalanceAppState extends State<ModelBalanceApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // 生产环境（未注入测试状态）才初始化系统通知平台通道。
    if (widget.state == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initNotifications();
      });
    }
  }

  Future<void> _initNotifications() async {
    final launchedFromNotification = await NotificationService.instance.init(
      onTap: _openNotifications,
    );
    if (launchedFromNotification) {
      _openNotifications();
    }
  }

  Future<void> _openNotifications() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => widget.state ?? BalanceState(),
      child: MaterialApp(
        title: '模型余额',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    UsageScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '余额',
          ),
          NavigationDestination(
            icon: Icon(Icons.data_usage_outlined),
            selectedIcon: Icon(Icons.data_usage),
            label: '用量',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
