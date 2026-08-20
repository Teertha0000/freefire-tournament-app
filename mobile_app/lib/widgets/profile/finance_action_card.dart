import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../../screens/deposit_screen.dart' as deposit_ui;

class FinanceActionCard extends ConsumerWidget {
  final UserModel user;
  final bool isLoading;

  const FinanceActionCard({
    super.key,
    required this.user,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 100, // Total height (50px hidden behind, 50px exposed)
      decoration: const BoxDecoration(
        color: Color(0xFF071430),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildActionHalf(
                context,
                title: 'Deposit',
                icon: Icons.add,
                iconColor: Colors.black, // Dark icon for contrast
                bgColor: AppTheme.primaryCyan, // Solid vibrant cyan
                onTap: isLoading ? null : () => _showDepositDialog(context),
              ),
            ),
            Container(width: 1, height: 50, color: Colors.black.withOpacity(0.2)),
            Expanded(
              child: _buildActionHalf(
                context,
                title: 'Withdraw',
                icon: Icons.arrow_outward_rounded,
                iconColor: Colors.black, // Dark icon for contrast
                bgColor: const Color(0xFF45F882), // Solid vibrant green (matches glow)
                onTap: isLoading ? null : () => _showWithdrawalDialog(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHalf(BuildContext context, {required String title, required IconData icon, required Color iconColor, required Color bgColor, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: bgColor,
        alignment: Alignment.bottomCenter, // Align to bottom so it drops into the exposed area
        padding: const EdgeInsets.only(bottom: 16), // Visually center in the bottom 50px
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLoading && title == 'Deposit')
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            else
              Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black, // Dark text for contrast against solid vibrant background
                fontWeight: FontWeight.w700, // Slightly bolder for visibility
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawalDialog(BuildContext context, WidgetRef ref) {
    if (user.withdrawableBalance < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum withdrawal is 50 Tk.'), backgroundColor: Colors.red),
      );
      return;
    }

    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedMethod = 'bkash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.surfaceGrey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Withdraw Funds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.primaryCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Available: ৳ ${user.withdrawableBalance.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Payment Method
                const Text('Payment Method', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMethod,
                      isExpanded: true,
                      dropdownColor: AppTheme.surfaceGrey,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: const [
                        DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                        DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                      ],
                      onChanged: (val) => setState(() => selectedMethod = val!),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Phone Number
                const Text('Account Number', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. 01XXXXXXXXX',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                
                const SizedBox(height: 16),
                
                // Amount
                const Text('Amount (Tk)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Minimum 50',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount < 50 || amount > user.withdrawableBalance) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid amount'), backgroundColor: Colors.red));
                  return;
                }
                if (phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter account number'), backgroundColor: Colors.red));
                  return;
                }

                Navigator.pop(ctx);
                ref.read(financeActionProvider.notifier).requestWithdrawal(amount, selectedMethod, phoneController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
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
