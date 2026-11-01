// PoolLengthSelector widget - chip row for selecting pool length.

import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Row of chips: 25m · 50m · Custom.
/// Calls [onChanged] with the selected length in metres.
class PoolLengthSelector extends StatefulWidget {
  /// Currently selected pool length in metres.
  final int selectedLength;

  /// Called when the user selects a different length.
  final ValueChanged<int> onChanged;

  const PoolLengthSelector({
    super.key,
    required this.selectedLength,
    required this.onChanged,
  });

  @override
  State<PoolLengthSelector> createState() => _PoolLengthSelectorState();
}

class _PoolLengthSelectorState extends State<PoolLengthSelector> {
  static const _presets = [25, 50];

  bool get _isCustom =>
      !_presets.contains(widget.selectedLength);

  void _showCustomDialog() {
    final ctrl = TextEditingController(
      text: _isCustom ? widget.selectedLength.toString() : '',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Custom Pool Length',
            style: SwimTrackTextStyles.sectionHeader()),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. 33',
            suffixText: 'm',
            hintStyle:
                SwimTrackTextStyles.body(color: SwimTrackColors.textHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: SwimTrackTextStyles.body(
                    color: SwimTrackColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 10 && v <= 100) {
                widget.onChanged(v);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ..._presets.map((len) => _buildChip(
              label: '${len}m',
              isSelected: widget.selectedLength == len,
              onTap: () => widget.onChanged(len),
            )),
        _buildChip(
          label: _isCustom
              ? '${widget.selectedLength}m ✎'
              : 'Custom',
          isSelected: _isCustom,
          onTap: _showCustomDialog,
        ),
      ],
    );
  }

  Widget _buildChip({
    required String   label,
    required bool     isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
            label,
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
      ),
    );
  }
}