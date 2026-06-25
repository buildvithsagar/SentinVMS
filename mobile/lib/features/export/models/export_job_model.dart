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
    return ExportJob(
      id: json['exportId'] as String? ?? json['id'] as String? ?? '',
      cameraId: json['cameraId'] as String? ?? '',
      siteId: json['siteId'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      status: json['status'] as String? ?? 'PENDING',
      downloadUrl: json['downloadUrl'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
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

  bool get isCompleted => status == 'COMPLETED';
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
