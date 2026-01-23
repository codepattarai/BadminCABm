// lib/report_manager.dart
// BadminCAB Mobile App - Report Management System
// Handles session reports, cost calculations, and CSV export

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ReportManager {
  static const String _historyKey = 'match_history';
  static const String _settingsKey = 'report_settings';

  // Report Settings
  ReportSettings _settings = ReportSettings();

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    
    if (settingsJson != null) {
      _settings = ReportSettings.fromJson(json.decode(settingsJson));
    }
  }

  Future<void> saveSettings(ReportSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings.toJson()));
  }

  ReportSettings get settings => _settings;

  // Match History Management
  Future<void> logMatch(MatchRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    List<Map<String, dynamic>> history = [];
    if (historyJson != null) {
      history = List<Map<String, dynamic>>.from(json.decode(historyJson));
    }
    
    history.add(record.toJson());
    await prefs.setString(_historyKey, json.encode(history));
  }

  Future<List<MatchRecord>> getMatchHistory({DateTime? date}) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) return [];
    
    final List<dynamic> history = json.decode(historyJson);
    final records = history.map((json) => MatchRecord.fromJson(json)).toList();
    
    if (date != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      return records.where((r) => r.dateStr == dateStr).toList();
    }
    
    return records;
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // Report Generation
  // In class ReportManager:
  Future<SessionReport> generateReport({
  required DateTime date,
  required double courtHire,
  required int shuttleCount,
  required double otherExpenses,
  Map<String, String>? playerTypesByName, // NEW: name -> 'full' | 'casual'
  }) async {
  final matches = await getMatchHistory(date: date);
  if (matches.isEmpty) {
	  return SessionReport.empty(date);
  }
  
  // Summary
  final uniqueRounds = matches.map((m) => m.round).toSet().length;
  final totalMatches = matches.where((m) => m.status == 'Playing').length;
  
  // Build per-player session counts with correct TYPE
  final Map<String, PlayerSessionData> playerSessions = {};
  for (final match in matches) {
	  if (match.status == 'Playing') {
	  for (final playerName in match.players) {
		  final resolvedType = (playerTypesByName?[playerName]?.toLowerCase().trim()) ?? 'full';
		  if (!playerSessions.containsKey(playerName)) {
		  playerSessions[playerName] = PlayerSessionData(
			  name: playerName,
			  type: (resolvedType == 'casual') ? 'casual' : 'full',
			  sessions: 0,
		  );
		  }
		  playerSessions[playerName]!.sessions++;
		  // If any subsequent occurrence says the player is casual, prefer 'casual'
		  if (resolvedType == 'casual') {
		  playerSessions[playerName]!.type = 'casual';
		  }
	  }
	  }
  }
  
  final totalPlayers = playerSessions.length;
  
  // Costs
  final totalShuttleCost = shuttleCount * _settings.shuttleCost;
  final totalBaseCost = courtHire + totalShuttleCost + otherExpenses;
  
  final playerCosts = _calculatePlayerCosts(
	  playerSessions: playerSessions,
	  totalBaseCost: totalBaseCost,
	  totalShuttleCost: totalShuttleCost,
	  totalPlayers: totalPlayers,
  );
  
  return SessionReport(
	  date: date,
	  totalRounds: uniqueRounds,
	  totalMatches: totalMatches,
	  totalPlayers: totalPlayers,
	  shuttlesUsed: shuttleCount,
	  courtHire: courtHire,
	  shuttleCost: _settings.shuttleCost,
	  totalShuttleCost: totalShuttleCost,
	  otherExpenses: otherExpenses,
	  totalBaseCost: totalBaseCost,
	  playerCosts: playerCosts,
	  chargeType: _settings.casualChargeType,
	  casualChargePerSession: _settings.casualChargePerSession,
  );
  }


  List<PlayerCost> _calculatePlayerCosts({
    required Map<String, PlayerSessionData> playerSessions,
    required double totalBaseCost,
    required double totalShuttleCost,
    required int totalPlayers,
  }) {
    final List<PlayerCost> costs = [];
    
    final casualPlayers = playerSessions.values.where((p) => p.type == 'casual').toList();
    final fullPlayers = playerSessions.values.where((p) => p.type == 'full').toList();

    double totalCasualCharges = 0.0;
    double chargePerFullMember = 0.0;

    if (_settings.casualChargeType == CasualChargeType.fixed) {
      // Fixed charge for casual players
      totalCasualCharges = casualPlayers.length * _settings.casualChargePerSession;
      final remainingCharge = totalBaseCost - totalCasualCharges;
      
      if (fullPlayers.isNotEmpty) {
        chargePerFullMember = remainingCharge / fullPlayers.length;
      }
    } else {
      // Equal split for all players
      if (totalPlayers > 0) {
        final chargePerPlayer = totalBaseCost / totalPlayers;
        chargePerFullMember = chargePerPlayer;
        totalCasualCharges = casualPlayers.length * chargePerPlayer;
      }
    }

    // Calculate shuttle share (always split equally)
    final shuttleSharePerPlayer = totalPlayers > 0 ? totalShuttleCost / totalPlayers : 0.0;

    // Create cost entries for each player
    for (final playerData in playerSessions.values) {
      final cost = playerData.type == 'casual'
          ? (_settings.casualChargeType == CasualChargeType.fixed
              ? _settings.casualChargePerSession
              : totalBaseCost / totalPlayers)
          : chargePerFullMember;

      costs.add(PlayerCost(
        name: playerData.name,
        type: playerData.type,
        sessions: playerData.sessions,
        shuttleShare: shuttleSharePerPlayer,
        cost: cost,
      ));
    }

    // Sort by name
    costs.sort((a, b) => a.name.compareTo(b.name));

    return costs;
  }

  // CSV Export
  String generateCSV(SessionReport report) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('BadminCAB Session Report');
    buffer.writeln('Date:,${DateFormat('yyyy-MM-dd').format(report.date)}');
    buffer.writeln('');
    
    // Summary Statistics
    buffer.writeln('Summary Statistics');
    buffer.writeln('Total Rounds:,${report.totalRounds}');
    buffer.writeln('Total Matches:,${report.totalMatches}');
    buffer.writeln('Total Players:,${report.totalPlayers}');
    buffer.writeln('Shuttles Used:,${report.shuttlesUsed}');
    buffer.writeln('');
    
    // Cost Breakdown
    buffer.writeln('Cost Breakdown');
    buffer.writeln('Court Hire Charge:,\$${report.courtHire.toStringAsFixed(2)}');
    buffer.writeln('Shuttles Cost (${report.shuttlesUsed} × \$${report.shuttleCost.toStringAsFixed(2)}):,\$${report.totalShuttleCost.toStringAsFixed(2)}');
    buffer.writeln('Other Expenses:,\$${report.otherExpenses.toStringAsFixed(2)}');
    buffer.writeln('Total Base Cost:,\$${report.totalBaseCost.toStringAsFixed(2)}');
    buffer.writeln('');
    
    // Player Costs
    buffer.writeln('Player Name,Type,Sessions Played,Shuttle Share,Total Cost');
    for (final player in report.playerCosts) {
      buffer.writeln(
        '${player.name},'
        '${player.type.toUpperCase()},'
        '${player.sessions},'
        '\$${player.shuttleShare.toStringAsFixed(2)},'
        '\$${player.cost.toStringAsFixed(2)}'
      );
    }
    buffer.writeln('');
    
    // Financial Summary
    buffer.writeln('Financial Summary');
    buffer.writeln('Charge Model:,${report.chargeType == CasualChargeType.fixed ? "Fixed Charge for Casual Players" : "Equal Split for All Players"}');
    
    final casualCount = report.playerCosts.where((p) => p.type == 'casual').length;
    final fullCount = report.playerCosts.where((p) => p.type == 'full').length;
    final totalCasualCharges = report.playerCosts
        .where((p) => p.type == 'casual')
        .fold(0.0, (sum, p) => sum + p.cost);
    final totalFullCharges = report.playerCosts
        .where((p) => p.type == 'full')
        .fold(0.0, (sum, p) => sum + p.cost);
    
    buffer.writeln('Casual Players Contribution ($casualCount players):,\$${totalCasualCharges.toStringAsFixed(2)}');
    buffer.writeln('Full Members Split ($fullCount members):,\$${totalFullCharges.toStringAsFixed(2)}');
    
    final totalCollected = report.playerCosts.fold(0.0, (sum, p) => sum + p.cost);
    buffer.writeln('Total Collected:,\$${totalCollected.toStringAsFixed(2)}');
    
    return buffer.toString();
  }
}

