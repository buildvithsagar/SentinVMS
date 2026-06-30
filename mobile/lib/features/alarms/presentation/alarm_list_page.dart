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

  @override
  Widget build(BuildContext context) {
    final isActive = alarm.isActive;
    final statusColor =
        isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
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
        trailing: isActive
            ? TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
                onPressed: () {
                  context
                      .read<AlarmBloc>()
                      .add(AlarmAcknowledged(alarmId: alarm.id));
                },
                child: const Text(
                  'ACK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              )
            : Icon(
                Icons.check_circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.7),
                size: 20,
              ),
      ),
    );
  }
}
