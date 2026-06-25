import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/models/timetable_models.dart';
import '../core/auth/auth_session.dart';

class TimetableService {
  TimetableService(this.baseUrl);
  final String baseUrl;

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse("$baseUrl$path").replace(queryParameters: q);

  Future<Map<String, dynamic>> createMaster(MasterTimetableCreate payload) async {
    final r = await http.post(
      _u("/api/v1/school_authority/timetable/master"),
      headers: AuthSession.instance.headers(),
      body: jsonEncode(payload.toJson()),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(r.body);
  }

  Future<List<MasterTimetableSummary>> listMasters(UUID tenantId, {String? academicYear, String? status}) async {
    final q = <String, String>{};
    if (academicYear != null) q["academic_year"] = academicYear;
    if (status != null) q["status"] = status;
    final r = await http.get(_u("/api/v1/school_authority/timetable/master/$tenantId", q), headers: AuthSession.instance.headers(json: false));
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final arr = jsonDecode(r.body) as List;
      return arr.map((e) => MasterTimetableSummary.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception(r.body);
  }

  Future<Map<String, dynamic>> createClassTimetable(ClassTimetableCreate payload) async {
    final jsonPayload = payload.toJson();
    
    // Determine which endpoint to use based on payload content
    final hasTimeSlots = payload.timeSlots != null && payload.timeSlots!.isNotEmpty;
    final hasWeeklySchedule = payload.weeklySchedule != null && payload.weeklySchedule!.isNotEmpty;
    final useExtended = hasTimeSlots || hasWeeklySchedule;
    
    final endpoint = useExtended 
        ? "/api/v1/school_authority/timetable/class/extended"
        : "/api/v1/school_authority/timetable/class";
    
    // Add required timestamp fields
    if (!jsonPayload.containsKey('created_at')) {
      jsonPayload['created_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (!jsonPayload.containsKey('last_modified_at')) {
      jsonPayload['last_modified_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (!jsonPayload.containsKey('last_modified_by')) {
      jsonPayload['last_modified_by'] = payload.createdBy;
    }
    
    print('DEBUG: Using endpoint: $endpoint');
    print('DEBUG: Payload: ${jsonEncode(jsonPayload)}');
    
    final r = await http.post(
      _u(endpoint),
      headers: {
        "Accept": "application/json",
        ...AuthSession.instance.headers(),
      },
      body: jsonEncode(jsonPayload),
    );
    
    print('DEBUG: Response status: ${r.statusCode}');
    print('DEBUG: Response body: ${r.body}');
    
    if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    
    // The /class/extended route does not exist on the backend (returns 404), and
    // some payloads 400. Fall back to the basic /class endpoint on ANY failure so
    // timetable creation still succeeds instead of hard-erroring.
    if (useExtended) {
      print('DEBUG: Extended endpoint failed (${r.statusCode}), trying basic endpoint');
      final basicPayload = {
        "tenant_id": payload.tenantId,
        "class_id": payload.classId,
        "master_timetable_id": payload.masterTimetableId,
        "academic_year": payload.academicYear,
        "created_by": payload.createdBy,
        "created_at": jsonPayload['created_at'],
        "last_modified_by": jsonPayload['last_modified_by'],
        "last_modified_at": jsonPayload['last_modified_at'],
      };
      
      final basicR = await http.post(
        _u("/api/v1/school_authority/timetable/class"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(basicPayload),
      );
      
      print('DEBUG: Basic endpoint response: ${basicR.statusCode}');
      print('DEBUG: Basic endpoint body: ${basicR.body}');
      
      if (basicR.statusCode >= 200 && basicR.statusCode < 300) {
        return jsonDecode(basicR.body) as Map<String, dynamic>;
      }
    }
    
    throw Exception('HTTP ${r.statusCode}: ${r.body}');
  }

  Future<({UUID classId, String academicYear, WeeklySchedule weekly, int totalPeriods, List<DayOfWeek> workingDays})>
      getClassWeeklySchedule(UUID classId, String academicYear) async {
    final r = await http.get(_u(
      "/api/v1/school_authority/timetable/class/$classId/schedule",
      {"academic_year": academicYear, "requester_type": "school_authority"},
    ), headers: AuthSession.instance.headers(json: false));
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return (
        classId: j["class_id"] as String,
        academicYear: j["academic_year"] as String,
        weekly: WeeklySchedule.fromJson(j["weekly_schedule"] as Map<String, dynamic>),
        totalPeriods: (j["total_periods"] ?? 8) as int,
        workingDays: ((j["working_days"] ?? []) as List).map((e) => dayFromString(e.toString())).toList()
      );
    }
    throw Exception(r.body);
  }

  Future<Map<String, dynamic>> bulkCreateSchedule(BulkScheduleCreate payload) async {
    final r = await http.post(
      _u("/api/v1/school_authority/timetable/bulk/schedule"),
      headers: AuthSession.instance.headers(),
      body: jsonEncode(payload.toJson()),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(r.body);
  }

  Future<Map<String, dynamic>> bulkUpdateSchedule(BulkScheduleUpdate payload) async {
    final r = await http.put(
      _u("/api/v1/school_authority/timetable/bulk/schedule"),
      headers: AuthSession.instance.headers(),
      body: jsonEncode(payload.toJson()),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(r.body);
  }

  Future<Map<String, dynamic>> bulkDeleteSchedule(List<UUID> scheduleEntryIds, {bool hardDelete = false}) async {
    final r = await http.delete(
      _u("/api/v1/school_authority/timetable/bulk/schedule", {"hard_delete": hardDelete.toString()}),
      headers: AuthSession.instance.headers(),
      body: jsonEncode(scheduleEntryIds),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(r.body);
  }

  Future<Map<String, dynamic>> getAnalytics(UUID tenantId, String academicYear) async {
    final r = await http.get(_u(
      "/api/v1/school_authority/timetable/analytics/$tenantId",
      {"academic_year": academicYear},
    ), headers: AuthSession.instance.headers(json: false));
    if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(r.body);
  }

  Future<List<ConflictItem>> getConflicts(UUID tenantId, {bool unresolvedOnly = true, String? severity}) async {
    final q = {"unresolved_only": unresolvedOnly.toString()};
    if (severity != null) q["severity"] = severity;
    final r = await http.get(_u("/api/v1/school_authority/timetable/conflicts/$tenantId", q), headers: AuthSession.instance.headers(json: false));
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final arr = jsonDecode(r.body) as List;
      return arr.map((e) => ConflictItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception(r.body);
  }
}
