typedef UUID = String;

enum DayOfWeek {
  monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

enum PeriodType {
  regular, break_, lunch, assembly, sports, library, lab, exam, activity, study_hall
}

enum TimetableStatus { draft, active, suspended, archived, pending_approval }

String dayToString(DayOfWeek d) => d.name;
DayOfWeek dayFromString(String s) => DayOfWeek.values.firstWhere((e) => e.name == s.toLowerCase());

String periodTypeToString(PeriodType p) => p == PeriodType.break_ ? "break" : p.name;
PeriodType periodTypeFromString(String s) =>
    s == "break" ? PeriodType.break_ : PeriodType.values.firstWhere((e) => e.name == s.toLowerCase());

String statusToString(TimetableStatus s) => s.name;

class MasterTimetableCreate {
  final UUID tenantId;
  final UUID createdBy;
  final String timetableName;
  final String? description;
  final String academicYear;
  final String? term;
  final String effectiveFrom;      // ISO date yyyy-MM-dd
  final String? effectiveUntil;    // ISO date
  final int totalPeriodsPerDay;
  final String schoolStartTime;    // "09:00:00"
  final String schoolEndTime;      // "16:00:00"
  final int periodDuration;        // minutes
  final int breakDuration;         // minutes
  final int lunchDuration;         // minutes
  final List<DayOfWeek> workingDays;
  final bool autoGeneratePeriods;

  MasterTimetableCreate({
    required this.tenantId,
    required this.createdBy,
    required this.timetableName,
    this.description,
    required this.academicYear,
    this.term,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.totalPeriodsPerDay = 8,
    required this.schoolStartTime,
    required this.schoolEndTime,
    this.periodDuration = 45,
    this.breakDuration = 15,
    this.lunchDuration = 60,
    required this.workingDays,
    this.autoGeneratePeriods = true,
  });

  Map<String, dynamic> toJson() => {
    "tenant_id": tenantId,
    "created_by": createdBy,
    "timetable_name": timetableName,
    "description": description,
    "academic_year": academicYear,
    "term": term,
    "effective_from": effectiveFrom,
    "effective_until": effectiveUntil,
    "total_periods_per_day": totalPeriodsPerDay,
    "school_start_time": schoolStartTime,
    "school_end_time": schoolEndTime,
    "period_duration": periodDuration,
    "break_duration": breakDuration,
    "lunch_duration": lunchDuration,
    "working_days": workingDays.map(dayToString).toList(),
    "auto_generate_periods": autoGeneratePeriods,
  };
}

class MasterTimetableSummary {
  final UUID id;
  final String timetableName;
  final String? description;
  final String academicYear;
  final String? term;
  final String? effectiveFrom;
  final String? effectiveUntil;
  final String? schoolStartTime;
  final String? schoolEndTime;
  final int totalPeriodsPerDay;
  final TimetableStatus status;
  final bool isDefault;
  final List<DayOfWeek> workingDays;
  final int totalClasses;
  final int totalTeachers;
  final int totalScheduleEntries;
  final String createdAt;

  MasterTimetableSummary({
    required this.id,
    required this.timetableName,
    this.description,
    required this.academicYear,
    this.term,
    this.effectiveFrom,
    this.effectiveUntil,
    this.schoolStartTime,
    this.schoolEndTime,
    required this.totalPeriodsPerDay,
    required this.status,
    required this.isDefault,
    required this.workingDays,
    required this.totalClasses,
    required this.totalTeachers,
    required this.totalScheduleEntries,
    required this.createdAt,
  });

  factory MasterTimetableSummary.fromJson(Map<String, dynamic> j) => MasterTimetableSummary(
    id: j["id"] as String,
    timetableName: j["timetable_name"] ?? "",
    description: j["description"],
    academicYear: j["academic_year"] ?? "",
    term: j["term"],
    effectiveFrom: j["effective_from"],
    effectiveUntil: j["effective_until"],
    schoolStartTime: j["school_start_time"],
    schoolEndTime: j["school_end_time"],
    totalPeriodsPerDay: (j["total_periods_per_day"] ?? 8) as int,
    status: TimetableStatus.values.firstWhere(
      (e) => e.name == (j["status"] ?? "draft"),
      orElse: () => TimetableStatus.draft,
    ),
    isDefault: (j["is_default"] ?? false) as bool,
    workingDays: ((j["working_days"] ?? []) as List).map((e) => dayFromString(e.toString())).toList(),
    totalClasses: (j["total_classes"] ?? 0) as int,
    totalTeachers: (j["total_teachers"] ?? 0) as int,
    totalScheduleEntries: (j["total_schedule_entries"] ?? 0) as int,
    createdAt: j["created_at"] ?? "",
  );
}

class ClassTimetableCreate {
  final UUID tenantId;
  final UUID classId;
  final UUID masterTimetableId;
  final String academicYear;
  final String? term;
  final String? className;
  final String? gradeLevel;
  final UUID createdBy;
  final String? createdAtIso;
  final String? lastModifiedBy;
  final String? lastModifiedAtIso;
  final List<Map<String, dynamic>>? timeSlots;
  final Map<String, List<Map<String, dynamic>>>? weeklySchedule;

