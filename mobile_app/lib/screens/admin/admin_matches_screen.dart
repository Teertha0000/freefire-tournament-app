import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/admin_provider.dart';
import 'admin_result_verification_screen.dart';

final adminAllMatchesProvider = StreamProvider((ref) {
  return () async* {
    while (true) {
      final data = await Supabase.instance.client.from('matches').select().order('created_at', ascending: false);
      yield data;
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

class AdminMatchesScreen extends ConsumerWidget {
  const AdminMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(adminAllMatchesProvider);

    ref.listen<AdminActionState>(adminActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Matches (Logic)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateMatchDialog(context, ref),
          ),
        ],
      ),
      body: matchesAsync.when(
        data: (matches) {
          if (matches.isEmpty) return const Center(child: Text('No matches found.'));
          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              return Card(
                child: ListTile(
                  title: Text(match['title']),
                  subtitle: Text('Status: ${match['status']} | Fee: ${match['entry_fee']} Tk'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (match['status'] != 'completed' && match['status'] != 'calculating' && match['status'] != 'cancelled') ...[
                        TextButton(
                          onPressed: () async {
                            await _showUpdateRoomDialog(context, ref, match['id']);
                          },
                          child: const Text('Update Room', style: TextStyle(color: Colors.blue)),
                        ),
                        TextButton(
                          onPressed: () => _confirmAction(context, 'Start Result Timer', 'Are you sure you want to start the 2-hour result submission timer? This cannot be undone.', () {
                            ref.read(adminActionProvider.notifier).markMatchFinished(match['id'], 2);
                          }),
                          child: const Text('Start Result Timer'),
                        ),
                      ],
                      if (match['status'] == 'calculating')
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AdminResultVerificationScreen(
                                matchId: match['id'],
                                defaultFilledSpots: match['filled_spots'] ?? 0,
                              )),
                            );
                          },
                          child: const Text('Verify Results'),
                        ),
                      if (match['status'] == 'calculating')
                        TextButton(
                          onPressed: () => _confirmAction(context, 'Close Match', 'Are you sure you want to permanently close this match? You should verify all results first.', () {
                            ref.read(adminActionProvider.notifier).closeMatch(match['id']);
                          }),
                          child: const Text('Close Match', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMatchDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmAction(BuildContext context, String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateMatchDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final spotsCtrl = TextEditingController();
    final prizeCtrl = TextEditingController();
    final perKillCtrl = TextEditingController(text: '0');
    final firstPrizeCtrl = TextEditingController(text: '0');
    final secondPrizeCtrl = TextEditingController(text: '0');
    final thirdPrizeCtrl = TextEditingController(text: '0');
    final roomCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Match'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category (e.g., BR, CS)')),
                TextField(controller: feeCtrl, decoration: const InputDecoration(labelText: 'Entry Fee (Tk)'), keyboardType: TextInputType.number),
                TextField(controller: spotsCtrl, decoration: const InputDecoration(labelText: 'Total Spots'), keyboardType: TextInputType.number),
                TextField(controller: prizeCtrl, decoration: const InputDecoration(labelText: 'Total Prize Pool (Tk)'), keyboardType: TextInputType.number),
                const Divider(),
                const Text('Prize Breakdown (Used for Auto-Verify)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                TextField(controller: perKillCtrl, decoration: const InputDecoration(labelText: 'Per Kill Prize (Tk)'), keyboardType: TextInputType.number),
                TextField(controller: firstPrizeCtrl, decoration: const InputDecoration(labelText: '1st Place Prize (Tk)'), keyboardType: TextInputType.number),
                TextField(controller: secondPrizeCtrl, decoration: const InputDecoration(labelText: '2nd Place Prize (Tk)'), keyboardType: TextInputType.number),
                TextField(controller: thirdPrizeCtrl, decoration: const InputDecoration(labelText: '3rd Place Prize (Tk)'), keyboardType: TextInputType.number),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text(selectedDate == null ? 'No start time selected' : 'Start: ${selectedDate!.toLocal().toString().split('.')[0]}')),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                        if (date != null) {
                          final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (time != null) {
                            setState(() {
                              selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                      child: const Text('Pick Time'),
                    ),
                  ],
                ),
                TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room ID (Optional)')),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Room Password (Optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.isEmpty || catCtrl.text.isEmpty || feeCtrl.text.isEmpty || spotsCtrl.text.isEmpty || prizeCtrl.text.isEmpty || selectedDate == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red));
                  return;
                }

                final matchData = {
                  'title': titleCtrl.text,
                  'category': catCtrl.text,
                  'entry_fee': double.tryParse(feeCtrl.text) ?? 0,
                  'total_spots': int.tryParse(spotsCtrl.text) ?? 0,
                  'prize_pool': double.tryParse(prizeCtrl.text) ?? 0,
                  'per_kill_prize': double.tryParse(perKillCtrl.text) ?? 0,
                  'first_prize': double.tryParse(firstPrizeCtrl.text) ?? 0,
                  'second_prize': double.tryParse(secondPrizeCtrl.text) ?? 0,
                  'third_prize': double.tryParse(thirdPrizeCtrl.text) ?? 0,
                  'start_time': selectedDate!.toUtc().toIso8601String(),
                  'room_id': roomCtrl.text.isEmpty ? null : roomCtrl.text,
                  'room_password': passCtrl.text.isEmpty ? null : passCtrl.text,
                };

                Navigator.pop(ctx);
                ref.read(adminActionProvider.notifier).createMatch(matchData);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUpdateRoomDialog(BuildContext context, WidgetRef ref, String matchId) async {
    // Show a quick loading indicator or just await the fetch
    final secretData = await Supabase.instance.client
        .from('match_secrets')
        .select()
        .eq('match_id', matchId)
        .maybeSingle();

    if (!context.mounted) return;

    final roomCtrl = TextEditingController(text: secretData?['room_id'] ?? '');
    final passCtrl = TextEditingController(text: secretData?['room_password'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Room Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Updating the room details will instantly notify all players who joined this match!', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room ID (Optional)')),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Room Password (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminActionProvider.notifier).updateMatchRoomDetails(matchId, roomCtrl.text, passCtrl.text);
            },
            child: const Text('Update & Notify Players'),
          ),
        ],
      ),
    );
  }
}
