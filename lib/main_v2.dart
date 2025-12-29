// lib/main.dart
// BadminCAB Flutter Mobile App - Updated Version
// No license, simplified pairing mode, player management

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';

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
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// ==================== APP STATE ====================
class AppState extends ChangeNotifier {
  List<Player> _allPlayers = [];
  List<String> _selectedPlayers = [];
  List<List<String>> _courtAssignments = [];
  List<String> _restingPlayers = [];
  int _matchDuration = 10;
  int _breakDuration = 20;
  String _courtNumbers = '1,2,3';
  int _timeRemaining = 600;
  bool _isTimerRunning = false;
  int _currentRound = 1;
  Timer? _timer;

  // Getters
  List<Player> get allPlayers => _allPlayers;
  List<String> get selectedPlayers => _selectedPlayers;
  List<List<String>> get courtAssignments => _courtAssignments;
  List<String> get restingPlayers => _restingPlayers;
  int get matchDuration => _matchDuration;
  int get breakDuration => _breakDuration;
  String get courtNumbers => _courtNumbers;
  int get timeRemaining => _timeRemaining;
  bool get isTimerRunning => _isTimerRunning;
  int get currentRound => _currentRound;

  AppState() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPlayers();
    await _loadSettings();
    notifyListeners();
  }

  Future<void> _loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final playersJson = prefs.getStringList('players');
    
    if (playersJson != null && playersJson.isNotEmpty) {
      _allPlayers = playersJson.map((json) {
        final parts = json.split('|');
        return Player(
          id: parts[0],
          name: parts[1],
          type: parts[2],
          pairNum: parts.length > 3 && parts[3].isNotEmpty ? int.parse(parts[3]) : null,
        );
      }).toList();
    } else {
      // Load sample players only if no players exist
      _loadSamplePlayers();
      await _savePlayers();
    }
  }

  void _loadSamplePlayers() {
    _allPlayers = [
      Player(id: '1', name: 'PV Sindhu', type: 'full', pairNum: null),
      Player(id: '2', name: 'Lakshya Sen', type: 'full', pairNum: null),
      Player(id: '3', name: 'Shi Yuqi', type: 'casual', pairNum: null),
      Player(id: '4', name: 'Anders Antonsen', type: 'full', pairNum: null),
      Player(id: '5', name: 'Kunlavut Vitidsarn', type: 'full', pairNum: 1),
      Player(id: '6', name: 'Li Shifeng', type: 'full', pairNum: 1),
      Player(id: '7', name: 'Chou Tien chen', type: 'casual', pairNum: 2),
      Player(id: '8', name: 'Jonatan Christie', type: 'casual', pairNum: 2),
      Player(id: '9', name: 'Alex Lanier', type: 'full', pairNum: null),
      Player(id: '10', name: 'Christo Popov', type: 'full', pairNum: null),
      Player(id: '11', name: 'Loh Kean Yew', type: 'full', pairNum: null),
      Player(id: '12', name: 'Weng Hongyang', type: 'casual', pairNum: null),
    ];
  }

  Future<void> _savePlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final playersJson = _allPlayers.map((p) {
      return '${p.id}|${p.name}|${p.type}|${p.pairNum ?? ''}';
    }).toList();
    await prefs.setStringList('players', playersJson);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _courtNumbers = prefs.getString('courtNumbers') ?? '1,2,3';
    _matchDuration = prefs.getInt('matchDuration') ?? 10;
    _breakDuration = prefs.getInt('breakDuration') ?? 20;
    _timeRemaining = _matchDuration * 60;
  }

  void togglePlayerSelection(String playerId) {
    if (_selectedPlayers.contains(playerId)) {
      _selectedPlayers.remove(playerId);
    } else {
      _selectedPlayers.add(playerId);
    }
    notifyListeners();
  }

  void autoAssignCourts() {
    if (_selectedPlayers.length < 4) {
      throw Exception('Need at least 4 players');
    }

    final courts = _courtNumbers.split(',').map((c) => c.trim()).toList();
    final playersPerCourt = 4;

    // Get full player names with pair info
    final selectedPlayerNames = _selectedPlayers.map((id) {
      final player = _allPlayers.firstWhere((p) => p.id == id);
      return player.pairNum != null ? '${player.name}-${player.pairNum}' : player.name;
    }).toList();

    // Shuffle players
    final shuffled = List<String>.from(selectedPlayerNames);
    shuffled.shuffle();

    // Assign to courts
    _courtAssignments = [];
    int playerIndex = 0;

    for (int i = 0; i < courts.length; i++) {
      final courtPlayers = <String>[];
      while (courtPlayers.length < playersPerCourt && playerIndex < shuffled.length) {
        courtPlayers.add(shuffled[playerIndex]);
        playerIndex++;
      }
      if (courtPlayers.isNotEmpty) {
        _courtAssignments.add(courtPlayers);
      }
    }

    // Remaining players rest
    _restingPlayers = shuffled.sublist(playerIndex);
    
    // Auto-start timer
    startTimer();
    
    _saveSettings();
    notifyListeners();
  }

  void startTimer() {
    if (_isTimerRunning) return;
    
    _isTimerRunning = true;
    notifyListeners();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        _timeRemaining--;
        notifyListeners();
      } else {
        // Timer finished
        _onTimerComplete();
      }
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    _isTimerRunning = false;
    
    // Play sound
    SystemSound.play(SystemSoundType.alert);
    
    // Wait for break duration, then auto-assign
    Future.delayed(Duration(seconds: _breakDuration), () {
      if (_selectedPlayers.length >= 4) {
        _currentRound++;
        _timeRemaining = _matchDuration * 60;
        autoAssignCourts();
      }
    });
    
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    _timeRemaining = _matchDuration * 60;
    notifyListeners();
  }

  void updateSettings({
    String? courtNumbers,
    int? matchDuration,
    int? breakDuration,
  }) {
    if (courtNumbers != null) _courtNumbers = courtNumbers;
    if (matchDuration != null) {
      _matchDuration = matchDuration;
      _timeRemaining = matchDuration * 60;
    }
    if (breakDuration != null) _breakDuration = breakDuration;

    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('courtNumbers', _courtNumbers);
    await prefs.setInt('matchDuration', _matchDuration);
    await prefs.setInt('breakDuration', _breakDuration);
  }

  void clearHistory() {
    _courtAssignments = [];
    _restingPlayers = [];
    _currentRound = 1;
    notifyListeners();
  }

  // Player management methods
  Future<void> addPlayer(String name, String type, int? pairNum) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    _allPlayers.add(Player(
      id: newId,
      name: name,
      type: type,
      pairNum: pairNum,
    ));
    await _savePlayers();
    notifyListeners();
  }

  Future<void> updatePlayer(String id, String name, String type, int? pairNum) async {
    final index = _allPlayers.indexWhere((p) => p.id == id);
    if (index != -1) {
      _allPlayers[index] = Player(
        id: id,
        name: name,
        type: type,
        pairNum: pairNum,
      );
      await _savePlayers();
      notifyListeners();
    }
  }

  Future<void> deletePlayer(String id) async {
    _allPlayers.removeWhere((p) => p.id == id);
    _selectedPlayers.remove(id);
    await _savePlayers();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ==================== MODELS ====================
class Player {
  final String id;
  final String name;
  final String type;
  final int? pairNum;

  Player({
    required this.id,
    required this.name,
    required this.type,
    this.pairNum,
  });
}

// ==================== MAIN SCREEN ====================
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
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Players'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ==================== DASHBOARD SCREEN ====================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BadminCAB Dashboard'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTimerCard(context, appState),
                const SizedBox(height: 16),
                _buildActionButtons(context, appState),
                const SizedBox(height: 16),
                if (appState.courtAssignments.isNotEmpty) ...[
                  _buildCourtAssignments(appState),
                  const SizedBox(height: 16),
                  if (appState.restingPlayers.isNotEmpty)
                    _buildRestingPlayers(appState),
                ] else
                  _buildEmptyState(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimerCard(BuildContext context, AppState appState) {
    final minutes = appState.timeRemaining ~/ 60;
    final seconds = appState.timeRemaining % 60;
    final progress = (appState.matchDuration * 60 - appState.timeRemaining) /
        (appState.matchDuration * 60);

    return Card(
      color: const Color(0xFF6366F1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Round ${appState.currentRound}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'play',
                  onPressed: () {
                    if (appState.isTimerRunning) {
                      appState.pauseTimer();
                    } else {
                      appState.startTimer();
                    }
                  },
                  backgroundColor: Colors.white,
                  child: Icon(
                    appState.isTimerRunning ? Icons.pause : Icons.play_arrow,
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: 'reset',
                  onPressed: appState.resetTimer,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppState appState) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PlayerSelectionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.people),
            label: Text('Select Players (${appState.selectedPlayers.length})'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              try {
                appState.autoAssignCourts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Courts assigned and timer started!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Auto Assign'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourtAssignments(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Court Assignments',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...appState.courtAssignments.asMap().entries.map((entry) {
          final index = entry.key;
          final players = entry.value;
          final courtNum = appState.courtNumbers.split(',')[index].trim();
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Court $courtNum',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: players.map((playerName) {
                      final isPaired = playerName.contains('-');
                      return Chip(
                        label: Text(playerName),
                        backgroundColor: isPaired
                            ? Colors.orange[100]
                            : Colors.blue[100],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRestingPlayers(AppState appState) {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resting',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: appState.restingPlayers.map((playerName) {
                return Chip(
                  label: Text(playerName),
                  backgroundColor: Colors.amber[200],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select players to begin',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PLAYER SELECTION SCREEN ====================
class PlayerSelectionScreen extends StatelessWidget {
  const PlayerSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Players for Session'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.indigo[50],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${appState.selectedPlayers.length} players selected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: appState.allPlayers.length,
                  itemBuilder: (context, index) {
                    final player = appState.allPlayers[index];
                    final isSelected = appState.selectedPlayers.contains(player.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                      child: ListTile(
                        onTap: () => appState.togglePlayerSelection(player.id),
                        title: Text(
                          player.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Chip(
                              label: Text(
                                player.type.toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: isSelected
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.grey[200],
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            if (player.pairNum != null) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  'Pair ${player.pairNum}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: isSelected
                                    ? Colors.orange.withOpacity(0.3)
                                    : Colors.orange[100],
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.white)
                            : const Icon(Icons.circle_outlined, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Confirm Selection (${appState.selectedPlayers.length})',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Continue in next part...
// ==================== PLAYERS MANAGEMENT SCREEN ====================
class PlayersManagementScreen extends StatelessWidget {
  const PlayersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Players'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPlayerDialog(context),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          if (appState.allPlayers.isEmpty) {
            return const Center(
              child: Text('No players yet. Tap + to add players.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appState.allPlayers.length,
            itemBuilder: (context, index) {
              final player = appState.allPlayers[index];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    player.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    children: [
                      Chip(
                        label: Text(
                          player.type.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Colors.blue[100],
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      if (player.pairNum != null) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            'Pair ${player.pairNum}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.orange[100],
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditPlayerDialog(context, player),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, appState, player),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPlayerDialog(context),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddPlayerDialog(BuildContext context) {
    final nameController = TextEditingController();
    String playerType = 'full';
    int? pairNum;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Player'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Player Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: playerType,
                decoration: const InputDecoration(
                  labelText: 'Player Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'full', child: Text('Full Member')),
                  DropdownMenuItem(value: 'casual', child: Text('Casual Player')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => playerType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Pair Number (optional)',
                  hintText: 'e.g., 1, 2, 3...',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  pairNum = value.isEmpty ? null : int.tryParse(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }
                
                final appState = Provider.of<AppState>(context, listen: false);
                await appState.addPlayer(
                  nameController.text.trim(),
                  playerType,
                  pairNum,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Player added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPlayerDialog(BuildContext context, Player player) {
    final nameController = TextEditingController(text: player.name);
    String playerType = player.type;
    int? pairNum = player.pairNum;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Player'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Player Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: playerType,
                decoration: const InputDecoration(
                  labelText: 'Player Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'full', child: Text('Full Member')),
                  DropdownMenuItem(value: 'casual', child: Text('Casual Player')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => playerType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Pair Number (optional)',
                  hintText: 'e.g., 1, 2, 3...',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: pairNum?.toString() ?? '',
                ),
                onChanged: (value) {
                  pairNum = value.isEmpty ? null : int.tryParse(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }
                
                final appState = Provider.of<AppState>(context, listen: false);
                await appState.updatePlayer(
                  player.id,
                  nameController.text.trim(),
                  playerType,
                  pairNum,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Player updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState, Player player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Player'),
        content: Text('Are you sure you want to delete ${player.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await appState.deletePlayer(player.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Player deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ==================== REPORTS SCREEN ====================
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Report'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsGrid(appState),
                const SizedBox(height: 16),
                _buildSessionSummary(appState),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report export coming soon!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export Report'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(AppState appState) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard(
          'Total Rounds',
          appState.currentRound.toString(),
          const Color(0xFF6366F1),
        ),
        _buildStatCard(
          'Active Courts',
          appState.courtAssignments.length.toString(),
          Colors.green,
        ),
        _buildStatCard(
          'Total Players',
          appState.selectedPlayers.length.toString(),
          Colors.orange,
        ),
        _buildStatCard(
          'Resting',
          appState.restingPlayers.length.toString(),
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionSummary(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildSummaryRow('Courts:', appState.courtNumbers),
            _buildSummaryRow(
                'Match Duration:', '${appState.matchDuration} minutes'),
            _buildSummaryRow(
                'Break Duration:', '${appState.breakDuration} seconds'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ==================== SETTINGS SCREEN ====================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _courtNumbersController = TextEditingController();
  final _matchDurationController = TextEditingController();
  final _breakDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _courtNumbersController.text = appState.courtNumbers;
    _matchDurationController.text = appState.matchDuration.toString();
    _breakDurationController.text = appState.breakDuration.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Match Settings',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _courtNumbersController,
                          decoration: const InputDecoration(
                            labelText: 'Court Numbers',
                            hintText: 'e.g., 1,2,3',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _matchDurationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Match Duration (minutes)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _breakDurationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Break Duration (seconds)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    appState.updateSettings(
                      courtNumbers: _courtNumbersController.text,
                      matchDuration: int.tryParse(_matchDurationController.text),
                      breakDuration: int.tryParse(_breakDurationController.text),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings saved successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear History'),
                        content: const Text(
                          'This will reset all match history and rest tracking. Continue?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              appState.clearHistory();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('History cleared!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: const Text('Clear',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear History'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _courtNumbersController.dispose();
    _matchDurationController.dispose();
    _breakDurationController.dispose();
    super.dispose();
  }
}