// LapTable widget - shows per-lap breakdown with colour-coded SWOLF cells.

import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/session.dart';

/// Table showing each lap's stroke count, time, SWOLF, and SPM.
/// SWOLF cells are green when below session average, red when above.
class LapTable extends StatelessWidget {
  /// The laps to display.
  final List<Lap> laps;

  /// Session average SWOLF - used to colour-code individual lap cells.
  final double avgSwolf;

  const LapTable({
    super.key,
    required this.laps,
    required this.avgSwolf,
  });

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No lap data recorded for this session.',
            style: SwimTrackTextStyles.body(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          _buildHeader(),
          ...laps.asMap().entries.map(
            (e) => _buildRow(e.value, e.key.isEven),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: SwimTrackColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _headerCell('#', flex: 1),
          _headerCell('Strokes', flex: 3),
          _headerCell('Time', flex: 3),
          _headerCell('SWOLF', flex: 3),
          _headerCell('DPS', flex: 3),
          _headerCell('SPM', flex: 2),
        ],
      ),
    );
  }

  Widget _buildRow(Lap lap, bool isEven) {
    final isBelowAvg = lap.swolf < avgSwolf;
    final swolfBg    = isBelowAvg
        ? SwimTrackColors.good.withValues(alpha: 0.12)
        : SwimTrackColors.bad.withValues(alpha: 0.12);
    final swolfColor = isBelowAvg ? SwimTrackColors.good : SwimTrackColors.bad;

    return Container(
      color: isEven ? SwimTrackColors.card : SwimTrackColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // # (lap number)
                Expanded(
                  flex: 1,
                  child: Text(
                    lap.lapNumber.toString(),
                    style: SwimTrackTextStyles.label(
                        color: SwimTrackColors.textHint),
                  ),
                ),
                // Strokes
                Expanded(
                  flex: 3,
                  child: Text(
                    lap.strokeCount.toString(),
                    style: SwimTrackTextStyles.body(
                        color: SwimTrackColors.dark),
                  ),
                ),
                // Time
                Expanded(
                  flex: 3,
                  child: Text(
                    '${lap.timeSeconds.toStringAsFixed(1)}s',
                    style: SwimTrackTextStyles.body(
                        color: SwimTrackColors.dark),
                  ),
                ),
                // SWOLF (colour-coded)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: swolfBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      lap.swolf.toStringAsFixed(1),
                      style: SwimTrackTextStyles.label(color: swolfColor)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // DPS
                Expanded(
                  flex: 3,
                  child: Text(
                    lap.dps > 0
                        ? '${lap.dps.toStringAsFixed(2)}m'
                        : '-',
                    style: SwimTrackTextStyles.body(
                        color: SwimTrackColors.dark),
                  ),
                ),
                // SPM
                Expanded(
                  flex: 2,
                  child: Text(
                    lap.strokeRate.toStringAsFixed(0),
                    style: SwimTrackTextStyles.label(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: SwimTrackColors.divider),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        style: SwimTrackTextStyles.label(color: SwimTrackColors.textSecondary)
            .copyWith(fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}