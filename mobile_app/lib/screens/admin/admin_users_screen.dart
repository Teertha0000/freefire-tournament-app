import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/admin_provider.dart';

final allUsersProvider = StreamProvider((ref) {
  return () async* {
    while (true) {
      final data = await Supabase.instance.client.from('users').select().order('created_at', ascending: false);
      yield data;
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final actionState = ref.watch(adminActionProvider);

    ref.listen<AdminActionState>(adminActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users (Logic)')),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) return const Center(child: Text('No users found.'));
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text('${user['ign']} (${user['phone']})'),
                subtitle: Text('Bonus: ${user['bonus_balance']} | W/D: ${user['withdrawable_balance']} | Role: ${user['role']}'),
                trailing: ElevatedButton(
                  onPressed: actionState.isLoading ? null : () => _showAdjustBalanceDialog(context, ref, user),
                  child: const Text('Adjust Balance'),
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

  void _showAdjustBalanceDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String balanceType = 'withdrawable';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Adjust Balance: ${user['ign']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: balanceType,
                items: const [
                  DropdownMenuItem(value: 'withdrawable', child: Text('Withdrawable Balance')),
                  DropdownMenuItem(value: 'bonus', child: Text('Bonus Balance')),
                ],
                onChanged: (val) => setState(() => balanceType = val!),
                decoration: const InputDecoration(labelText: 'Wallet Type'),
              ),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount (Use negative to deduct)'),
                keyboardType: const TextInputType.numberWithOptions(signed: true),
              ),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for Ledger'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null) return;
                Navigator.pop(ctx);
                ref.read(adminActionProvider.notifier).adjustUserBalance(user['id'], amount, balanceType, reasonCtrl.text);
              },
              child: const Text('Submit Adjustment'),
            ),
          ],
        ),
      ),
    );
  }
}
