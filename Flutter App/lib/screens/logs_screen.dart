import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:security_system_app/models/sensor_data.dart';
import 'package:security_system_app/services/firebase_service.dart';
import 'package:security_system_app/widgets/event_tile.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<String> _filterOptions = ['All', 'Motion', 'Face', 'Vibration', 'Door'];
  String _selectedFilter = 'All';
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.watch<FirebaseService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Logs'),
        actions: [
          // Filter dropdown
          DropdownButton<String>(
            value: _selectedFilter,
            items: _filterOptions.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedFilter = value!;
              });
            },
          ),
          const SizedBox(width: 16),
          // Date range picker
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDateRange,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Events',
                    value: '${firebaseService.recentEvents.length}',
                    color: Colors.blue,
                    icon: Icons.event,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Today',
                    value: _getTodayCount(firebaseService.recentEvents),
                    color: Colors.green,
                    icon: Icons.today,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Intruders',
                    value: _getIntruderCount(firebaseService.recentEvents),
                    color: Colors.red,
                    icon: Icons.warning,
                  ),
                ),
              ],
            ),
          ),

          // Charts Section
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Event Distribution Chart
                  _buildEventChart(firebaseService.recentEvents),

                  // Events List
                  StreamBuilder<List<EventLog>>(
                    stream: firebaseService.eventsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No events recorded yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      var events = snapshot.data!;

                      // Apply filters
                      if (_selectedFilter != 'All') {
                        events = events
                            .where((event) =>
                                event.eventType.toLowerCase() ==
                                _selectedFilter.toLowerCase())
                            .toList();
                      }

                      // Apply date range filter
                      if (_dateRange != null) {
                        events = events
                            .where((event) =>
                                event.timestamp != null &&
                                event.timestamp!.isAfter(_dateRange!.start) &&
                                event.timestamp!.isBefore(_dateRange!.end))
                            .toList();
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return EventTile(
                            event: event,
                            onTap: () {
                              _showEventDetails(event);
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventChart(List<EventLog> events) {
    final eventCounts = _countEventsByType(events);

    final data = eventCounts.entries.map((entry) {
      return _EventData(
        type: entry.key,
        count: entry.value,
        color: _getEventColor(entry.key),
      );
    }).toList();

    final series = [
      charts.Series<_EventData, String>(
        id: 'Events',
        domainFn: (_EventData data, _) => data.type,
        measureFn: (_EventData data, _) => data.count,
        colorFn: (_EventData data, _) => data.color,
        data: data,
        labelAccessorFn: (_EventData data, _) => '${data.type}: ${data.count}',
      ),
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: charts.BarChart(
                series,
                animate: true,
                vertical: false,
                barRendererDecorator: charts.BarLabelDecorator<String>(),
                domainAxis: const charts.OrdinalAxisSpec(
                  renderSpec: charts.SmallTickRendererSpec(
                    labelRotation: 45,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _countEventsByType(List<EventLog> events) {
    final counts = <String, int>{};
    
    for (final event in events) {
      counts.update(
        event.eventType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    
    return counts;
  }

  charts.Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'motion':
        return charts.ColorUtil.fromDartColor(Colors.orange);
      case 'face':
        return charts.ColorUtil.fromDartColor(Colors.blue);
      case 'vibration':
        return charts.ColorUtil.fromDartColor(Colors.red);
      case 'door':
        return charts.ColorUtil.fromDartColor(Colors.green);
      default:
        return charts.ColorUtil.fromDartColor(Colors.grey);
    }
  }

  String _getTodayCount(List<EventLog> events) {
    final today = DateTime.now();
    final count = events.where((event) {
      return event.timestamp != null &&
          event.timestamp!.year == today.year &&
          event.timestamp!.month == today.month &&
          event.timestamp!.day == today.day;
    }).length;
    
    return count.toString();
  }

  String _getIntruderCount(List<EventLog> events) {
    final count = events
        .where((event) => event.faceName == 'Intruder')
        .length;
    
    return count.toString();
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  void _showEventDetails(EventLog event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.eventType.toUpperCase()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (event.timestamp != null)
                _buildDetailRow('Time:', event.timestamp!.toLocal().toString()),
              if (event.faceName != null)
                _buildDetailRow('Face:', event.faceName!),
              if (event.distance != null)
                _buildDetailRow('Distance:', '${event.distance} cm'),
              if (event.cameraAngle != null)
                _buildDetailRow('Camera Angle:', '${event.cameraAngle}°'),
              if (event.doorOpen != null)
                _buildDetailRow('Door:', event.doorOpen! ? 'Open' : 'Closed'),
              if (event.ipAddress != null)
                _buildDetailRow('IP Address:', event.ipAddress!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _EventData {
  final String type;
  final int count;
  final charts.Color color;

  _EventData({
    required this.type,
    required this.count,
    required this.color,
  });
}