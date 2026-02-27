// lib/app_state.dart
// BadminCAB v20.26.5 – AppState & Player model
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'report_manager.dart';

// ==================== PLAYER MODEL ====================
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
  bool _isInBreak = false;
  int _currentRound = 1;
  Timer? _timer;
  int _restRotationIndex = 0;
  final _audioPlayer = AudioPlayer();
  int _breakTimeRemaining = 0;

  final reportManager = ReportManager();

  double _chipScale = 1.0;
  double get chipScale => _chipScale;

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
    await _audioPlayer.setSource(AssetSource('beep.mp3'));
    _audioPlayer.onPlayerComplete.listen((_) {});
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
          pairNum: parts.length > 3 && parts[3].isNotEmpty
              ? int.parse(parts[3])
              : null,
        );
      }).toList();
    } else {
      _loadSamplePlayers();
      await _savePlayers();
    }
  }

  void _loadSamplePlayers() {
    _allPlayers = [
      Player(id: '1', name: 'PV Sindhu', type: 'full'),
      Player(id: '2', name: 'Lakshya Sen', type: 'full'),
      Player(id: '3', name: 'Shi Yuqi', type: 'casual'),
      Player(id: '4', name: 'Anders Antonsen', type: 'full'),
      Player(id: '5', name: 'Kunlavut Vitidsarn', type: 'full', pairNum: 1),
      Player(id: '6', name: 'Li Shifeng', type: 'full', pairNum: 1),
      Player(id: '7', name: 'Chou Tien chen', type: 'casual', pairNum: 2),
      Player(id: '8', name: 'Jonatan Christie', type: 'casual', pairNum: 2),
      Player(id: '9', name: 'Alex Lanier', type: 'full'),
      Player(id: '10', name: 'Christo Popov', type: 'full'),
      Player(id: '11', name: 'Loh Kean Yew', type: 'full'),
      Player(id: '12', name: 'Weng Hongyang', type: 'casual'),
      Player(id: '13', name: 'Saina Nehwal', type: 'casual'),
      Player(id: '14', name: 'Satheesh K', type: 'full'),
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
    _chipScale = prefs.getDouble('chipScale') ?? 1.0;
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
    const playersPerCourt = 4;
    final totalPlayingSlots = courts.length * playersPerCourt;

    final units = _buildUnitsInOrder();
    final totalPlayers = _selectedPlayers.length;
    final numRestingPlayers = max(0, totalPlayers - totalPlayingSlots);

    // Play-first model: units at the START of the list play first.
    // We rest units from the END of the rotation queue.
    final restingUnits = <List<String>>[];
    int restingPlayerCount = 0;

    // Collect resting units from the tail of the rotation
    final reversedIndices = List.generate(units.length, (i) => i).reversed.toList();
    final tentativeResting = <int>[];
    for (final i in reversedIndices) {
      final unitIdx = (_restRotationIndex + i) % units.length;
      final unit = units[unitIdx];
      if (restingPlayerCount + unit.length <= numRestingPlayers) {
        tentativeResting.add(unitIdx);
        restingPlayerCount += unit.length;
      }
      if (restingPlayerCount >= numRestingPlayers) break;
    }

    final restingIndexSet = tentativeResting.toSet();
    for (int i = 0; i < units.length; i++) {
      final unitIdx = (_restRotationIndex + i) % units.length;
      if (restingIndexSet.contains(unitIdx)) {
        restingUnits.add(units[unitIdx]);
      }
    }

    _restRotationIndex = (_restRotationIndex + restingUnits.length) % units.length;
    final playingUnits = units.where((u) => !restingUnits.contains(u)).toList();
    playingUnits.shuffle();

    _courtAssignments = [];
    int unitIdx = 0;
    for (int courtIdx = 0; courtIdx < courts.length; courtIdx++) {
      final court = <String>[];
      while (court.length < playersPerCourt && unitIdx < playingUnits.length) {
        final unit = playingUnits[unitIdx];
        if (court.length + unit.length <= playersPerCourt) {
          court.addAll(unit);
          unitIdx++;
        } else {
          break;
        }
      }
      if (court.length < playersPerCourt && court.length > 0) {
        for (int i = unitIdx; i < playingUnits.length; i++) {
          final unit = playingUnits[i];
          if (unit.length == 1 && court.length < playersPerCourt) {
            court.add(unit[0]);
            playingUnits.removeAt(i);
            break;
          }
        }
      }
      if (court.isNotEmpty) {
        _courtAssignments.add(court);
      }
    }
    _restingPlayers = restingUnits.expand((unit) => unit).toList();
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

  Future<void> _saveMatchToHistory() async {
    if (_courtAssignments.isEmpty) return;
    final courts = _courtNumbers.split(',').map((c) => c.trim()).toList();
    final now = DateTime.now();
    for (int i = 0; i < _courtAssignments.length && i < courts.length; i++) {
      final record = MatchRecord(
        round: _currentRound,
        timestamp: now,
        court: 'Court ${courts[i]}',
        players: _courtAssignments[i],
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
    _breakTimeRemaining = _breakDuration;
    notifyListeners();

    if (_selectedPlayers.length >= 4) {
      _currentRound++;
      try {
        autoAssignCourts();
        await _saveMatchToHistory();
      } catch (e) {
        // ignore
      }
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(AssetSource('beep.mp3'));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_breakTimeRemaining > 0) {
        _breakTimeRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        _isInBreak = false;
        _timeRemaining = _matchDuration * 60;
        _audioPlayer.stop();
        notifyListeners();
        startTimer();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    WakelockPlus.disable();
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
    _isInBreak = false;
    _breakTimeRemaining = 0;
    _timeRemaining = _matchDuration * 60;
    WakelockPlus.disable();
    notifyListeners();
  }

  void updateSettings({
    String? courtNumbers,
    int? matchDuration,
    int? breakDuration,
    double? chipScale,
  }) {
    if (_isTimerRunning) pauseTimer();
    if (courtNumbers != null) {
      final oldCount = _courtNumbers.split(',').length;
      final newCount = courtNumbers.split(',').length;
      if (oldCount != newCount) {
        _courtAssignments = [];
        _restingPlayers = [];
      }
      _courtNumbers = courtNumbers;
    }
    if (matchDuration != null) {
      _matchDuration = matchDuration;
      if (!_isTimerRunning) _timeRemaining = matchDuration * 60;
    }
    if (breakDuration != null) _breakDuration = breakDuration;
    if (chipScale != null) _chipScale = chipScale;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('courtNumbers', _courtNumbers);
    await prefs.setInt('matchDuration', _matchDuration);
    await prefs.setInt('breakDuration', _breakDuration);
    await prefs.setDouble('chipScale', _chipScale);
  }

  Future<void> clearHistory() async {
    if (_isTimerRunning) pauseTimer();
    _courtAssignments = [];
    _restingPlayers = [];
    _currentRound = 1;
    _restRotationIndex = 0;
    _isInBreak = false;
    await reportManager.clearHistory();
    notifyListeners();
  }

  void setChipScale(double v) {
    _chipScale = v.clamp(0.75, 1.60);
    _saveSettings();
    notifyListeners();
  }

  Future<void> testBeep() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(AssetSource('beep.mp3'));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      await HapticFeedback.heavyImpact();
    }
  }

  void resetRestOrder() {
    _restRotationIndex = 0;
    _restingPlayers = [];
    notifyListeners();
  }

  Future<void> addPlayer(String name, String type, int? pairNum) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    _allPlayers.add(Player(id: newId, name: name, type: type, pairNum: pairNum));
    _allPlayers.sort((a, b) => a.name.compareTo(b.name));
    await _savePlayers();
    notifyListeners();
  }

  Future<void> updatePlayer(
      String id, String name, String type, int? pairNum) async {
    final index = _allPlayers.indexWhere((p) => p.id == id);
    if (index != -1) {
      _allPlayers[index] =
          Player(id: id, name: name, type: type, pairNum: pairNum);
      _allPlayers.sort((a, b) => a.name.compareTo(b.name));
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

  // ── Import / Export helpers ──────────────────────────────────────────────

  /// Export all persistent data as a map of filename → CSV string.
  Future<Map<String, String>> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, String>{};

    // 1. Players
    final sb1 = StringBuffer();
    sb1.writeln('id,name,type,pairNum');
    for (final p in _allPlayers) {
      sb1.writeln('${_csvEsc(p.id)},${_csvEsc(p.name)},${_csvEsc(p.type)},${p.pairNum ?? ''}');
    }
    result['players.csv'] = sb1.toString();

    // 2. Match history (via ReportManager)
    final history = await reportManager.getMatchHistory();
    final sb2 = StringBuffer();
    sb2.writeln('round,timestamp,court,players,duration,status,playMode');
    for (final m in history) {
      sb2.writeln(
        '${m.round},'
        '${_csvEsc(m.timestamp.toIso8601String())},'
        '${_csvEsc(m.court)},'
        '"${m.players.map(_csvEsc).join(';')}",'
        '${m.duration},'
        '${_csvEsc(m.status)},'
        '${_csvEsc(m.playMode)}',
      );
    }
    result['match_history.csv'] = sb2.toString();

    // 3. Match / app settings
    final sb3 = StringBuffer();
    sb3.writeln('key,value');
    sb3.writeln('courtNumbers,${_csvEsc(_courtNumbers)}');
    sb3.writeln('matchDuration,$_matchDuration');
    sb3.writeln('breakDuration,$_breakDuration');
    sb3.writeln('chipScale,$_chipScale');
    result['match_settings.csv'] = sb3.toString();

    // 4. Report settings (raw JSON stored by ReportManager, re-emit as CSV)
    await reportManager.loadSettings();
    final rs = reportManager.settings;
    final sb4 = StringBuffer();
    sb4.writeln('key,value');
    sb4.writeln('casualChargeType,${rs.casualChargeType == CasualChargeType.fixed ? 'fixed' : 'split'}');
    sb4.writeln('casualChargePerSession,${rs.casualChargePerSession}');
    sb4.writeln('shuttleCost,${rs.shuttleCost}');
    sb4.writeln('defaultCourtHire,${rs.defaultCourtHire}');
    result['report_settings.csv'] = sb4.toString();

    // 5. Other prefs (install_id, license details excluded for security)
    final sb5 = StringBuffer();
    sb5.writeln('key,value');
    final otherKeys = ['install_id'];
    for (final k in otherKeys) {
      final v = prefs.get(k);
      if (v != null) sb5.writeln('${_csvEsc(k)},${_csvEsc(v.toString())}');
    }
    result['other_settings.csv'] = sb5.toString();

    return result;
  }

  /// Import from a map of filename → CSV string. Unknown files are skipped.
  Future<List<String>> importAllData(Map<String, String> files) async {
    final log = <String>[];

    if (files.containsKey('players.csv')) {
      try {
        final rows = _parseCsv(files['players.csv']!);
        final imported = <Player>[];
        for (final row in rows) {
          if (row.length < 3) continue;
          imported.add(Player(
            id: row[0],
            name: row[1],
            type: row[2],
            pairNum: (row.length > 3 && row[3].isNotEmpty)
                ? int.tryParse(row[3])
                : null,
          ));
        }
        imported.sort((a, b) => a.name.compareTo(b.name));
        _allPlayers = imported;
        await _savePlayers();
        log.add('Players: imported ${imported.length} records');
      } catch (e) {
        log.add('Players: ERROR – $e');
      }
    }

    if (files.containsKey('match_history.csv')) {
      try {
        final rows = _parseCsv(files['match_history.csv']!);
        int count = 0;
        await reportManager.clearHistory();
        for (final row in rows) {
          if (row.length < 6) continue;
          final players = row[3].split(';').map((s) => s.trim()).toList();
          final record = MatchRecord(
            round: int.tryParse(row[0]) ?? 1,
            timestamp: DateTime.tryParse(row[1]) ?? DateTime.now(),
            court: row[2],
            players: players,
            duration: int.tryParse(row[4]) ?? _matchDuration,
            status: row[5],
            playMode: row.length > 6 ? row[6] : 'Doubles',
          );
          await reportManager.logMatch(record);
          count++;
        }
        log.add('Match history: imported $count records');
      } catch (e) {
        log.add('Match history: ERROR – $e');
      }
    }

    if (files.containsKey('match_settings.csv')) {
      try {
        final rows = _parseCsv(files['match_settings.csv']!);
        for (final row in rows) {
          if (row.length < 2) continue;
          switch (row[0]) {
            case 'courtNumbers':
              _courtNumbers = row[1];
              break;
            case 'matchDuration':
              _matchDuration = int.tryParse(row[1]) ?? _matchDuration;
              _timeRemaining = _matchDuration * 60;
              break;
            case 'breakDuration':
              _breakDuration = int.tryParse(row[1]) ?? _breakDuration;
              break;
            case 'chipScale':
              _chipScale = double.tryParse(row[1]) ?? _chipScale;
              break;
          }
        }
        await _saveSettings();
        log.add('Match settings: imported');
      } catch (e) {
        log.add('Match settings: ERROR – $e');
      }
    }

    if (files.containsKey('report_settings.csv')) {
      try {
        final rows = _parseCsv(files['report_settings.csv']!);
        final map = <String, String>{for (final r in rows) if (r.length >= 2) r[0]: r[1]};
        final rs = ReportSettings(
          casualChargeType: map['casualChargeType'] == 'split'
              ? CasualChargeType.split
              : CasualChargeType.fixed,
          casualChargePerSession:
              double.tryParse(map['casualChargePerSession'] ?? '') ?? 10.0,
          shuttleCost: double.tryParse(map['shuttleCost'] ?? '') ?? 3.0,
          defaultCourtHire:
              double.tryParse(map['defaultCourtHire'] ?? '') ?? 0.0,
        );
        await reportManager.saveSettings(rs);
        log.add('Report settings: imported');
      } catch (e) {
        log.add('Report settings: ERROR – $e');
      }
    }

    notifyListeners();
    return log;
  }

  // ── CSV helpers ──────────────────────────────────────────────────────────

  String _csvEsc(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// RFC-4180 compliant CSV parser.
  /// Handles \r\n (Windows/GDrive), \n (Unix), \r (old Mac) line endings.
  /// Skips the first (header) row and returns data rows only.
  List<List<String>> _parseCsv(String csv) {
    // Normalise all line endings to \n
    final src = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final result = <List<String>>[];
    bool header = true;
    int pos = 0;
    final len = src.length;

    while (pos < len) {
      final row = <String>[];
      // Parse one complete row (fields separated by commas)
      while (pos < len) {
        final field = StringBuffer();
        if (src[pos] == '"') {
          // Quoted field
          pos++; // skip opening quote
          while (pos < len) {
            if (src[pos] == '"') {
              if (pos + 1 < len && src[pos + 1] == '"') {
                field.write('"'); pos += 2; // escaped double-quote
              } else {
                pos++; break;              // closing quote
              }
            } else {
              field.write(src[pos]); pos++;
            }
          }
        } else {
          // Unquoted field: read until comma or newline
          while (pos < len && src[pos] != ',' && src[pos] != '\n') {
            field.write(src[pos]); pos++;
          }
        }
        row.add(field.toString().trim());
        if (pos < len && src[pos] == ',') { pos++; continue; } // next field
        break; // newline or EOF → row is complete
      }
      if (pos < len && src[pos] == '\n') pos++; // consume the newline

      // Skip blank rows
      if (row.isEmpty || (row.length == 1 && row[0].isEmpty)) continue;

      if (header) { header = false; continue; } // discard header row
      result.add(row);
    }
    return result;
  }
  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}
