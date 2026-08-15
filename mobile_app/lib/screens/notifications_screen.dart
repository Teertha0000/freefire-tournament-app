import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              final userId = ref.read(authProvider).userId;
              if (userId != null) {
                ref.read(notificationActionProvider).markAllAsRead(userId);
              }
            },
          )
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) return const Center(child: Text('No notifications right now.'));
          
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                tileColor: notif.isRead ? null : Colors.blue.withOpacity(0.1),
                leading: Icon(
                  notif.isRead ? Icons.notifications_none : Icons.notifications_active,
                  color: notif.isRead ? Colors.grey : Colors.blue,
                ),
                title: Text(notif.title, style: TextStyle(fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(notif.message),
                trailing: Text(
                  notif.createdAt.toLocal().toString().split('.')[0],
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                onTap: () {
                  if (!notif.isRead) {
                    ref.read(notificationActionProvider).markAsRead(notif.id);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
