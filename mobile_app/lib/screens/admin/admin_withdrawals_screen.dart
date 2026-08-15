import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/admin_provider.dart';

final pendingWithdrawalsProvider = StreamProvider((ref) {
  return () async* {
    while (true) {
      final data = await Supabase.instance.client.from('withdrawals').select().eq('status', 'pending').order('created_at');
      yield data;
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

class AdminWithdrawalsScreen extends ConsumerWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final withdrawalsAsync = ref.watch(pendingWithdrawalsProvider);
    final actionState = ref.watch(adminActionProvider);

    ref.listen<AdminActionState>(adminActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Withdrawals (Logic)')),
      body: withdrawalsAsync.when(
        data: (withdrawals) {
          if (withdrawals.isEmpty) return const Center(child: Text('No pending withdrawals.'));
          return ListView.builder(
            itemCount: withdrawals.length,
            itemBuilder: (context, index) {
              final wd = withdrawals[index];
              return ListTile(
                title: Text('${wd['amount']} Tk via ${wd['payment_method']}'),
                subtitle: Text('Phone: ${wd['phone_number']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: actionState.isLoading ? null : () {
                        ref.read(adminActionProvider.notifier).rejectWithdrawal(wd['id'], 'Rejected by Admin');
                      },
                      child: const Text('Reject & Refund', style: TextStyle(color: Colors.red)),
                    ),
                    ElevatedButton(
                      onPressed: actionState.isLoading ? null : () {
                        ref.read(adminActionProvider.notifier).approveWithdrawal(wd['id']);
                      },
                      child: const Text('Mark as Paid'),
                    ),
                  ],
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
}
