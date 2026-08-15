import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class AdminRepository {
  // Use dotenv to read the ADMIN_API_URL instead of hardcoding
  String get _baseUrl => dotenv.env['ADMIN_API_URL'] ?? 'http://localhost:3001/admin';

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('custom_auth_token');
    if (token == null || token.isEmpty) throw Exception('Not logged in');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getStats() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/stats'), headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load stats: ${response.body}');
    }
  }

  Future<void> approveWithdrawal(String withdrawalId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/withdrawals/approve'),
      headers: headers,
      body: json.encode({'withdrawal_id': withdrawalId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to approve withdrawal: ${response.body}');
    }
  }

  Future<void> rejectWithdrawal(String withdrawalId, String reason) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/withdrawals/reject'),
      headers: headers,
      body: json.encode({'withdrawal_id': withdrawalId, 'reason': reason}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reject withdrawal: ${response.body}');
    }
  }

  Future<void> adjustUserBalance(String userId, double amount, String balanceType, String reason) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/users/adjust-balance'),
      headers: headers,
      body: json.encode({
        'user_id': userId,
        'amount': amount,
        'balance_type': balanceType,
        'reason': reason,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to adjust balance: ${response.body}');
    }
  }

  Future<void> createMatch(Map<String, dynamic> matchData) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/create'),
      headers: headers,
      body: json.encode(matchData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create match: ${response.body}');
    }
  }

  Future<void> updateMatchRoomDetails(String matchId, String roomId, String roomPassword) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/update-room'),
      headers: headers,
      body: json.encode({
        'match_id': matchId,
        'room_id': roomId,
        'room_password': roomPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update room details: ${response.body}');
    }
  }

  Future<void> markMatchFinished(String matchId, int timerHours) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/mark-finished'),
      headers: headers,
      body: json.encode({'match_id': matchId, 'timer_hours': timerHours}),
    );

    if (response.statusCode != 200) throw Exception('Failed: ${response.body}');
  }

  Future<void> reviewMatchResult(String resultId, String action, double prizeAmount, String comment) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/review-result'),
      headers: headers,
      body: json.encode({
        'result_id': resultId,
        'action': action,
        'prize_amount': prizeAmount,
        'comment': comment,
      }),
    );

    if (response.statusCode != 200) throw Exception('Failed: ${response.body}');
  }

  Future<void> autoVerifyMatchResults(String matchId, int actualPlayers) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/auto-verify'),
      headers: headers,
      body: json.encode({'match_id': matchId, 'actual_players': actualPlayers}),
    );

    if (response.statusCode != 200) {
      final errorMsg = json.decode(response.body)['error'] ?? response.body;
      throw Exception(errorMsg);
    }
  }

  Future<void> closeMatch(String matchId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/close'),
      headers: headers,
      body: json.encode({'match_id': matchId}),
    );

    if (response.statusCode != 200) throw Exception('Failed: ${response.body}');
  }

  Future<void> cancelUpcomingMatch(String matchId, String reason) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/cancel-upcoming'),
      headers: headers,
      body: json.encode({'match_id': matchId, 'reason': reason}),
    );

    if (response.statusCode != 200) throw Exception('Failed: ${response.body}');
  }

  Future<void> refundHistoricalMatch(String matchId, String reason) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/refund-historical'),
      headers: headers,
      body: json.encode({'match_id': matchId, 'reason': reason}),
    );

    if (response.statusCode != 200) throw Exception('Failed: ${response.body}');
  }

  Future<List<dynamic>> getDisputes() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/disputes'), headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load disputes: ${response.body}');
    }
  }

  Future<void> resolveDispute(String disputeId, String status, String adminResponse, double prizeCorrection) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/disputes/resolve'),
      headers: headers,
      body: json.encode({
        'dispute_id': disputeId,
        'status': status,
        'admin_response': adminResponse,
        'prize_correction': prizeCorrection,
      }),
    );

    if (response.statusCode != 200) throw Exception('Failed to resolve dispute: ${response.body}');
  }

  Future<void> uploadAdminProof(String matchId, String proofUrl) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/matches/admin-proof'),
      headers: headers,
      body: json.encode({
        'match_id': matchId,
        'proof_url': proofUrl,
      }),
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'];
      throw Exception(error ?? 'Failed to upload admin proof');
    }
  }
}
