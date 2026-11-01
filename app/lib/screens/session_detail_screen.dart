// SessionDetailScreen - shows full metrics, SWOLF chart, and lap table for one session.

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import '../services/database_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/swolf_chart.dart';
import '../widgets/lap_table.dart';

/// Session detail screen - full breakdown of a single swim session.
class SessionDetailScreen extends ConsumerStatefulWidget {
  /// The session ID passed via GoRouter path parameter ':id'.
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Session?  _session;
  bool      _loading   = true;
  String?   _error;
  bool      _showDeleteDialog = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      // First try to find it in the provider (already loaded)
      final sessions = ref.read(sessionProvider).sessions;
      var found = sessions.where((s) => s.id == widget.sessionId).firstOrNull;

      // If not in provider list (e.g. navigated directly), load from DB
      if (found == null) {
        await DatabaseService.instance.initDatabase();
        found = await DatabaseService.instance.getSession(widget.sessionId);
      }

      setState(() {
        _session = found;
        _loading  = false;
        _error    = found == null ? 'Session not found.' : null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error   = 'Could not load session. Please try again.';
      });
      debugPrint('SessionDetail: load error → $e');
    }
  }

  Future<void> _deleteSession() async {
    try {
      await ref.read(sessionProvider.notifier).deleteSession(widget.sessionId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete session.',
                style: SwimTrackTextStyles.body(color: Colors.white)),
            backgroundColor: SwimTrackColors.bad,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwimTrackColors.background,
      appBar: AppBar(
        title: Text(
          _session != null
              ? DateFormat('EEE, MMM d').format(_session!.startTime)
              : 'Session',
          style: SwimTrackTextStyles.screenTitle(color: Colors.white),
        ),
        backgroundColor: SwimTrackColors.primary,
        elevation: 0,
        actions: [
          if (_session != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: SwimTrackColors.bad),
              tooltip: 'Delete session',
              onPressed: () => setState(() => _showDeleteDialog = true),
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_showDeleteDialog) _buildDeleteDialog(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SwimTrackColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: SwimTrackColors.bad),
              const SizedBox(height: 16),
              Text(_error!,
                  style: SwimTrackTextStyles.body(),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final s = _session!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header info row ──────────────────────────────────────────────
          _buildHeaderRow(s),
          const SizedBox(height: 20),

          // ── 2×2 metrics grid ─────────────────────────────────────────────
          _buildMetricsGrid(s),
          const SizedBox(height: 28),

          // ── SWOLF chart ──────────────────────────────────────────────────
          if (s.laps.isNotEmpty) ...[
            Text('SWOLF per Lap',
                style: SwimTrackTextStyles.sectionHeader()),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: SwimTrackColors.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: SwolfChart(laps: s.laps, height: 200),
            ),
            const SizedBox(height: 28),

            // ── Lap breakdown table ────────────────────────────────────────
            Text('Lap Breakdown',
                style: SwimTrackTextStyles.sectionHeader()),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: SwimTrackColors.card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LapTable(laps: s.laps, avgSwolf: s.avgSwolf),
            ),
          ],

          if (s.laps.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No lap data recorded for this session.',
                  style: SwimTrackTextStyles.body(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(Session s) {
    return Row(
      children: [
        _InfoItem(
            value: '${s.totalDistanceM}m', label: 'Distance'),
        _InfoItem(
            value: _formatDuration(s.durationSec), label: 'Duration'),
        _InfoItem(
            value: '${s.poolLengthM}m', label: 'Pool'),
        _InfoItem(
            value: '${s.lapCount}', label: 'Laps'),
      ],
    );
  }

  Widget _buildMetricsGrid(Session s) {
    final restSec = s.totalRestSec;
    final restLabel = restSec > 0
        ? '${restSec.toStringAsFixed(0)}s'
        : '-';

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        MetricCard(
            value: s.avgSwolf.toStringAsFixed(1),
            label: 'Avg SWOLF',
            valueColor: SwimTrackColors.primary),
        MetricCard(
            value: '${s.avgStrokeRate.toStringAsFixed(0)} spm',
            label: 'Avg Rate'),
        MetricCard(
            value: s.laps.fold(0, (sum, l) => sum + l.strokeCount).toString(),
            label: 'Total Strokes'),
        MetricCard(
            value: restLabel,
            label: 'Rest Time'),
        MetricCard(
            value: s.avgDps > 0
                ? '${s.avgDps.toStringAsFixed(2)}m'
                : '-',
            label: 'Avg DPS',
            valueColor: SwimTrackColors.secondary),
      ],
    );
  }

  Widget _buildDeleteDialog() {
    return GestureDetector(
      onTap: () => setState(() => _showDeleteDialog = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent tap-through
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: SwimTrackColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete Session?',
                      style: SwimTrackTextStyles.sectionHeader()),
                  const SizedBox(height: 12),
                  Text(
                    'This action cannot be undone. Your session data will be permanently deleted.',
                    style: SwimTrackTextStyles.body(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _showDeleteDialog = false),
                        child: Text('Cancel',
                            style: SwimTrackTextStyles.body(
                                color: SwimTrackColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _deleteSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SwimTrackColors.bad,
                          minimumSize: const Size(80, 40),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Delete',
                            style: SwimTrackTextStyles.body(
                                color: Colors.white)
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// A single header info item: large value + small label.
class _InfoItem extends StatelessWidget {
  final String value;
  final String label;

  const _InfoItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: SwimTrackTextStyles.cardTitle(color: SwimTrackColors.dark),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: SwimTrackTextStyles.tiny(),
          ),
        ],
      ),
    );
  }
}