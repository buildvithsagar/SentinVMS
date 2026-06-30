import 'package:flutter/material.dart';

/// Horizontal speed selector for playback. Displays a row of speed chips
/// from 0.5× to 16× with the currently-selected speed highlighted in
/// accent green.
class PlaybackSpeedControl extends StatelessWidget {
  const PlaybackSpeedControl({
    required this.currentSpeed,
    required this.onSpeedChanged,
    super.key,
  });

  /// The currently active playback speed multiplier.
  final double currentSpeed;

  /// Called when the user selects a different speed.
  final ValueChanged<double> onSpeedChanged;

  /// Available speed options.
  static const List<double> _speeds = [0.5, 1, 2, 4, 8, 16];

  // ─── Palette ──────────────────────────────────────────────────────────

  static const Color _selectedBg = Color(0xFF2563EB);
  static const Color _unselectedBg = Colors.white12;
  static const Color _selectedText = Color(0xFFFFFFFF);
  static const Color _unselectedText = Color(0xFF94A3B8);

  // ─── Helpers ──────────────────────────────────────────────────────────

  /// Format speed label – omit trailing `.0` for whole numbers.
  static String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) {
      return '${speed.toInt()}x';
    }
    return '${speed}x';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _speeds.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _SpeedChip(
            speed: _speeds[i],
            label: _formatSpeed(_speeds[i]),
            isSelected: _speeds[i] == currentSpeed,
            onTap: () => onSpeedChanged(_speeds[i]),
          ),
        ],
      ],
    );
  }
}

/// A single speed chip button.
class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final double speed;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? PlaybackSpeedControl._selectedBg
          : PlaybackSpeedControl._unselectedBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? PlaybackSpeedControl._selectedText
                  : PlaybackSpeedControl._unselectedText,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
