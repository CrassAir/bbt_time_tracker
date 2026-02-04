import 'package:bbt_time_tracker/pages/home.dart';
import 'package:bbt_time_tracker/services/strore.dart';
import 'package:bbt_time_tracker/utils/global_timer.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

late ObjectBox objectbox;

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalTimer().initialize();
  WidgetsBinding.instance.addObserver(AppLifecycleObserver());
  objectbox = await ObjectBox.create();

  await WindowsSingleInstance.ensureSingleInstance(
    args,
    "bbt_time_tracker_2026",
    onSecondWindow: (args) async {
      await windowManager.focus();
      await windowManager.show();
    },
  );

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 1000),
    minimumSize: Size(600, 1000),
    center: true,
    title: 'BBT Time Tracker',
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () {});
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        hoverColor: Colors.transparent,
      ),
      home: const HomePage(),
    );
  }
}
