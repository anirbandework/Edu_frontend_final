// lib/core/models/student.dart
class Student {
  final String id;
  final String? tenantId;
  final String studentId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? address;
  final String? admissionNumber;
  final String? rollNumber;
  final int gradeLevel;
  final String? section;
  final String? academicYear;
  final String status;
  final Map<String, dynamic>? parentInfo;
  final Map<String, dynamic>? healthMedicalInfo;
  final Map<String, dynamic>? emergencyInformation;
  final Map<String, dynamic>? behavioralDisciplinary;
  final Map<String, dynamic>? extendedAcademicInfo;
  final Map<String, dynamic>? enrollmentDetails;
  final Map<String, dynamic>? financialInfo;
  final Map<String, dynamic>? extracurricularSocial;
  final Map<String, dynamic>? attendanceEngagement;
  final Map<String, dynamic>? additionalMetadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Student({
    required this.id,
    this.tenantId,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.address,
    this.admissionNumber,
    this.rollNumber,
    required this.gradeLevel,
    this.section,
    this.academicYear,
    this.status = 'active',
    this.parentInfo,
    this.healthMedicalInfo,
    this.emergencyInformation,
    this.behavioralDisciplinary,
    this.extendedAcademicInfo,
    this.enrollmentDetails,
    this.financialInfo,
    this.extracurricularSocial,
    this.attendanceEngagement,
    this.additionalMetadata,
    this.createdAt,
    this.updatedAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      // A "student" is now a row in the members table. `id` is the member UUID
      // (the backend also returns the same value as `member_id`), and `student_id`
      // is the member's staff_id HRID (e.g. "STU001"). grade_level/section come
      // back out of members.profile and are transitional — the authoritative
      // grade/section is the student's enrolment class. Response keys are
      // unchanged, so this mapping stays identical to the legacy contract.
      id: json['id'] ?? json['member_id'] ?? '',
      tenantId: json['tenant_id'],
      studentId: json['student_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.tryParse(json['date_of_birth']) 
          : null,
      address: json['address'],
      admissionNumber: json['admission_number'],
      rollNumber: json['roll_number'],
      gradeLevel: json['grade_level'] ?? 0,
      section: json['section'],
      academicYear: json['academic_year'],
      status: json['status'] ?? 'active',
      parentInfo: json['parent_info'],
      healthMedicalInfo: json['health_medical_info'],
      emergencyInformation: json['emergency_information'],
      behavioralDisciplinary: json['behavioral_disciplinary'],
      extendedAcademicInfo: json['extended_academic_info'],
      enrollmentDetails: json['enrollment_details'],
      financialInfo: json['financial_info'],
      extracurricularSocial: json['extracurricular_social'],
      attendanceEngagement: json['attendance_engagement'],
      additionalMetadata: json['additional_metadata'],
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'student_id': studentId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'address': address,
      'admission_number': admissionNumber,
      'roll_number': rollNumber,
      'grade_level': gradeLevel,
      'section': section,
      'academic_year': academicYear,
      'status': status,
      'parent_info': parentInfo,
      'health_medical_info': healthMedicalInfo,
      'emergency_information': emergencyInformation,
      'behavioral_disciplinary': behavioralDisciplinary,
      'extended_academic_info': extendedAcademicInfo,
      'enrollment_details': enrollmentDetails,
      'financial_info': financialInfo,
      'extracurricular_social': extracurricularSocial,
      'attendance_engagement': attendanceEngagement,
      'additional_metadata': additionalMetadata,
    };
  }

  String get fullName => '$firstName $lastName';
  
  bool get isActive => status.toLowerCase() == 'active';
  
  String get statusText {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'suspended':
        return 'Suspended';
      case 'graduated':
        return 'Graduated';
      case 'transferred':
        return 'Transferred';
      default:
        return 'Unknown';
    }
  }

  String get gradeText => 'Grade $gradeLevel${section != null ? '-$section' : ''}';

  int get age {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    final age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      return age - 1;
    }
    return age;
  }
}
