// lib/reports_screen.dart
// BadminCAB v20.26.4 – Reports Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'app_state.dart';
import 'report_manager.dart';
import 'csv_exporter.dart';

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

  String _casualChargeType = 'fixed';
  bool _isLoading = false;

  final _reportManager = ReportManager();
  SessionReport? _report;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    await _reportManager.loadSettings();
    final s = _reportManager.settings;
    _shuttleCostController.text = s.shuttleCost.toString();
    _casualChargeController.text = s.casualChargePerSession.toString();
    _casualChargeType =
        s.casualChargeType == CasualChargeType.fixed ? 'fixed' : 'split';
    await _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final courtHire = double.tryParse(_courtHireController.text) ?? 0;
    final shuttlesUsed = int.tryParse(_shuttlesUsedController.text) ?? 0;
    final otherExpenses = double.tryParse(_otherExpensesController.text) ?? 0;
    final shuttleCost = double.tryParse(_shuttleCostController.text) ?? 3;
    final casualCharge = double.tryParse(_casualChargeController.text) ?? 10;

    await _reportManager.saveSettings(ReportSettings(
      casualChargeType: _casualChargeType == 'fixed'
          ? CasualChargeType.fixed
          : CasualChargeType.split,
      casualChargePerSession: casualCharge,
      shuttleCost: shuttleCost,
      defaultCourtHire: 0.0,
    ));

    final appState = Provider.of<AppState>(context, listen: false);
    final typeMap = {
      for (final p in appState.allPlayers) p.name: p.type.toLowerCase().trim(),
    };

    final report = await _reportManager.generateReport(
      date: _selectedDate,
      courtHire: courtHire,
      shuttleCount: shuttlesUsed,
      otherExpenses: otherExpenses,
      playerTypesByName: typeMap,
    );

    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  Future<void> _exportToCsv() async {
    if (_report == null) return;
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
          const SnackBar(
              content: Text('Report exported'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error exporting: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNoData = (_report == null) ||
        (_report!.totalMatches == 0 && _report!.playerCosts.isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Report'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: (_report != null && _report!.playerCosts.isNotEmpty)
                ? _exportToCsv
                : null,
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
            const Text('Select Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    const Icon(Icons.calendar_today,
                        color: Color(0xFF6366F1)),
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
            const Text('Session Costs',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _courtHireController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Other Expenses (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt),
              ),
              onChanged: (_) => _loadReport(),
            ),
            const SizedBox(height: 20),
            const Text('Casual Player Charging',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _casualChargeType,
              decoration: const InputDecoration(
                  labelText: 'Charge Type',
                  border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'fixed', child: Text('Fixed Charge')),
                DropdownMenuItem(
                    value: 'split',
                    child: Text('Split Equally with Full Members')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _casualChargeType = v);
                  _loadReport();
                }
              },
            ),
            if (_casualChargeType == 'fixed') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _casualChargeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
        _buildStatCard('Total Rounds', r.totalRounds.toString(),
            const Color(0xFF6366F1)),
        _buildStatCard(
            'Total Matches', r.totalMatches.toString(), Colors.green),
        _buildStatCard(
            'Total Players', r.totalPlayers.toString(), Colors.orange),
        _buildStatCard(
            'Shuttles Used', r.shuttlesUsed.toString(), Colors.amber),
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
            Text(value,
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center),
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
    final totalCollected =
        r.playerCosts.fold<double>(0, (s, p) => s + p.cost);

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Financial Summary',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1))),
            const Divider(height: 24),
            _buildSummaryRow('Charge Model',
                r.chargeType == CasualChargeType.fixed
                    ? 'Fixed Charge'
                    : 'Equal Split'),
            _buildSummaryRow(
                'Court Hire', '\$${r.courtHire.toStringAsFixed(2)}'),
            _buildSummaryRow('Shuttles Cost',
                '\$${r.totalShuttleCost.toStringAsFixed(2)}'),
            _buildSummaryRow('Other Expenses',
                '\$${r.otherExpenses.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _buildSummaryRow('Total Base Cost',
                '\$${r.totalBaseCost.toStringAsFixed(2)}',
                bold: true),
            _buildSummaryRow(
                'Casual Contribution (${casual.length})',
                '\$${casualTotal.toStringAsFixed(2)}'),
            _buildSummaryRow('Full Member Split (${full.length})',
                '\$${fullTotal.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _buildSummaryRow(
                'Total Collected', '\$${totalCollected.toStringAsFixed(2)}',
                bold: true, fontSize: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool bold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: fontSize)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w500,
                  fontSize: fontSize)),
        ],
      ),
    );
  }

  Widget _buildPlayerCosts() {
    if (_report == null || _report!.playerCosts.isEmpty) {
      return const SizedBox.shrink();
    }
    final players = [..._report!.playerCosts]
      ..sort((a, b) => a.name.compareTo(b.name));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Player Costs',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final p = players[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: p.type == 'full'
                      ? Colors.blue[50]
                      : Colors.orange[50],
                  child: ListTile(
                    title: Text(p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${p.type.toUpperCase()}'),
                        Text('Sessions: ${p.sessions}'),
                        Text(
                            'Shuttle Share: \$${p.shuttleShare.toStringAsFixed(2)}'),
                      ],
                    ),
                    trailing: Text(
                      '\$${p.cost.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1)),
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
