import 'package:equatable/equatable.dart';

/// Represents an AI-triggered alarm event from the AIEYE inference pipeline.
class Alarm extends Equatable {
  const Alarm({
    required this.id,
    required this.siteId,
    required this.cameraId,
    required this.cameraName,
    required this.eventClass,
    required this.confidence,
    required this.status,
    required this.timestamp,
    this.acknowledgedBy,
    this.acknowledgedAt,
  });

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['alarmId'] as String? ?? json['id'] as String? ?? '',
      siteId: json['siteId'] as String? ?? '',
      cameraId: json['cameraId'] as String? ?? '',
      cameraName: json['cameraName'] as String? ?? '',
      eventClass: json['eventClass'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'ACTIVE',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      acknowledgedBy: json['acknowledgedBy'] as String?,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.parse(json['acknowledgedAt'] as String)
          : null,
    );
  }

  final String id;
  final String siteId;
  final String cameraId;
  final String cameraName;
  final String eventClass;
  final double confidence;

  /// Alarm status: 'ACTIVE' or 'ACKNOWLEDGED'.
  final String status;
  final DateTime timestamp;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;

  bool get isActive => status == 'ACTIVE';

  Alarm copyWith({
    String? id,
    String? siteId,
    String? cameraId,
    String? cameraName,
    String? eventClass,
    double? confidence,
    String? status,
    DateTime? timestamp,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
  }) {
    return Alarm(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      cameraId: cameraId ?? this.cameraId,
      cameraName: cameraName ?? this.cameraName,
      eventClass: eventClass ?? this.eventClass,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alarmId': id,
      'siteId': siteId,
      'cameraId': cameraId,
      'cameraName': cameraName,
      'eventClass': eventClass,
      'confidence': confidence,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        siteId,
        cameraId,
        cameraName,
        eventClass,
        confidence,
        status,
        timestamp,
        acknowledgedBy,
        acknowledgedAt,
      ];
}
