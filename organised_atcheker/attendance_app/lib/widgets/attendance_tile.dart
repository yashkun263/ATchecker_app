import 'package:flutter/material.dart';
import '../attendance_model.dart';

class AttendanceTile extends StatelessWidget {
  final AttendanceInfo info;
  final bool isDarkMode;

  const AttendanceTile({super.key, required this.info, this.isDarkMode = false});

  Color _getAttendanceColor(String percentageStr) {
    if (percentageStr == 'N/A') return Colors.grey;
    final value = double.tryParse(percentageStr.replaceAll('%', ''));
    if (value == null) return Colors.grey;
    if (value >= 75) return Colors.green.shade600;
    if (value >= 60) return Colors.orange.shade500;
    return Colors.red.shade600;
  }

  Color _getShadowColor(String percentageStr) {
    if (percentageStr == 'N/A') return isDarkMode ? Colors.black45 : Colors.black.withValues(alpha: 0.03);
    final value = double.tryParse(percentageStr.replaceAll('%', ''));
    if (value == null) return isDarkMode ? Colors.black45 : Colors.black.withValues(alpha: 0.03);
    if (value >= 75) return Colors.green.withValues(alpha: 0.4);
    if (value >= 60) return Colors.amber.withValues(alpha: 0.4);
    return Colors.red.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final attendColor = _getAttendanceColor(info.attendancePercentage);
    final shadowColor = _getShadowColor(info.attendancePercentage);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: isDarkMode ? Colors.white10 : Colors.blue.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        iconColor: isDarkMode ? Colors.white70 : Colors.blueGrey,
        collapsedIconColor: isDarkMode ? Colors.white70 : Colors.blueGrey,
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          info.subjectName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDarkMode ? Colors.white : Colors.black87,
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
                  _InfoBadge(label: 'Total', value: info.totalClasses, color: Colors.blueGrey, isDarkMode: isDarkMode),
                  _InfoBadge(label: 'Present', value: info.presentCount, color: Colors.green, isDarkMode: isDarkMode),
                  _InfoBadge(label: 'Absent', value: info.absentCount, color: Colors.red, isDarkMode: isDarkMode),
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
              
              // Status Message (Skips/Takes)
              if (info.getStatusData() != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      info.getStatusData()!['isYellow'] 
                          ? Icons.info_outline 
                          : (info.getStatusData()!['isSkip'] ? Icons.check_circle_outline : Icons.warning_amber_rounded),
                      size: 16,
                      color: info.getStatusData()!['isYellow'] 
                          ? Colors.amber.shade400 
                          : (info.getStatusData()!['isSkip'] ? Colors.green.shade400 : Colors.red.shade400),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info.getStatusData()!['message'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: info.getStatusData()!['isYellow'] 
                              ? Colors.amber.shade400 
                              : (info.getStatusData()!['isSkip'] ? Colors.green.shade400 : Colors.red.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        children: [
          Container(
            color: isDarkMode ? const Color(0xFF252525) : Colors.blueGrey.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Records',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                if (info.dailyRecords.isEmpty)
                   Text(
                    'No daily records found.',
                    style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ...info.dailyRecords.reversed.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rec.status.toLowerCase().contains('present') 
                              ? (isDarkMode ? Colors.green.shade900.withValues(alpha: 0.4) : Colors.green.shade100)
                              : (isDarkMode ? Colors.red.shade900.withValues(alpha: 0.4) : Colors.red.shade100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rec.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: rec.status.toLowerCase().contains('present') 
                                ? Colors.green.shade400 
                                : Colors.red.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.date, 
                              style: TextStyle(
                                fontWeight: FontWeight.w600, 
                                fontSize: 13,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              rec.time, 
                              style: TextStyle(
                                color: isDarkMode ? Colors.white54 : Colors.grey.shade700, 
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (rec.remarks.isNotEmpty)
                        Tooltip(
                          message: rec.remarks,
                          child: Icon(Icons.info_outline, size: 16, color: isDarkMode ? Colors.white38 : Colors.blueGrey.shade400),
                        )
                    ],
                  ),
                ))
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
  final bool isDarkMode;

  const _InfoBadge({
    required this.label, 
    required this.value, 
    required this.color,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? color.shade900.withValues(alpha: 0.2) : color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDarkMode ? color.shade800 : color.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11, 
              color: isDarkMode ? color.shade300 : color.shade700, 
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14, 
              color: isDarkMode ? Colors.white : color.shade900, 
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
