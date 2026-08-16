import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../repositories/match_repository.dart';
import '../core/constants.dart';
import '../models/match_model.dart';
import '../models/category_model.dart';
import 'auth_provider.dart'; // Contains supabaseProvider

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(ref.watch(supabaseProvider));
});

// Streams the dynamic tabs (BR, CS, etc) directly from DB
final categoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(matchRepositoryProvider).streamCategories();
});

// Streams ALL matches for the entire app
final allMatchesStreamProvider = StreamProvider<List<MatchModel>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return () async* {
    while (true) {
      final data = await supabase.from('matches').select().order('start_time', ascending: true);
      yield data.map((map) => MatchModel.fromJson(map)).toList();
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

// Streams the IDs of matches the user has joined
final myJoinedMatchIdsProvider = StreamProvider<List<String>>((ref) {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return Stream.value([]);
  return ref.watch(matchRepositoryProvider).streamMyJoinedMatchIds(userId);
});

// Fetches the secure room details for a match (Proxy via Node.js)
final matchSecretsProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, matchId) async* {
  while (true) {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token != null) {
        final res = await http.get(
          Uri.parse('$backendApiUrl/match/$matchId/secrets'),
          headers: {'Authorization': 'Bearer $token', 'Connection': 'close'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          yield data;
        } else {
          yield null; // E.g. Not a participant or not uploaded
        }
      } else {
        yield null;
      }
    } catch (_) {
      yield null;
    }
    await Future.delayed(const Duration(seconds: 3));
  }
});

// Fetches the current user's match result status for a specific match
final userMatchResultProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, matchId) async* {
  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(authProvider).userId;

  if (userId == null) {
    yield null;
    return;
  }

  while (true) {
    try {
      final data = await supabase
          .from('match_results')
          .select('*')
          .eq('match_id', matchId)
          .eq('user_id', userId)
          .maybeSingle();
      yield data;
    } catch (_) {
      yield null;
    }
    await Future.delayed(const Duration(seconds: 3));
  }
});

// Derived Provider: Matches for Home Screen (Filters out joined matches and matches by category)
final homeMatchesProvider = Provider.family<AsyncValue<List<MatchModel>>, String>((ref, category) {
  final allMatches = ref.watch(allMatchesStreamProvider);
  final joinedIds = ref.watch(myJoinedMatchIdsProvider).value ?? [];

  return allMatches.whenData((matches) => matches
      .where((m) => m.category == category && !joinedIds.contains(m.id) && m.status == 'upcoming')
      .toList());
});

// Derived Provider: Matches for "My Matches" Screen
final myMatchesProvider = Provider<AsyncValue<List<MatchModel>>>((ref) {
  final allMatches = ref.watch(allMatchesStreamProvider);
  final joinedIds = ref.watch(myJoinedMatchIdsProvider).value ?? [];

  return allMatches.whenData((matches) => matches
      .where((m) => joinedIds.contains(m.id))
      .toList());
});

// State for match actions (like joining)
class MatchActionState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  const MatchActionState({this.isLoading = false, this.error, this.successMessage});
}

// Logic Layer for actions
class MatchActionNotifier extends StateNotifier<MatchActionState> {
  final MatchRepository _repository;
  final SupabaseClient _supabase;

  MatchActionNotifier(this._repository, this._supabase) : super(const MatchActionState());

  Future<void> joinMatch(String matchId) async {
    state = const MatchActionState(isLoading: true);
      try {
        final token = _supabase.auth.currentSession?.accessToken;
        if (token == null) throw Exception('Authentication token missing. Please log in again.');
        
        await _repository.joinMatch(matchId, token);
      state = const MatchActionState(isLoading: false, successMessage: 'Successfully joined the match!');
    } catch (e) {
      state = MatchActionState(isLoading: false, error: e.toString());
    }
  }

  Future<void> submitProof(String matchId, int kills, int rank, String screenshotUrl) async {
    state = const MatchActionState(isLoading: true);
      try {
        final token = _supabase.auth.currentSession?.accessToken;
        if (token == null) throw Exception('Authentication token missing. Please log in again.');
        
        await _repository.submitMatchResult(matchId, kills, rank, screenshotUrl, token);
      state = const MatchActionState(isLoading: false, successMessage: 'Proof submitted successfully!');
    } catch (e) {
      state = MatchActionState(isLoading: false, error: e.toString());
    }
  }

  Future<void> reportDispute(String matchId, String message) async {
    state = const MatchActionState(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('custom_auth_token');
      if (token == null) throw Exception('Authentication token missing.');
      
      await _repository.reportDispute(matchId, message, token);
      state = const MatchActionState(isLoading: false, successMessage: 'Issue reported successfully! An admin will investigate.');
    } catch (e) {
      state = MatchActionState(isLoading: false, error: e.toString());
    }
  }
}

final matchActionProvider = StateNotifierProvider<MatchActionNotifier, MatchActionState>((ref) {
  return MatchActionNotifier(ref.watch(matchRepositoryProvider), ref.watch(supabaseProvider));
});
