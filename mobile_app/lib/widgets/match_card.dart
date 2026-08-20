import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_model.dart';
import '../core/theme.dart';
import 'primary_gradient_button.dart';
import 'countdown_timer_widget.dart';
import '../providers/match_provider.dart';

class MatchCard extends ConsumerWidget {
  final MatchModel match;

  const MatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(matchActionProvider);
    final isUpcoming = match.status == 'upcoming';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category and Status
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    match.category.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (match.startTime != null && isUpcoming)
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryCyan),
                      const SizedBox(width: 4),
                      CountdownTimerWidget(
                        targetTime: match.startTime!,
                        style: const TextStyle(
                          color: AppTheme.primaryCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Match Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              match.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textWhite,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Details Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Entry Fee', '৳${match.entryFee.toInt()}', isHighlight: false),
                _buildInfoColumn('Prize Pool', '৳${match.prizePool.toInt()}', isHighlight: true),
                _buildInfoColumn('Spots', '${match.filledSpots}/${match.totalSpots}', isHighlight: false),
              ],
            ),
          ),
          
          // Progress Bar
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: match.totalSpots > 0 ? match.filledSpots / match.totalSpots : 0,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryCyan),
                minHeight: 6,
              ),
            ),
          ),
          
          // Action Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: PrimaryGradientButton(
              text: isUpcoming ? 'Join Match' : match.status.toUpperCase(),
              isLoading: actionState.isLoading,
              onPressed: (isUpcoming && !actionState.isLoading) 
                  ? () => _showJoinDialog(context, ref, match)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {required bool isHighlight}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.primaryCyan : AppTheme.textWhite,
          ),
        ),
      ],
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref, MatchModel match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Join Match', style: TextStyle(color: Colors.white)),
        content: Text(
          'Entry fee is ৳${match.entryFee.toInt()}.\nThis will be deducted from your wallet.\n\nDo you want to proceed?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(matchActionProvider.notifier).joinMatch(match.id);
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );
  }
}
