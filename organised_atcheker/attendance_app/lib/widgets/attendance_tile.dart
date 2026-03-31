import 'package:flutter/material.dart';
import '../attendance_model.dart';

class AttendanceTile extends StatelessWidget {
  final AttendanceInfo info;

  const AttendanceTile({Key? key, required this.info}) : super(key: key);

  Color _getAttendanceColor(String percentageStr) {
    if (percentageStr == 'N/A') return Colors.grey;
    final value = double.tryParse(percentageStr.replaceAll('%', ''));
    if (value == null) return Colors.grey;
    if (value >= 75) return Colors.green.shade600;
    if (value >= 60) return Colors.orange.shade500;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final attendColor = _getAttendanceColor(info.attendancePercentage);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          info.subjectName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoBadge(label: 'Total', value: info.totalClasses, color: Colors.blueGrey),
                  _InfoBadge(label: 'Present', value: info.presentCount, color: Colors.green),
                  _InfoBadge(label: 'Absent', value: info.absentCount, color: Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   Icon(Icons.pie_chart, size: 18, color: attendColor),
                  const SizedBox(width: 8),
                  Text(
                    'Attendance: ${info.attendancePercentage}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: attendColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Container(
            color: Colors.blueGrey.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Records',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                if (info.dailyRecords.isEmpty)
                   Text(
                    'No daily records found.',
                    style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ...info.dailyRecords.reversed.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rec.status.toLowerCase().contains('present') 
                              ? Colors.green.shade100 
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rec.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: rec.status.toLowerCase().contains('present') 
                                ? Colors.green.shade800 
                                : Colors.red.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rec.date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(rec.time, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (rec.remarks.isNotEmpty)
                        Tooltip(
                          message: rec.remarks,
                          child: Icon(Icons.info_outline, size: 16, color: Colors.blueGrey.shade400),
                        )
                    ],
                  ),
                )).toList()
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;
  final MaterialColor color;

  const _InfoBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, color: color.shade900, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
