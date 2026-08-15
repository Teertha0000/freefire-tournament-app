import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));

enum AuthMode { login, registerDetails, forgotPassword }

class AuthState {
  final bool isLoading;
  final String? error;
  final AuthMode mode;
  final bool isAuthenticated;
  final String? message;
  final String? userId;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.mode = AuthMode.login,
    this.isAuthenticated = false,
    this.message,
    this.userId,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    AuthMode? mode,
    bool? isAuthenticated,
    String? message,
    String? userId,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // nullable
      mode: mode ?? this.mode,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      message: message, // nullable
      userId: userId ?? this.userId,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final SupabaseClient _supabase;

  AuthNotifier(this._repository, this._supabase) : super(const AuthState()) {
    _init();
  }

  void _init() {
    // Listen to Supabase Auth state changes automatically!
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = state.copyWith(isAuthenticated: true, userId: session.user.id);
      } else {
        state = state.copyWith(isAuthenticated: false, userId: null);
      }
    });
  }

  void switchMode(AuthMode mode) {
    state = state.copyWith(mode: mode, error: null, message: null);
  }

  Future<void> register(String email, String password, String ign, String uid) async {
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      await _repository.registerWithEmail(email, password, ign, uid);
      state = state.copyWith(isLoading: false, message: 'Registration successful! Check your email to verify (if enabled).');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.loginWithEmail(email, password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signInWithGoogle();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginWithFacebook() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signInWithFacebook();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(isLoading: false, message: 'Password reset link sent to your email.');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _repository.logout();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref.watch(supabaseProvider));
});
