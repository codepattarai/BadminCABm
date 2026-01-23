
// lib/license_manager.dart
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LicenseType { none, trial, full }

class LicenseInfo {
  final LicenseType type;
  final DateTime? expiry; // only for trial
  final String? key;

  const LicenseInfo({required this.type, this.expiry, this.key});

  bool get isActive {
    if (type == LicenseType.full) return true;
    if (type == LicenseType.trial && expiry != null) {
      return DateTime.now().isBefore(expiry!);
    }
    return false;
  }
}

/// Centralized licensing manager
class LicenseManager {
  // ====== CONFIG ======
  static const String kVendor = 'codepattarai';
  static const String kProduct = 'BadminCAB';
  static const String kTrialKey = 'TRIAL-2026-BADMINCAB';

  /// !!! CHANGE THIS BEFORE RELEASE !!!
  static const String kHmacSecret =
      'BadminCAB-Oodi-Vilayadu-Paappa-2026';

  // Pref keys
  static const _pLicenseType = 'lic_type'; // 'none' | 'trial' | 'full'
  static const _pLicenseKey = 'lic_key';
  static const _pTrialExpiryEpoch = 'lic_trial_expiry_epoch';
  static const _pInstallId = 'install_id'; // fallback for device code

  static final LicenseManager _instance = LicenseManager._internal();
  factory LicenseManager() => _instance;
  LicenseManager._internal();

  // ---------------- Device Code ----------------
  Future<String> getDeviceCode() async {
    final id = await _getStableDeviceId();
    // Device code = first 16 hex chars of HMAC(secret, "$id|$kProduct"), grouped 4-4-4-4
    final raw = _hmacHex('$id|$kProduct');
    final code16 = raw.substring(0, 16).toUpperCase();
    return '${code16.substring(0, 4)}-'
        '${code16.substring(4, 8)}-'
        '${code16.substring(8, 12)}-'
        '${code16.substring(12, 16)}';
  }

  Future<String> _getStableDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await deviceInfo.androidInfo;
        // Prefer ANDROID_ID if available; fallback to a combo
        final androidId = a.id ?? a.fingerprint ?? '${a.brand}|${a.model}|${a.device}';
        return 'android:$androidId';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await deviceInfo.iosInfo;
        final idfv = i.identifierForVendor ?? '${i.name}|${i.model}|${i.systemVersion}';
        return 'ios:$idfv';
      }
    } catch (_) {
      // swallow
    }
    // Fallback: per-install UUID stored in prefs
    final prefs = await SharedPreferences.getInstance();
    String? installId = prefs.getString(_pInstallId);
    if (installId == null || installId.isEmpty) {
      installId = _uuidV4();
      await prefs.setString(_pInstallId, installId);
    }
    return 'install:$installId';
  }

  // ---------------- Verification ----------------
  /// Returns current license info (from disk).
  Future<LicenseInfo> getCurrentLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_pLicenseType) ?? 'none';
    if (t == 'full') {
      return LicenseInfo(type: LicenseType.full, key: prefs.getString(_pLicenseKey));
    }
    if (t == 'trial') {
      final epoch = prefs.getInt(_pTrialExpiryEpoch);
      final dt = epoch == null ? null : DateTime.fromMillisecondsSinceEpoch(epoch);
      return LicenseInfo(
        type: LicenseType.trial,
        expiry: dt,
        key: prefs.getString(_pLicenseKey),
      );
    }
    return const LicenseInfo(type: LicenseType.none);
  }

  /// Validate & activate a key. Returns null on success or an error message.
  Future<String?> activateWithKey(String inputKey) async {
    final key = inputKey.trim().toUpperCase();

    // Trial key?
    if (key == kTrialKey) {
      final prefs = await SharedPreferences.getInstance();
      final expiry = DateTime.now().add(const Duration(days: 30));
      await prefs.setString(_pLicenseType, 'trial');
      await prefs.setInt(_pTrialExpiryEpoch, expiry.millisecondsSinceEpoch);
      await prefs.setString(_pLicenseKey, key);
      return null; // success
    }

    // Full key verification
    final deviceCode = await getDeviceCode();
    final expected = generateFullKeyForDevice(deviceCode);
    if (key == expected) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pLicenseType, 'full');
      await prefs.setInt(_pTrialExpiryEpoch, 0);
      await prefs.setString(_pLicenseKey, key);
      return null; // success
    }

    return 'Invalid license key for this device.';
  }

  /// Deterministically generate a FULL license key for a given device code.
  /// This mirrors the HTML generator.
  String generateFullKeyForDevice(String deviceCode) {
    // Remove hyphens for signing
    final payload = 'FULL|${deviceCode.replaceAll('-', '')}|$kVendor|$kProduct';
    final hex = _hmacHex(payload).toUpperCase(); // 64 hex chars
    // Use 25 chars grouped 5-5-5-5-5 (e.g., XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)
    final first25 = hex.substring(0, 25);
    return '${first25.substring(0, 5)}-'
        '${first25.substring(5, 10)}-'
        '${first25.substring(10, 15)}-'
        '${first25.substring(15, 20)}-'
        '${first25.substring(20, 25)}';
  }

  // ---------------- Helpers ----------------
  String _hmacHex(String text) {
    final key = utf8.encode(kHmacSecret);
    final bytes = utf8.encode(text);
    final hmac = crypto.Hmac(crypto.sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString(); // lowercase hex
  }

  String _uuidV4() {
    // Minimal UUIDv4 generator (not cryptographically strong, good enough for install ID)
    final rnd = crypto.sha256.convert(utf8.encode('${DateTime.now().microsecondsSinceEpoch}-${kProduct}-${kVendor}-${UniqueKey()}')).bytes;
    String hex2(int i) => i.toRadixString(16).padLeft(2, '0');
    final b = rnd.take(16).toList();
    b[6] = (b[6] & 0x0F) | 0x40;
    b[8] = (b[8] & 0x3F) | 0x80;
    final parts = [
      for (var i in [0,1,2,3]) hex2(b[i]),
      '-',
      for (var i in [4,5]) hex2(b[i]),
      '-',
      for (var i in [6,7]) hex2(b[i]),
      '-',
      for (var i in [8,9]) hex2(b[i]),
      '-',
      for (var i in [10,11,12,13,14,15]) hex2(b[i]),
    ];
    return parts.join();
  }
}