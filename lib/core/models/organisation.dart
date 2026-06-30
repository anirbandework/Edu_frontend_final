// lib/core/models/organisation.dart
class Organisation {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String headName;
  final bool isActive;
  final double annualTuition;
  final double registrationFee;
  final int totalStudents;
  final int totalTeachers;
  final int totalStaff;
  final int maximumCapacity;
  final int currentEnrollment;
  final String orgType;
  final List<String> levelsOffered;
  final DateTime? academicYearStart;
  final DateTime? academicYearEnd;
  final int? establishedYear;
  final String? accreditation;
  final String languageOfInstruction;
  final String? code;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Organisation({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.headName,
    this.isActive = true,
    this.annualTuition = 0.0,
    this.registrationFee = 0.0,
    this.totalStudents = 0,
    this.totalTeachers = 0,
    this.totalStaff = 0,
    this.maximumCapacity = 0,
    this.currentEnrollment = 0,
    this.orgType = 'School',
    this.levelsOffered = const [],
    this.academicYearStart,
    this.academicYearEnd,
    this.establishedYear,
    this.accreditation,
    this.languageOfInstruction = 'English',
    this.code,
    this.createdAt,
    this.updatedAt,
  });

  factory Organisation.fromJson(Map<String, dynamic> json) {
    return Organisation(
      id: json['id']?.toString() ?? '',
      name: _parseToString(json['name']),
      address: _parseToString(json['address']),
      phone: _parseToString(json['phone']),
      email: _parseToString(json['email']),
      headName: _parseToString(json['head_name']),
      isActive: _parseToBool(json['is_active']),
      annualTuition: _parseToDouble(json['annual_tuition']),
      registrationFee: _parseToDouble(json['registration_fee']),
      totalStudents: _parseToInt(json['total_students']),
      totalTeachers: _parseToInt(json['total_teachers']),
      totalStaff: _parseToInt(json['total_staff']),
      maximumCapacity: _parseToInt(json['maximum_capacity']),
      currentEnrollment: _parseToInt(json['current_enrollment']),
      orgType: json['org_type']?.toString() ?? 'School',
      levelsOffered: _parseToStringList(json['levels_offered']),
      academicYearStart: _parseToDateTime(json['academic_year_start']),
      academicYearEnd: _parseToDateTime(json['academic_year_end']),
      establishedYear: _parseToIntNullable(json['established_year']),
      accreditation: json['accreditation']?.toString(),
      languageOfInstruction: json['language_of_instruction']?.toString() ?? 'English',
      code: json['code']?.toString(),
      createdAt: _parseToDateTime(json['created_at']),
      updatedAt: _parseToDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'head_name': headName,
      'is_active': isActive,
      'annual_tuition': annualTuition,
      'registration_fee': registrationFee,
      'total_students': totalStudents,
      'total_teachers': totalTeachers,
      'total_staff': totalStaff,
      'maximum_capacity': maximumCapacity,
      'current_enrollment': currentEnrollment,
      'org_type': orgType,
      'levels_offered': levelsOffered,
      'academic_year_start': academicYearStart?.toIso8601String(),
      'academic_year_end': academicYearEnd?.toIso8601String(),
      'established_year': establishedYear,
      'accreditation': accreditation,
      'language_of_instruction': languageOfInstruction,
      'code': code,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Helper methods for safe parsing
  static String _parseToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static bool _parseToBool(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value == 1;
    return true;
  }

  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  static int? _parseToIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static DateTime? _parseToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static List<String> _parseToStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  // Utility getters
  double get capacityUtilization {
    if (maximumCapacity == 0) return 0.0;
    return (currentEnrollment / maximumCapacity * 100);
  }

  double get studentTeacherRatio {
    if (totalTeachers == 0) return 0.0;
    return totalStudents / totalTeachers;
  }

  bool get isOverCapacity => currentEnrollment > maximumCapacity;

  String get statusText => isActive ? 'Active' : 'Inactive';

  // Copy with method for updates
  Organisation copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? headName,
    bool? isActive,
    double? annualTuition,
    double? registrationFee,
    int? totalStudents,
    int? totalTeachers,
    int? totalStaff,
    int? maximumCapacity,
    int? currentEnrollment,
    String? orgType,
    List<String>? levelsOffered,
    DateTime? academicYearStart,
    DateTime? academicYearEnd,
    int? establishedYear,
    String? accreditation,
    String? languageOfInstruction,
    String? code,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Organisation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      headName: headName ?? this.headName,
      isActive: isActive ?? this.isActive,
      annualTuition: annualTuition ?? this.annualTuition,
      registrationFee: registrationFee ?? this.registrationFee,
      totalStudents: totalStudents ?? this.totalStudents,
      totalTeachers: totalTeachers ?? this.totalTeachers,
      totalStaff: totalStaff ?? this.totalStaff,
      maximumCapacity: maximumCapacity ?? this.maximumCapacity,
      currentEnrollment: currentEnrollment ?? this.currentEnrollment,
      orgType: orgType ?? this.orgType,
      levelsOffered: levelsOffered ?? this.levelsOffered,
      academicYearStart: academicYearStart ?? this.academicYearStart,
      academicYearEnd: academicYearEnd ?? this.academicYearEnd,
      establishedYear: establishedYear ?? this.establishedYear,
      accreditation: accreditation ?? this.accreditation,
      languageOfInstruction: languageOfInstruction ?? this.languageOfInstruction,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
