import 'package:bbt_time_tracker/pages/home.dart';
import 'package:bbt_time_tracker/utils/global_timer.dart';
import 'package:flutter/material.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalTimer().initialize();

  WidgetsBinding.instance.addObserver(AppLifecycleObserver());
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