// Data Models
class ReportSettings {
  CasualChargeType casualChargeType;
  double casualChargePerSession;
  double shuttleCost;
  double defaultCourtHire;

  ReportSettings({
    this.casualChargeType = CasualChargeType.fixed,
    this.casualChargePerSession = 10.0,
    this.shuttleCost = 3.0,
    this.defaultCourtHire = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'casualChargeType': casualChargeType.toString(),
    'casualChargePerSession': casualChargePerSession,
    'shuttleCost': shuttleCost,
    'defaultCourtHire': defaultCourtHire,
  };

  factory ReportSettings.fromJson(Map<String, dynamic> json) => ReportSettings(
    casualChargeType: json['casualChargeType'] == 'CasualChargeType.split'
        ? CasualChargeType.split
        : CasualChargeType.fixed,
    casualChargePerSession: json['casualChargePerSession'] ?? 10.0,
    shuttleCost: json['shuttleCost'] ?? 3.0,
    defaultCourtHire: json['defaultCourtHire'] ?? 0.0,
  );
}

enum CasualChargeType { fixed, split }

class MatchRecord {
  final int round;
  final DateTime timestamp;
  final String court;
  final List<String> players;
  final int duration;
  final String status;
  final String playMode;

  MatchRecord({
    required this.round,
    required this.timestamp,
    required this.court,
    required this.players,
    required this.duration,
    required this.status,
    this.playMode = 'Doubles',
  });

