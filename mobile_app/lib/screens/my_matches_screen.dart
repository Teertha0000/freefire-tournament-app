import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import '../widgets/result_submission_dialog.dart';
import '../widgets/countdown_timer_widget.dart';
import '../widgets/notification_bell_widget.dart';

class MyMatchesScreen extends ConsumerWidget {
  const MyMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(myMatchesProvider);

    return matchesAsync.when(
      data: (matches) {
        final joinedMatches = matches.where((m) => ['upcoming', 'ongoing', 'calculating'].contains(m.status)).toList();
        final historyMatches = matches.where((m) => ['completed', 'cancelled', 'delayed'].contains(m.status)).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('My Matches'),
              actions: const [NotificationBellWidget()],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Joined'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildMatchList(joinedMatches),
                _buildMatchList(historyMatches, isHistory: true),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildMatchList(List<MatchModel> matches, {bool isHistory = false}) {
    if (matches.isEmpty) {
      return Center(child: Text(isHistory ? 'No match history found.' : 'You haven\'t joined any active matches yet.'));
    }
    
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return _MatchLifecycleCard(match: match);
      },
    );
  }
}

class _MatchLifecycleCard extends ConsumerWidget {
  final MatchModel match;
  
  const _MatchLifecycleCard({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool revealRoomDetails = false;

    // Time-based unlock logic
    if (match.status == 'upcoming' && match.startTime != null) {
      final timeDifference = match.startTime!.difference(DateTime.now());
      if (timeDifference.inMinutes <= 10) {
        revealRoomDetails = true;
      }
    } else if (match.status == 'ongoing' || match.status == 'calculating') {
      revealRoomDetails = true;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(match.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Status: ${match.status.toUpperCase()}', style: TextStyle(color: Colors.blueAccent)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Start Time: ', style: TextStyle(color: Colors.grey)),
                if (match.startTime != null && match.status == 'upcoming')
                  CountdownTimerWidget(targetTime: match.startTime!)
                else
                  Text(match.startTime?.toLocal().toString() ?? "TBD"),
              ],
            ),
            const Divider(),

            if (revealRoomDetails) 
              ref.watch(matchSecretsProvider(match.id)).when(
                data: (secrets) {
                  if (secrets == null) return const Text('Waiting for admin to upload room details...');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Room Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Room ID: ${secrets['room_id'] ?? "Pending..."}'),
                      Text('Password: ${secrets['room_password'] ?? "Pending..."}'),
                      const Divider(),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (err, _) => Text('Error loading room: $err'),
              )
            else if (match.status == 'upcoming') ...[
              const Text('Room ID & Password will be revealed 10 minutes before start time.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              const Divider(),
            ],

            if (match.status == 'calculating') ...[
              if (match.resultSubmissionDeadline != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Text('Upload Deadline: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      CountdownTimerWidget(
                        targetTime: match.resultSubmissionDeadline!,
                        prefixText: '',
                        finishedText: 'Time is up! (Closed)',
                      ),
                    ],
                  ),
                ),
              Consumer(
                builder: (context, ref, child) {
                  final resultAsync = ref.watch(userMatchResultProvider(match.id));
                  return resultAsync.when(
                    data: (resultData) {
                      final hasSubmitted = resultData != null;
                      final isApproved = resultData != null && resultData['status'] == 'approved';

                      if (isApproved) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('✅ Result Approved! Prize Awarded.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        );
                      }

                      return ElevatedButton(
                        onPressed: () async {
                          final success = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => ResultSubmissionDialog(matchId: match.id),
                          );
                          
                          if (success == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Proof submitted successfully!'), backgroundColor: Colors.green)
                            );
                          }
                        },
                        child: Text(hasSubmitted ? 'Change Match Proof' : 'Upload Match Proof'),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, st) => const SizedBox.shrink(),
                  );
                },
              ),
            ],

            // History Actions
            if (['completed', 'cancelled', 'delayed'].contains(match.status)) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: match.id));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match ID copied!')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy ID'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showDisputeDialog(context, ref, match.id),
                    icon: const Icon(Icons.report_problem, size: 16, color: Colors.orange),
                    label: const Text('Report Issue', style: TextStyle(color: Colors.orange)),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  void _showDisputeDialog(BuildContext context, WidgetRef ref, String matchId) {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report an Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please describe the problem (e.g. "My booyah screenshot was rejected"). Admin will investigate.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter details...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (msgCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              ref.read(matchActionProvider.notifier).reportDispute(matchId, msgCtrl.text);
            },
            child: const Text('Submit'),
          )
        ],
      ),
    );
  }
}
