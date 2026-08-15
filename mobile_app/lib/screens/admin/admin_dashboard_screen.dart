import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';
import 'admin_users_screen.dart';
import 'admin_matches_screen.dart';
import 'admin_withdrawals_screen.dart';
import 'admin_refunds_screen.dart';
import 'admin_disputes_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard (Logic)'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(adminStatsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Stats Data Layer
            const Text('Live Statistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            statsAsync.when(
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Users: ${stats['totalUsers']}'),
                  Text('Active Matches: ${stats['activeMatches']}'),
                  Text('Total Revenue: ${stats['totalRevenue']} Tk'),
                  Text('Pending Withdrawals: ${stats['pendingWithdrawalsCount']}'),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: $err'),
            ),
            const Divider(height: 32),

            // 2. Navigation Actions
            const Text('Management Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMatchesScreen())),
              child: const Text('Manage Matches'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWithdrawalsScreen())),
              child: const Text('Manage Withdrawals'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
              child: const Text('Manage Users'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDisputesScreen())),
              child: const Text('Dispute Investigation', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRefundsScreen())),
              child: const Text('Refunds & Cancellations Hub', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
