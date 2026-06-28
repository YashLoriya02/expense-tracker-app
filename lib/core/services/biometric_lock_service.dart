import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricLockService {
  static const String enabledPrefsKey = 'biometric_lock_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledPrefsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledPrefsKey, enabled);
  }

  Future<bool> canUseDeviceLock() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Device lock check failed: $e');
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Available biometrics check failed: $e');
      return [];
    }
  }

  Future<bool> hasEnrolledBiometric() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();

      debugPrint('Biometric supported: $supported');
      debugPrint('Can check biometrics: $canCheck');
      debugPrint('Available biometrics: $available');

      return supported && canCheck && available.isNotEmpty;
    } catch (e) {
      debugPrint('Biometric check failed: $e');
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Unlock Expense Tracker',
    bool biometricOnly = false,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
      );
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }
}

class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  final _service = BiometricLockService();
  bool _checking = true;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final enabled = await _service.isEnabled();
    if (!mounted) return;

    if (!enabled) {
      setState(() {
        _checking = false;
        _unlocked = true;
      });
      return;
    }

    final ok = await _service.authenticate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _unlocked = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_unlocked) return widget.child;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Expense Tracker is locked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('Authenticate to continue.'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _checkLock,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
