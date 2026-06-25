import 'package:equatable/equatable.dart';

/// Represents a single recorded video segment from the cloud storage pipeline.
class RecordingSegment extends Equatable {
  const RecordingSegment({
    required this.id,
    required this.siteId,
    required this.cameraId,
    required this.startTime,
    required this.endTime,
    required this.type,
  });

  factory RecordingSegment.fromJson(Map<String, dynamic> json) {
    return RecordingSegment(
      id: json['segmentId'] as String? ?? json['id'] as String? ?? '',
      siteId: json['siteId'] as String? ?? '',
      cameraId: json['cameraId'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      type: json['type'] as String? ?? 'CONTINUOUS',
    );
  }

  final String id;
  final String siteId;
  final String cameraId;
  final DateTime startTime;
  final DateTime endTime;

  /// Recording type: 'CONTINUOUS', 'MOTION', or 'SCHEDULED'.
  final String type;

  Map<String, dynamic> toJson() {
    return {
      'segmentId': id,
      'siteId': siteId,
      'cameraId': cameraId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'type': type,
    };
  }

  @override
  List<Object?> get props => [id, siteId, cameraId, startTime, endTime, type];
}
