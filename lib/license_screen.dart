// lib/license_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'license_manager.dart';
import 'main.dart';


/// Gate widget: decides whether to show LicenseScreen or your MainScreen.
class LicenseGate extends StatefulWidget {
  final Widget child; // your main screen
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

/// License screen UI
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
  
      // Delay navigation until after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LicenseGate(
              child: MainScreen(),
            ),
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


  // Helper: after unlock, land at your main scaffold
  Widget widgetAfterUnlock() {
    // You already have MainScreen in main.dart; import not needed here.
    // We'll just rebuild LicenseGate at app root, so this won't be used.
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final hintTrial = 'To start a 30‑day trial, enter: ${LicenseManager.kTrialKey}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activate BadminCAB'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.indigo[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Device Code',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SelectableText(
                            _deviceCode,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 20),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Email this device code to codepattarai@gmail.com to request a full license.',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Enter License Key',
                      hintText: 'e.g., XXXXX-XXXXX-XXXXX-XXXXX-XXXXX or TRIAL-2026-BADMINCAB',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.vpn_key),
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(hintTrial, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _activate,
                      icon: const Icon(Icons.check),
                      label: const Text('Activate'),
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
}