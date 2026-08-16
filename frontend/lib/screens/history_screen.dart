import "package:flutter/material.dart";

import "../models/prediction_history_entry.dart";
import "../services/auth_service.dart";
import "../services/firestore_service.dart";
import "../theme/app_theme.dart";
import "../widgets/source_badge.dart";

/// History tab body. No Scaffold/AppBar of its own -- this is one page
/// inside DashboardScreen's PageView.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    final firestore = FirestoreService();

    if (uid == null) {
      return const Center(
        child: Text("Sign in to see your history.", style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "History",
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            "Every prediction you've run, saved to your account.",
            style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<PredictionHistoryEntry>>(
              stream: firestore.watchHistory(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text("Couldn't load history.", style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "No predictions yet. Run one from the Home tab and it'll show up here.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _historyTile(context, firestore, uid, entries[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(BuildContext context, FirestoreService firestore, String uid, PredictionHistoryEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${entry.brand} ${entry.model}",
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                SourceBadge(isVerified: entry.isVerified),
                const SizedBox(height: 6),
                Text(_formatDate(entry.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
              ],
            ),
          ),
          Text(
            entry.chargingWatt % 1 == 0
                ? "${entry.chargingWatt.toStringAsFixed(0)}W"
                : "${entry.chargingWatt.toStringAsFixed(1)}W",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
          ),
          if (entry.id != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textFaint),
              onPressed: () => firestore.deleteEntry(uid, entry.id!),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
