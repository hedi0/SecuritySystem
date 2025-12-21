import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_system_app/models/sensor_data.dart';
import 'package:security_system_app/services/firebase_service.dart';
import 'package:security_system_app/widgets/sensor_card.dart';
import 'package:security_system_app/widgets/control_button.dart';
import 'package:security_system_app/screens/camera_control_screen.dart';
import 'package:security_system_app/screens/face_management_screen.dart';
import 'package:security_system_app/screens/logs_screen.dart';
import 'package:security_system_app/screens/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late Stream<SensorData?> _sensorStream;

  @override
  void initState() {
    super.initState();
    final firebaseService = context.read<FirebaseService>();
    _sensorStream = firebaseService.sensorStream;
  }

  final List<Widget> _screens = [
    const HomeTab(),
    const CameraControlScreen(),
    const FaceManagementScreen(),
    const LogsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          StreamBuilder<SensorData?>(
            stream: _sensorStream,
            builder: (context, snapshot) {
              final isOnline = snapshot.data?.online ?? false;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: isOnline ? Colors.green : Colors.red,
                      size: 12,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.face),
            label: 'Faces',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.watch<FirebaseService>();

    return RefreshIndicator(
      onRefresh: () async {
        await firebaseService.refreshData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Status
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.deepPurple,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'System Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StreamBuilder<SensorData?>(
                          stream: firebaseService.sensorStream,
                          builder: (context, snapshot) {
                            final isActive =
                                snapshot.data?.systemActive ?? false;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: isActive ? Colors.red : Colors.green,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isActive ? 'ACTIVE' : 'IDLE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isActive ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ControlButton(
                          icon: Icons.camera_alt,
                          label: 'Take Photo',
                          onPressed: () {
                            // Implement photo capture
                          },
                          color: Colors.blue,
                        ),
                        ControlButton(
                          icon: Icons.door_front_door,
                          label: 'Door Control',
                          onPressed: () {
                            _showDoorControlDialog(context);
                          },
                          color: Colors.green,
                        ),
                        ControlButton(
                          icon: Icons.warning,
                          label: 'Emergency',
                          onPressed: () {
                            _triggerEmergencyAlert(context);
                          },
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sensor Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                StreamBuilder<SensorData?>(
                  stream: firebaseService.sensorStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return SensorCard(
                      title: 'Distance',
                      value: '${data?.distance?.toStringAsFixed(1) ?? '--'} cm',
                      icon: Icons.social_distance,
                      color: Colors.blue,
                      trend: data?.distance != null && data!.distance! < 50
                          ? Trend.alert
                          : Trend.normal,
                    );
                  },
                ),
                StreamBuilder<SensorData?>(
                  stream: firebaseService.sensorStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return SensorCard(
                      title: 'Vibration',
                      value: data?.vibration ?? false ? 'DETECTED' : 'NORMAL',
                      icon: Icons.vibration,
                      color:
                          data?.vibration ?? false ? Colors.red : Colors.green,
                      trend:
                          data?.vibration ?? false ? Trend.alert : Trend.normal,
                    );
                  },
                ),
                StreamBuilder<SensorData?>(
                  stream: firebaseService.sensorStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return SensorCard(
                      title: 'WiFi Signal',
                      value: '${data?.wifiStrength?.toString() ?? '--'} dBm',
                      icon: Icons.wifi,
                      color: _getWifiColor(data?.wifiStrength),
                      trend: _getWifiTrend(data?.wifiStrength),
                    );
                  },
                ),
                StreamBuilder<SensorData?>(
                  stream: firebaseService.sensorStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return SensorCard(
                      title: 'Camera Angle',
                      value: '${data?.cameraAngle?.toString() ?? '0'}°',
                      icon: Icons.videocam,
                      color: Colors.purple,
                      trend: Trend.normal,
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Recent Events
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Recent Events',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LogsScreen(),
                              ),
                            );
                          },
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<EventLog>>(
                      stream: firebaseService.eventsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text('No events found'),
                          );
                        }

                        final events = snapshot.data!.take(5).toList();

                        return Column(
                          children: events
                              .map((event) => ListTile(
                                    leading: _getEventIcon(event.eventType),
                                    title: Text(event.eventType.toUpperCase()),
                                    subtitle: Text(
                                      event.timestamp != null
                                          ? '${_formatTime(event.timestamp!)}'
                                          : 'Unknown time',
                                    ),
                                    trailing: event.faceName != null
                                        ? Chip(
                                            label: Text(event.faceName!),
                                            backgroundColor: event.faceName ==
                                                    'Intruder'
                                                ? Colors.red.withOpacity(0.2)
                                                : Colors.green.withOpacity(0.2),
                                          )
                                        : null,
                                    onTap: () {
                                      _showEventDetails(context, event);
                                    },
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getWifiColor(int? strength) {
    if (strength == null) return Colors.grey;
    if (strength >= -50) return Colors.green;
    if (strength >= -70) return Colors.orange;
    return Colors.red;
  }

  Trend _getWifiTrend(int? strength) {
    if (strength == null) return Trend.normal;
    if (strength <= -80) return Trend.alert;
    return Trend.normal;
  }

  Icon _getEventIcon(String eventType) {
    switch (eventType) {
      case 'motion':
        return const Icon(Icons.directions_run, color: Colors.orange);
      case 'face':
        return const Icon(Icons.face, color: Colors.blue);
      case 'vibration':
        return const Icon(Icons.vibration, color: Colors.red);
      case 'door':
        return const Icon(Icons.door_front_door, color: Colors.green);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _showDoorControlDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Door Control'),
        content: const Text('Do you want to open or close the door?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Send open door command
              Navigator.pop(context);
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () {
              // Send close door command
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _triggerEmergencyAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content:
            const Text('Are you sure you want to trigger emergency alert?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Trigger emergency
              Navigator.pop(context);
            },
            child: const Text('Trigger Alert'),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(BuildContext context, EventLog event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.eventType.toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (event.timestamp != null)
              Text('Time: ${event.timestamp!.toLocal()}'),
            if (event.faceName != null) Text('Face: ${event.faceName}'),
            if (event.distance != null) Text('Distance: ${event.distance} cm'),
            if (event.cameraAngle != null)
              Text('Camera Angle: ${event.cameraAngle}°'),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
