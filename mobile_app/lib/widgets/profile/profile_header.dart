import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../core/theme.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/edit_profile_screen.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          // Clean Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceGrey,
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              image: DecorationImage(
                image: NetworkImage(
                  user.avatarId.startsWith('http') 
                    ? user.avatarId 
                    : 'https://api.dicebear.com/7.x/avataaars/png?seed=${user.ign.isEmpty ? 'Player' : user.ign}&backgroundColor=b6e3f4,c0aede,d1d4f9'
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.ign.isEmpty ? 'Player' : user.ign,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'UID: ${user.uid}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          
          // Edit Profile Button
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
              );
            },
            tooltip: 'Edit Profile',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          
          if (user.role == 'admin') const SizedBox(width: 8),
          
          // Admin Dashboard Button (Only visible to admins)
          if (user.role == 'admin')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryCyan),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
              },
              tooltip: 'Admin Dashboard',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan.withOpacity(0.1),
              ),
            ),
        ],
      ),
    );
  }
}

