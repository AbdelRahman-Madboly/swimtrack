// SettingsTab - profile, training prefs, device connection, and app settings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/device_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/connection_status.dart';
import '../widgets/pool_length_selector.dart';
import '../widgets/stroke_selector.dart';
import '../services/device_api_service.dart';

/// Settings tab - grouped sections for profile, training, device, and app.
class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  bool   _syncing       = false;
  String _defaultStroke = 'FREESTYLE';

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final result = await ref.read(sessionProvider.notifier).sync();
      if (!mounted) return;
      final msg = result.newSessions > 0
          ? '${result.newSessions} new session${result.newSessions == 1 ? '' : 's'} synced!'
          : 'Already up to date.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: SwimTrackTextStyles.body(color: Colors.white)),
        backgroundColor: SwimTrackColors.good,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sync failed. Try again.',
            style: SwimTrackTextStyles.body(color: Colors.white)),
        backgroundColor: SwimTrackColors.bad,
      ));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile     = ref.watch(profileProvider);
    final settings    = ref.watch(settingsProvider);
    final deviceState = ref.watch(deviceProvider);
    final isConnected = deviceState.isConnected;
    final devStatus   = deviceState.deviceStatus;

    return Scaffold(
      backgroundColor: SwimTrackColors.background,
      appBar: AppBar(
        title: Text('Settings',
            style: SwimTrackTextStyles.screenTitle(color: Colors.white)),
        backgroundColor: SwimTrackColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── PROFILE ──────────────────────────────────────────────────
            _sectionHeader('PROFILE'),
            _card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: SwimTrackColors.primary,
                      child: Text(
                        profile?.initials ?? '?',
                        style: SwimTrackTextStyles.cardTitle(
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'Not set',
                            style: SwimTrackTextStyles.cardTitle(
                                color: SwimTrackColors.dark),
                          ),
                          if (profile != null)
                            Text(
                              profile.summaryLine,
                              style: SwimTrackTextStyles.label(),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: SwimTrackColors.primary, size: 20),
                      tooltip: 'Edit profile',
                      onPressed: () => context.push('/profile-setup'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── TRAINING ─────────────────────────────────────────────────
            _sectionHeader('TRAINING'),
            _card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('Pool Length',
                        style: SwimTrackTextStyles.body(
                            color: SwimTrackColors.dark)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${settings.poolLengthM}m',
                            style: SwimTrackTextStyles.label(
                                color: SwimTrackColors.primary)),
                        const Icon(Icons.chevron_right,
                            color: SwimTrackColors.textHint),
                      ],
                    ),
                    onTap: () => _showPoolSheet(context, settings.poolLengthM),
                  ),
                  const Divider(
                      height: 1, indent: 16, endIndent: 16,
                      color: SwimTrackColors.divider),
                  ListTile(
                    title: Text('Default Stroke',
                        style: SwimTrackTextStyles.body(
                            color: SwimTrackColors.dark)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_strokeLabel(_defaultStroke),
                            style: SwimTrackTextStyles.label(
                                color: SwimTrackColors.primary)),
                        const Icon(Icons.chevron_right,
                            color: SwimTrackColors.textHint),
                      ],
                    ),
                    onTap: () => _showStrokeSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── DEVICE ────────────────────────────────────────────────────
            _sectionHeader('DEVICE'),
            _card(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        Expanded(child: ConnectionStatusWidget()),
                      ],
                    ),
                  ),
                  if (isConnected && devStatus != null) ...[
                    const Divider(
                        height: 1, indent: 16, endIndent: 16,
                        color: SwimTrackColors.divider),
                    // Battery
                    ListTile(
                      leading: Icon(
                        _batteryIcon(devStatus.batteryPct),
                        color: _batteryColor(devStatus.batteryPct),
                        size: 22,
                      ),
                      title: Text('Battery',
                          style: SwimTrackTextStyles.body(
                              color: SwimTrackColors.dark)),
                      trailing: Text(
                        devStatus.batteryLabel,
                        style: SwimTrackTextStyles.label(
                          color: _batteryColor(devStatus.batteryPct),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Divider(
                        height: 1, indent: 16, endIndent: 16,
                        color: SwimTrackColors.divider),
                    // Firmware
                    ListTile(
                      title: Text('Firmware',
                          style: SwimTrackTextStyles.body(
                              color: SwimTrackColors.dark)),
                      trailing: Text(
                        'v${devStatus.firmwareVersion}',
                        style: SwimTrackTextStyles.label(),
                      ),
                    ),
                    const Divider(
                        height: 1, indent: 16, endIndent: 16,
                        color: SwimTrackColors.divider),
                    // Sync button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _syncing ? null : _sync,
                          icon: _syncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.sync, size: 18),
                          label: Text(_syncing ? 'Syncing…' : 'Sync Sessions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SwimTrackColors.primary,
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    // Disconnect button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.read(deviceProvider.notifier).disconnect(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SwimTrackColors.bad,
                            side: const BorderSide(
                                color: SwimTrackColors.bad, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            minimumSize: Size.zero,
                          ),
                          child: Text('Disconnect',
                              style: SwimTrackTextStyles.body(
                                  color: SwimTrackColors.bad)
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ] else if (!isConnected) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Connect your phone to the SwimTrack WiFi network first, then tap Connect.',
                        style: SwimTrackTextStyles.body(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: deviceState.status ==
                                  ConnectionStatus.connecting
                              ? null
                              : () => ref.read(deviceProvider.notifier).connect(
                                    kDeviceSsid,
                                    kDevicePassword,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SwimTrackColors.primary,
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: deviceState.status ==
                                  ConnectionStatus.connecting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('Connecting…',
                                        style: SwimTrackTextStyles.body(
                                            color: Colors.white)),
                                  ],
                                )
                              : Text('Connect to SwimTrack',
                                  style: SwimTrackTextStyles.body(
                                      color: Colors.white)
                                      .copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── APP ───────────────────────────────────────────────────────
            _sectionHeader('APP'),
            _card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Simulator Mode',
                        style: SwimTrackTextStyles.body(
                            color: SwimTrackColors.dark)),
                    subtitle: Text(
                      'Use mock data - no device needed',
                      style: SwimTrackTextStyles.label(),
                    ),
                    value: settings.simulatorMode,
                    activeThumbColor: SwimTrackColors.primary,
                    onChanged: (v) {
                      ref.read(settingsProvider.notifier).setSimulatorMode(v);
                      DeviceApiService.instance.setSimulatorMode(v);
                    },
                  ),
                  const Divider(
                      height: 1, indent: 16, endIndent: 16,
                      color: SwimTrackColors.divider),
                  ListTile(
                    title: Text('App Version',
                        style: SwimTrackTextStyles.body(
                            color: SwimTrackColors.dark)),
                    trailing: Text('v1.0.0',
                        style: SwimTrackTextStyles.label()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPoolSheet(BuildContext context, int current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 40, height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: SwimTrackColors.divider,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Pool Length',
                style: SwimTrackTextStyles.sectionHeader()),
            const SizedBox(height: 16),
            PoolLengthSelector(
              selectedLength: current,
              onChanged: (v) {
                ref.read(settingsProvider.notifier).setPoolLength(v);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showStrokeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 40, height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: SwimTrackColors.divider,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Default Stroke',
                style: SwimTrackTextStyles.sectionHeader()),
            const SizedBox(height: 16),
            StrokeSelector(
              selectedStroke: _defaultStroke,
              onChanged: (v) {
                setState(() => _defaultStroke = v);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: SwimTrackTextStyles.tiny(color: SwimTrackColors.textHint)
              .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w600),
        ),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: SwimTrackColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  String _strokeLabel(String key) {
    switch (key) {
      case 'BACKSTROKE':   return '↩ Back';
      case 'BREASTSTROKE': return '🤸 Breast';
      case 'BUTTERFLY':    return '🦋 Fly';
      default:             return '🏊 Free';
    }
  }

  IconData _batteryIcon(int pct) {
    if (pct >= 80) return Icons.battery_full;
    if (pct >= 50) return Icons.battery_3_bar;
    if (pct >= 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  Color _batteryColor(int pct) {
    if (pct >= 50) return SwimTrackColors.good;
    if (pct >= 20) return SwimTrackColors.neutral;
    return SwimTrackColors.bad;
  }
}