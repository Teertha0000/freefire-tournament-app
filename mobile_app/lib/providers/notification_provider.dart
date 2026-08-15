import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';

final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return const Stream.empty();

  final userId = authState.userId;
  if (userId == null) return const Stream.empty();

  return () async* {
    while (true) {
      final data = await Supabase.instance.client.from('notifications').select().eq('user_id', userId).order('created_at', ascending: false);
      yield data.map((json) => NotificationModel.fromJson(json)).toList();
      await Future.delayed(const Duration(seconds: 10));
    }
  }();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final asyncNotifications = ref.watch(notificationsStreamProvider);
  return asyncNotifications.when(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final notificationActionProvider = Provider((ref) => NotificationAction(Supabase.instance.client));

class NotificationAction {
  final SupabaseClient _supabase;

  NotificationAction(this._supabase);

  Future<void> markAsRead(String notificationId) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('user_id', userId);
  }
}
