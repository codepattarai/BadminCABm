// lib/license_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'license_manager.dart';
import 'main.dart';
import 'app_theme.dart';

/// Gate widget: decides whether to show LicenseScreen or your MainScreen.
class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  final _lm = LicenseManager();
  Future<bool>? _future;

  @override
  void initState() {
    super.initState();
    _future = _isLicensed();
  }

  Future<bool> _isLicensed() async {
    final info = await _lm.getCurrentLicense();
    return info.isActive;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data! ? widget.child : const LicenseScreen();
      },
    );
  }
}

/// License activation screen
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _lm = LicenseManager();
  final _controller = TextEditingController();
  String _deviceCode = '';
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dc = await _lm.getDeviceCode();
    setState(() {
      _deviceCode = dc;
      _busy = false;
    });
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final msg = await _lm.activateWithKey(_controller.text);

    if (msg == null) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LicenseGate(child: MainScreen()),
          ),
        );
      });
      return;
    }

    setState(() {
      _error = msg;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hintTrial =
        'To start a 30‑day trial, enter: ${LicenseManager.kTrialKey}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activate BadminCAB'),
        // Uses AppTheme.panel via the global AppBarTheme — no override needed
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Device Code card ──────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      // Glow border: same blue→teal treatment as court cards
                      gradient: AppTheme.glowGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.panel,
                        borderRadius: BorderRadius.circular(14.5),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Device Code',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accent,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Device code in accent colour — clearly visible
                          SelectableText(
                            _deviceCode.isEmpty ? '—' : _deviceCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Email this code to codepattarai@gmail.com to request a full license.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── License key input ─────────────────────────────────────
                  TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Enter License Key',
                      hintText:
                          'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX  or  TRIAL-2026-BADMINCAB',
                      prefixIcon: const Icon(Icons.vpn_key,
                          color: AppTheme.accent),
                      errorText: _error,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    hintTrial,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                  ),

                  const SizedBox(height: 20),

                  // ── Activate button ───────────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _activate,
                      icon: const Icon(Icons.check),
                      label: const Text('Activate',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.action,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}