import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';

class LocationInfoWidget extends StatelessWidget {
  final AttendanceLocation? location;
  final String label;
  final bool isCompact;

  const LocationInfoWidget({
    super.key,
    this.location,
    required this.label,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (location == null) {
      return isCompact
          ? const Icon(Icons.location_off, size: 16, color: Colors.grey)
          : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_off, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'No location data',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
    }

    final isWithinZone = location!.isWithinWorkZone;
    final statusColor = isWithinZone ? Colors.green : Colors.orange;
    final statusIcon = isWithinZone ? Icons.location_on : Icons.location_off;

    if (isCompact) {
      return Tooltip(
        message: '$label: ${isWithinZone ? "Within workplace" : "Outside workplace"}\nDistance: ${location!.formattedDistance}',
        child: Icon(
          statusIcon,
          size: 16,
          color: statusColor,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 20, color: statusColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isWithinZone ? 'VERIFIED' : 'FLAGGED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildLocationDetail('Status', isWithinZone ? 'Within workplace zone' : 'Outside workplace zone'),
          if (location!.distanceFromWork != null)
            _buildLocationDetail('Distance from workplace', location!.formattedDistance),
          _buildLocationDetail('Accuracy', '±${location!.accuracy.round()}m'),
          _buildLocationDetail('Coordinates', '${location!.latitude.toStringAsFixed(6)}, ${location!.longitude.toStringAsFixed(6)}'),
        ],
      ),
    );
  }

  Widget _buildLocationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationSummaryCard extends StatelessWidget {
  final List<AttendanceModel> attendanceRecords;

  const LocationSummaryCard({
    super.key,
    required this.attendanceRecords,
  });

  @override
  Widget build(BuildContext context) {
    int totalRecords = 0;
    int flaggedClockIns = 0;
    int flaggedClockOuts = 0;
    int verifiedClockIns = 0;
    int verifiedClockOuts = 0;

    for (var record in attendanceRecords) {
      if (record.clockInLocation != null) {
        totalRecords++;
        if (record.clockInLocation!.isWithinWorkZone) {
          verifiedClockIns++;
        } else {
          flaggedClockIns++;
        }
      }

      if (record.clockOutLocation != null) {
        totalRecords++;
        if (record.clockOutLocation!.isWithinWorkZone) {
          verifiedClockOuts++;
        } else {
          flaggedClockOuts++;
        }
      }
    }

    double flaggedPercentage = totalRecords > 0 ? ((flaggedClockIns + flaggedClockOuts) / totalRecords) * 100 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Location Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Verified',
                    '${verifiedClockIns + verifiedClockOuts}',
                    Colors.green,
                    Icons.verified,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Flagged',
                    '${flaggedClockIns + flaggedClockOuts}',
                    Colors.orange,
                    Icons.flag,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    '$totalRecords',
                    Colors.blue,
                    Icons.location_on,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Flag Rate',
                    '${flaggedPercentage.toStringAsFixed(1)}%',
                    flaggedPercentage > 20 ? Colors.red : Colors.grey,
                    Icons.percent,
                  ),
                ),
              ],
            ),
            
            if (flaggedPercentage > 20) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'High flag rate detected. Consider reviewing this worker\'s location compliance.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
