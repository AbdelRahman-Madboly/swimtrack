// SwimTrack app entry point.
// Wraps the app in ProviderScope (Riverpod) and sets up theme + GoRouter.
// On startup, reads persisted simulatorMode from SharedPreferences and
// syncs it to DeviceApiService.instance so the app never uses mock data
// when the user had simulator mode OFF.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'config/constants.dart';
import 'providers/settings_provider.dart';
import 'services/device_api_service.dart';

/// Initialises Flutter bindings, pre-loads simulator mode preference,
/// and launches the app inside a [ProviderScope].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Sync simulator mode before any provider initialises ──────────────────
  // DeviceApiService.instance._simulatorMode defaults to false.
  // If the user had simulator ON from the last run, settingsProvider will
  // load it from prefs AFTER the first build - too late.
  // Reading the pref here ensures the singleton is correct from frame 1.
  try {
    final prefs = await SharedPreferences.getInstance();
    final simMode = prefs.getBool(kPrefKeySimulatorMode) ?? false;
    DeviceApiService.instance.setSimulatorMode(simMode);
    debugPrint('main: simulator mode pre-loaded → $simMode');
  } catch (e) {
    debugPrint('main: could not pre-load simulator mode → $e');
  }

  runApp(
    const ProviderScope(
      child: SwimTrackApp(),
    ),
  );
}

/// Root widget - reads the [GoRouter] from Riverpod and applies the theme.
class SwimTrackApp extends ConsumerWidget {
  const SwimTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // ── Keep DeviceApiService in sync whenever the settings toggle changes ──
    ref.listen<AppSettings>(
      settingsProvider,
      (AppSettings? prev, AppSettings next) {
        if (prev?.simulatorMode != next.simulatorMode) {
          DeviceApiService.instance.setSimulatorMode(next.simulatorMode);
          debugPrint('main: simulator mode changed → ${next.simulatorMode}');
        }
      },
    );

    return MaterialApp.router(
      title: 'SwimTrack',
      theme: swimTrackTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}