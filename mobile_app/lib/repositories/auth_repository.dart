import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Helper to determine if we are on Mobile natively (Android/iOS)
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // ==============================
  // 1. EMAIL/PASSWORD LOGIN
  // ==============================
  Future<void> registerWithEmail(String email, String password, String ign, String uid) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user != null) {
        // Automatically insert into public.users since trigger handles it, but we need to update ign/uid
        await _supabase.from('users').update({
          'ign': ign,
          'uid': uid,
        }).eq('id', res.user!.id);
      }
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Registration failed: $e');
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  // ==============================
  // 2. GOOGLE LOGIN
  // ==============================
  Future<void> signInWithGoogle() async {
    try {
      if (_isMobile) {
        // Native Google Sign-In (Android/iOS)
        const webClientId = '854863582443-cgv23dnu4mvg1aupsjs6biephi5t7t32.apps.googleusercontent.com';
        
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: webClientId,
        );
        
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw AuthException('Sign-in cancelled by user');
        }
        
        final googleAuth = await googleUser.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        if (accessToken == null || idToken == null) {
          throw AuthException('Failed to get authentication tokens from Google');
        }

        await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      } else {
        // Web / Desktop Fallback
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'io.supabase.flutter://callback',
        );
      }
    } catch (e) {
      throw AuthException('Google Sign-In failed: $e');
    }
  }

  // ==============================
  // 3. FACEBOOK LOGIN
  // ==============================
  Future<void> signInWithFacebook() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: _isMobile ? 'io.supabase.flutter://callback' : null,
      );
    } catch (e) {
      throw AuthException('Facebook Sign-In failed: $e');
    }
  }

  // ==============================
  // 4. PASSWORD RESET
  // ==============================
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw AuthException('Failed to send reset email: $e');
    }
  }

  Future<void> logout() async {
    try {
      if (_isMobile) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
    } catch (_) {
      // Ignore errors if they didn't log in with Google
    }
    await _supabase.auth.signOut();
  }
}

