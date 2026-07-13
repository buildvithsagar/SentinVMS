import 'package:app/features/alarms/bloc/alarm_bloc.dart';
import 'package:app/features/alarms/bloc/alarm_event.dart';
import 'package:app/features/alarms/bloc/alarm_state.dart';
import 'package:app/features/alarms/models/alarm_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Alarm list page that displays AI-triggered alarm events with
/// acknowledge functionality via BLoC.
class AlarmListPage extends StatelessWidget {
  const AlarmListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8)),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/live_grid');
            }
          },
        ),
        title: const Text(
          'Alarms',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
      ),
      body: BlocBuilder<AlarmBloc, AlarmState>(
        builder: (context, state) {
          if (state is AlarmLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            );
          }

          if (state is AlarmError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEF4444),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load alarms',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        context
                            .read<AlarmBloc>()
                            .add(const FetchAlarms());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is AlarmLoaded) {
            final alarms = state.alarms;

            if (alarms.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_off_outlined,
                      color: Color(0xFF94A3B8),
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No alarms',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF94A3B8),
                              ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              itemCount: alarms.length,
              itemBuilder: (context, index) {
                final alarm = alarms[index];
                return _AlarmCard(alarm: alarm);
              },
            );
          }

          // AlarmInitial – show nothing until fetched
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Individual alarm card with status indicator, icon, and ACK button.
class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.alarm});

  final Alarm alarm;

  IconData _iconForEventClass(String eventClass) {
    switch (eventClass.toUpperCase()) {
      case 'INTRUSION':
        return Icons.warning_amber_rounded;
      case 'FIRE':
        return Icons.local_fire_department;
      case 'LOITERING':
        return Icons.directions_walk;
      case 'VANDALISM':
        return Icons.broken_image;
      default:
        return Icons.notifications_active;
    }
  }

  void _showAlarmDetailModal(BuildContext context, Alarm alarm) {
    final statusColor = alarm.isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return BlocProvider.value(
          value: context.read<AlarmBloc>(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      alarm.eventClass.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alarm.isActive ? 'ACTIVE THREAT' : 'RESOLVED',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Camera Name & Time Info
                Row(
                  children: [
                    const Icon(Icons.videocam, color: Color(0xFF94A3B8), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      alarm.cameraName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFF94A3B8), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm:ss').format(alarm.timestamp),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Mock Snapshot Frame
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.15,
                            child: GridPaper(
                              color: statusColor,
                              divisions: 2,
                              subdivisions: 1,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, color: statusColor.withOpacity(0.5), size: 36),
                            const SizedBox(height: 8),
                            Text(
                              '${alarm.eventClass} Alert Snapshot Frame',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        if (alarm.isActive)
                          Positioned(
                            top: 25,
                            left: 40,
                            right: 40,
                            bottom: 25,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Container(
                                      color: const Color(0xFFEF4444),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                      child: Text(
                                        'IVA DETECTION: ${alarm.eventClass}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Acknowledge Action Button
                if (alarm.isActive)
                  ElevatedButton.icon(
                    key: const Key('modalAcknowledgeButton'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('ACKNOWLEDGE INCIDENT', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      context.read<AlarmBloc>().add(AlarmAcknowledged(alarmId: alarm.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Incident ${alarm.id} acknowledged successfully.')),
                      );
                    },
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('ALARM RESOLVED & ACKNOWLEDGED'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = alarm.isActive;
    final statusColor =
        isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return GestureDetector(
      key: Key('alarmCard_${alarm.id}'),
      onTap: () => _showAlarmDetailModal(context, alarm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: statusColor,
              width: 3,
            ),
            top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _iconForEventClass(alarm.eventClass),
              color: statusColor,
              size: 24,
            ),
          ),
          title: Text(
            alarm.eventClass,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${alarm.cameraName} • '
              '${DateFormat('dd MMM yyyy, HH:mm').format(alarm.timestamp)}',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
