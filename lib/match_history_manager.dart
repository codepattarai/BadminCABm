import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class MatchHistoryManager {
  static const String historyFileName = 'match_history.json';
  
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
  
  Future<File> get _historyFile async {
    final path = await _localPath;
    return File('$path/$historyFileName');
  }
  
  // Save match record
  Future<void> saveMatch(MatchRecord record) async {
    try {
      final file = await _historyFile;
      List<MatchRecord> history = await loadHistory();
      history.add(record);
      
      final jsonData = history.map((r) => r.toJson()).toList();
      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      print('Error saving match: $e');
    }
  }
  
  // Load all match history
  Future<List<MatchRecord>> loadHistory() async {
    try {
      final file = await _historyFile;
      if (!await file.exists()) {
        return [];
      }
      
      final contents = await file.readAsString();
      final List<dynamic> jsonData = json.decode(contents);
      return jsonData.map((json) => MatchRecord.fromJson(json)).toList();
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }
  
  // Get matches for specific date
  Future<List<MatchRecord>> getMatchesForDate(DateTime date) async {
    final allMatches = await loadHistory();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    return allMatches.where((match) {
      final matchDateStr = DateFormat('yyyy-MM-dd').format(match.timestamp);
      return matchDateStr == dateStr;
    }).toList();
  }
  
  // Clear all history
  Future<void> clearHistory() async {
    try {
      final file = await _historyFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing history: $e');
    }
  }
}

class MatchRecord {
  final int round;
  final DateTime timestamp;
  final List<List<String>> courtAssignments;
  final List<String> restingPlayers;
  final List<String> courtLabels;
  final int duration;
  
  MatchRecord({
    required this.round,
    required this.timestamp,
    required this.courtAssignments,
    required this.restingPlayers,
    required this.courtLabels,
    required this.duration,
  });
  
  Map<String, dynamic> toJson() => {
    'round': round,
    'timestamp': timestamp.toIso8601String(),
    'courtAssignments': courtAssignments,
    'restingPlayers': restingPlayers,
    'courtLabels': courtLabels,
    'duration': duration,
  };
  
  factory MatchRecord.fromJson(Map<String, dynamic> json) => MatchRecord(
    round: json['round'],
    timestamp: DateTime.parse(json['timestamp']),
    courtAssignments: (json['courtAssignments'] as List)
        .map((court) => (court as List).map((p) => p.toString()).toList())
        .toList(),
    restingPlayers: (json['restingPlayers'] as List)
        .map((p) => p.toString())
        .toList(),
    courtLabels: (json['courtLabels'] as List)
        .map((l) => l.toString())
        .toList(),
    duration: json['duration'],
  );
}