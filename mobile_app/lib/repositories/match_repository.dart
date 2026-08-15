import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_model.dart';
import '../models/category_model.dart';
import '../core/constants.dart';

/// Data Layer: Strictly handles Supabase queries and API calls.
class MatchRepository {
  final SupabaseClient _supabase;

  MatchRepository(this._supabase);

  /// Streams dynamic categories for the tabs
  Stream<List<CategoryModel>> streamCategories() async* {
    while (true) {
      try {
        final data = await _supabase.from('match_categories').select().order('sort_order', ascending: true);
        if (data.isEmpty) {
          // Fallback if RLS or DB is not configured properly
          yield [
            const CategoryModel(id: 1, name: 'BR', sortOrder: 1),
            const CategoryModel(id: 2, name: 'CS', sortOrder: 2),
            const CategoryModel(id: 3, name: 'Lone Wolf', sortOrder: 3),
            const CategoryModel(id: 4, name: 'Tournament', sortOrder: 4),
          ];
        } else {
          yield data.map((map) => CategoryModel.fromJson(map)).toList();
        }
      } catch (_) {
        // Fallback on error
        yield [
          const CategoryModel(id: 1, name: 'BR', sortOrder: 1),
          const CategoryModel(id: 2, name: 'CS', sortOrder: 2),
          const CategoryModel(id: 3, name: 'Lone Wolf', sortOrder: 3),
          const CategoryModel(id: 4, name: 'Tournament', sortOrder: 4),
        ];
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  /// Uses Supabase Streams for Realtime WebSockets updates.
  Stream<List<MatchModel>> streamMatches(String category) async* {
    while (true) {
      final data = await _supabase.from('matches').select().eq('category', category).order('created_at', ascending: false);
      yield data.map((map) => MatchModel.fromJson(map)).toList();
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  /// Streams the list of match IDs the current user has joined
  Stream<List<String>> streamMyJoinedMatchIds(String userId) async* {
    while (true) {
      final data = await _supabase.from('match_participants').select('match_id').eq('user_id', userId);
      yield data.map((map) => map['match_id'] as String).toList();
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  /// Submits match proof (kills, rank, screenshot URL) to the backend
  Future<void> submitMatchResult(String matchId, int kills, int rank, String screenshotUrl, String token) async {
    final res = await http.post(
      Uri.parse('$backendApiUrl/match/submit-result'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'match_id': matchId,
        'kills': kills,
        'rank': rank,
        'screenshot_url': screenshotUrl
      }),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Submission failed');
    }
  }

  /// Calls the Node.js backend to securely join a match
  Future<void> joinMatch(String matchId, String token) async {
    final res = await http.post(
      Uri.parse('$backendApiUrl/match/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'match_id': matchId}),
    );
    
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body)['error'] ?? 'Failed to join match';
      throw Exception(err);
    }
  }

  /// Calls the Node.js backend to report a problem with a match (Dispute)
  Future<void> reportDispute(String matchId, String message, String token) async {
    final res = await http.post(
      Uri.parse('$backendApiUrl/user/disputes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'match_id': matchId,
        'message': message,
      }),
    );
    
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body)['error'] ?? 'Failed to report issue';
      throw Exception(err);
    }
  }
}
