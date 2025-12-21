import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:security_system_app/models/sensor_data.dart';

class FirebaseService extends ChangeNotifier {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription? _sensorSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _statusSubscription;

  SensorData? _currentSensorData;
  List<EventLog> _recentEvents = [];
  bool _isConnected = false;
  bool _isLoading = true;

  SensorData? get currentSensorData => _currentSensorData;
  List<EventLog> get recentEvents => _recentEvents;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;

  final StreamController<SensorData?> _sensorController =
      StreamController<SensorData?>.broadcast();
  final StreamController<List<EventLog>> _eventsController =
      StreamController<List<EventLog>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<SensorData?> get sensorStream => _sensorController.stream;
  Stream<List<EventLog>> get eventsStream => _eventsController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> initializeListeners() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Listen for latest sensor data
      _sensorSubscription = _database
          .child('devices/ESP32_CAM/latest')
          .onValue
          .listen((event) {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(
              event.snapshot.value as Map<Object?, Object?>);
          _currentSensorData = SensorData.fromMap(data);
          _currentSensorData = _currentSensorData!.copyWith(online: true);
          _sensorController.add(_currentSensorData);
          notifyListeners();
        }
      });

      // Listen for device status
      _statusSubscription = _database
          .child('devices/ESP32_CAM/status')
          .onValue
          .listen((event) {
        if (event.snapshot.value != null) {
          final status = Map<String, dynamic>.from(
              event.snapshot.value as Map<Object?, Object?>);
          final isOnline = status['online'] ?? false;
          _isConnected = isOnline;
          _connectionController.add(isOnline);
          notifyListeners();
        }
      });

      // Listen for recent events
      _eventsSubscription = _database
          .child('sensor_data')
          .orderByChild('timestamp')
          .limitToLast(50)
          .onValue
          .listen((event) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<Object?, Object?>;
          _recentEvents = data.entries.map((entry) {
            final eventData = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
            return EventLog.fromMap(eventData);
          }).toList()
            ..sort((a, b) => (b.timestamp ?? DateTime.now())
                .compareTo(a.timestamp ?? DateTime.now()));
          _eventsController.add(_recentEvents);
          notifyListeners();
        }
      });

      // Check connection status
      _database.ref.onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        _isConnected = connected;
        _connectionController.add(connected);
        notifyListeners();
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendCommand(String command, [Map<String, dynamic>? params]) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final commandData = {
        'command': command,
        'params': params ?? {},
        'timestamp': timestamp,
        'processed': false,
      };

      await _database
          .child('commands/ESP32_CAM')
          .set(commandData);
    } catch (e) {
      throw Exception('Failed to send command: $e');
    }
  }

  Future<void> openDoor() async {
    await sendCommand('open_door');
  }

  Future<void> closeDoor() async {
    await sendCommand('close_door');
  }

  Future<void> startFaceScan() async {
    await sendCommand('start_scan');
  }

  Future<void> stopSystem() async {
    await sendCommand('stop_system');
  }

  Future<void> triggerVibrationTest() async {
    await sendCommand('vibration_test');
  }

  Future<void> rebootSystem() async {
    await sendCommand('reboot');
  }

  Future<void> addNewFace(String name, String imageBase64) async {
    try {
      final faceData = {
        'name': name,
        'image': imageBase64,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final newFaceRef = _database.child('faces').push();
      await newFaceRef.set(faceData);
    } catch (e) {
      throw Exception('Failed to add face: $e');
    }
  }

  Future<List<FaceData>> getAuthorizedFaces() async {
    try {
      final snapshot = await _database.child('faces').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<Object?, Object?>;
        return data.entries.map((entry) {
          final faceData = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
          return FaceData.fromMap(faceData);
        }).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get faces: $e');
    }
  }

  Future<void> deleteFace(String faceId) async {
    try {
      await _database.child('faces/$faceId').remove();
    } catch (e) {
      throw Exception('Failed to delete face: $e');
    }
  }

  Future<void> refreshData() async {
    // Reinitialize listeners
    await disposeListeners();
    await initializeListeners();
  }

  Future<void> disposeListeners() async {
    await _sensorSubscription?.cancel();
    await _eventsSubscription?.cancel();
    await _statusSubscription?.cancel();
    _sensorSubscription = null;
    _eventsSubscription = null;
    _statusSubscription = null;
  }

  @override
  void dispose() {
    disposeListeners();
    _sensorController.close();
    _eventsController.close();
    _connectionController.close();
    super.dispose();
  }
}