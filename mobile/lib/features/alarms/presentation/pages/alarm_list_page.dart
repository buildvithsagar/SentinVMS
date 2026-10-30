import 'package:app/core/core.dart';
import 'package:app/features/alarms/alarms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class AlarmListPage extends StatelessWidget {
  const AlarmListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const VmsDrawer(currentRoute: '/alarms'),
      appBar: AppBar(
        title: const VmsPageTitle(
          title: 'Alarms',
          subtitle: 'Review and acknowledge incidents',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh alarms',
            onPressed: () => context.read<AlarmBloc>().add(const FetchAlarms()),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocConsumer<AlarmBloc, AlarmState>(
        listener: (context, state) {
          if (state is AlarmError) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text('Alarm action failed: ${state.message}'),
                  backgroundColor: VmsColors.danger,
                ),
              );
          }
        },
        builder: (context, state) {
          if (state is AlarmLoading || state is AlarmInitial) {
            return const VmsLoadingView(label: 'Loading alarms...');
          }
          if (state is AlarmError) {
            return VmsStateView.error(
              title: 'Could not load alarms',
              message: '${state.message}\nCheck the control-plane connection.',
              onRetry: () => context.read<AlarmBloc>().add(const FetchAlarms()),
            );
          }
          if (state is! AlarmLoaded) return const SizedBox.shrink();
          if (state.alarms.isEmpty) {
            return VmsStateView.empty(
              icon: Icons.notifications_off_outlined,
              title: 'No alarm events',
              message: 'New camera incidents will appear here in real time.',
              actionLabel: 'Refresh',
              onAction: () =>
                  context.read<AlarmBloc>().add(const FetchAlarms()),
            );
          }

          final activeCount = state.alarms
              .where((alarm) => alarm.isActive)
              .length;
          final resolvedCount = state.alarms.length - activeCount;
          return RefreshIndicator(
            onRefresh: () async {
              context.read<AlarmBloc>().add(const FetchAlarms());
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Row(
                      children: [
                        VmsStatusBadge(
                          label: '$activeCount ACTIVE',
                          color: activeCount > 0
                              ? VmsColors.danger
                              : VmsColors.success,
                          icon: activeCount > 0
                              ? Icons.warning_amber_rounded
                              : Icons.verified_outlined,
                        ),
                        const SizedBox(width: 8),
                        VmsStatusBadge(
                          label: '$resolvedCount RESOLVED',
                          color: VmsColors.textSecondary,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverList.separated(
                    itemCount: state.alarms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _AlarmCard(alarm: state.alarms[index]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const VmsNavigationBar(currentRoute: '/alarms'),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.alarm});

  final Alarm alarm;

  @override
  Widget build(BuildContext context) {
    final active = alarm.isActive;
    final color = active ? VmsColors.danger : VmsColors.success;
    return VmsSurfaceCard(
      key: Key('alarmCard_${alarm.id}'),
      semanticLabel:
          '${alarm.eventClass} alarm from ${alarm.cameraName}, ${active ? 'active' : 'resolved'}',
      onTap: () => _showDetails(context),
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Container(width: 4, height: 86, color: color),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(VmsRadii.sm),
            ),
            child: Icon(_eventIcon(alarm.eventClass), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _readableEvent(alarm.eventClass),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    VmsStatusBadge(
                      label: active ? 'ACTIVE' : 'RESOLVED',
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  alarm.cameraName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  DateFormat('dd MMM · HH:mm:ss').format(alarm.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: VmsColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final active = alarm.isActive;
    final color = active ? VmsColors.danger : VmsColors.success;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<AlarmBloc>(),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: VmsPageTitle(
                      title: _readableEvent(alarm.eventClass),
                      subtitle: alarm.cameraName,
                    ),
                  ),
                  VmsStatusBadge(
                    label: active ? 'ACTIVE' : 'RESOLVED',
                    color: color,
                    icon: active
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              VmsSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Detected',
                      value: DateFormat(
                        'dd MMM yyyy, HH:mm:ss',
                      ).format(alarm.timestamp),
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Incident ID',
                      value: alarm.id,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(VmsRadii.md),
                  border: Border.all(color: VmsColors.border),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: VmsColors.textMuted,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Snapshot not provided for this event',
                      style: TextStyle(color: VmsColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (active)
                FilledButton.icon(
                  key: const Key('modalAcknowledgeButton'),
                  onPressed: () {
                    context.read<AlarmBloc>().add(
                      AlarmAcknowledged(alarmId: alarm.id),
                    );
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ACKNOWLEDGE INCIDENT'),
                )
              else
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('INCIDENT ACKNOWLEDGED'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _readableEvent(String value) {
    final normalized = value.replaceAll('_', ' ').trim().toLowerCase();
    if (normalized.isEmpty) return 'Camera event';
    return normalized
        .split(' ')
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static IconData _eventIcon(String eventClass) {
    return switch (eventClass.toUpperCase()) {
      'INTRUSION' => Icons.warning_amber_rounded,
      'FIRE' => Icons.local_fire_department_rounded,
      'LOITERING' => Icons.directions_walk_rounded,
      'VANDALISM' => Icons.broken_image_outlined,
      _ => Icons.notifications_active_outlined,
    };
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: VmsColors.textSecondary, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: VmsColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
