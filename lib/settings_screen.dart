// lib/settings_screen.dart
// BadminCAB v20.26.4.1 – Settings Screen
//
// Card layout (top to bottom):
//   1. License Status   – compact single-line status + Manage License button
//   2. Match Settings   – court numbers, durations + Save Settings button
//   3. Display          – chip size slider + live chip previews
//   4. Controls         – Test Sound, Reset Rest Order, Delete History,
//                         Import Data, Export All Data

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'app_state.dart';
import 'license_manager.dart';
import 'license_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Match settings controllers
  final _courtNumbersController = TextEditingController();
  final _matchDurationController = TextEditingController();
  final _breakDurationController = TextEditingController();

  // License state
  final _lm = LicenseManager();
  bool _licLoading = true;
  String _licenseStatus = 'Checking...';
  IconData _licIcon = Icons.hourglass_top;
  Color _licIconColor = Colors.grey;

  // Display state
  double? _localScale;

  // Controls busy flags
  bool _exportBusy = false;
  bool _importBusy = false;

  // Known import filenames
  static const _knownFiles = {
    'players.csv': 'Player roster',
    'match_history.csv': 'Match history',
    'match_settings.csv': 'Match & timer settings',
    'report_settings.csv': 'Report / cost settings',
    'other_settings.csv': 'Other preferences',
  };

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _courtNumbersController.text = appState.courtNumbers;
    _matchDurationController.text = appState.matchDuration.toString();
    _breakDurationController.text = appState.breakDuration.toString();
    _loadLicenseInfo();
  }

  // ── License ──────────────────────────────────────────────────────────────

  Future<void> _loadLicenseInfo() async {
    try {
      final info = await _lm.getCurrentLicense();
      String status;
      IconData icon;
      Color color;
      switch (info.type) {
        case LicenseType.full:
          status = 'Full License – device locked';
          icon = Icons.verified;
          color = Colors.green;
          break;
        case LicenseType.trial:
          final expiry = info.expiry;
          if (expiry != null && expiry.isAfter(DateTime.now())) {
            final days = expiry.difference(DateTime.now()).inDays + 1;
            status =
                'Trial – $days day(s) left · expires ${DateFormat('dd MMM yyyy').format(expiry)}';
            icon = Icons.hourglass_top;
            color = Colors.orange;
          } else {
            status = 'Trial expired – please activate a full license';
            icon = Icons.error_outline;
            color = Colors.red;
          }
          break;
        default:
          status = 'Not activated';
          icon = Icons.lock_outline;
          color = Colors.red;
      }
      if (!mounted) return;
      setState(() {
        _licenseStatus = status;
        _licIcon = icon;
        _licIconColor = color;
        _licLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _licenseStatus = 'Unable to read license';
        _licIcon = Icons.error_outline;
        _licIconColor = Colors.red;
        _licLoading = false;
      });
    }
  }

  void _openLicenseManager() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LicenseScreen()));
    _loadLicenseInfo();
  }

  // ── Export ───────────────────────────────────────────────────────────────

  Future<void> _exportData() async {
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final files = await appState.exportAllData();
      final dir = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final exportDir = Directory('${dir.path}/BadminCAB_Export_$dateStr');
      await exportDir.create(recursive: true);
      final xFiles = <XFile>[];
      for (final entry in files.entries) {
        final file = File('${exportDir.path}/${entry.key}');
        await file.writeAsString(entry.value);
        xFiles.add(XFile(file.path));
      }
      await Share.shareXFiles(
        xFiles,
        subject: 'BadminCAB Data Export $dateStr',
        text: 'BadminCAB full data export – ${xFiles.length} files',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported ${xFiles.length} file(s) successfully'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  // ── Import ───────────────────────────────────────────────────────────────

  String _normKey(String filename) {
    final lower = filename.toLowerCase();
    for (final key in _knownFiles.keys) {
      if (lower == key ||
          lower.endsWith('_$key') ||
          lower.endsWith('-$key')) return key;
    }
    return lower;
  }

  Future<void> _importData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Data'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This will replace your current data with the selected CSV files.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Select one or more CSV files previously exported from BadminCAB:\n\n'
                '• players.csv\n'
                '• match_history.csv\n'
                '• match_settings.csv\n'
                '• report_settings.csv\n\n'
                'You can select multiple files at once.',
              ),
              SizedBox(height: 12),
              Text(
                'License data is never imported for security.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white),
            child: const Text('Pick Files'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('File picker error: $e'),
            backgroundColor: Colors.red));
      }
      return;
    }

    if (result == null || result.files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No files selected – import cancelled.'),
            backgroundColor: Colors.orange));
      }
      return;
    }

    final pickedNames = result.files.map((f) => f.name).toList();
    final recognized =
        pickedNames.where((n) => _knownFiles.containsKey(_normKey(n))).toList();
    final unrecognized =
        pickedNames.where((n) => !_knownFiles.containsKey(_normKey(n))).toList();

    if (recognized.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'No recognised BadminCAB files selected.\n'
            'Expected: ${_knownFiles.keys.join(', ')}\n'
            'Got: ${pickedNames.join(', ')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ));
      }
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Import'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The following files will be imported:'),
              const SizedBox(height: 8),
              ...recognized.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child:
                              Text('$n  –  ${_knownFiles[_normKey(n)]}')),
                    ]),
                  )),
              if (unrecognized.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Skipped (not recognised):',
                    style: TextStyle(color: Colors.orange)),
                ...unrecognized.map((n) =>
                    Text('  • $n', style: const TextStyle(color: Colors.orange))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Import Now'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;
    setState(() => _importBusy = true);

    try {
      final importMap = <String, String>{};
      for (final file in result.files) {
        final normName = _normKey(file.name);
        if (!_knownFiles.containsKey(normName)) continue;
        String csvText;
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          try {
            csvText = utf8.decode(file.bytes!, allowMalformed: true);
          } catch (_) {
            csvText = String.fromCharCodes(file.bytes!);
          }
          if (csvText.startsWith('\uFEFF')) csvText = csvText.substring(1);
        } else if (file.path != null) {
          csvText = await File(file.path!).readAsString();
          if (csvText.startsWith('\uFEFF')) csvText = csvText.substring(1);
        } else {
          continue;
        }
        importMap[normName] = csvText;
      }

      if (importMap.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not read any file content.'),
              backgroundColor: Colors.red));
        }
        return;
      }

      final appState = Provider.of<AppState>(context, listen: false);
      final log = await appState.importAllData(importMap);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Complete'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: log
                  .map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              l.contains('ERROR') ? Icons.error : Icons.check,
                              color: l.contains('ERROR')
                                  ? Colors.red
                                  : Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(l)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) {
        _courtNumbersController.text = appState.courtNumbers;
        _matchDurationController.text = appState.matchDuration.toString();
        _breakDurationController.text = appState.breakDuration.toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Import failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _importBusy = false);
    }
  }

  // ── Delete history ────────────────────────────────────────────────────────

  Future<void> _confirmDeleteHistory(AppState appState) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete History'),
        content: const Text(
            'This will permanently delete all match history and reset the '
            'rest rotation. This cannot be undone.\n\nContinue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await appState.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('History deleted.'), backgroundColor: Colors.green));
      }
    }
  }

  // ── Reset rest order ──────────────────────────────────────────────────────

  Future<void> _confirmResetRestOrder(AppState appState) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Rest Order'),
        content: const Text(
            'This resets only the player rest rotation order.\n'
            'Match history and round number are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) {
      appState.resetRestOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Rest order reset.'), backgroundColor: Colors.green));
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

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
                _buildLicenseCard(),
                const SizedBox(height: 12),
                _buildMatchSettingsCard(appState),
                const SizedBox(height: 12),
                _buildDisplayCard(appState),
                const SizedBox(height: 12),
                _buildControlsCard(appState),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Card 1: License Status ────────────────────────────────────────────────

  Widget _buildLicenseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: _licLoading
            ? const Row(children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Checking license...'),
              ])
            : Row(
                children: [
                  Icon(_licIcon, color: _licIconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_licenseStatus,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _openLicenseManager,
                    icon: const Icon(Icons.vpn_key, size: 15),
                    label: const Text('Manage'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Card 2: Match Settings ────────────────────────────────────────────────

  Widget _buildMatchSettingsCard(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Match Settings',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: _courtNumbersController,
              decoration: const InputDecoration(
                labelText: 'Court Numbers',
                hintText: 'e.g., 1,2,3',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matchDurationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Match Duration (minutes)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _breakDurationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Break Duration (seconds)',
                helperText: 'Time for players to check new assignments',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  appState.updateSettings(
                    courtNumbers: _courtNumbersController.text,
                    matchDuration: int.tryParse(_matchDurationController.text),
                    breakDuration: int.tryParse(_breakDurationController.text),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Settings saved!'),
                      backgroundColor: Colors.green));
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card 3: Display ───────────────────────────────────────────────────────

  Widget _buildDisplayCard(AppState appState) {
    final scale = _localScale ?? appState.chipScale;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Display',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.text_increase,
                    color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Player Chip Size',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Text('${scale.toStringAsFixed(2)}x',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            Slider(
              value: scale,
              min: 0.75,
              max: 1.60,
              divisions: 17,
              label: '${scale.toStringAsFixed(2)}x',
              onChanged: (v) => setState(() => _localScale = v),
              onChangeEnd: (v) {
                _localScale = null;
                appState.setChipScale(v);
              },
            ),
            const SizedBox(height: 4),
            const Text('Preview:',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _previewChip(
                    label: 'Paired - Playing',
                    icon: Icons.link,
                    bg: Colors.orangeAccent.shade100,
                    border: Colors.deepOrange.shade300),
                _previewChip(
                    label: 'Playing',
                    bg: Colors.orange.shade200,
                    border: Colors.orange.shade400),
                _previewChip(
                    label: 'Paired - Resting',
                    icon: Icons.link,
                    bg: Colors.teal.shade300,
                    border: Colors.teal.shade600),
                _previewChip(
                    label: 'Resting',
                    bg: Colors.teal.shade200,
                    border: Colors.teal.shade500),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewChip({
    required String label,
    IconData? icon,
    required Color bg,
    required Color border,
  }) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.black87),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ],
      ),
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: border, width: 1.2),
      ),
      elevation: 0,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }

  // ── Card 4: Controls ──────────────────────────────────────────────────────

  Widget _buildControlsCard(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Controls',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),

            // Row 1: Test Sound | Reset Rest Order
            Row(
              children: [
                Expanded(
                  child: _ctrlBtn(
                    icon: Icons.volume_up,
                    label: 'Test Sound',
                    color: const Color(0xFF6366F1),
                    onTap: () => appState.testBeep(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ctrlBtn(
                    icon: Icons.replay,
                    label: 'Reset Rest Order',
                    color: Colors.blueGrey,
                    onTap: () => _confirmResetRestOrder(appState),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Delete History (full width, red)
            _ctrlBtn(
              icon: Icons.delete_sweep,
              label: 'Delete History',
              color: Colors.red,
              onTap: () => _confirmDeleteHistory(appState),
              fullWidth: true,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),

            // Row 3: Import | Export
            Row(
              children: [
                Expanded(
                  child: _ctrlBtn(
                    icon: Icons.download_for_offline,
                    label: 'Import Data',
                    color: Colors.teal,
                    busy: _importBusy,
                    onTap: _importData,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ctrlBtn(
                    icon: Icons.upload_file,
                    label: 'Export All Data',
                    color: const Color(0xFF6366F1),
                    busy: _exportBusy,
                    onTap: _exportData,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'License keys are never exported or imported.',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool busy = false,
    bool fullWidth = false,
  }) {
    final btn = ElevatedButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 18),
      label: Text(label, textAlign: TextAlign.center),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  @override
  void dispose() {
    _courtNumbersController.dispose();
    _matchDurationController.dispose();
    _breakDurationController.dispose();
    super.dispose();
  }
}
