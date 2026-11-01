// StrokeSelector widget - chip row for selecting swimming stroke type.

import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Row of 4 stroke type chips.
/// Calls [onChanged] with the selected stroke key string.
class StrokeSelector extends StatelessWidget {
  /// Currently selected stroke key (e.g. 'FREESTYLE').
  final String selectedStroke;

  /// Called when the user selects a different stroke.
  final ValueChanged<String> onChanged;

  const StrokeSelector({
    super.key,
    required this.selectedStroke,
    required this.onChanged,
  });

  static const _strokes = [
    ('FREESTYLE',   '🏊 Free'),
    ('BACKSTROKE',  '↩ Back'),
    ('BREASTSTROKE','🤸 Breast'),
    ('BUTTERFLY',   '🦋 Fly'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _strokes.map((s) {
        final isSelected = selectedStroke == s.$1;
        return GestureDetector(
          onTap: () => onChanged(s.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? SwimTrackColors.primary
                  : SwimTrackColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? SwimTrackColors.primary
                    : SwimTrackColors.divider,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: SwimTrackColors.primary.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              s.$2,
              style: SwimTrackTextStyles.label(
                color: isSelected
                    ? Colors.white
                    : SwimTrackColors.textSecondary,
              ).copyWith(
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}