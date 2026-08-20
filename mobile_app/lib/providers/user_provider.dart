import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/user_repository.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import 'auth_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseProvider));
});

// Live Profile Data Stream
final userProfileProvider = StreamProvider<UserModel>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final authState = ref.watch(authProvider);
  if (authState.userId == null) throw Exception('Not logged in');
  
  return ref.watch(userRepositoryProvider).streamUserProfile(authState.userId!);
});

// Live Transaction Ledger Stream
final transactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final authState = ref.watch(authProvider);
  if (authState.userId == null) return Stream.value([]);
  
  return ref.watch(userRepositoryProvider).streamTransactions(authState.userId!);
});

// Logic Layer for Withdrawal Actions
class FinanceActionState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  const FinanceActionState({this.isLoading = false, this.error, this.successMessage});
}

class FinanceActionNotifier extends StateNotifier<FinanceActionState> {
  final UserRepository _repository;
  FinanceActionNotifier(this._repository) : super(const FinanceActionState());

  Future<void> requestWithdrawal(double amount, String paymentMethod, String phone) async {
    state = const FinanceActionState(isLoading: true);
    try {
      await _repository.requestWithdrawal(amount, paymentMethod, phone);
      state = const FinanceActionState(isLoading: false, successMessage: 'Withdrawal request submitted!');
    } catch (e) {
      state = FinanceActionState(isLoading: false, error: e.toString());
    }
  }
}

final financeActionProvider = StateNotifierProvider<FinanceActionNotifier, FinanceActionState>((ref) {
  return FinanceActionNotifier(ref.watch(userRepositoryProvider));
});

// Logic Layer for Profile Update Action
class ProfileUpdateState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  const ProfileUpdateState({this.isLoading = false, this.error, this.successMessage});
}

class ProfileUpdateNotifier extends StateNotifier<ProfileUpdateState> {
  final UserRepository _repository;
  ProfileUpdateNotifier(this._repository) : super(const ProfileUpdateState());

  Future<void> updateProfile(String userId, String ign, String uid, String phone, String referralCode, String paymentMethod, String currentAvatarId, {File? newAvatarFile}) async {
    state = const ProfileUpdateState(isLoading: true);
    try {
      String finalAvatarId = currentAvatarId;
      
      // If a new local image was selected, upload it first
      if (newAvatarFile != null) {
        finalAvatarId = await _repository.uploadAvatar(newAvatarFile, userId);
      }
      
      await _repository.updateProfile(ign, uid, phone, referralCode, paymentMethod, finalAvatarId);
      state = const ProfileUpdateState(isLoading: false, successMessage: 'Profile updated successfully!');
    } catch (e) {
      state = ProfileUpdateState(isLoading: false, error: e.toString());
    }
  }
}

final profileUpdateProvider = StateNotifierProvider<ProfileUpdateNotifier, ProfileUpdateState>((ref) {
  return ProfileUpdateNotifier(ref.watch(userRepositoryProvider));
});
