// lib/dashboard_screen.dart
// BadminCAB v20.26.6 – Dashboard Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'player_selection_screen.dart';
import 'app_theme.dart';

// ── Shared glow-border card widget ───────────────────────────────────────────
class _GlowCard extends StatelessWidget {
  const _GlowCard({
    required this.child,
    this.glowColors,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16.0,
    this.cardColor,
    this.boxShadow,
  });

  final Widget child;
  final List<Color>? glowColors;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? cardColor;
  final List<BoxShadow>? boxShadow;

  static const List<Color> defaultGlow = [AppTheme.accent, AppTheme.accent2];
  static const List<Color> restGlow    = [AppTheme.accent2, AppTheme.accent2];

  @override
  Widget build(BuildContext context) {
    final glow       = glowColors ?? defaultGlow;
    final r          = borderRadius;
    final innerColor = cardColor ?? AppTheme.panel;
    const glowWidth  = 1.5;

    final innerContainer = Container(
      decoration: BoxDecoration(
        color: innerColor,
        borderRadius: BorderRadius.circular(r - glowWidth),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [innerColor.withOpacity(1), AppTheme.panel2],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (glow.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: AppTheme.border),
          color: innerColor,
          boxShadow: boxShadow,
        ),
        child: Padding(padding: padding, child: child),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: glow,
        ),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: glow.first.withOpacity(0.20),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: glow.last.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      padding: EdgeInsets.all(glowWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r - glowWidth),
        child: innerContainer,
      ),
    );
  }
}

