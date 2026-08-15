import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import 'admin/admin_dashboard_screen.dart' as admin_dash;
import 'package:flutter/services.dart';
import '../widgets/notification_bell_widget.dart';
import '../providers/auth_provider.dart';
import 'deposit_screen.dart' as deposit_ui;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final txAsync = ref.watch(transactionsProvider);
    final financeAction = ref.watch(financeActionProvider);

    // Listen for withdrawal action messages
    ref.listen<FinanceActionState>(financeActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Wallet'),
        actions: [
          const NotificationBellWidget(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          )
        ],
      ),
      body: userAsync.when(
        data: (user) => RefreshIndicator(
          onRefresh: () async {
            // ignore: unused_result
            ref.refresh(userProfileProvider);
            // ignore: unused_result
            ref.refresh(transactionsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileCard(context, user),
                const SizedBox(height: 16),
                _buildWalletCard(context, ref, user, financeAction.isLoading),
                const SizedBox(height: 16),
                _buildReferralCard(context, user),
                const SizedBox(height: 24),
                const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildTransactionList(txAsync),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading profile: $err')),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, UserModel user) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user.ign, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text('UID: ${user.uid}\nPhone: ${user.phone}'),
            isThreeLine: true,
          ),
        ),
        if (user.role == 'admin') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              label: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const admin_dash.AdminDashboardScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReferralCard(BuildContext context, UserModel user) {
    return Card(
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Refer & Earn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text('Share your code to get Bonus Balance!', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  Text(user.referralCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.referralCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code copied!')));
                    },
                    child: const Icon(Icons.copy, size: 20, color: Colors.amber),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, WidgetRef ref, UserModel user, bool isLoading) {
    return Card(
      color: Colors.blueGrey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Total Balance', style: TextStyle(color: Colors.white70)),
            Text('${user.totalBalance.toStringAsFixed(2)} Tk', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceBox('Bonus', user.bonusBalance),
                _buildBalanceBox('Withdrawable', user.withdrawableBalance),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add_circle_outline),
                    label: const Text('Deposit'),
                    onPressed: isLoading ? null : () => _showDepositDialog(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.money),
                    label: const Text('Withdraw'),
                    onPressed: isLoading ? null : () => _showWithdrawalDialog(context, ref, user.withdrawableBalance),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceBox(String label, double amount) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text('${amount.toStringAsFixed(2)} Tk', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildTransactionList(AsyncValue<List<TransactionModel>> txAsync) {
    return txAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) return const Text('No transactions yet.');
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isPositive = tx.amount > 0;
            return ListTile(
              leading: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, color: isPositive ? Colors.green : Colors.red),
              title: Text(tx.description ?? tx.type.toUpperCase()),
              subtitle: Text(tx.createdAt.toLocal().toString()),
              trailing: Text(
                '${isPositive ? '+' : ''}${tx.amount.toStringAsFixed(2)} Tk',
                style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Failed to load history: $err'),
    );
  }

  void _showWithdrawalDialog(BuildContext context, WidgetRef ref, double withdrawableBalance) {
    if (withdrawableBalance < 50) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum withdrawal is 50 Tk.'), backgroundColor: Colors.red));
      return;
    }

    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedMethod = 'bkash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Withdraw Funds'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Available: ${withdrawableBalance.toStringAsFixed(2)} Tk'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  items: const [
                    DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                    DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                  ],
                  onChanged: (val) => setState(() => selectedMethod = val!),
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount (Tk)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount < 50 || amount > withdrawableBalance) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid amount'), backgroundColor: Colors.red));
                  return;
                }
                if (phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter phone number'), backgroundColor: Colors.red));
                  return;
                }

                Navigator.pop(ctx);
                ref.read(financeActionProvider.notifier).requestWithdrawal(amount, selectedMethod, phoneController.text);
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositDialog(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const deposit_ui.DepositScreen()));
  }
}
