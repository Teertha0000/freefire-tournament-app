import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../../screens/deposit_screen.dart' as deposit_ui;

class WalletCard extends StatelessWidget {
  final UserModel user;
  final bool isLoading;
  final WidgetRef ref;

  const WalletCard({
    super.key,
    required this.user,
    required this.isLoading,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The Physical Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          height: 225, // Adjusted height to accommodate 40px bottom padding
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF101010), // Deep absolute black
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.5),
            child: Stack(
              children: [
                // The Glowing Mesh Gradient (Top Right)
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFE8F845), // Vibrant yellow/green core
                          Color(0xFF45F882), // Neon green edge
                          Color(0xFF00FFCC), // Cyan outer edge
                          Colors.transparent,
                        ],
                        stops: [0.1, 0.4, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // Frosted Glass Blur over the glow to make it diffuse seamlessly
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                // Top Right Branding
                const Positioned(
                  top: 24,
                  right: 24,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.white, size: 24), // Solid bolt shape
                      SizedBox(width: 0), // Removed manual spacing completely
                      Text(
                        'PlayRift',
                        style: TextStyle(
                          fontFamily: 'Bellota',
                          fontSize: 20,
                          fontWeight: FontWeight.w900, // Maximum boldness
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Card Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end, // Push content to bottom left
                    children: [
                      const Text(
                        'Balance',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BDT ${user.totalBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      
                      // Conditional Bonus Display
                      if (user.bonusBalance > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.greenAccent, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Includes BDT ${user.bonusBalance.toStringAsFixed(2)} Bonus',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 24), // Space before the "card number"
                      
                      // Phone Number formatted as Card Number
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            user.paymentMethod,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatPhoneAsCard(user.phone),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              letterSpacing: 2.0,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatPhoneAsCard(String phone) {
    if (phone.length == 11) {
      // Format 11-digit BD number like 0171 2345 678
      return '${phone.substring(0, 4)} ${phone.substring(4, 8)} ${phone.substring(8)}';
    } else if (phone.length > 4) {
      // Just add some spaces for generic long numbers
      return phone.replaceAllMapped(RegExp(r".{4}"), (match) => "${match.group(0)} ");
    }
    return phone;
  }
}
