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
  static const double targetPercentage = 75.0;

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

  // --- New Helper Methods ---

  /// Parses the latestClass string (e.g., "2026-03-25 15:00-17:00") into a DateTime.
  DateTime? getParsedLatestDate() {
    if (latestClass.isEmpty || latestClass == 'N/A') return null;
    try {
      // Split by space to get the date part "2026-03-25"
      final datePart = latestClass.split(' ')[0];
      return DateTime.tryParse(datePart);
    } catch (e) {
      return null;
    }
  }

  /// Calculates how many classes to skip or attend to reach the target percentage.
  Map<String, dynamic>? getStatusData() {
    final pStr = presentCount;
    final tStr = totalClasses;
    if (pStr == 'N/A' || tStr == 'N/A') return null;

    final int p = int.tryParse(pStr) ?? 0;
    final int t = int.tryParse(tStr) ?? 0;
    if (t == 0) return null;

    final double currentPct = (p / t) * 100;
    final double target = targetPercentage / 100;

    if (currentPct > targetPercentage) {
      // How many can we skip?
      final int s = ((p / target) - t).floor();
      return {
        'isSkip': true,
        'isYellow': s == 0,
        'count': s,
        'message': s == 0 
            ? 'Safe for now, but skipping next class will put you below ${targetPercentage.toInt()}%'
            : 'You can skip next $s classes to reach ${targetPercentage.toInt()}%',
      };
    } else if (currentPct == targetPercentage) {
       return {
        'isSkip': false,
        'isYellow': true,
        'count': 0,
        'message': 'Exactly at ${targetPercentage.toInt()}% - Don\'t miss the next class',
      };
    } else {
      // How many more to attend?
      final int a = ((target * t - p) / (1 - target)).ceil();
      return {
        'isSkip': false,
        'isYellow': false,
        'count': a,
        'message': 'You need to take next $a classes to reach ${targetPercentage.toInt()}%',
      };
    }
  }
}
