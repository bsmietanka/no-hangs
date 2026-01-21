import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable widget for displaying a labeled stat value
class StatDisplay extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double labelSize;
  final double valueSize;
  final FontWeight valueFontWeight;

  const StatDisplay({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelSize = 10,
    this.valueSize = 14,
    this.valueFontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: labelSize, color: appColors.statLabel),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: valueFontWeight,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Larger variant for header stats
class HeaderStatDisplay extends StatelessWidget {
  final String label;
  final String value;

  const HeaderStatDisplay({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: appColors.statLabel)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
