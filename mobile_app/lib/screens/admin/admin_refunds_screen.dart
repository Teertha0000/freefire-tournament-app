import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/admin_provider.dart';

final refundableMatchesProvider = StreamProvider((ref) {
  return () async* {
    while (true) {
      final data = await Supabase.instance.client
          .from('matches')
          .select()
          .neq('status', 'cancelled')
          .order('created_at', ascending: false);
      yield data;
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

class AdminRefundsScreen extends ConsumerWidget {
  const AdminRefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(refundableMatchesProvider);
    final actionState = ref.watch(adminActionProvider);

    ref.listen<AdminActionState>(adminActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
      }
    });

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Refunds & Cancellations (Logic)'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active Matches'),
              Tab(text: 'Historical (Completed)'),
            ],
          ),
        ),
        body: matchesAsync.when(
          data: (matches) {
            final activeMatches = matches.where((m) => m['status'] != 'completed').toList();
            final historicalMatches = matches.where((m) => m['status'] == 'completed').toList();

            return TabBarView(
              children: [
                _buildList(context, ref, activeMatches, false, actionState.isLoading),
                _buildList(context, ref, historicalMatches, true, actionState.isLoading),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> matches, bool isHistorical, bool isLoading) {
    if (matches.isEmpty) return const Center(child: Text('No matches found.'));
    
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return Card(
          child: ListTile(
            title: Text(match['title']),
            subtitle: Text('Status: ${match['status']} | Fee: ${match['entry_fee']} Tk'),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: isLoading ? null : () => _showCancelDialog(context, ref, match['id'], isHistorical),
              child: Text(isHistorical ? 'Reverse & Refund' : 'Cancel & Refund'),
            ),
          ),
        );
      },
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, String matchId, bool isHistorical) {
    final reasonCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHistorical ? 'CRITICAL: Reverse Historical Match' : 'Cancel Upcoming Match'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHistorical)
              const Text(
                'WARNING: This match is already completed. '
                'Reversing it will deduct prizes from the winners\' wallets and refund the entry fee to all players.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason for Cancellation/Reversal'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abort')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              if (isHistorical) {
                ref.read(adminActionProvider.notifier).refundHistoricalMatch(matchId, reasonCtrl.text);
              } else {
                ref.read(adminActionProvider.notifier).cancelUpcomingMatch(matchId, reasonCtrl.text);
              }
            },
            child: const Text('Confirm Action'),
          ),
        ],
      ),
    );
  }
}
