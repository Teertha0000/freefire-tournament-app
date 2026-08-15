import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

// A stream to fetch admin stats and auto-refresh them every 30 seconds
final adminStatsProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final repo = ref.watch(adminRepositoryProvider);
  while (true) {
    yield await repo.getStats();
    await Future.delayed(const Duration(seconds: 30));
  }
});

// Stream provider for fetching active disputes (refreshed manually or periodically)
final adminDisputesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.watch(adminRepositoryProvider).getDisputes();
});

class AdminActionState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  AdminActionState({this.isLoading = false, this.error, this.successMessage});
}

class AdminActionNotifier extends StateNotifier<AdminActionState> {
  final AdminRepository _repository;

  AdminActionNotifier(this._repository) : super(AdminActionState());

  Future<void> approveWithdrawal(String withdrawalId) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.approveWithdrawal(withdrawalId);
      state = AdminActionState(successMessage: 'Withdrawal approved successfully');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> rejectWithdrawal(String withdrawalId, String reason) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.rejectWithdrawal(withdrawalId, reason);
      state = AdminActionState(successMessage: 'Withdrawal rejected and refunded');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> adjustUserBalance(String userId, double amount, String balanceType, String reason) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.adjustUserBalance(userId, amount, balanceType, reason);
      state = AdminActionState(successMessage: 'Balance adjusted successfully');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> createMatch(Map<String, dynamic> matchData) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.createMatch(matchData);
      state = AdminActionState(successMessage: 'Match created successfully');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> updateMatchRoomDetails(String matchId, String roomId, String roomPassword) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.updateMatchRoomDetails(matchId, roomId, roomPassword);
      state = AdminActionState(successMessage: 'Room details updated and players notified');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> markMatchFinished(String matchId, int timerHours) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.markMatchFinished(matchId, timerHours);
      state = AdminActionState(successMessage: 'Match marked as finished');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> reviewMatchResult(String resultId, String action, double prizeAmount, String comment) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.reviewMatchResult(resultId, action, prizeAmount, comment);
      state = AdminActionState(successMessage: 'Result $action successfully');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> autoVerifyMatchResults(String matchId, int actualPlayers) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.autoVerifyMatchResults(matchId, actualPlayers);
      state = AdminActionState(successMessage: 'Smart Verification Complete!');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> closeMatch(String matchId) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.closeMatch(matchId);
      state = AdminActionState(successMessage: 'Match officially closed');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> cancelUpcomingMatch(String matchId, String reason) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.cancelUpcomingMatch(matchId, reason);
      state = AdminActionState(successMessage: 'Match cancelled and entry fees refunded.');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> refundHistoricalMatch(String matchId, String reason) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.refundHistoricalMatch(matchId, reason);
      state = AdminActionState(successMessage: 'Historical match reversed successfully.');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }
  Future<void> resolveDispute(String disputeId, String status, String adminResponse, double prizeCorrection) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.resolveDispute(disputeId, status, adminResponse, prizeCorrection);
      state = AdminActionState(successMessage: 'Dispute resolved successfully.');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }

  Future<void> uploadAdminProof(String matchId, String proofUrl) async {
    state = AdminActionState(isLoading: true);
    try {
      await _repository.uploadAdminProof(matchId, proofUrl);
      state = AdminActionState(successMessage: 'Admin proof uploaded successfully.');
    } catch (e) {
      state = AdminActionState(error: e.toString());
    }
  }
}

final adminActionProvider = StateNotifierProvider<AdminActionNotifier, AdminActionState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminActionNotifier(repo);
});
