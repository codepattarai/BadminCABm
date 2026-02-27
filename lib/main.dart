// lib/main.dart
// BadminCAB Flutter Mobile App
// Version 20.26.4  Prod Owner Satheesh K.
//
// Changelog v20.26.4:
//   [Step 1] Import / Export – full data backup & restore via CSV files
//            (players, match history, match settings, report settings,
//             other preferences). Accessible from Settings screen.
//   [Step 5] Code tidy-up – each screen is now its own Dart file.
//            main.dart contains only app bootstrap + navigation shell.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'dashboard_screen.dart';
import 'players_management_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'license_screen.dart';

void main() {
  runApp(const BadminCABApp());
}

class BadminCABApp extends StatelessWidget {
  const BadminCABApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'BadminCAB',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
          ),
        ),
        home: const LicenseGate(child: MainScreen()),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// ==================== MAIN SCREEN (Navigation shell) ====================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    PlayersManagementScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6366F1),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Players'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assessment), label: 'Reports'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
