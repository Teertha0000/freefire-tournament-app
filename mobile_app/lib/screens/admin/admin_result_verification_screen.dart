import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as import_url_launcher;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/admin_provider.dart';

final matchResultsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) {
  return () async* {
    while (true) {
      final data = await Supabase.instance.client
          .from('match_results')
          .select('*, users(ign)')
          .eq('match_id', matchId)
          .eq('status', 'pending');
      yield data;
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

final matchDetailsProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, matchId) {
  return () async* {
    while (true) {
      final data = await Supabase.instance.client
          .from('matches')
          .select('*')
          .eq('id', matchId)
          .single();
      yield data;
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

class AdminResultVerificationScreen extends ConsumerStatefulWidget {
  final String matchId;
  final int defaultFilledSpots;

  const AdminResultVerificationScreen({
    super.key,
    required this.matchId,
    required this.defaultFilledSpots,
  });

  @override
  ConsumerState<AdminResultVerificationScreen> createState() => _AdminResultVerificationScreenState();
}

class _AdminResultVerificationScreenState extends ConsumerState<AdminResultVerificationScreen> {
  late TextEditingController _actualPlayersCtrl;

  @override
  void initState() {
    super.initState();
    _actualPlayersCtrl = TextEditingController(text: widget.defaultFilledSpots.toString());
  }

  @override
  void dispose() {
    _actualPlayersCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(matchResultsProvider(widget.matchId));
    final matchDetailsAsync = ref.watch(matchDetailsProvider(widget.matchId));
    final actionState = ref.watch(adminActionProvider);

    ref.listen<AdminActionState>(adminActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Results (Logic)')),
      body: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) return const Center(child: Text('No pending results to verify.'));
          return Column(
            children: [
              matchDetailsAsync.when(
                data: (matchData) {
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const Text('Admin Match Proof', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (matchData['admin_proof_url'] != null) ...[
                            const Text('✅ Proof Uploaded', style: TextStyle(color: Colors.green)),
                            TextButton.icon(
                              onPressed: () {
                                import_url_launcher.launchUrl(Uri.parse(matchData['admin_proof_url']));
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('View Proof'),
                            )
                          ] else
                            const Text('❌ No Proof Uploaded', style: TextStyle(color: Colors.red)),
                          ElevatedButton.icon(
                            onPressed: actionState.isLoading ? null : () => _pickAndUploadAdminProof(),
                            icon: const Icon(Icons.upload),
                            label: const Text('Upload Match Proof (Image/Video)'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => const Text('Error loading match details'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _actualPlayersCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Actual Players Joined (Defaults to Registered Users)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: actionState.isLoading ? null : () {
                    final actual = int.tryParse(_actualPlayersCtrl.text) ?? widget.defaultFilledSpots;
                    ref.read(adminActionProvider.notifier).autoVerifyMatchResults(widget.matchId, actual);
                  },
                  icon: const Icon(Icons.bolt, color: Colors.yellow),
                  label: const Text('Run Smart Verification (Auto-Verify)', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return Card(
                child: Column(
                  children: [
                    Expanded(
                      child: result['proof_image_url'] != null
                          ? Image.network(result['proof_image_url'], fit: BoxFit.cover)
                          : const Center(child: Text('No Image')),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text('Kills: ${result['kills']} | Rank: ${result['rank']}'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: actionState.isLoading ? null : () => _showRejectDialog(context, ref, result['id']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: actionState.isLoading ? null : () => _showApproveDialog(context, ref, result['id']),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showApproveDialog(BuildContext context, WidgetRef ref, String resultId) {
    final prizeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Result'),
        content: TextField(
          controller: prizeCtrl,
          decoration: const InputDecoration(labelText: 'Prize Amount (Tk)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final prize = double.tryParse(prizeCtrl.text) ?? 0.0;
              Navigator.pop(ctx);
              ref.read(adminActionProvider.notifier).reviewMatchResult(resultId, 'approved', prize, 'Approved');
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, String resultId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Result'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason for Rejection'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminActionProvider.notifier).reviewMatchResult(resultId, 'rejected', 0, reasonCtrl.text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAdminProof() async {
    final result = await FilePicker.pickFiles(
      type: FileType.media,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      try {
        final File file = File(result.files.single.path!);
        final ext = result.files.single.extension ?? 'unknown';
        final fileName = 'admin_${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading proof...')));

        await Supabase.instance.client.storage.from('match_proofs').upload(fileName, file);
        final url = Supabase.instance.client.storage.from('match_proofs').getPublicUrl(fileName);
        
        await ref.read(adminActionProvider.notifier).uploadAdminProof(widget.matchId, url);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
