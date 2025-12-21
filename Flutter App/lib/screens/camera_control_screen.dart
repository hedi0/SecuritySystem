import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_system_app/services/firebase_service.dart';
import 'package:security_system_app/widgets/control_button.dart';

class CameraControlScreen extends StatefulWidget {
  const CameraControlScreen({super.key});

  @override
  State<CameraControlScreen> createState() => _CameraControlScreenState();
}

class _CameraControlScreenState extends State<CameraControlScreen> {
  bool _isScanning = false;
  int _currentAngle = 0;
  final List<int> _angles = [30, 60, 120, 150];

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.watch<FirebaseService>();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Camera Preview Placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: NetworkImage(
                      'https://via.placeholder.com/400x200/333333/FFFFFF?text=Camera+Preview'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live View',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Camera Angle Control
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Camera Pan Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _currentAngle.toDouble(),
                      min: 0,
                      max: 180,
                      divisions: 6,
                      label: '$_currentAngle°',
                      onChanged: (value) {
                        setState(() {
                          _currentAngle = value.toInt();
                        });
                      },
                      onChangeEnd: (value) {
                        // Send angle to ESP32
                        _sendCameraAngle(value.toInt());
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _angles.map((angle) {
                        return ChoiceChip(
                          label: Text('$angle°'),
                          selected: _currentAngle == angle,
                          onSelected: (selected) {
                            setState(() {
                              _currentAngle = selected ? angle : _currentAngle;
                            });
                            if (selected) {
                              _sendCameraAngle(angle);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Camera Actions Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                ControlButton(
                  icon: Icons.camera_alt,
                  label: 'Capture Photo',
                  color: Colors.blue,
                  onPressed: () {
                    _capturePhoto();
                  },
                ),
                ControlButton(
                  icon: Icons.video_camera_back,
                  label: 'Start Recording',
                  color: Colors.red,
                  onPressed: () {
                    _startRecording();
                  },
                ),
                ControlButton(
                  icon: Icons.nightlight_round,
                  label: 'Night Mode',
                  color: Colors.purple,
                  onPressed: () {
                    _toggleNightMode();
                  },
                ),
                ControlButton(
                  icon: Icons.flash_on,
                  label: 'Toggle Flash',
                  color: Colors.amber,
                  onPressed: () {
                    _toggleFlash();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Scan Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: _isScanning ? Colors.red : Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Face Scan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isScanning,
                          onChanged: (value) {
                            setState(() {
                              _isScanning = value;
                            });
                            if (value) {
                              firebaseService.startFaceScan();
                            } else {
                              firebaseService.stopSystem();
                            }
                          },
                          activeColor: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isScanning
                          ? 'System is actively scanning for faces'
                          : 'System is idle',
                      style: TextStyle(
                        color: _isScanning ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Manual Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    firebaseService.triggerVibrationTest();
                  },
                  icon: const Icon(Icons.vibration),
                  label: const Text('Test Vibration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    firebaseService.rebootSystem();
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reboot System'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendCameraAngle(int angle) async {
    try {
      await context.read<FirebaseService>().sendCommand('set_camera_angle', {
        'angle': angle,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera angle set to $angle°'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to set camera angle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _capturePhoto() {
    // Implement photo capture
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo captured and saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _startRecording() {
    // Implement video recording
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording started'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _toggleNightMode() {
    // Implement night mode toggle
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Night mode toggled'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _toggleFlash() {
    // Implement flash toggle
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flash toggled'),
        backgroundColor: Colors.amber,
      ),
    );
  }
}