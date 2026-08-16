import "package:flutter/material.dart";

import "../theme/app_theme.dart";

/// Horizontal bar gauge scaled to the dataset's observed charging_watt
/// range (5-125W).
class WattageGauge extends StatelessWidget {
  final double watts;
  final double min;
  final double max;

  const WattageGauge({
    super.key,
    required this.watts,
    this.min = 5,
    this.max = 125,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = ((watts - min) / (max - min)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              watts % 1 == 0 ? watts.toStringAsFixed(0) : watts.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                "watts",
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.surfaceBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6FD79A), AppColors.primary],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _scaleLabel("${min.toStringAsFixed(0)}W"),
            _scaleLabel("${((min + max) / 2).toStringAsFixed(0)}W"),
            _scaleLabel("${max.toStringAsFixed(0)}W"),
          ],
        ),
      ],
    );
  }

  Widget _scaleLabel(String text) =>
      Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textFaint));
}
