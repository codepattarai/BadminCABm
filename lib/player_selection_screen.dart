// lib/player_selection_screen.dart
// BadminCAB v20.26.4 – Player Selection Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'app_theme.dart';

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
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(Player p, String q) {
    if (q.isEmpty) return true;
    return p.name.toLowerCase().contains(q) ||
        p.type.toLowerCase().contains(q) ||
        (p.pairNum != null && p.pairNum.toString().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Players for Session'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final filtered = appState.allPlayers
              .where((p) => _matchesQuery(p, _query))
              .toList();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.surface,
                child: Column(
                  children: [
                    Text(
                      '${appState.selectedPlayers.length} players selected',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryLight),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selection order determines play priority (first in = first on court)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
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
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final player = filtered[index];
                    final isSelected =
                        appState.selectedPlayers.contains(player.id);
                    final selectionIndex = isSelected
                        ? appState.selectedPlayers.indexOf(player.id) + 1
                        : null;

                    // Chip text is always dark — chips use light bg colours
                    const chipTextStyle = TextStyle(
                        fontSize: 10, color: Color(0xFF1A1A1A));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected
                          ? AppTheme.accent   // sky blue when selected
                          : AppTheme.panel,   // dark panel when unselected
                      child: ListTile(
                        onTap: () => appState.togglePlayerSelection(player.id),
                        leading: isSelected
                            ? CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Text(
                                  '$selectionIndex',
                                  style: const TextStyle(
                                      color: AppTheme.panel,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        title: Text(
                          player.name,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w500),
                        ),
                        subtitle: Row(
                          children: [
                            Chip(
                              label: Text(player.type.toUpperCase(),
                                  style: chipTextStyle),
                              // Always use yellow chip — dark text always readable
                              backgroundColor: AppTheme.chipPlayBg,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            if (player.pairNum != null) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text('Pair ${player.pairNum}',
                                    style: chipTextStyle),
                                // Always use teal chip — dark text always readable
                                backgroundColor: AppTheme.chipRestBg,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.white)
                            : Icon(Icons.circle_outlined,
                                color: AppTheme.textMuted),
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
                        backgroundColor: AppTheme.accent,
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