
// lib/main.dart
// BadminCAB Flutter Mobile App - Fixed Version
// Issues fixed: report manager separated
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // For avoiding Timer freeze during screen lock
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'report_manager.dart';
import 'csv_exporter.dart';

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
  List<String> _selectedPlayers = []; // Ordered by selection (rest rotation)
  List<List<String>> _courtAssignments = [];
  List<String> _restingPlayers = [];
  int _matchDuration = 10;
  int _breakDuration = 20;
  String _courtNumbers = '1,2,3';
  int _timeRemaining = 600;
  bool _isTimerRunning = false;
  bool _isInBreak = false; // Track break state
  int _currentRound = 1;
  Timer? _timer;
  int _restRotationIndex = 0; // Track rotation for fair rest
  final _audioPlayer = AudioPlayer(); // Audio player
  int _breakTimeRemaining = 0; // Separate break timer

  // >>> NEW: Use ReportManager for logging & reporting
  final reportManager = ReportManager();

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
  bool get isInBreak => _isInBreak;
  int get currentRound => _currentRound;
  int get breakTimeRemaining => _breakTimeRemaining;

  AppState() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPlayers();
    await _loadSettings();
    // Preload audio
    await _audioPlayer.setSource(AssetSource('beep.mp3'));
    // Listen for audio completion (optional - for cleaner handling)
    _audioPlayer.onPlayerComplete.listen((_) {
      print('Audio playback completed');
    });
    notifyListeners();
  }

  Future<void> _loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final playersJson = prefs.getStringList('players');
    if (playersJson != null && playersJson.isNotEmpty) {
      _allPlayers = playersJson.map((json) {
        final parts = json.split('\n');
        return Player(
          id: parts[0],
          name: parts[1],
          type: parts[2],
          pairNum: parts.length > 3 && parts[3].isNotEmpty ? int.parse(parts[3]) : null,
        );
      }).toList();
    } else {
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
      Player(id: '13', name: 'Saina Nehwal', type: 'casual', pairNum: null),
      Player(id: '14', name: 'Satheesh K', type: 'full', pairNum: null),
    ];
  }

  Future<void> _savePlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final playersJson = _allPlayers.map((p) {
      return '${p.id}\n${p.name}\n${p.type}\n${p.pairNum ?? ''}';
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
      _selectedPlayers.add(playerId); // Maintains selection order
    }
    notifyListeners();
  }

  void autoAssignCourts() {
    if (_selectedPlayers.length < 4) {
      throw Exception('Need at least 4 players');
    }
    final courts = _courtNumbers.split(',').map((c) => c.trim()).toList();
    final playersPerCourt = 4;
    final totalPlayingSlots = courts.length * playersPerCourt;

    final units = _buildUnitsInOrder();
    final totalPlayers = _selectedPlayers.length;
    final numRestingPlayers = max(0, totalPlayers - totalPlayingSlots);

    final restingUnits = <List<String>>[];
    int restingPlayerCount = 0;
    for (int i = 0; i < units.length; i++) {
      final unitIdx = (_restRotationIndex + i) % units.length;
      final unit = units[unitIdx];
      if (restingPlayerCount + unit.length <= numRestingPlayers) {
        restingUnits.add(unit);
        restingPlayerCount += unit.length;
      }
    }

    _restRotationIndex = (_restRotationIndex + restingUnits.length) % units.length;
    final playingUnits = units.where((u) => !restingUnits.contains(u)).toList();
    playingUnits.shuffle();

    _courtAssignments = [];
    int unitIdx = 0;
    for (int courtIdx = 0; courtIdx < courts.length; courtIdx++) {
      final court = <String>[];
      // First pass: try to fit units normally
      while (court.length < playersPerCourt && unitIdx < playingUnits.length) {
        final unit = playingUnits[unitIdx];
        if (court.length + unit.length <= playersPerCourt) {
          court.addAll(unit);
          unitIdx++;
        } else {
          break; // Unit doesn't fit, try next court
        }
      }
      // Second pass: if court isn't full, try to fill with single players
      if (court.length < playersPerCourt && court.length > 0) {
        for (int i = unitIdx; i < playingUnits.length; i++) {
          final unit = playingUnits[i];
          if (unit.length == 1 && court.length < playersPerCourt) {
            court.add(unit[0]);
            playingUnits.removeAt(i);
            break; // Only add one single player to avoid disrupting order
          }
        }
      }
      if (court.isNotEmpty) {
        _courtAssignments.add(court);
      }
    }
    // Handle any remaining units that didn't fit
    final remainingPlayers = playingUnits.expand((unit) => unit).toList();
    _restingPlayers.addAll(remainingPlayers);
    _restingPlayers = restingUnits.expand((unit) => unit).toList();

    // Don't auto-start timer - let user start it manually
    _saveSettings();
    notifyListeners();
  }

  List<List<String>> _buildUnitsInOrder() {
    final pairGroups = <int, List<String>>{};
    final singles = <String>[];

    for (final playerId in _selectedPlayers) {
      final player = _allPlayers.firstWhere((p) => p.id == playerId);
      final pairNum = player.pairNum;
      if (pairNum != null) {
        pairGroups.putIfAbsent(pairNum, () => []);
        pairGroups[pairNum]!.add(player.name);
      } else {
        singles.add(player.name);
      }
    }

    final units = <List<String>>[];
    for (final pairNum in pairGroups.keys) {
      final pair = pairGroups[pairNum]!;
      if (pair.length == 2) {
        units.add(pair);
      } else {
        singles.addAll(pair);
      }
    }
    for (final single in singles) {
      units.add([single]);
    }
    return units;
  }

  // >>> REWRITTEN: save match history using ReportManager (one record per court)
  Future<void> _saveMatchToHistory() async {
    if (_courtAssignments.isEmpty) return;

    final courts = _courtNumbers.split(',').map((c) => c.trim()).toList();
    final now = DateTime.now();

    for (int i = 0; i < _courtAssignments.length && i < courts.length; i++) {
      final courtLabel = 'Court ${courts[i]}';
      final playersOnCourt = _courtAssignments[i]; // names already
      final record = MatchRecord(
        round: _currentRound,
        timestamp: now,
        court: courtLabel,
        players: playersOnCourt,
        duration: _matchDuration,
        status: 'Playing',
        playMode: 'Doubles',
      );
      await reportManager.logMatch(record);
    }
  }

  void startTimer() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    _isInBreak = false;

    // Enable wakelock to keep screen on and timer running
    WakelockPlus.enable();
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        _timeRemaining--;
        notifyListeners();
      } else {
        _onTimerComplete();
      }
    });
  }

  void _onTimerComplete() async {
    _timer?.cancel();
    _isTimerRunning = false;
    _isInBreak = true;
    _breakTimeRemaining = _breakDuration; // Start break countdown
    notifyListeners();

    // IMMEDIATELY generate new assignments (while break is counting down)
    if (_selectedPlayers.length >= 4) {
      _currentRound++;
      try {
        autoAssignCourts(); // Generate new assignments NOW
        await _saveMatchToHistory(); // SAVE MATCH HISTORY
      } catch (e) {
        print('Error in auto-assign: $e');
      }
    }

    // Play sound AFTER assignments are ready
    try {
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop); // Stop when finished
      await _audioPlayer.play(AssetSource('beep.mp3'));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('Audio error: $e');
      SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    }

    // Start break countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_breakTimeRemaining > 0) {
        _breakTimeRemaining--;
        notifyListeners();
      } else {
        // Break is over - start next round
        timer.cancel();
        _isInBreak = false;
        _timeRemaining = _matchDuration * 60;
        // Stop audio if still playing
        _audioPlayer.stop();
        notifyListeners();
        // Auto-start next round
        startTimer();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    // Disable wakelock when timer is paused
    WakelockPlus.disable();
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    _isInBreak = false;
    _breakTimeRemaining = 0;
    _timeRemaining = _matchDuration * 60;
    // Disable wakelock when timer is reset
    WakelockPlus.disable();
    notifyListeners();
  }

  // Safe settings update that pauses timer if running
  void updateSettings({
    String? courtNumbers,
    int? matchDuration,
    int? breakDuration,
  }) {
    // Pause timer to prevent crashes
    if (_isTimerRunning) {
      pauseTimer();
    }
    if (courtNumbers != null) {
      // Clear assignments if court count changes
      final oldCourtCount = _courtNumbers.split(',').length;
      final newCourtCount = courtNumbers.split(',').length;
      if (oldCourtCount != newCourtCount) {
        _courtAssignments = [];
        _restingPlayers = [];
      }
      _courtNumbers = courtNumbers;
    }
    if (matchDuration != null) {
      _matchDuration = matchDuration;
      if (!_isTimerRunning) {
        _timeRemaining = matchDuration * 60;
      }
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

  Future<void> clearHistory() async {
    // Pause timer first
    if (_isTimerRunning) {
      pauseTimer();
    }
    _courtAssignments = [];
    _restingPlayers = [];
    _currentRound = 1;
    _restRotationIndex = 0;
    _isInBreak = false;
    // >>> NEW: clear via ReportManager
    await reportManager.clearHistory();
    notifyListeners();
  }

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
    _audioPlayer.dispose();
    // Ensure wakelock is disabled when app closes
    WakelockPlus.disable();
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
                  _buildCourtAssignments(context, appState),
                  const SizedBox(height: 16),
                  if (appState.restingPlayers.isNotEmpty)
                    _buildRestingPlayers(context, appState),
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
    // Use break time when in break, match time otherwise
    final displayTime = appState.isInBreak ? appState.breakTimeRemaining : appState.timeRemaining;
    final minutes = displayTime ~/ 60;
    final seconds = displayTime % 60;
    final progress =
        (appState.matchDuration * 60 - appState.timeRemaining) / (appState.matchDuration * 60);
    return Card(
      color: appState.isInBreak ? Colors.orange : const Color(0xFF6366F1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              appState.isInBreak ? '⏱️ BREAK TIME' : 'Round ${appState.currentRound}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
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
                  onPressed: appState.isInBreak
                      ? null
                      : () {
                          if (appState.isTimerRunning) {
                            appState.pauseTimer();
                          } else {
                            appState.startTimer();
                          }
                        },
                  backgroundColor: appState.isInBreak ? Colors.grey : Colors.white,
                  child: Icon(
                    appState.isTimerRunning ? Icons.pause : Icons.play_arrow,
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: 'reset',
                  onPressed: appState.isInBreak ? null : appState.resetTimer,
                  backgroundColor:
                      appState.isInBreak ? Colors.grey.withOpacity(0.3) : Colors.white.withOpacity(0.3),
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
            // Indication for app keeping the screen awake
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.screen_lock_portrait,
                  color: Colors.white70,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  'Screen will stay awake',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
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
                    content: Text('Courts assigned! Press ▶️ to start'),
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
            label: const Text('Assign'),
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

  // Responsive court layout
  Widget _buildCourtAssignments(BuildContext context, AppState appState) {
    final screenWidth = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;
    final cardsPerRow = orientation == Orientation.portrait ? 1 : 2;
    final cardWidth = (screenWidth - (16 * (cardsPerRow + 1))) / cardsPerRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Court Assignments',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: appState.courtAssignments.asMap().entries.map((entry) {
            final index = entry.key;
            final players = entry.value;
            final courtNum = appState.courtNumbers.split(',')[index].trim();
            return SizedBox(
              width: orientation == Orientation.portrait
                  ? double.infinity
                  : cardWidth,
              child: Card(
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
                          final isPaired = _isPaired(playerName, appState);
                          return Chip(
                            label: Text(playerName),
                            backgroundColor:
                                isPaired ? Colors.orange[100] : Colors.blue[100],
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  bool _isPaired(String playerName, AppState appState) {
    final player = appState.allPlayers.firstWhere(
      (p) => p.name == playerName,
      orElse: () => Player(id: '', name: '', type: 'full', pairNum: null),
    );
    return player.pairNum != null;
    }

  Widget _buildRestingPlayers(BuildContext context, AppState appState) {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resting Players',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: appState.restingPlayers.map((playerName) {
                final isPaired = _isPaired(playerName, appState);
                return Chip(
                  label: Text(playerName),
                  backgroundColor: isPaired ? Colors.orange[200] : Colors.amber[200],
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


// ==================== PLAYER SELECTION SCREEN (with Search) ====================
class PlayerSelectionScreen extends StatefulWidget {
  const PlayerSelectionScreen({super.key});

  @override
  State<PlayerSelectionScreen> createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(Player p, String q) {
    if (q.isEmpty) return true;
    final inName = p.name.toLowerCase().contains(q);
    final inType = p.type.toLowerCase().contains(q); // 'full' or 'casual'
    final inPair = p.pairNum != null && p.pairNum.toString().contains(q);
    return inName || inType || inPair;
  }

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
          // Apply filtering based on the search query
          final filteredPlayers =
              appState.allPlayers.where((p) => _matchesQuery(p, _query)).toList();

          return Column(
            children: [
              // Header: selected count + hint
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.indigo[50],
                child: Column(
                  children: [
                    Text(
                      '${appState.selectedPlayers.length} players selected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selection order determines rest rotation',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // SEARCH BAR
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search players (name, type, pair #)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),

              // Filter chips (optional quick helpers)
              // You can uncomment this block if you want quick filters.
              /*
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Full'),
                      selected: _query == 'full',
                      onSelected: (v) {
                        setState(() => _searchController.text = v ? 'full' : '');
                      },
                    ),
                    FilterChip(
                      label: const Text('Casual'),
                      selected: _query == 'casual',
                      onSelected: (v) {
                        setState(() => _searchController.text = v ? 'casual' : '');
                      },
                    ),
                  ],
                ),
              ),
              */

              // Players list (filtered)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPlayers.length,
                  itemBuilder: (context, index) {
                    final player = filteredPlayers[index];
                    final isSelected = appState.selectedPlayers.contains(player.id);
                    final selectionIndex =
                        isSelected ? appState.selectedPlayers.indexOf(player.id) + 1 : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                      child: ListTile(
                        onTap: () => appState.togglePlayerSelection(player.id),
                        leading: isSelected
                            ? CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Text(
                                  '$selectionIndex',
                                  style: const TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
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
                              backgroundColor:
                                  isSelected ? Colors.white.withOpacity(0.3) : Colors.grey[200],
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
                                backgroundColor:
                                    isSelected ? Colors.orange.withOpacity(0.3) : Colors.orange[100],
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

              // Confirm button
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

// ==================== PLAYERS MANAGEMENT, REPORTS, SETTINGS ====================
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
          content: SingleChildScrollView(
            child: Column(
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
          content: SingleChildScrollView(
            child: Column(
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
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();

  final _courtHireController = TextEditingController(text: '0');
  final _shuttlesUsedController = TextEditingController(text: '0');
  final _otherExpensesController = TextEditingController(text: '0');
  final _casualChargeController = TextEditingController(text: '10');
  final _shuttleCostController = TextEditingController(text: '3');

  String _casualChargeType = 'fixed'; // 'fixed' or 'split'
  bool _isLoading = false;

  // >>> NEW: Use the report manager API + SessionReport
  final _reportManager = ReportManager();
  SessionReport? _report;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    // Load persisted settings to prefill inputs
    await _reportManager.loadSettings();
    final s = _reportManager.settings;
    _shuttleCostController.text = s.shuttleCost.toString();
    _casualChargeController.text = s.casualChargePerSession.toString();
    _casualChargeType = (s.casualChargeType == CasualChargeType.fixed) ? 'fixed' : 'split';
    await _loadReport();
  }


  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
  
    // 1) Parse UI inputs (unchanged)
    final courtHire = double.tryParse(_courtHireController.text) ?? 0;
    final shuttlesUsed = int.tryParse(_shuttlesUsedController.text) ?? 0;
    final otherExpenses = double.tryParse(_otherExpensesController.text) ?? 0;
    final shuttleCost = double.tryParse(_shuttleCostController.text) ?? 3;
    final casualCharge = double.tryParse(_casualChargeController.text) ?? 10;
  
    // 2) Persist report settings (unchanged)
    await _reportManager.saveSettings(ReportSettings(
      casualChargeType:
          _casualChargeType == 'fixed' ? CasualChargeType.fixed : CasualChargeType.split,
      casualChargePerSession: casualCharge,
      shuttleCost: shuttleCost,
      defaultCourtHire: 0.0,
    ));
  
    // 3) Build a name -> type map from current roster (NEW)
    //    This makes sure casual players are not treated as full by default.
    final appState = Provider.of<AppState>(context, listen: false);
    final typeMap = {
      for (final p in appState.allPlayers) p.name: p.type.toLowerCase().trim(),
    };
  
    // 4) Generate the report with player types (NEW: playerTypesByName)
    final report = await _reportManager.generateReport(
      date: _selectedDate,
      courtHire: courtHire,
      shuttleCount: shuttlesUsed,
      otherExpenses: otherExpenses,
      playerTypesByName: typeMap, // <-- key addition
    );
  
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  Future<void> _exportToCsv() async {
    if (_report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }
    try {
      final csvString = _reportManager.generateCSV(_report!);
      await saveCsvReport(
        fileNamePrefix: 'BadminCAB_Report',
        date: _selectedDate,
        csvContent: csvString,
        shareSubject:
            'BadminCAB Report ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final showNoData = (_report == null) ||
        ((_report!.totalMatches == 0) && _report!.playerCosts.isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Report'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed:
                (_report != null && _report!.playerCosts.isNotEmpty) ? _exportToCsv : null,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDateSelector(),
                  const SizedBox(height: 20),
                  if (showNoData)
                    _buildNoDataCard()
                  else ...[
                    _buildInputSection(),
                    const SizedBox(height: 20),
                    _buildStatsGrid(),
                    const SizedBox(height: 20),
                    _buildFinancialSummary(),
                    const SizedBox(height: 20),
                    _buildPlayerCosts(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                  _loadReport();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF6366F1)),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No matches found for ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Play some matches and they will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Costs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _courtHireController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Court Hire Fee (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sports_tennis),
              ),
              onChanged: (_) => _loadReport(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shuttlesUsedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Shuttles Used',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sports),
              ),
              onChanged: (_) => _loadReport(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shuttleCostController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Shuttle Cost per Unit (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              onChanged: (_) => _loadReport(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otherExpensesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Other Expenses (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt),
              ),
              onChanged: (_) => _loadReport(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Casual Player Charging',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _casualChargeType,
              decoration: const InputDecoration(
                labelText: 'Charge Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'fixed', child: Text('Fixed Charge')),
                DropdownMenuItem(value: 'split', child: Text('Split Equally with Full Members')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _casualChargeType = value);
                  _loadReport();
                }
              },
            ),
            if (_casualChargeType == 'fixed') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _casualChargeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Casual Charge per Session (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (_) => _loadReport(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh),
                label: const Text('Recalculate'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_report == null) return const SizedBox.shrink();
    final r = _report!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard('Total Rounds', r.totalRounds.toString(), const Color(0xFF6366F1)),
        _buildStatCard('Total Matches', r.totalMatches.toString(), Colors.green),
        _buildStatCard('Total Players', r.totalPlayers.toString(), Colors.orange),
        _buildStatCard('Shuttles Used', r.shuttlesUsed.toString(), Colors.amber),
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

  Widget _buildFinancialSummary() {
    if (_report == null) return const SizedBox.shrink();
    final r = _report!;
    final casual = r.playerCosts.where((p) => p.type == 'casual').toList();
    final full = r.playerCosts.where((p) => p.type == 'full').toList();
    final casualTotal = casual.fold<double>(0, (s, p) => s + p.cost);
    final fullTotal = full.fold<double>(0, (s, p) => s + p.cost);
    final totalCollected = r.playerCosts.fold<double>(0, (s, p) => s + p.cost);

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
            ),
            const Divider(height: 24),
            _buildSummaryRow('Charge Model',
                r.chargeType == CasualChargeType.fixed ? 'Fixed Charge' : 'Equal Split'),
            _buildSummaryRow('Court Hire', '\$${r.courtHire.toStringAsFixed(2)}'),
            _buildSummaryRow('Shuttles Cost', '\$${r.totalShuttleCost.toStringAsFixed(2)}'),
            _buildSummaryRow('Other Expenses', '\$${r.otherExpenses.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _buildSummaryRow('Total Base Cost', '\$${r.totalBaseCost.toStringAsFixed(2)}', bold: true),
            _buildSummaryRow('Casual Contribution (${casual.length})',
                '\$${casualTotal.toStringAsFixed(2)}'),
            _buildSummaryRow('Full Member Split (${full.length})', '\$${fullTotal.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _buildSummaryRow('Total Collected', '\$${totalCollected.toStringAsFixed(2)}',
                bold: true, fontSize: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool bold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCosts() {
    if (_report == null || _report!.playerCosts.isEmpty) return const SizedBox.shrink();
    final players = [..._report!.playerCosts]..sort((a, b) => a.name.compareTo(b.name));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Player Costs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final p = players[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: p.type == 'full' ? Colors.blue[50] : Colors.orange[50],
                  child: ListTile(
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${p.type.toUpperCase()}'),
                        Text('Sessions: ${p.sessions}'),
                        Text('Shuttle Share: \$${p.shuttleShare.toStringAsFixed(2)}'),
                      ],
                    ),
                    trailing: Text(
                      '\$${p.cost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _courtHireController.dispose();
    _shuttlesUsedController.dispose();
    _otherExpensesController.dispose();
    _casualChargeController.dispose();
    _shuttleCostController.dispose();
    super.dispose();
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
                        const Text('Match Settings',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            helperText: 'Time for players to check new assignments',
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
                      const SnackBar(content: Text('Settings saved!'), backgroundColor: Colors.green),
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
                        content: const Text('Reset all match history and rest rotation. Continue?'),
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
                                    content: Text('History cleared!'), backgroundColor: Colors.green),
                              );
                            },
                            child: const Text('Clear', style: TextStyle(color: Colors.red)),
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
