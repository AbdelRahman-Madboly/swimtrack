// ConnectionStatus widget - shows a coloured dot and connection label.
// Dot pulses amber while connecting, solid green when connected.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/device_provider.dart';

/// Compact row showing the current device connection status.
/// Green dot = connected · Grey = disconnected · Amber pulsing = connecting.
class ConnectionStatusWidget extends ConsumerStatefulWidget {
  const ConnectionStatusWidget({super.key});

  @override
  ConsumerState<ConnectionStatusWidget> createState() =>
      _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState
    extends ConsumerState<ConnectionStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceProvider);
    final status      = deviceState.status;

    Color  dotColor;
    String label;
    bool   pulse = false;

    switch (status) {
      case ConnectionStatus.connected:
        dotColor = SwimTrackColors.good;
        final fw = deviceState.deviceStatus?.firmwareVersion ?? '';
        label    = 'SwimTrack · 192.168.4.1${fw.isNotEmpty ? ' · v$fw' : ''}';
        pulse    = false;
      case ConnectionStatus.connecting:
        dotColor = SwimTrackColors.neutral;
        label    = 'Connecting…';
        pulse    = true;
      case ConnectionStatus.error:
        dotColor = SwimTrackColors.bad;
        label    = deviceState.error ?? 'Connection error';
        pulse    = false;
      case ConnectionStatus.disconnected:
        dotColor = SwimTrackColors.divider;
        label    = 'Not Connected';
        pulse    = false;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated dot
        pulse
            ? AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: _pulseAnim.value,
                  child: _dot(dotColor),
                ),
              )
            : _dot(dotColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: SwimTrackTextStyles.label(color: SwimTrackColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}