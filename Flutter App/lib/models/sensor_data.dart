// Updated SensorData class with copyWith method
class SensorData {
  final String deviceId;
  final DateTime timestamp;
  final double? distance;
  final bool? vibration;
  final bool? doorOpen;
  final bool? systemActive;
  final bool? faceDetected;
  final String? faceName;
  final int? cameraAngle;
  final String? eventType;
  final int? wifiStrength;
  final String? ipAddress;
  final int? uptime;
  final bool online;

  SensorData({
    required this.deviceId,
    required this.timestamp,
    this.distance,
    this.vibration,
    this.doorOpen,
    this.systemActive,
    this.faceDetected,
    this.faceName,
    this.cameraAngle,
    this.eventType,
    this.wifiStrength,
    this.ipAddress,
    this.uptime,
    required this.online,
  });

  factory SensorData.fromMap(Map<String, dynamic> map) {
    return SensorData(
      deviceId: map['device_id'] ?? 'ESP32_CAM',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      distance: map['distance']?.toDouble(),
      vibration: map['vibration'] ?? false,
      doorOpen: map['door_open'] ?? false,
      systemActive: map['system_active'] ?? false,
      faceDetected: map['face_detected'] ?? false,
      faceName: map['face_name'],
      cameraAngle: map['camera_angle'],
      eventType: map['event_type'],
      wifiStrength: map['wifi_strength'],
      ipAddress: map['ip_address'],
      uptime: map['uptime'],
      online: map['online'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'distance': distance,
      'vibration': vibration,
      'door_open': doorOpen,
      'system_active': systemActive,
      'face_detected': faceDetected,
      'face_name': faceName,
      'camera_angle': cameraAngle,
      'event_type': eventType,
      'wifi_strength': wifiStrength,
      'ip_address': ipAddress,
      'uptime': uptime,
      'online': online,
    };
  }

  // Add this copyWith method
  SensorData copyWith({
    String? deviceId,
    DateTime? timestamp,
    double? distance,
    bool? vibration,
    bool? doorOpen,
    bool? systemActive,
    bool? faceDetected,
    String? faceName,
    int? cameraAngle,
    String? eventType,
    int? wifiStrength,
    String? ipAddress,
    int? uptime,
    bool? online,
  }) {
    return SensorData(
      deviceId: deviceId ?? this.deviceId,
      timestamp: timestamp ?? this.timestamp,
      distance: distance ?? this.distance,
      vibration: vibration ?? this.vibration,
      doorOpen: doorOpen ?? this.doorOpen,
      systemActive: systemActive ?? this.systemActive,
      faceDetected: faceDetected ?? this.faceDetected,
      faceName: faceName ?? this.faceName,
      cameraAngle: cameraAngle ?? this.cameraAngle,
      eventType: eventType ?? this.eventType,
      wifiStrength: wifiStrength ?? this.wifiStrength,
      ipAddress: ipAddress ?? this.ipAddress,
      uptime: uptime ?? this.uptime,
      online: online ?? this.online,
    );
  }
}

class EventLog {
  final String eventType;
  final DateTime? timestamp;
  final String? faceName;
  final double? distance;
  final int? cameraAngle;
  final bool? doorOpen;
  final String? ipAddress;

  EventLog({
    required this.eventType,
    this.timestamp,
    this.faceName,
    this.distance,
    this.cameraAngle,
    this.doorOpen,
    this.ipAddress,
  });

  factory EventLog.fromMap(Map<String, dynamic> map) {
    return EventLog(
      eventType: map['event_type'] ?? 'unknown',
      timestamp:
          map['timestamp'] != null ? DateTime.parse(map['timestamp']) : null,
      faceName: map['face_name'],
      distance: map['distance']?.toDouble(),
      cameraAngle: map['camera_angle'],
      doorOpen: map['door_open'],
      ipAddress: map['ip_address'],
    );
  }
}

class FaceData {
  final String id;
  final String name;
  final String imageUrl;
  final DateTime addedDate;
  final double confidence;

  FaceData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.addedDate,
    required this.confidence,
  });

  factory FaceData.fromMap(Map<String, dynamic> map) {
    return FaceData(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      imageUrl: map['image_url'] ?? '',
      addedDate: map['added_date'] != null
          ? DateTime.parse(map['added_date'])
          : DateTime.now(),
      confidence: map['confidence']?.toDouble() ?? 0.0,
    );
  }
}

enum Trend { normal, alert, warning, success }
