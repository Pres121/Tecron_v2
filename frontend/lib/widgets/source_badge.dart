import "package:flutter/material.dart";

import "../theme/app_theme.dart";

class SourceBadge extends StatelessWidget {
  final bool isVerified;

  const SourceBadge({super.key, required this.isVerified});

  @override
  Widget build(BuildContext context) {
    final fill = isVerified ? AppColors.primarySoft : AppColors.neutralSoft;
    final fg = isVerified ? AppColors.primaryDark : AppColors.neutral;
    final label = isVerified ? "Verified database match" : "Machine learning prediction";
    final icon = isVerified ? Icons.verified_rounded : Icons.auto_graph_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: fg)),
        ],
      ),
    );
  }
}
