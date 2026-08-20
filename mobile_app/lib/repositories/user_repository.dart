import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../core/constants.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  /// Real-time stream of the user's profile and wallet balances (Proxy via Node.js)
  Stream<UserModel> streamUserProfile(String userId) async* {
    while (true) {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not logged in');
      
      final res = await http.get(
        Uri.parse('$backendApiUrl/user/profile'),
        headers: {'Authorization': 'Bearer $token', 'Connection': 'close'},
      );
      if (res.statusCode == 200) {
        yield UserModel.fromJson(jsonDecode(res.body));
      } else {
        throw Exception('Failed to load profile: ${res.statusCode} ${res.body}');
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  /// Real-time stream of the user's transaction ledger (Proxy via Node.js)
  Stream<List<TransactionModel>> streamTransactions(String userId) async* {
    while (true) {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not logged in');

      final res = await http.get(
        Uri.parse('$backendApiUrl/user/transactions'),
        headers: {'Authorization': 'Bearer $token', 'Connection': 'close'},
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        yield data.map((map) => TransactionModel.fromJson(map)).toList();
      } else {
        throw Exception('Failed to load transactions: ${res.statusCode} ${res.body}');
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  /// API call to update the user profile
  Future<void> updateProfile(String ign, String uid, String phone, String referralCode, String paymentMethod, String avatarId) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not logged in');

    final res = await http.post(
      Uri.parse('$backendApiUrl/user/update-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ign': ign,
        'uid': uid,
        'phone': phone,
        'referral_code': referralCode,
        'payment_method': paymentMethod,
        'avatar_id': avatarId,
      }),
    );
    
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body)['error'] ?? 'Profile update failed';
      throw Exception(err);
    }
  }

  /// Uploads an avatar image to Supabase Storage and returns the public URL
  Future<String> uploadAvatar(File imageFile, String userId) async {
    final fileExt = imageFile.path.split('.').last;
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = 'avatars/$fileName';

    await _supabase.storage.from('avatars').upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
    return publicUrl;
  }

  /// API call to request a withdrawal securely
  Future<void> requestWithdrawal(double amount, String paymentMethod, String phone) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not logged in');

    final res = await http.post(
      Uri.parse('$backendApiUrl/finance/withdraw'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'amount': amount,
        'payment_method': paymentMethod,
        'phone_number': phone,
      }),
    );
    
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body)['error'] ?? 'Withdrawal failed';
      throw Exception(err);
    }
  }

  /// API call to initialize a deposit via Paymently
  Future<Map<String, dynamic>> initializeDeposit(double amount) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not logged in');

    final res = await http.post(
      Uri.parse('$backendApiUrl/finance/deposit/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'amount': amount,
      }),
    );
    
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body)['error'] ?? 'Deposit initialization failed';
      throw Exception(err);
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
