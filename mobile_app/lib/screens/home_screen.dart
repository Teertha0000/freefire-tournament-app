import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../widgets/countdown_timer_widget.dart';
import '../widgets/notification_bell_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to the live stream of categories from the database
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        actions: const [NotificationBellWidget()],
        // Only show tabs if we have data
        bottom: categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) return const PreferredSize(preferredSize: Size.zero, child: SizedBox());
            return TabBar(
              isScrollable: true,
              tabs: categories.map((c) => Tab(text: c.name)).toList(),
            );
          },
          loading: () => const PreferredSize(preferredSize: Size.zero, child: LinearProgressIndicator()),
          error: (_, __) => const PreferredSize(preferredSize: Size.zero, child: SizedBox()),
        ),
      ),
      body: Column(
        children: [
          // Dynamic Banner Placeholder
          Container(
            height: 120,
            width: double.infinity,
            color: Colors.blueGrey,
            alignment: Alignment.center,
            child: const Text('APP BANNER (Image Slider Here)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          
          // Tab Views filtering by dynamic category
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) return const Center(child: Text('No categories available.'));
                return TabBarView(
                  children: categories.map((c) => MatchListWidget(category: c.name)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Failed to load categories: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

// Wrap HomeScreen in DefaultTabController
class DynamicTabsWrapper extends ConsumerWidget {
  const DynamicTabsWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    
    return categoriesAsync.when(
      data: (categories) => DefaultTabController(
        key: ValueKey(categories.length),
        length: categories.length,
        child: const HomeScreen(),
      ),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class MatchListWidget extends ConsumerWidget {
  final String category;
  
  const MatchListWidget({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for Action results (Success or Error)
    ref.listen<MatchActionState>(matchActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
      }
    });

    // Watches the live stream from Supabase, EXCLUDING matches the user has already joined
    final matchesAsync = ref.watch(homeMatchesProvider(category));
    final actionState = ref.watch(matchActionProvider);

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return Center(child: Text('No $category matches available right now.'));
        }
        
        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ListTile(
                title: Text(match.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entry: ${match.entryFee} Tk | Prize: ${match.prizePool} Tk'),
                    Text('Spots: ${match.filledSpots}/${match.totalSpots} Filled'),
                    if (match.startTime != null)
                      CountdownTimerWidget(targetTime: match.startTime!),
                  ],
                ),
                isThreeLine: true,
                trailing: ElevatedButton(
                  onPressed: (match.status == 'upcoming' && !actionState.isLoading) 
                      ? () => _showJoinDialog(context, ref, match)
                      : null,
                  child: actionState.isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : Text(match.status.toUpperCase()),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref, match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Match'),
        content: Text('Entry fee is ${match.entryFee} Tk.\nThis will be deducted from your wallet.\n\nDo you want to proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(matchActionProvider.notifier).joinMatch(match.id);
            },
            child: const Text('Confirm'),
          )
        ]
      )
    );
  }
}
