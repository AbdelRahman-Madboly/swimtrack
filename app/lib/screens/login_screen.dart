// LoginScreen - WiFi credential form + connect button.
// Simulator mode: 1-second fake connection.
// Real mode: calls DeviceProvider.connect() which uses wifi_service + device_api_service.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/device_provider.dart';

/// Login screen - entry point. Connects to the SwimTrack device WiFi.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _ssidController     = TextEditingController(text: kDeviceSsid);
  final _passwordController = TextEditingController(text: kDevicePassword);

  bool    _obscurePass  = true;
  String? _errorMessage;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _errorMessage = null);

    final ssid     = _ssidController.text.trim();
    final password = _passwordController.text;

    // Use deviceProvider to handle the full connect flow
    await ref.read(deviceProvider.notifier).connect(ssid, password);

    if (!mounted) return;

    final deviceState = ref.read(deviceProvider);

    if (deviceState.status == ConnectionStatus.error) {
      setState(() => _errorMessage = deviceState.error ??
          'Could not connect. Make sure you are on the SwimTrack WiFi.');
      return;
    }

    // Success - navigate based on profile state
    final isFirstRun = ref.read(profileProvider.notifier).isFirstRun;
    if (isFirstRun) {
      context.go('/profile-setup');
    } else {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final deviceState  = ref.watch(deviceProvider);
    final isConnecting = deviceState.status == ConnectionStatus.connecting;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SizedBox(
        width: double.infinity,
        height: screenHeight,
        child: Stack(
          children: [
            // ── Gradient background ───────────────────────────────────────
            Container(
              width: double.infinity,
              height: screenHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [SwimTrackColors.primary, SwimTrackColors.gradientEnd],
                ),
              ),
            ),

            // ── Logo + tagline ─────────────────────────────────────────────
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌊', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('SwimTrack',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  SizedBox(height: 8),
                  Text('Your swim, perfected.',
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),

            // ── White card ─────────────────────────────────────────────────
            Positioned(
              top: 306, left: 0, right: 0, bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: SwimTrackColors.card,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connect to Device',
                          style: SwimTrackTextStyles.cardTitle(
                              color: SwimTrackColors.dark)),
                      const SizedBox(height: 24),

                      // Device Name
                      _buildLabel('Device Name'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _ssidController,
                        enabled: !isConnecting,
                        textInputAction: TextInputAction.next,
                        style: SwimTrackTextStyles.body(
                            color: SwimTrackColors.dark),
                        decoration: _inputDecoration('SwimTrack'),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _buildLabel('Password'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        enabled: !isConnecting,
                        obscureText: _obscurePass,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => isConnecting ? null : _connect(),
                        style: SwimTrackTextStyles.body(
                            color: SwimTrackColors.dark),
                        decoration: _inputDecoration('••••••••').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: SwimTrackColors.textHint,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Text(
                          'Make sure your phone is connected to the SwimTrack WiFi first',
                          textAlign: TextAlign.center,
                          style: SwimTrackTextStyles.tiny(),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Connect button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isConnecting ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SwimTrackColors.primary,
                            disabledBackgroundColor:
                                SwimTrackColors.primary.withValues(alpha: 0.8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor:
                                SwimTrackColors.primary.withValues(alpha: 0.3),
                          ),
                          child: isConnecting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('Connecting…',
                                        style: SwimTrackTextStyles.cardTitle(
                                            color: Colors.white)),
                                  ],
                                )
                              : Text('Connect',
                                  style: SwimTrackTextStyles.cardTitle(
                                      color: Colors.white)),
                        ),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: SwimTrackColors.bad.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: SwimTrackColors.bad
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: SwimTrackColors.bad, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_errorMessage!,
                                    style: SwimTrackTextStyles.label(
                                        color: SwimTrackColors.bad)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const _SimulatorNote(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: SwimTrackTextStyles.label(color: SwimTrackColors.textSecondary));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            SwimTrackTextStyles.body(color: SwimTrackColors.textHint),
        filled: true,
        fillColor: SwimTrackColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: SwimTrackColors.divider, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: SwimTrackColors.divider, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: SwimTrackColors.primary, width: 1.5),
        ),
      );
}

/// Shows simulator mode status at the bottom of the login card.
class _SimulatorNote extends ConsumerWidget {
  const _SimulatorNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSimulator = ref.watch(settingsProvider).simulatorMode;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSimulator ? Icons.science_outlined : Icons.wifi,
            size: 14,
            color: SwimTrackColors.textHint,
          ),
          const SizedBox(width: 6),
          Text(
            isSimulator
                ? 'Simulator mode ON - no device needed'
                : 'Connect phone to SwimTrack WiFi first',
            style: SwimTrackTextStyles.tiny(),
          ),
        ],
      ),
    );
  }
}