import 'package:bbt_time_tracker/pages/home.dart';
import 'package:bbt_time_tracker/services/strore.dart';
import 'package:bbt_time_tracker/utils/global_timer.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

late ObjectBox objectbox;

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalTimer().initialize();
  WidgetsBinding.instance.addObserver(AppLifecycleObserver());
  objectbox = await ObjectBox.create();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(600, 1000),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () {});
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey)),
      home: const HomePage(),
    );
  }
}
