import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/notification_bell_widget.dart';
import '../widgets/app_background.dart';
import '../core/theme.dart';

// Import profile components
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/wallet_card.dart';
import '../widgets/profile/profile_menu_item.dart';
import '../widgets/profile/finance_action_card.dart';
import 'transaction_history_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackground(
        child: userAsync.when(
          data: (user) => Column(
            children: [
              // Top massive container holding header and wallet card
              Stack(
                children: [
                  // The secondary stacked card (Finance Actions) hiding under the main container
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: FinanceActionCard(
                      user: user,
                      isLoading: financeAction.isLoading,
                    ),
                  ),
                  
                  // The main massive container on top
                  Container(
                    margin: const EdgeInsets.only(bottom: 50), // Leaves 50px of the finance card exposed at the bottom
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.deepBlueGlow,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF132853), // Slightly lighter deep blue
                          Color(0xFF0B1F4A), // AppTheme.deepBlueGlow
                          Color(0xFF071430), // Slightly darker
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                          // No bottom padding so the card touches the very edge of the clipping mask
                        ),
                        child: Column(
                          children: [
                            // Avatar and Info
                            ProfileHeader(user: user),
                            
                            const SizedBox(height: 12), // Reduced gap
                            
                            // The Wallet Card (Credit Card Style)
                            // Translated down so the bottom 30px gets clipped off by the container's curved border!
                            Transform.translate(
                              offset: const Offset(0, 30),
                              child: WalletCard(
                                user: user,
                                isLoading: financeAction.isLoading,
                                ref: ref,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Menu List below the container
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 16),
                  children: [
                    ProfileMenuItem(
                      icon: Icons.group_add_rounded,
                      title: 'Invite Friends',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: user.referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Referral code copied!'), backgroundColor: AppTheme.primaryCyan)
                        );
                      },
                    ),
                    
                    ProfileMenuItem(
                      icon: Icons.history_rounded,
                      title: 'Transaction History',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                        );
                      },
                    ),
                    
                    ProfileMenuItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support center coming soon!'))
                        );
                      },
                    ),
                    
                    const SizedBox(height: 100), // Space for bottom nav bar
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
          error: (err, stack) => Center(child: Text('Error loading profile: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }
}