  ClassTimetableCreate({
    required this.tenantId,
    required this.classId,
    required this.masterTimetableId,
    required this.academicYear,
    this.term,
    this.className,
    this.gradeLevel,
    required this.createdBy,
    this.createdAtIso,
    this.lastModifiedBy,
    this.lastModifiedAtIso,
    this.timeSlots,
    this.weeklySchedule,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      "tenant_id": tenantId,
      "class_id": classId,
      "master_timetable_id": masterTimetableId,
      "academic_year": academicYear,
      "created_by": createdBy,
    };
    
    if (term != null) json["term"] = term;
    if (className != null) json["class_name"] = className;
    if (gradeLevel != null) json["grade_level"] = gradeLevel;
    if (createdAtIso != null) json["created_at"] = createdAtIso;
    if (lastModifiedBy != null) json["last_modified_by"] = lastModifiedBy;
    if (lastModifiedAtIso != null) json["last_modified_at"] = lastModifiedAtIso;
    if (timeSlots != null) json["time_slots"] = timeSlots;
    if (weeklySchedule != null) json["weekly_schedule"] = weeklySchedule;
    
    return json;
  }
}

class ScheduleCell {
  final int periodNumber;
  final String periodName;
  final PeriodType periodType;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final String? subjectName;
  final String? subjectCode;
  final String? roomNumber;
  final String? teacherName;
  final UUID? scheduleEntryId;
  final UUID? periodId;

  ScheduleCell({
    required this.periodNumber,
    required this.periodName,
    required this.periodType,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.subjectName,
    this.subjectCode,
    this.roomNumber,
    this.teacherName,
    this.scheduleEntryId,
    this.periodId,
  });

  factory ScheduleCell.fromJson(Map<String, dynamic> j) => ScheduleCell(
    periodNumber: (j["period_number"] ?? 0) as int,
    periodName: j["period_name"] ?? "",
    periodType: periodTypeFromString(j["period_type"] ?? "regular"),
    startTime: j["start_time"] ?? "",
    endTime: j["end_time"] ?? "",
    durationMinutes: (j["duration_minutes"] ?? 0) as int,
    subjectName: j["subject_name"],
    subjectCode: j["subject_code"],
    roomNumber: j["room_number"],
    teacherName: j["teacher_name"],
    scheduleEntryId: j["schedule_entry_id"],
    periodId: j["period_id"],
  );
}

class WeeklySchedule {
  final Map<DayOfWeek, List<ScheduleCell>> days;
  WeeklySchedule(this.days);

  factory WeeklySchedule.fromJson(Map<String, dynamic> j) {
    final map = <DayOfWeek, List<ScheduleCell>>{};
    for (final k in j.keys) {
      final day = dayFromString(k);
      final list = (j[k] as List?)?.map((e) => ScheduleCell.fromJson(e as Map<String, dynamic>)).toList() ?? <ScheduleCell>[];
      map[day] = list;
    }
    return WeeklySchedule(map);
  }
}

class BulkScheduleCreate {
  final UUID tenantId;
  final List<Map<String, dynamic>> scheduleEntries;
  BulkScheduleCreate({required this.tenantId, required this.scheduleEntries});
  Map<String, dynamic> toJson() => {"tenant_id": tenantId, "schedule_entries": scheduleEntries};
}

class BulkScheduleUpdate {
  final List<Map<String, dynamic>> updates;
  BulkScheduleUpdate(this.updates);
  Map<String, dynamic> toJson() => {"updates": updates};
}

class ConflictItem {
  final UUID id;
  final String conflictType;
  final String severity;
  final String title;
  final String description;
  final DayOfWeek? dayOfWeek;
  final int? periodNumber;
  final String? roomNumber;
  final bool isResolved;
  final String createdAt;

  ConflictItem({
    required this.id,
    required this.conflictType,
    required this.severity,
    required this.title,
    required this.description,
    this.dayOfWeek,
    this.periodNumber,
    this.roomNumber,
    required this.isResolved,
    required this.createdAt,
  });

  factory ConflictItem.fromJson(Map<String, dynamic> j) => ConflictItem(
    id: j["id"],
    conflictType: j["conflict_type"] ?? "",
    severity: j["severity"] ?? "low",
    title: j["title"] ?? "",
    description: j["description"] ?? "",
    dayOfWeek: j["day_of_week"] != null ? dayFromString(j["day_of_week"]) : null,
    periodNumber: j["period_number"],
    roomNumber: j["room_number"],
    isResolved: (j["is_resolved"] ?? false) as bool,
    createdAt: j["created_at"] ?? "",
  );
}
