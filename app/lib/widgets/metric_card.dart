// MetricCard widget - displays a single metric value with a label.
// Used in Session Detail and Home tab.

import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A small card showing a [value] (large) above a [label] (small).
/// Optional [trend] shows a coloured up/down arrow.
class MetricCard extends StatelessWidget {
  /// The metric value to display (e.g. "42.0", "1:26").
  final String value;

  /// The label below the value (e.g. "Avg SWOLF", "Duration").
  final String label;

  /// Optional trend: 'up' = bad/red, 'down' = good/green, null = no arrow.
  final String? trend;

  /// Optional colour override for the value text.
  final Color? valueColor;

  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    this.trend,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: SwimTrackTextStyles.sectionHeader(
                  color: valueColor ?? SwimTrackColors.dark,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 4),
                Icon(
                  trend == 'down' ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 14,
                  color: trend == 'down'
                      ? SwimTrackColors.good
                      : SwimTrackColors.bad,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: SwimTrackTextStyles.label(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}