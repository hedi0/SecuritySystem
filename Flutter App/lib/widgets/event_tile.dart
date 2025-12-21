import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:security_system_app/models/sensor_data.dart';

class EventTile extends StatelessWidget {
  final EventLog event;
  final VoidCallback onTap;
  final bool isExpanded;

  const EventTile({
    super.key,
    required this.event,
    required this.onTap,
    this.isExpanded = false,
  });

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'motion':
        return Icons.directions_run;
      case 'face':
        return Icons.face;
      case 'vibration':
        return Icons.vibration;
      case 'door':
        return Icons.door_front_door;
      case 'alert':
        return Icons.warning;
      case 'system_reboot':
        return Icons.restart_alt;
      case 'firebase_test':
        return Icons.cloud;
      case 'status':
        return Icons.info;
      default:
        return Icons.event;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'motion':
        return Colors.orange;
      case 'face':
        return event.faceName == 'Intruder' ? Colors.red : Colors.green;
      case 'vibration':
        return Colors.red;
      case 'door':
        return Colors.blue;
      case 'alert':
        return Colors.red;
      case 'system_reboot':
        return Colors.purple;
      case 'firebase_test':
        return Colors.blue;
      case 'status':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getEventTitle(String eventType) {
    switch (eventType) {
      case 'motion':
        return 'Motion Detected';
      case 'face':
        return event.faceName == 'Intruder' ? 'Intruder Alert' : 'Face Recognized';
      case 'vibration':
        return 'Vibration Detected';
      case 'door':
        return event.doorOpen == true ? 'Door Opened' : 'Door Closed';
      case 'alert':
        return 'Security Alert';
      case 'system_reboot':
        return 'System Rebooted';
      case 'firebase_test':
        return 'Firebase Test';
      case 'status':
        return 'Status Update';
      default:
        return eventType;
    }
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final eventDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (eventDay == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (eventDay == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      return DateFormat('MMM dd, HH:mm').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getEventColor(event.eventType).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getEventIcon(event.eventType),
                      color: _getEventColor(event.eventType),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getEventTitle(event.eventType),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (event.timestamp != null)
                          Text(
                            _formatTime(event.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (event.faceName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: event.faceName == 'Intruder'
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.faceName!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: event.faceName == 'Intruder'
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
              
              if (isExpanded) ...[
                const SizedBox(height: 8),
                _buildEventDetails(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.distance != null)
          _buildDetailRow('Distance', '${event.distance!.toStringAsFixed(1)} cm'),
        if (event.cameraAngle != null)
          _buildDetailRow('Camera Angle', '${event.cameraAngle}°'),
        if (event.doorOpen != null)
          _buildDetailRow('Door', event.doorOpen! ? 'Open' : 'Closed'),
        if (event.ipAddress != null)
          _buildDetailRow('IP Address', event.ipAddress!),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}