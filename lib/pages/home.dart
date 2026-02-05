import 'package:bbt_time_tracker/pages/history.dart';
import 'package:bbt_time_tracker/pages/timer_list.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PageController pageController = PageController(initialPage: 0);
  int curPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text('TIME TRACKER'),
            InkWell(
              onTap: () => launchUrl(Uri.parse('https://github.com/CrassAir'), mode: LaunchMode.externalApplication),
              child: Text(
                'developed by CrassAir',
                style: TextStyle(fontSize: 10, color: Colors.blue, decorationColor: Colors.blue),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: curPage,
        onTap: (value) {
          pageController.animateToPage(value, duration: Duration(milliseconds: 250), curve: Curves.easeInOut);
          curPage = value;
          setState(() {});
        },
        items: [
          BottomNavigationBarItem(
            icon: MouseRegion(onEnter: (_) {}, onExit: (_) {}, child: Icon(Icons.home)),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: ''),
        ],
      ),
      body: PageView(controller: pageController, children: [TimerList(), HistoryPage()]),
    );
  }
}

// TODO: Сделать сервер, добавить тг бота
// TODO: Добавить настройки(старт рабочего дня, робочее время)
