// HomeTab - idle state and recording state with full polish.
// START SESSION fix: works with real device by calling DeviceApiService directly.
// If deviceProvider shows disconnected but we have sessions, we're connected via WiFi.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/theme.dart';
import '../models/session.dart';
import '../providers/device_provider.dart';
import '../providers/live_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/profile_provider.dart';
import '../services/mock_data_service.dart';
import '../services/device_api_service.dart';
import '../widgets/connection_status.dart';
import '../widgets/pool_length_selector.dart';
import '../widgets/stroke_selector.dart';
import '../widgets/session_card.dart';
import '../widgets/metric_card.dart';

/// Home tab - device status, session controls, and live metrics.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  String _selectedStroke = 'FREESTYLE';
  bool   _startLoading   = false;
  bool   _stopLoading    = false;
  int    _elapsedSec     = 0;
  Timer? _elapsedTimer;

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  // ─── Start session ─────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    HapticFeedback.mediumImpact();
    setState(() => _startLoading = true);

    try {
      final poolLength  = ref.read(settingsProvider).poolLength;
      final isSimulator = ref.read(settingsProvider).simulatorMode;

      if (isSimulator) {
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        // Call the real device API - user must already be on SwimTrack WiFi
        DeviceApiService.instance.setSimulatorMode(false);
        await DeviceApiService.instance.startSession(poolLength);
      }

      // Mark session active in provider
      // If not connected in provider yet, auto-connect with mock status
      final deviceState = ref.read(deviceProvider);
      if (!deviceState.isConnected) {
        ref.read(deviceProvider.notifier).markSessionStarted();
      } else {
        ref.read(deviceProvider.notifier).markSessionStarted();
      }

      // Start elapsed timer
      _elapsedSec = 0;
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSec++);
      });

      await WakelockPlus.enable();
      setState(() => _startLoading = false);
    } catch (e) {
      setState(() => _startLoading = false);
      if (mounted) {
        _showError('Could not start session: $e\n\nMake sure you are connected to the SwimTrack WiFi.');
      }
    }
  }

  // ─── Stop session ──────────────────────────────────────────────────────────

  Future<void> _stopSession() async {
    HapticFeedback.heavyImpact();
    setState(() => _stopLoading = true);

    try {
      final isSimulator = ref.read(settingsProvider).simulatorMode;
      final poolLength  = ref.read(settingsProvider).poolLength;

      Session session;

      if (isSimulator) {
        await Future.delayed(const Duration(milliseconds: 800));
        final base = MockDataService.generateSessions(count: 1).first;
        session = Session(
          id:             DateTime.now().millisecondsSinceEpoch.toString(),
          startTime:      DateTime.now().subtract(Duration(seconds: _elapsedSec)),
          poolLengthM:    poolLength,
          durationSec:    _elapsedSec,
          totalDistanceM: base.totalDistanceM,
          avgSwolf:       base.avgSwolf,
          avgStrokeRate:  base.avgStrokeRate,
          avgDps:         base.avgDps,
          laps:           base.laps,
          rests:          base.rests,
        );
      } else {
        // Real device: stop and fetch the saved session
        DeviceApiService.instance.setSimulatorMode(false);
        final savedId = await DeviceApiService.instance.stopSession();
        session = await DeviceApiService.instance.getSession(savedId);
      }

      // Save to SQLite
      await ref.read(sessionProvider.notifier).saveSession(session);

      // Stop timer and wakelock
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      await WakelockPlus.disable();

      // Mark stopped
      ref.read(deviceProvider.notifier).markSessionStopped();
      setState(() => _stopLoading = false);

      // Navigate to detail
      if (mounted) context.push('/session/${session.id}');
    } catch (e) {
      setState(() => _stopLoading = false);
      if (mounted) {
        _showError('Could not stop session. Try again.\n$e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: SwimTrackTextStyles.body(color: Colors.white)),
      backgroundColor: SwimTrackColors.bad,
      duration: const Duration(seconds: 4),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(deviceProvider).isSessionActive;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: isRecording
          ? _RecordingView(
              key:            const ValueKey('recording'),
              elapsedSec:     _elapsedSec,
              selectedStroke: _selectedStroke,
              stopLoading:    _stopLoading,
              onStop:         _stopSession,
            )
          : _IdleView(
              key:             const ValueKey('idle'),
              selectedStroke:  _selectedStroke,
              startLoading:    _startLoading,
              onStrokeChanged: (s) => setState(() => _selectedStroke = s),
              onStart:         _startSession,
            ),
    );
  }
}

// ─── Idle View ───────────────────────────────────────────────────────────────

class _IdleView extends ConsumerWidget {
  final String   selectedStroke;
  final bool     startLoading;
  final ValueChanged<String> onStrokeChanged;
  final VoidCallback onStart;

  const _IdleView({
    super.key,
    required this.selectedStroke,
    required this.startLoading,
    required this.onStrokeChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile      = ref.watch(profileProvider);
    final sessionState = ref.watch(sessionProvider);
    final settings     = ref.watch(settingsProvider);
    final sessions     = sessionState.sessions;

    // Weekly stats
    final now        = DateTime.now();
    final weekStart  = now.subtract(Duration(days: now.weekday - 1));
    final weekSess   = sessions.where((s) => s.startTime.isAfter(weekStart)).toList();
    final weekDist   = weekSess.fold(0, (s, e) => s + e.totalDistanceM);
    final bestSwolf  = sessions.isEmpty ? null
        : sessions.map((s) => s.avgSwolf).where((v) => v > 0).fold<double?>(
            null, (best, v) => best == null ? v : (v < best ? v : best));

    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning'
        : hour < 17 ? 'Good afternoon' : 'Good evening';
    final firstName = (profile?.name.split(' ').first ?? 'Swimmer');
    // Truncate long names
    final displayName = firstName.length > 15
        ? '${firstName.substring(0, 15)}…' : firstName;

    return Scaffold(
      backgroundColor: SwimTrackColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status
              const ConnectionStatusWidget(),
              const SizedBox(height: 16),

              // Greeting
              Text(
                '$greeting, $displayName! 🏊',
                style: SwimTrackTextStyles.cardTitle(color: SwimTrackColors.dark),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              // Last session or empty state
              if (sessions.isNotEmpty)
                SessionCard(
                  session: sessions.first,
                  onTap: () => context.push('/session/${sessions.first.id}'),
                )
              else
                _FirstSessionCard(),
              const SizedBox(height: 20),

              // Weekly stats
              Text('This Week', style: SwimTrackTextStyles.sectionHeader()),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: MetricCard(
                      value: weekSess.length.toString(), label: 'Sessions')),
                  const SizedBox(width: 12),
                  Expanded(child: MetricCard(
                      value: '${weekDist}m', label: 'Distance')),
                  const SizedBox(width: 12),
                  Expanded(child: MetricCard(
                      value: bestSwolf != null
                          ? bestSwolf.toStringAsFixed(1) : '-',
                      label: 'Best SWOLF',
                      valueColor: SwimTrackColors.primary)),
                ],
              ),
              const SizedBox(height: 28),

              // Session config
              Text('Start a Session', style: SwimTrackTextStyles.sectionHeader()),
              const SizedBox(height: 14),

              Text('Pool Length',
                  style: SwimTrackTextStyles.label(
                      color: SwimTrackColors.textSecondary)),
              const SizedBox(height: 8),
              PoolLengthSelector(
                selectedLength: settings.poolLength,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setPoolLength(v),
              ),
              const SizedBox(height: 16),

              Text('Stroke',
                  style: SwimTrackTextStyles.label(
                      color: SwimTrackColors.textSecondary)),
              const SizedBox(height: 8),
              StrokeSelector(
                selectedStroke: selectedStroke,
                onChanged: onStrokeChanged,
              ),
              const SizedBox(height: 28),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: startLoading ? null : onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwimTrackColors.primary,
                    disabledBackgroundColor:
                        SwimTrackColors.primary.withValues(alpha: 0.8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: SwimTrackColors.primary.withValues(alpha: 0.3),
                  ),
                  child: startLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Starting…',
                                style: SwimTrackTextStyles.cardTitle(
                                    color: Colors.white)),
                          ],
                        )
                      : Text('START SESSION',
                          style: SwimTrackTextStyles.cardTitle(
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown on home tab when no sessions exist yet.
class _FirstSessionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SwimTrackColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SwimTrackColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🌊', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            'Start your first session!',
            style: SwimTrackTextStyles.cardTitle(color: SwimTrackColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Select pool length and stroke below, then tap Start.',
            style: SwimTrackTextStyles.body(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Recording View ──────────────────────────────────────────────────────────

class _RecordingView extends ConsumerStatefulWidget {
  final int    elapsedSec;
  final String selectedStroke;
  final bool   stopLoading;
  final VoidCallback onStop;

  const _RecordingView({
    super.key,
    required this.elapsedSec,
    required this.selectedStroke,
    required this.stopLoading,
    required this.onStop,
  });

  @override
  ConsumerState<_RecordingView> createState() => _RecordingViewState();
}

class _RecordingViewState extends ConsumerState<_RecordingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotCtrl;
  late Animation<double>   _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  /// Returns a display label for a stroke type string from the device.
  /// Falls back to Freestyle for any unrecognised value.
  String _strokeLabel(String key) {
    switch (key) {
      case 'BACKSTROKE':   return '↩ Backstroke';
      case 'BREASTSTROKE': return '🤸 Breaststroke';
      case 'BUTTERFLY':    return '🦋 Butterfly';
      case 'UNKNOWN':      return '❓ Detecting…';
      default:             return '🏊 Freestyle';
    }
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(liveProvider);
    final live      = liveAsync.value;

    return Scaffold(
      backgroundColor: SwimTrackColors.dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Status row - RECORDING indicator + elapsed time + battery
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _dotAnim,
                    builder: (_, __) => Opacity(
                      opacity: _dotAnim.value,
                      child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                          color: SwimTrackColors.bad,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('RECORDING',
                      style: SwimTrackTextStyles.label(color: SwimTrackColors.bad)
                          .copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Battery indicator - shown once firmware provides batt_pct
                  if (live != null && live.battPct > 0) ...[
                    Icon(
                      live.battPct >= 80 ? Icons.battery_full
                          : live.battPct >= 50 ? Icons.battery_3_bar
                          : live.battPct >= 20 ? Icons.battery_2_bar
                          : Icons.battery_1_bar,
                      color: live.battPct >= 50 ? SwimTrackColors.good
                          : live.battPct >= 20 ? SwimTrackColors.neutral
                          : SwimTrackColors.bad,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${live.battPct}%',
                      style: SwimTrackTextStyles.tiny(color: Colors.white70),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    _fmt(live?.elapsedSec ?? widget.elapsedSec),
                    style: SwimTrackTextStyles.screenTitle(color: Colors.white70),
                  ),
                ],
              ),

              const Spacer(),

              // Huge stroke count
              Text(
                '${live?.strokeCount ?? 0}',
                style: SwimTrackTextStyles.hugeNumber(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text('STROKES',
                  style: SwimTrackTextStyles.label(color: Colors.white54)),
              const SizedBox(height: 12),

              // Stroke type - uses real device detection, falls back to user selection
              Text(
                _strokeLabel(live?.strokeType ?? widget.selectedStroke),
                style: SwimTrackTextStyles.cardTitle(
                    color: SwimTrackColors.secondary),
              ),

              const SizedBox(height: 40),

              // Glass cards row
              Row(
                children: [
                  Expanded(child: _GlassCard(
                    topLabel:    'LAP',
                    topValue:    '${(live?.lapCount ?? 0) + 1}',
                    bottomLabel: 'lap time',
                    bottomValue: live != null
                        ? '${live.lapElapsedS.toStringAsFixed(0)}s'
                        : '--',
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _GlassCard(
                    topLabel:    'RATE',
                    topValue:    '${live?.strokeRate.toStringAsFixed(1) ?? '--'} spm',
                    bottomLabel: 'SWOLF',
                    bottomValue: live != null
                        ? live.currentSwolf.toStringAsFixed(1)
                        : '--',
                    bottomColor: SwimTrackColors.secondary,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              // DPS card - full width below the two glass cards
              _GlassCard(
                topLabel:    'DPS',
                topValue:    live != null && live.lapDps > 0
                    ? '${live.lapDps.toStringAsFixed(2)}m'
                    : '--',
                bottomLabel: 'dist per stroke',
                bottomValue: '',
              ),

              const Spacer(),

              // Stop button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: widget.stopLoading ? null : widget.onStop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwimTrackColors.bad,
                    disabledBackgroundColor:
                        SwimTrackColors.bad.withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: SwimTrackColors.bad.withValues(alpha: 0.4),
                  ),
                  child: widget.stopLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Saving…',
                                style: SwimTrackTextStyles.cardTitle(
                                    color: Colors.white)),
                          ],
                        )
                      : Text('STOP SESSION',
                          style: SwimTrackTextStyles.cardTitle(
                              color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final String topLabel;
  final String topValue;
  final String bottomLabel;
  final String bottomValue;
  final Color  bottomColor;

  const _GlassCard({
    required this.topLabel,
    required this.topValue,
    required this.bottomLabel,
    required this.bottomValue,
    this.bottomColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(topLabel,
              style: SwimTrackTextStyles.tiny(color: Colors.white54)),
          const SizedBox(height: 4),
          Text(topValue,
              style: SwimTrackTextStyles.sectionHeader(color: Colors.white)),
          if (bottomValue.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('$bottomLabel: $bottomValue',
                style: SwimTrackTextStyles.label(color: bottomColor)),
          ],
        ],
      ),
    );
  }
}