import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/admin_provider.dart';

final allMatchResultsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) {
  return () async* {
    while (true) {
      final data = await Supabase.instance.client
          .from('match_results')
          .select()
          .eq('match_id', matchId);
      yield data;
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

final adminDisputesProvider = StreamProvider((ref) {
  return () async* {
    while (true) {
      final data = await Supabase.instance.client
          .from('disputes')
          .select('*, matches(title), users(ign)')
          .order('created_at', ascending: false);
      yield data;
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(adminDisputesProvider);
    final actionState = ref.watch(adminActionProvider);

    ref.listen<AdminActionState>(adminActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
        ref.refresh(adminDisputesProvider); // Refresh list
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispute Investigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminDisputesProvider),
          )
        ],
      ),
      body: disputesAsync.when(
        data: (disputes) {
          if (disputes.isEmpty) return const Center(child: Text('No pending disputes. Great job!'));
          return ListView.builder(
            itemCount: disputes.length,
            itemBuilder: (context, index) {
              final dispute = disputes[index];
              final matchTitle = dispute['matches']?['title'] ?? 'Unknown Match';
              final userIgn = dispute['users']?['ign'] ?? 'Unknown Player';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Match: $matchTitle'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reported by: $userIgn'),
                      Text('Message: ${dispute['message']}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _showInvestigationDashboard(context, ref, dispute),
                    child: const Text('Investigate'),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showInvestigationDashboard(BuildContext context, WidgetRef ref, Map<String, dynamic> dispute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _InvestigationDashboard(dispute: dispute),
      ),
    );
  }
}

class _InvestigationDashboard extends ConsumerWidget {
  final Map<String, dynamic> dispute;

  const _InvestigationDashboard({required this.dispute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchId = dispute['match_id'];
    final resultsAsync = ref.watch(allMatchResultsProvider(matchId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investigate Truth'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Complaint:\n${dispute['message']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(),
          const Text('All Submitted Results for this Match:', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: resultsAsync.when(
              data: (results) {
                if (results.isEmpty) return const Center(child: Text('No results submitted for this match.'));
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final res = results[index];
                    final isReporter = res['user_id'] == dispute['user_id'];
                    return ListTile(
                      tileColor: isReporter ? Colors.orange.withOpacity(0.2) : null,
                      leading: res['proof_image_url'] != null
                          ? Image.network(res['proof_image_url'], width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.image_not_supported),
                      title: Text('Kills: ${res['kills']} | Rank: ${res['rank']}'),
                      subtitle: Text('Status: ${res['status']} | Prize Given: ${res['prize_amount'] ?? 0} Tk'),
                      trailing: isReporter ? const Text('REPORTER', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)) : null,
                      onTap: () {
                        if (res['proof_image_url'] != null) {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              content: Image.network(res['proof_image_url']),
                            )
                          );
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _resolveDispute(context, ref, 'rejected', 0, 'Your claim was rejected after investigation.'),
                  child: const Text('Reject Dispute', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _promptPrizeCorrection(context, ref),
                  child: const Text('Approve & Correct Prize', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _resolveDispute(BuildContext context, WidgetRef ref, String status, double prize, String response) {
    ref.read(adminActionProvider.notifier).resolveDispute(dispute['id'], status, response, prize);
    Navigator.pop(context); // Close bottom sheet
  }

  void _promptPrizeCorrection(BuildContext context, WidgetRef ref) {
    final prizeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Correct Prize Amount'),
        content: TextField(
          controller: prizeCtrl,
          decoration: const InputDecoration(labelText: 'Amount to Credit (Tk)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final prize = double.tryParse(prizeCtrl.text) ?? 0;
              Navigator.pop(ctx);
              _resolveDispute(context, ref, 'resolved', prize, 'We found a mistake. The prize has been credited.');
            },
            child: const Text('Submit'),
          )
        ],
      ),
    );
  }
}
