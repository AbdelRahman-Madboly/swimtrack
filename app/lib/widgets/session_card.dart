// SessionCard widget - displays a single session summary in the History list.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/session.dart';

/// A tappable card showing date, distance, laps, duration, and SWOLF.
class SessionCard extends StatelessWidget {
  /// The session to display.
  final Session session;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: SwimTrackColors.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ── Swim emoji circle ───────────────────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SwimTrackColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('🏊', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),

              // ── Session info ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDate(session.startTime),
                          style: SwimTrackTextStyles.cardTitle(
                              color: SwimTrackColors.dark),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(session.durationSec),
                          style: SwimTrackTextStyles.label(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.totalDistanceM}m · ${session.lapCount} laps · ${session.poolLengthM}m pool',
                      style: SwimTrackTextStyles.body(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ── SWOLF score ──────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    session.avgSwolf.toStringAsFixed(1),
                    style: SwimTrackTextStyles.sectionHeader(
                        color: SwimTrackColors.primary),
                  ),
                  Text(
                    'SWOLF',
                    style: SwimTrackTextStyles.tiny(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats [dt] as "Wed, Mar 20".
  String _formatDate(DateTime dt) {
    return DateFormat('EEE, MMM d').format(dt);
  }

  /// Formats [seconds] as "M:SS" or "H:MM:SS".
  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}