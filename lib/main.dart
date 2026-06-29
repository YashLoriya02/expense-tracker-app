import 'package:expense_tracker_ai/shared/services/sms_listener_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'core/services/biometric_lock_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SmsListenerService.initialize();

  runApp(const ProviderScope(child: ExpenseTrackerApp()));
}

class ExpenseTrackerApp extends ConsumerWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Expense Tracker AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) => BiometricGate(child: child ?? const SizedBox.shrink()),
      routerConfig: appRouter,
    );
  }
}
