import 'package:flutter/material.dart';
import 'package:security_system_app/models/sensor_data.dart';

class SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Trend trend;
  final VoidCallback? onTap;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend = Trend.normal,
    this.onTap,
  });

  Color _getTrendColor(Trend trend) {
    switch (trend) {
      case Trend.alert:
        return Colors.red;
      case Trend.warning:
        return Colors.orange;
      case Trend.success:
        return Colors.green;
      case Trend.normal:
      // ignore: unreachable_switch_default
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTrendColor(trend).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getTrendColor(trend).withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      _getTrendIcon(trend),
                      color: _getTrendColor(trend),
                      size: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTrendIcon(Trend trend) {
    switch (trend) {
      case Trend.alert:
        return Icons.arrow_upward;
      case Trend.warning:
        return Icons.warning;
      case Trend.success:
        return Icons.check_circle;
      case Trend.normal:
      // ignore: unreachable_switch_default
      default:
        return Icons.trending_flat;
    }
  }
}