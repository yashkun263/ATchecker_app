class DailyRecord {
  final String index;
  final String date;
  final String time;
  final String status;
  final String remarks;

  DailyRecord({
    required this.index,
    required this.date,
    required this.time,
    required this.status,
    required this.remarks,
  });

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      index: json['index'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      status: json['status'] ?? '',
      remarks: json['remarks'] ?? '',
    );
  }
}

class AttendanceInfo {
  final String subjectName;
  final String percent;
  final String latestClass;
  final List<DailyRecord> dailyRecords;

  AttendanceInfo({
    required this.subjectName,
    required this.percent,
    required this.latestClass,
    required this.dailyRecords,
  });

  factory AttendanceInfo.fromJson(Map<String, dynamic> json) {
    var rawRecords = json['daily_records'];
    List<DailyRecord> records = [];
    if (rawRecords != null && rawRecords is List) {
      records = rawRecords.map((e) => DailyRecord.fromJson(e)).toList();
    }
    return AttendanceInfo(
      subjectName: json['subject_name'] ?? '',
      percent: json['percent'] ?? '',
      latestClass: json['latest_class'] ?? '',
      dailyRecords: records,
    );
  }
  
  // Helper methods to extract info from "percent" string
  // Format: [Total Classes Taken: 32, Present Count: 26, Absent Count: 6, Leave Count: 0] Percentage: 81.25%
  String get totalClasses {
    final match = RegExp(r'Total Classes Taken:\s*(\d+)').firstMatch(percent);
    return match?.group(1) ?? 'N/A';
  }
  
  String get presentCount {
    final match = RegExp(r'Present Count:\s*(\d+)').firstMatch(percent);
    return match?.group(1) ?? 'N/A';
  }

  String get absentCount {
    final match = RegExp(r'Absent Count:\s*(\d+)').firstMatch(percent);
    return match?.group(1) ?? 'N/A';
  }
  
  String get attendancePercentage {
    final match = RegExp(r'Percentage:\s*(.*)').firstMatch(percent);
    return match?.group(1)?.trim() ?? 'N/A';
  }
}
