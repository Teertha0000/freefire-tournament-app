import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/auth_provider.dart';
import 'screens/complete_profile_screen.dart';
import 'providers/user_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock screen orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  await dotenv.load(fileName: ".env");


  // Initialize Supabase for Native Auth & Database Reads
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Wrap the app in ProviderScope for Riverpod state management
  runApp(const ProviderScope(child: FreeFireTournamentApp()));
}

class FreeFireTournamentApp extends StatelessWidget {
  const FreeFireTournamentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayRift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

/// Automagically routes the user based on their authentication state.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      // Fetch user profile data to check if onboarding is complete
      final userProfileAsync = ref.watch(userProfileProvider);

      return userProfileAsync.when(
        data: (user) {
          // If IGN or Phone is missing, force them to the Complete Profile Screen
          if (user.ign.isEmpty || user.phone.isEmpty) {
            return const CompleteProfileScreen();
          }
          // Otherwise, they are fully onboarded, go to the main app!
          return const MainNavigation();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Colors.yellow),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Text('Error loading profile: $err', style: const TextStyle(color: Colors.red)),
          ),
        ),
      );
    }
    
    return const LoginScreen();
  }
}