  String get dateStr => DateFormat('yyyy-MM-dd').format(timestamp);

  Map<String, dynamic> toJson() => {
    'round': round,
    'timestamp': timestamp.toIso8601String(),
    'court': court,
    'players': players,
    'duration': duration,
    'status': status,
    'playMode': playMode,
  };

  factory MatchRecord.fromJson(Map<String, dynamic> json) => MatchRecord(
    round: json['round'],
    timestamp: DateTime.parse(json['timestamp']),
    court: json['court'],
    players: List<String>.from(json['players']),
    duration: json['duration'],
    status: json['status'],
    playMode: json['playMode'] ?? 'Doubles',
  );
}

class PlayerSessionData {
  final String name;
  String type;
  int sessions;

  PlayerSessionData({
    required this.name,
    required this.type,
    required this.sessions,
  });
}

class PlayerCost {
  final String name;
  final String type;
  final int sessions;
  final double shuttleShare;
  final double cost;

  PlayerCost({
    required this.name,
    required this.type,
    required this.sessions,
    required this.shuttleShare,
    required this.cost,
  });
}

class SessionReport {
  final DateTime date;
  final int totalRounds;
  final int totalMatches;
  final int totalPlayers;
  final int shuttlesUsed;
  final double courtHire;
  final double shuttleCost;
  final double totalShuttleCost;
  final double otherExpenses;
  final double totalBaseCost;
  final List<PlayerCost> playerCosts;
  final CasualChargeType chargeType;
  final double casualChargePerSession;

  SessionReport({
    required this.date,
    required this.totalRounds,
    required this.totalMatches,
    required this.totalPlayers,
    required this.shuttlesUsed,
    required this.courtHire,
    required this.shuttleCost,
    required this.totalShuttleCost,
    required this.otherExpenses,
    required this.totalBaseCost,
    required this.playerCosts,
    required this.chargeType,
    required this.casualChargePerSession,
  });

  factory SessionReport.empty(DateTime date) => SessionReport(
    date: date,
    totalRounds: 0,
    totalMatches: 0,
    totalPlayers: 0,
    shuttlesUsed: 0,
    courtHire: 0,
    shuttleCost: 3.0,
    totalShuttleCost: 0,
    otherExpenses: 0,
    totalBaseCost: 0,
    playerCosts: [],
    chargeType: CasualChargeType.fixed,
    casualChargePerSession: 10.0,
  );
}