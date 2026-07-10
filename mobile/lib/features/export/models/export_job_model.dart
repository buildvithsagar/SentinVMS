import 'package:equatable/equatable.dart';

/// Represents a server-side video export job.
class ExportJob extends Equatable {
  const ExportJob({
    required this.id,
    required this.cameraId,
    required this.siteId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.downloadUrl,
    this.progress,
    this.createdAt,
  });

  factory ExportJob.fromJson(Map<String, dynamic> json) {
    final startTimeStr = json['startTime'] as String? ?? json['start_time'] as String?;
    final endTimeStr = json['endTime'] as String? ?? json['end_time'] as String?;
    final createdAtStr = json['createdAt'] as String? ?? json['created_at'] as String?;

    return ExportJob(
      id: json['export_id'] as String? ?? json['exportId'] as String? ?? json['id'] as String? ?? '',
      cameraId: json['cameraId'] as String? ?? '',
      siteId: json['siteId'] as String? ?? '',
      startTime: startTimeStr != null ? DateTime.parse(startTimeStr) : DateTime.now(),
      endTime: endTimeStr != null ? DateTime.parse(endTimeStr) : DateTime.now(),
      status: json['status'] as String? ?? 'PENDING',
      downloadUrl: json['download_url'] as String? ?? json['downloadUrl'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? (json['status'] == 'COMPLETE' || json['status'] == 'COMPLETED' ? 1.0 : 0.0),
      createdAt: createdAtStr != null ? DateTime.parse(createdAtStr) : null,
    );
  }

  final String id;
  final String cameraId;
  final String siteId;
  final DateTime startTime;
  final DateTime endTime;

  /// Export status: 'PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'.
  final String status;
  final String? downloadUrl;
  final double? progress;
  final DateTime? createdAt;

  bool get isCompleted => status == 'COMPLETED' || status == 'COMPLETE';
  bool get isFailed => status == 'FAILED';
  bool get isPending => status == 'PENDING' || status == 'PROCESSING';

  ExportJob copyWith({
    String? id,
    String? cameraId,
    String? siteId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? downloadUrl,
    double? progress,
    DateTime? createdAt,
  }) {
    return ExportJob(
      id: id ?? this.id,
      cameraId: cameraId ?? this.cameraId,
      siteId: siteId ?? this.siteId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exportId': id,
      'cameraId': cameraId,
      'siteId': siteId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'status': status,
      'downloadUrl': downloadUrl,
      'progress': progress,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        cameraId,
        siteId,
        startTime,
        endTime,
        status,
        downloadUrl,
        progress,
        createdAt,
      ];
}
