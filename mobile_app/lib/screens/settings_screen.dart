import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_background.dart';
import '../core/theme.dart';
import '../widgets/profile/profile_menu_item.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  children: [
                    // Account Settings
                    _buildSectionHeader('Account'),
                    ProfileMenuItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit profile coming soon!')),
                        );
                      },
                    ),
                    ProfileMenuItem(
                      icon: Icons.security_rounded,
                      title: 'Security & Password',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      onTap: () {},
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // App Preferences
                    _buildSectionHeader('Preferences'),
                    ProfileMenuItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      trailing: Switch(
                        value: true,
                        onChanged: (val) {},
                        activeColor: AppTheme.primaryCyan,
                        activeTrackColor: AppTheme.primaryCyan.withOpacity(0.3),
                      ),
                      onTap: () {},
                    ),
                    ProfileMenuItem(
                      icon: Icons.language_rounded,
                      title: 'Language',
                      trailing: const Text('English', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      onTap: () {},
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Support & About
                    _buildSectionHeader('Support'),
                    ProfileMenuItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help Center',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      onTap: () {},
                    ),
                    ProfileMenuItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About App',
                      trailing: const Text('v1.0.0', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      onTap: () {},
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Logout
                    ProfileMenuItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      isDestructive: true,
                      onTap: () => ref.read(authProvider.notifier).logout(),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryCyan,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
