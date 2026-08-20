import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../providers/user_provider.dart';
import '../core/theme.dart';
import '../widgets/notification_bell_widget.dart';
import '../widgets/bkash_balance_pill.dart';
import 'category_matches_screen.dart';
import '../widgets/app_background.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Massive Top Container with rounded bottom
            Container(
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
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Row(
                        children: [
                          // Avatar Placeholder
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                              image: const DecorationImage(
                                image: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Felix'), // Placeholder
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Name and Balance
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                userProfileAsync.when(
                                  data: (user) => Text(
                                    user.ign.isEmpty ? 'Player' : user.ign,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textWhite,
                                    ),
                                  ),
                                  loading: () => const SizedBox(height: 16, width: 80, child: LinearProgressIndicator()),
                                  error: (_, __) => const Text('Error', style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(height: 4),
                                userProfileAsync.when(
                                  data: (user) => BkashBalancePill(balance: user.totalBalance),
                                  loading: () => const SizedBox(),
                                  error: (_, __) => const SizedBox(),
                                ),
                              ],
                            ),
                          ),
                          
                          const NotificationBellWidget(),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Hero Banner (Liquid Glass)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryCyan.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(Icons.sports_esports, size: 120, color: Colors.white.withOpacity(0.05)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Mega Tournament',
                                        style: TextStyle(
                                          color: AppTheme.primaryCyan,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Win up to 10,000 Tk\nJoin Now!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
              
              // Categories Section Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Games',
                  style: TextStyle(
                    fontSize: 36, // Increased size significantly
                    fontWeight: FontWeight.w900, // Extra bold
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // Categories Horizontal Scroll
              Expanded(
                child: categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) return const Center(child: Text('No categories available.'));
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _buildCategoryCard(context, category.name);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Failed to load categories: $err')),
                ),
              ),
              
              const SizedBox(height: 100), // Space for floating nav bar
            ],
          ),
        ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CategoryMatchesScreen(categoryName: title)),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.gamepad_rounded,
                      color: AppTheme.primaryCyan,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to view matches',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// DynamicTabsWrapper is removed as we no longer use Tabs.