// ── Dashboard Screen ──────────────────────────────────────────────────────────

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.panel,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
            boxShadow: [
              BoxShadow(
                color: Color(0x595AAEF8),
                offset: Offset(0, 1),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: AppBar(
            title: const Text('Badminton Court Allocation Board'),
            backgroundColor: Colors.transparent,
            foregroundColor: AppTheme.textPrimary,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return Column(
            children: [
              // ── Sticky compact timer bar (never scrolls away) ─────────────
              _buildStickyTimer(context, appState),

              // ── Scrollable court content ──────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (appState.courtAssignments.isNotEmpty) ...[
                        _buildCourtAssignments(context, appState),
                        const SizedBox(height: 16),
                        if (appState.restingPlayers.isNotEmpty)
                          _buildRestingPlayers(context, appState),
                      ] else
                        _buildEmptyState(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Sticky compact timer bar ──────────────────────────────────────────────
  //
  //  Row 1 │ mode-badge  │  HH:MM (large)  │  round-badge
  //  Row 2 │ [Select Players]  ▶/⏸  ⏹  [Assign]
  //  Row 3 │ thin progress bar (teal / accent2)
  //
  Widget _buildStickyTimer(BuildContext context, AppState appState) {
    final displayTime =
        appState.isInBreak ? appState.breakTimeRemaining : appState.timeRemaining;
    final minutes = displayTime ~/ 60;
    final seconds = displayTime % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final progress =
        (appState.matchDuration * 60 - appState.timeRemaining) /
        (appState.matchDuration * 60);

    // Break → orange glow; playing → blue-teal glow
    final timerColor =
        appState.isInBreak ? AppTheme.breakColor : AppTheme.accent;
    final glowColors = appState.isInBreak
        ? [AppTheme.breakColor, const Color(0xFFB45309)]
        : _GlowCard.defaultGlow;

    // Play/pause AND stop share the same active/break colour pattern
    final fabActiveColor  = appState.isInBreak ? AppTheme.border : AppTheme.accent;

    return _GlowCard(
      glowColors: glowColors,
      borderRadius: 12,          // slightly rounded sticky bar
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Row 1: mode-badge | clock | round-badge ───────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _modeBadge(appState, timerColor),

              Text(
                timeStr,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  height: 1.0,
                ),
              ),

              // Hidden during break to keep clock centred
              appState.isInBreak
                  ? const SizedBox(width: 56)
                  : _roundBadge(appState.currentRound),
            ],
          ),

          const SizedBox(height: 8),

          // ── Row 2: [Select Players]  ▶/⏸  ⏹  [Assign] ───────────────────
          Row(
            children: [
              // Select Players  (accent / blue)
              Expanded(
                child: _compactButton(
                  label: 'Select (${appState.selectedPlayers.length})',
                  icon: Icons.people,
                  color: AppTheme.accent,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PlayerSelectionScreen()),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Play / Pause FAB
              _timerFab(
                heroTag: 'play',
                icon: appState.isTimerRunning ? Icons.pause : Icons.play_arrow,
                color: fabActiveColor,
                enabled: !appState.isInBreak,
                onPressed: () {
                  if (appState.isTimerRunning) {
                    appState.pauseTimer();
                  } else {
                    appState.startTimer();
                  }
                },
              ),

              const SizedBox(width: 6),

              // Stop FAB — same colour pattern as play/pause
              _timerFab(
                heroTag: 'reset',
                icon: Icons.stop,
                color: fabActiveColor,
                enabled: !appState.isInBreak,
                onPressed: appState.resetTimer,
              ),

              const SizedBox(width: 8),

              // Assign  (accent / blue — same as Select Players)
              Expanded(
                child: _compactButton(
                  label: 'Assign',
                  icon: Icons.shuffle,
                  color: AppTheme.accent,
                  onPressed: () {
                    try {
                      appState.autoAssignCourts();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Courts assigned! Press ▶ to start')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Row 3: progress bar (teal / accent2) ─────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.border,
              // accent2 (teal) always — distinct from the blue timer glow
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent2),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode badge (left of clock) ────────────────────────────────────────────
  Widget _modeBadge(AppState appState, Color color) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.40), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            appState.isInBreak ? Icons.coffee_outlined : Icons.timer,
            size: 18,
            color: color,
          ),
          const SizedBox(height: 2),
          Text(
            appState.isInBreak ? 'BREAK' : 'TIMER',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Round badge (right of clock) ──────────────────────────────────────────
  Widget _roundBadge(int round) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                '$round',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'ROUND',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Small FAB (play/pause and stop) ──────────────────────────────────────
  Widget _timerFab({
    required String heroTag,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: enabled ? onPressed : null,
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        mini: true,
        child: Icon(icon, size: 20),
      ),
    );
  }

  // ── Compact text button (Select Players / Assign) ─────────────────────────
  Widget _compactButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Court assignments ─────────────────────────────────────────────────────
  Widget _buildCourtAssignments(BuildContext context, AppState appState) {
    final orientation = MediaQuery.of(context).orientation;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardsPerRow = orientation == Orientation.portrait ? 1 : 2;
    final cardWidth   =
        (screenWidth - (16 * (cardsPerRow + 1))) / cardsPerRow;

    final s       = appState.chipScale;
    final nameFs  = (22.0 * s).clamp(14.0, 22.0);
    final titleFs = (28.0 * s).clamp(18.0, 30.0);
    final padH    = (10.0 * s).clamp(6.0,  14.0);
    final padV    = (3.0  * s).clamp(2.0,   6.0);
    final chipGap = (8.0  * s).clamp(6.0,  14.0);
    final borderW = (1.2  * s).clamp(1.0,   1.8);
    const chipRadius = BorderRadius.all(Radius.circular(12));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COURT ASSIGNMENTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMuted,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: appState.courtAssignments.asMap().entries.map((entry) {
            final index    = entry.key;
            final players  = entry.value;
            final courtNum =
                appState.courtNumbers.split(',')[index].trim();

            return SizedBox(
              width: orientation == Orientation.portrait
                  ? double.infinity
                  : cardWidth,
              child: _GlowCard(
                glowColors: _GlowCard.defaultGlow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Court $courtNum',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: titleFs,
                        letterSpacing: 0.2,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: chipGap),
                    Wrap(
                      spacing: chipGap,
                      runSpacing: chipGap,
                      children: players.map((playerName) {
                        final paired = _isPaired(playerName, appState);
                        // Chip.label must be a Row so Flexible has a valid
                        // Flex parent — bare Flexible causes ParentDataWidget error
                        return Chip(
                          labelPadding: EdgeInsets.symmetric(
                              horizontal: padH, vertical: padV),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (paired) ...[
                                Icon(Icons.link,
                                    size: nameFs * 0.85,
                                    color: AppTheme.chipPlayText),
                                SizedBox(width: padH * 0.4),
                              ],
                              Flexible(
                                child: Text(
                                  playerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: nameFs,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.15,
                                    color: AppTheme.chipPlayText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppTheme.chipPlayBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: chipRadius,
                            side: BorderSide(
                                color: AppTheme.chipPlayBorder,
                                width: borderW),
                          ),
                          elevation: 0,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(
                              horizontal: -1, vertical: -2),
                        );
                      }).toList(),
                    ),
                  ],
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

  // ── Resting players card ──────────────────────────────────────────────────
  Widget _buildRestingPlayers(BuildContext context, AppState appState) {
    final s       = appState.chipScale;
    final nameFs  = (22.0 * s).clamp(14.0, 22.0);
    final titleFs = (26.0 * s).clamp(16.0, 28.0);
    final padH    = (10.0 * s).clamp(6.0,  14.0);
    final padV    = (3.0  * s).clamp(2.0,   6.0);
    final chipGap = (8.0  * s).clamp(6.0,  14.0);
    final borderW = (1.4  * s).clamp(1.0,   2.0);
    const chipRadius = BorderRadius.all(Radius.circular(12));

    return _GlowCard(
      glowColors: _GlowCard.restGlow,
      cardColor: AppTheme.restCardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resting Players',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: titleFs,
              letterSpacing: 0.2,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: chipGap),
          Wrap(
            spacing: chipGap,
            runSpacing: chipGap,
            children: appState.restingPlayers.map((playerName) {
              final paired = _isPaired(playerName, appState);
              return Chip(
                labelPadding:
                    EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (paired) ...[
                      Icon(Icons.link,
                          size: nameFs * 0.85,
                          color: AppTheme.chipRestText),
                      SizedBox(width: padH * 0.4),
                    ],
                    Flexible(
                      child: Text(
                        playerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: nameFs,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.15,
                          color: AppTheme.chipRestText,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.chipRestBg,
                shape: RoundedRectangleBorder(
                  borderRadius: chipRadius,
                  side: BorderSide(
                      color: AppTheme.chipRestBorder, width: borderW),
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
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: const [
            Icon(Icons.people_outline, size: 64, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text('Select players to begin',
                style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
