// lib/main.dart
// BadminCAB Flutter Mobile App
// Version 20.26.8  Prod Owner Satheesh K.
//

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'dashboard_screen.dart';
import 'players_management_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'license_screen.dart';
import 'app_theme.dart';

void main() {
  runApp(const BadminCABApp());
}

class BadminCABApp extends StatelessWidget {
  const BadminCABApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      // Consumer rebuilds MaterialApp when isLightTheme changes so the whole
      // app re-themes instantly without a restart.
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          title: 'BadminCAB',
          theme: appState.isLightTheme
              ? AppTheme.lightThemeData
              : AppTheme.themeData,
          home: const LicenseGate(child: MainScreen()),
          debugShowCheckedModeBanner: false,
        ),
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
        selectedItemColor: AppTheme.navSelected,
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