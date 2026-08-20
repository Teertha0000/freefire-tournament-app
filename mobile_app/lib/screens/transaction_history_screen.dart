import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../models/transaction_model.dart';
import '../core/theme.dart';
import '../widgets/app_background.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: AppBackground(
        child: txAsync.when(
          data: (transactions) => RefreshIndicator(
            color: AppTheme.primaryCyan,
            backgroundColor: AppTheme.surfaceGrey,
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(transactionsProvider);
            },
            child: transactions.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + kToolbarHeight + 24,
                      bottom: 40,
                    ),
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.white.withOpacity(0.05),
                      height: 1,
                      indent: 64,
                    ),
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      return _buildTransactionItem(tx);
                    },
                  ),
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
          error: (err, stack) => Center(child: Text('Failed to load history: $err', style: const TextStyle(color: Colors.redAccent))),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text(
                  'No transactions yet.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(TransactionModel tx) {
    final isPositive = tx.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Minimalist Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPositive ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPositive ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isPositive ? Colors.greenAccent : Colors.redAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          
          // Description & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? tx.type.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(tx.createdAt),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // Amount
          Text(
            '${isPositive ? '+' : ''}৳ ${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isPositive ? Colors.greenAccent : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
