import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../core/theme.dart';
import '../widgets/match_card.dart';
import '../widgets/app_background.dart';

class CategoryMatchesScreen extends ConsumerWidget {
  final String categoryName;

  const CategoryMatchesScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for Action results (Success or Error)
    ref.listen<MatchActionState>(matchActionProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.redAccent));
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
      }
    });

    final matchesAsync = ref.watch(homeMatchesProvider(categoryName));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          categoryName.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: matchesAsync.when(
            data: (matches) {
              if (matches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sports_esports, size: 64, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No upcoming matches for\n$categoryName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 40),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  return MatchCard(match: matches[index]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          ),
        ),
      ),
    );
  }
}
