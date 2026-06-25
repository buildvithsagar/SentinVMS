import 'package:equatable/equatable.dart';

class Camera extends Equatable {
  const Camera({
    required this.id,
    required this.siteId,
    required this.name,
    required this.ipAddress,
    required this.rtspUrl,
    required this.onvifProfile,
    required this.codec,
    required this.ptzCapable,
    required this.status,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['cameraId'] as String? ?? json['id'] as String? ?? '',
      siteId: json['siteId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ipAddress: json['ipAddress'] as String? ?? '',
      rtspUrl: json['rtspUrl'] as String? ?? '',
      onvifProfile: json['onvifProfile'] as String? ?? 'S',
      codec: json['codec'] as String? ?? 'H264',
      ptzCapable: json['ptzCapable'] as bool? ?? false,
      status: json['status'] as String? ?? 'DISCONNECTED',
    );
  }

  final String id;
  final String siteId;
  final String name;
  final String ipAddress;
  final String rtspUrl;
  final String onvifProfile;
  final String codec;
  final bool ptzCapable;
  final String status;

  Camera copyWith({
    String? id,
    String? siteId,
    String? name,
    String? ipAddress,
    String? rtspUrl,
    String? onvifProfile,
    String? codec,
    bool? ptzCapable,
    String? status,
  }) {
    return Camera(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      onvifProfile: onvifProfile ?? this.onvifProfile,
      codec: codec ?? this.codec,
      ptzCapable: ptzCapable ?? this.ptzCapable,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cameraId': id,
      'siteId': siteId,
      'name': name,
      'ipAddress': ipAddress,
      'rtspUrl': rtspUrl,
      'onvifProfile': onvifProfile,
      'codec': codec,
      'ptzCapable': ptzCapable,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [
        id,
        siteId,
        name,
        ipAddress,
        rtspUrl,
        onvifProfile,
        codec,
        ptzCapable,
        status,
      ];
}
