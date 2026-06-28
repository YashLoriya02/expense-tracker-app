import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/biometric_lock_service.dart';
// import '../../../../core/services/drive_backup_service.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../features/dashboard/domain/dashboard_providers.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    if (stored == 'dark') state = ThemeMode.dark;
    if (stored == 'light') state = ThemeMode.light;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final enabled = await BiometricLockService().isEnabled();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    final service = BiometricLockService();

    try {
      if (enabled) {
        final hasBiometric = await service.hasEnrolledBiometric();

        if (!hasBiometric) {
          _showMessage(
            'No fingerprint or face unlock is enrolled on this device. Please set it up in phone settings first.',
          );
          return;
        }

        final confirmed = await service.authenticate(
          reason: 'Confirm your identity to enable biometric lock.',
          biometricOnly: true,
        );

        if (!confirmed) {
          _showMessage('Biometric confirmation cancelled.');
          return;
        }
      }

      await service.setEnabled(enabled);

      if (mounted) {
        setState(() => _biometricEnabled = enabled);
      }

      _showMessage(
        enabled ? 'Biometric lock enabled.' : 'Biometric lock disabled.',
      );
    } catch (e) {
      _showMessage('Biometric setup failed: $e');
    }
  }

  Future<void> _exportExcel() async {
    await _runBusy('export', () async {
      final file =
          await ExportService().exportAndShareExcel(ref.read(databaseProvider));
      _showMessage('Excel export created: ${file.path.split('/').last}');
    });
  }

  // Future<void> _backupToDrive() async {
  //   await _runBusy('backup', () async {
  //     final filename =
  //         await DriveBackupService().backupToDrive(ref.read(databaseProvider));
  //     _showMessage('Backup uploaded to Google Drive: $filename');
  //   });
  // }

  Future<void> _runBusy(String key, Future<void> Function() action) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = key);
    try {
      await action();
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _Section(title: 'Appearance', children: [
            ListTile(
              leading: const Icon(Icons.dark_mode_rounded),
              title: const Text('Theme'),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded, size: 16)),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded, size: 16)),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded, size: 16)),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).set(s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
          ]),
          _Section(title: 'AI Features', children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text('Gemini API Key'),
              subtitle: const Text(
                  'Powers natural-language entry, receipt parsing and insights'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showGeminiApiKeyDialog,
            ),
          ]),
          _Section(title: 'Security', children: [
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('Biometric Lock'),
              subtitle: const Text('Require device lock when opening the app'),
              value: _biometricEnabled,
              onChanged: _toggleBiometrics,
            ),
          ]),
          _Section(
            title: 'Data',
            children: [
              ListTile(
                leading: const Icon(Icons.grid_on_rounded),
                title: const Text('Export to Excel'),
                subtitle: const Text(
                    'Creates a .xlsx file and opens the share sheet'),
                trailing: _busyAction == 'export'
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _busyAction == null ? _exportExcel : null,
              ),
              // ListTile(
              //   leading: const Icon(Icons.backup_rounded),
              //   title: const Text('Backup to Google Drive'),
              //   subtitle: const Text('Uploads a JSON backup to your Drive'),
              //   trailing: _busyAction == 'backup'
              //       ? const SizedBox(
              //           width: 20,
              //           height: 20,
              //           child: CircularProgressIndicator(strokeWidth: 2),
              //         )
              //       : const Icon(Icons.chevron_right),
              //   onTap: _busyAction == null ? _backupToDrive : null,
              // ),
              // const ListTile(
              //   enabled: false,
              //   leading: Icon(Icons.restore_rounded),
              //   title: Text('Restore Backup'),
              //   subtitle: Text('Ignored for now'),
              // ),
            ],
          ),
          _Section(title: 'About', children: [
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Version'),
              trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _showGeminiApiKeyDialog() async {
    final service = GeminiService();
    final existing = await service.getApiKey();
    if (!mounted) return;

    final ctrl = TextEditingController(text: existing ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add a Gemini API key to enable AI parsing and insights. The key is stored only on this device.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API key',
                hintText: 'AIza...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              const String apiKeyPrefsKey = 'gemini_api_key';
              final prefs = await SharedPreferences.getInstance();

              if (ctrl.text.isEmpty) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("API Key should not be empty."),
                  ),
                );

                return;
              }

              await prefs.setString(apiKeyPrefsKey, ctrl.text);
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("API Key saved successfully."),
                ),
              );

              // ignore: use_build_context_synchronously
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await service.saveApiKey(ctrl.text.trim());
      _showMessage('Gemini API key saved.');
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5)),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}
