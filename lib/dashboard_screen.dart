// lib/dashboard_screen.dart
// BadminCAB v20.26.4 – Dashboard Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'player_selection_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badminton Court Allocation Board'),
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
    final displayTime =
        appState.isInBreak ? appState.breakTimeRemaining : appState.timeRemaining;
    final minutes = displayTime ~/ 60;
    final seconds = displayTime % 60;
    final progress = (appState.matchDuration * 60 - appState.timeRemaining) /
        (appState.matchDuration * 60);

    return Card(
      color: appState.isInBreak ? Colors.orange : const Color(0xFF6366F1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              appState.isInBreak ? '⏱️ BREAK TIME' : 'Round ${appState.currentRound}',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold),
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
                  backgroundColor: appState.isInBreak
                      ? Colors.grey.withOpacity(0.3)
                      : Colors.white.withOpacity(0.3),
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.screen_lock_portrait, color: Colors.white70, size: 16),
                SizedBox(width: 4),
                Text('Screen will stay awake',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlayerSelectionScreen()),
            ),
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
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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

  Widget _buildCourtAssignments(BuildContext context, AppState appState) {
    final orientation = MediaQuery.of(context).orientation;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardsPerRow = orientation == Orientation.portrait ? 1 : 2;
    final cardWidth = (screenWidth - (16 * (cardsPerRow + 1))) / cardsPerRow;

    final s = appState.chipScale;
    final nameFs = (22.0 * s).clamp(14.0, 22.0);
    final titleFs = (28.0 * s).clamp(18.0, 30.0);
    final padH = (10.0 * s).clamp(6.0, 14.0);
    final padV = (3.0 * s).clamp(2.0, 6.0);
    final chipGap = (8.0 * s).clamp(6.0, 14.0);
    final borderW = (1.2 * s).clamp(1.0, 1.8);
    const radius = BorderRadius.all(Radius.circular(12));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Court Assignments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: appState.courtAssignments.asMap().entries.map((entry) {
            final index = entry.key;
            final players = entry.value;
            final courtNum =
                appState.courtNumbers.split(',')[index].trim();
            return SizedBox(
              width: orientation == Orientation.portrait ? double.infinity : cardWidth,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Court $courtNum',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: titleFs,
                              letterSpacing: 0.2)),
                      SizedBox(height: chipGap),
                      Wrap(
                        spacing: chipGap,
                        runSpacing: chipGap,
                        children: players.map((playerName) {
                          final isPaired = _isPaired(playerName, appState);
                          final bg = isPaired
                              ? Colors.orange.shade300
                              : Colors.orange.shade200;
                          final border = isPaired
                              ? Colors.deepOrange.shade400
                              : Colors.orange.shade400;
                          return Chip(
                            labelPadding: EdgeInsets.symmetric(
                                horizontal: padH, vertical: padV),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPaired) ...[
                                  const Icon(Icons.link,
                                      size: 18, color: Colors.black87),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    playerName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: nameFs,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.15,
                                        color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: bg,
                            shape: RoundedRectangleBorder(
                              borderRadius: radius,
                              side: BorderSide(color: border, width: borderW),
                            ),
                            elevation: 0,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity:
                                const VisualDensity(horizontal: -1, vertical: -2),
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
      orElse: () =>
          Player(id: '', name: '', type: 'full', pairNum: null),
    );
    return player.pairNum != null;
  }

  Widget _buildRestingPlayers(BuildContext context, AppState appState) {
    final s = appState.chipScale;
    final nameFs = (22.0 * s).clamp(14.0, 22.0);
    final titleFs = (26.0 * s).clamp(16.0, 28.0);
    final padH = (10.0 * s).clamp(6.0, 14.0);
    final padV = (3.0 * s).clamp(2.0, 6.0);
    final chipGap = (8.0 * s).clamp(6.0, 14.0);
    final borderW = (1.4 * s).clamp(1.0, 2.0);
    const radius = BorderRadius.all(Radius.circular(12));

    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resting Players',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: titleFs,
                    letterSpacing: 0.2)),
            SizedBox(height: chipGap),
            Wrap(
              spacing: chipGap,
              runSpacing: chipGap,
              children: appState.restingPlayers.map((playerName) {
                final isPaired = _isPaired(playerName, appState);
                final bg =
                    isPaired ? Colors.teal.shade300 : Colors.teal.shade200;
                final border =
                    isPaired ? Colors.teal.shade700 : Colors.teal.shade600;
                return Chip(
                  labelPadding:
                      EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPaired) ...[
                        const Icon(Icons.link,
                            size: 18, color: Colors.black87),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          playerName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: nameFs,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.15,
                              color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: radius,
                    side: BorderSide(color: border, width: borderW),
                  ),
                  elevation: 0,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity:
                      const VisualDensity(horizontal: -1, vertical: -2),
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
            Text('Select players to begin',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
