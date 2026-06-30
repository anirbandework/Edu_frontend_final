// lib/features/rbac/widgets/role_templates.dart
//
// Ready-made role suggestions for ANY educational organisation — schools, colleges,
// coaching centres, private tutors. Each template is a role name + a sensible set of
// custom fields, grouped into a category, so an admin can add a common role in one tap
// instead of building it from scratch. Fields carry NO `key` — the backend assigns
// stable keys when the role is created. (Private tutors are usually the admin
// themselves, so they mainly need Student + Parent — both included.)
import 'package:flutter/material.dart';

class RoleTemplate {
  final String name;
  final String description;
  final String category;
  final IconData icon;

  /// Custom-field definitions: {label, type, required?, options?}. Types match
  /// kCustomFieldTypes (text / textarea / number / email / phone / date / select / bool).
  final List<Map<String, dynamic>> fields;

  const RoleTemplate({
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.fields,
  });
}

/// Display order of the category sections in the template picker.
const List<String> kRoleTemplateCategories = [
  'Students & Family',
  'Teaching',
  'Management & Leadership',
  'Office & Front Desk',
  'Support & Operations',
];

const List<RoleTemplate> kRoleTemplates = [
  // ── Students & Family ──────────────────────────────────────────────────────
  RoleTemplate(
    name: 'Student',
    description: 'Learners enrolled in a class or course.',
    category: 'Students & Family',
    icon: Icons.school_outlined,
    fields: [
      {
        'label': 'Grade / Class',
        'type': 'select',
        'required': true,
        'options': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
      },
      {'label': 'Section', 'type': 'text'},
      {'label': 'Roll number', 'type': 'text'},
      {'label': 'Date of birth', 'type': 'date'},
      {'label': 'Parent / Guardian name', 'type': 'text', 'required': true},
      {'label': 'Parent phone', 'type': 'phone', 'required': true},
      {'label': 'Address', 'type': 'textarea'},
      {
        'label': 'Blood group',
        'type': 'select',
        'options': ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
      },
    ],
  ),
  RoleTemplate(
    name: 'Parent / Guardian',
    description: 'Family members linked to a student.',
    category: 'Students & Family',
    icon: Icons.family_restroom_outlined,
    fields: [
      {
        'label': 'Relation to student',
        'type': 'select',
        'required': true,
        'options': ['Father', 'Mother', 'Guardian'],
      },
      {'label': 'Ward / Student name', 'type': 'text'},
      {'label': 'Occupation', 'type': 'text'},
      {'label': 'Alternate phone', 'type': 'phone'},
      {'label': 'Address', 'type': 'textarea'},
    ],
  ),

  // ── Teaching ───────────────────────────────────────────────────────────────
  RoleTemplate(
    name: 'Teacher',
    description: 'Faculty who teach classes and manage students.',
    category: 'Teaching',
    icon: Icons.cast_for_education_outlined,
    fields: [
      {'label': 'Highest qualification', 'type': 'text', 'required': true},
      {'label': 'Subjects taught', 'type': 'text', 'required': true},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
      {'label': 'Previous institution', 'type': 'text'},
    ],
  ),
  RoleTemplate(
    name: 'Professor / Lecturer',
    description: 'College / university teaching staff.',
    category: 'Teaching',
    icon: Icons.menu_book_outlined,
    fields: [
      {'label': 'Department', 'type': 'text', 'required': true},
      {
        'label': 'Designation',
        'type': 'select',
        'options': ['Lecturer', 'Assistant Professor', 'Associate Professor', 'Professor'],
      },
      {'label': 'Highest qualification', 'type': 'text', 'required': true},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Research area', 'type': 'text'},
    ],
  ),
  RoleTemplate(
    name: 'Sports Coach / PT',
    description: 'Physical training and sports instructors.',
    category: 'Teaching',
    icon: Icons.sports_outlined,
    fields: [
      {'label': 'Sport / Activity', 'type': 'text', 'required': true},
      {'label': 'Qualification / Certification', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Lab Assistant',
    description: 'Assists in practical / laboratory sessions.',
    category: 'Teaching',
    icon: Icons.biotech_outlined,
    fields: [
      {
        'label': 'Lab / Subject',
        'type': 'select',
        'required': true,
        'options': ['Physics', 'Chemistry', 'Biology', 'Computer', 'Language', 'Other'],
      },
      {'label': 'Qualification', 'type': 'text'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),

  // ── Management & Leadership ────────────────────────────────────────────────
  RoleTemplate(
    name: 'Principal',
    description: 'Head of the institution.',
    category: 'Management & Leadership',
    icon: Icons.workspace_premium_outlined,
    fields: [
      {'label': 'Highest qualification', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Vice Principal',
    description: 'Deputy head supporting the principal.',
    category: 'Management & Leadership',
    icon: Icons.supervisor_account_outlined,
    fields: [
      {'label': 'Highest qualification', 'type': 'text'},
      {'label': 'Section / Wing in charge', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Head of Department',
    description: 'Leads a subject or academic department.',
    category: 'Management & Leadership',
    icon: Icons.account_tree_outlined,
    fields: [
      {'label': 'Department', 'type': 'text', 'required': true},
      {'label': 'Highest qualification', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Dean',
    description: 'Head of a faculty / school in a college.',
    category: 'Management & Leadership',
    icon: Icons.account_balance_outlined,
    fields: [
      {'label': 'Faculty / School', 'type': 'text', 'required': true},
      {'label': 'Highest qualification', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
    ],
  ),
  RoleTemplate(
    name: 'Academic Coordinator',
    description: 'Coordinates classes, exams and schedules.',
    category: 'Management & Leadership',
    icon: Icons.event_note_outlined,
    fields: [
      {'label': 'Area of responsibility', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Center / Branch Manager',
    description: 'Runs a coaching centre or branch.',
    category: 'Management & Leadership',
    icon: Icons.store_outlined,
    fields: [
      {'label': 'Branch / Centre name', 'type': 'text', 'required': true},
      {'label': 'Contact phone', 'type': 'phone'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),

  // ── Office & Front Desk ────────────────────────────────────────────────────
  RoleTemplate(
    name: 'Receptionist / Front Desk',
    description: 'Greets visitors and handles enquiries.',
    category: 'Office & Front Desk',
    icon: Icons.support_agent_outlined,
    fields: [
      {
        'label': 'Shift',
        'type': 'select',
        'options': ['Morning', 'Afternoon', 'Evening', 'Full day'],
      },
      {'label': 'Languages known', 'type': 'text'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Admission Counsellor',
    description: 'Guides prospective students and admissions.',
    category: 'Office & Front Desk',
    icon: Icons.record_voice_over_outlined,
    fields: [
      {'label': 'Programs / Courses handled', 'type': 'text'},
      {'label': 'Contact phone', 'type': 'phone'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Accountant',
    description: 'Office / administrative finance staff.',
    category: 'Office & Front Desk',
    icon: Icons.calculate_outlined,
    fields: [
      {'label': 'Designation', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Clerk / Office Staff',
    description: 'Records, files and day-to-day office work.',
    category: 'Office & Front Desk',
    icon: Icons.description_outlined,
    fields: [
      {'label': 'Department / Section', 'type': 'text'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Registrar',
    description: 'Owns records, enrolment and certificates (college).',
    category: 'Office & Front Desk',
    icon: Icons.how_to_reg_outlined,
    fields: [
      {'label': 'Highest qualification', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),

  // ── Support & Operations ───────────────────────────────────────────────────
  RoleTemplate(
    name: 'Librarian',
    description: 'Manages the library and resources.',
    category: 'Support & Operations',
    icon: Icons.local_library_outlined,
    fields: [
      {'label': 'Qualification', 'type': 'text'},
      {'label': 'Date of joining', 'type': 'date'},
      {
        'label': 'Shift',
        'type': 'select',
        'options': ['Morning', 'Afternoon', 'Evening'],
      },
    ],
  ),
  RoleTemplate(
    name: 'Lab Technician',
    description: 'Maintains lab equipment and supplies.',
    category: 'Support & Operations',
    icon: Icons.science_outlined,
    fields: [
      {
        'label': 'Lab / Subject',
        'type': 'select',
        'required': true,
        'options': ['Physics', 'Chemistry', 'Biology', 'Computer', 'Other'],
      },
      {'label': 'Qualification', 'type': 'text'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Warden / Hostel In-charge',
    description: 'Looks after a residential hostel block.',
    category: 'Support & Operations',
    icon: Icons.night_shelter_outlined,
    fields: [
      {'label': 'Hostel / Block', 'type': 'text', 'required': true},
      {
        'label': 'Hostel type',
        'type': 'select',
        'options': ['Boys', 'Girls', 'Mixed'],
      },
      {'label': 'Contact phone', 'type': 'phone'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Nurse / Medical Staff',
    description: 'Runs the infirmary / first aid.',
    category: 'Support & Operations',
    icon: Icons.medical_services_outlined,
    fields: [
      {'label': 'Qualification', 'type': 'text', 'required': true},
      {'label': 'Registration / License no.', 'type': 'text'},
      {
        'label': 'Shift',
        'type': 'select',
        'options': ['Morning', 'Afternoon', 'Evening', 'On call'],
      },
      {'label': 'Contact phone', 'type': 'phone'},
    ],
  ),
  RoleTemplate(
    name: 'Transport / Driver',
    description: 'Bus drivers and transport staff.',
    category: 'Support & Operations',
    icon: Icons.directions_bus_outlined,
    fields: [
      {'label': 'License number', 'type': 'text', 'required': true},
      {'label': 'Vehicle number', 'type': 'text'},
      {'label': 'Route', 'type': 'text'},
      {'label': 'Contact phone', 'type': 'phone', 'required': true},
    ],
  ),
  RoleTemplate(
    name: 'Security Guard',
    description: 'Campus security and gate duty.',
    category: 'Support & Operations',
    icon: Icons.security_outlined,
    fields: [
      {
        'label': 'Shift',
        'type': 'select',
        'options': ['Day', 'Night', 'Rotational'],
      },
      {'label': 'Contact phone', 'type': 'phone'},
      {'label': 'ID / License no.', 'type': 'text'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'Support Staff / Helper',
    description: 'Housekeeping, peon and general help.',
    category: 'Support & Operations',
    icon: Icons.cleaning_services_outlined,
    fields: [
      {'label': 'Duty / Work', 'type': 'text'},
      {
        'label': 'Shift',
        'type': 'select',
        'options': ['Morning', 'Afternoon', 'Evening', 'Full day'],
      },
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
  RoleTemplate(
    name: 'IT Admin',
    description: 'Maintains systems, devices and network.',
    category: 'Support & Operations',
    icon: Icons.computer_outlined,
    fields: [
      {'label': 'Skills / Systems handled', 'type': 'text'},
      {'label': 'Years of experience', 'type': 'number'},
      {'label': 'Contact phone', 'type': 'phone'},
      {'label': 'Date of joining', 'type': 'date'},
    ],
  ),
];
