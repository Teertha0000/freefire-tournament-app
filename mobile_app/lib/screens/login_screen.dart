import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme.dart';
import '../widgets/app_background.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2), // Pushes the content further down
                
                // Center Brand and Title with subtle glow
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryCyan.withOpacity(0.15),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/BrandMark-Photoroom.png',
                          height: 120, // Smaller logo size
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'PlayRift',
                        style: TextStyle(
                          fontFamily: 'Bellota',
                          fontSize: 48, // Smaller text size
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textWhite,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Subtitle
                Center(
                  child: Text(
                    'Your ultimate esports arena.\nCompete, conquer, and earn rewards.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textMuted.withOpacity(0.7),
                      height: 1.4,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 48),

                // Premium Google Login Button (Reverted to Dark)
                GestureDetector(
                  onTap: state.isLoading ? null : () => notifier.loginWithGoogle(),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212), // Pitch dark button
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (state.isLoading)
                          const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        else ...[
                          Image.asset('assets/images/google_logo.png', height: 24, width: 24),
                          const SizedBox(width: 12),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Footer
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted.withOpacity(0.5),
                        height: 1.5,
                      ),
                      children: const [
                        TextSpan(text: 'By continuing, you confirm you are 18+ and agree to our\n'),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

