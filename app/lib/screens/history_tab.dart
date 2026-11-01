// HistoryTab - list of past sessions with pull-to-refresh and sync.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/session_provider.dart';
import '../widgets/session_card.dart';
import '../widgets/shimmer_card.dart';

/// History tab - scrollable list of saved swim sessions.
class HistoryTab extends ConsumerStatefulWidget {
  /// Called when "Go to Settings" is tapped in the empty state.
  final VoidCallback? onGoToSettings;

  const HistoryTab({super.key, this.onGoToSettings});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final result = await ref.read(sessionProvider.notifier).sync();
      if (!mounted) return;
      final msg = result.newSessions > 0
          ? '${result.newSessions} new session${result.newSessions == 1 ? '' : 's'} synced!'
          : 'Already up to date.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: SwimTrackTextStyles.body(color: Colors.white)),
        backgroundColor: result.newSessions > 0
            ? SwimTrackColors.good
            : SwimTrackColors.textHint,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sync failed. Try again.',
            style: SwimTrackTextStyles.body(color: Colors.white)),
        backgroundColor: SwimTrackColors.bad,
      ));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: SwimTrackColors.background,
      appBar: AppBar(
        title: Text('History',
            style: SwimTrackTextStyles.screenTitle(color: Colors.white)),
        backgroundColor: SwimTrackColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.sync, color: Colors.white),
            tooltip: 'Sync sessions',
            onPressed: _syncing ? null : _sync,
          ),
        ],
      ),
      body: _buildBody(sessionState),
    );
  }

  Widget _buildBody(SessionState state) {
    if (state.isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const ShimmerCard(),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: SwimTrackColors.bad),
              const SizedBox(height: 16),
              Text(state.error!,
                  style: SwimTrackTextStyles.body(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () =>
                    ref.read(sessionProvider.notifier).loadFromDatabase(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏊', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('No sessions yet',
                  style: SwimTrackTextStyles.screenTitle()),
              const SizedBox(height: 8),
              Text(
                'Connect your device and tap Sync\nto see your sessions here.',
                style: SwimTrackTextStyles.body(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: widget.onGoToSettings,
                  child: const Text('Go to Settings'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: SwimTrackColors.primary,
      onRefresh: _sync,
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: state.sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final session = state.sessions[index];
          return SessionCard(
            session: session,
            onTap: () => context.push('/session/${session.id}'),
          );
        },
      ),
    );
  }
}