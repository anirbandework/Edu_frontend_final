// lib/features/admin/widgets/tenant_create_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class TenantCreateDialog extends StatefulWidget {
  final VoidCallback onTenantCreated;

  const TenantCreateDialog({
    super.key,
    required this.onTenantCreated,
  });

  @override
  State<TenantCreateDialog> createState() => _TenantCreateDialogState();
}

class _TenantCreateDialogState extends State<TenantCreateDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isLoading = false;

  // Basic Info
  final _schoolNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _principalNameController = TextEditingController();
  String _schoolType = 'K-12';
  String _languageOfInstruction = 'English';

  // Academic Info
  final _establishedYearController = TextEditingController();
  final _accreditationController = TextEditingController();
  DateTime? _academicYearStart;
  DateTime? _academicYearEnd;
  final List<String> _selectedGradeLevels = [];

  // Capacity & Financial
  final _maximumCapacityController = TextEditingController();
  final _currentEnrollmentController = TextEditingController();
  final _totalStudentsController = TextEditingController();
  final _totalTeachersController = TextEditingController();
  final _totalStaffController = TextEditingController();
  final _annualTuitionController = TextEditingController();
  final _registrationFeeController = TextEditingController();

  final List<String> _schoolTypes = ['K-12', 'Elementary', 'Middle School', 'High School', 'University', 'Preschool'];
  final List<String> _languages = ['English', 'Hindi', 'Tamil', 'Telugu', 'Marathi', 'Bengali', 'Other'];
  final List<String> _gradeLevels = ['Pre-K', 'K', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Set default dates
    _academicYearStart = DateTime(DateTime.now().year, 6, 1); // June 1st
    _academicYearEnd = DateTime(DateTime.now().year + 1, 5, 31); // May 31st next year
  }

  @override
  void dispose() {
    _tabController.dispose();
    _schoolNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _principalNameController.dispose();
    _establishedYearController.dispose();
    _accreditationController.dispose();
    _maximumCapacityController.dispose();
    _currentEnrollmentController.dispose();
    _totalStudentsController.dispose();
    _totalTeachersController.dispose();
    _totalStaffController.dispose();
    _annualTuitionController.dispose();
    _registrationFeeController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Turn a FastAPI error detail (a string, or a 422 list of {loc, msg}) into a
  /// readable message instead of dumping raw JSON at the user.
  String _formatDetail(dynamic detail) {
    if (detail is String) return detail;
    if (detail is List) {
      final parts = detail.map((e) {
        if (e is Map) {
          final loc = (e['loc'] is List && (e['loc'] as List).isNotEmpty)
              ? (e['loc'] as List).last.toString()
              : '';
          final msg = (e['msg'] ?? '').toString();
          return loc.isEmpty ? msg : '$loc: $msg';
        }
        return e.toString();
      }).where((s) => s.isNotEmpty);
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return detail?.toString() ?? 'Failed to create school';
  }

  Future<void> _createTenant() async {
    // Validate the visible Form fields (Basic Info required fields).
    final formOk = _formKey.currentState?.validate() ?? false;

    // Cross-tab required checks — Form validators on inactive tabs don't fire
    // reliably, so enforce the compulsory numeric/list fields explicitly and
    // jump the user to the tab that needs attention.
    final maxCap = int.tryParse(_maximumCapacityController.text.trim());
    if (maxCap == null || maxCap <= 0) {
      _tabController.animateTo(2);
      _showError('Maximum capacity is required and must be greater than 0.');
      return;
    }
    if (_selectedGradeLevels.isEmpty) {
      _tabController.animateTo(1);
      setState(() {}); // surface the inline "required" hint
      _showError('Select at least one grade level offered.');
      return;
    }
    int? establishedYear;
    final yearText = _establishedYearController.text.trim();
    if (yearText.isNotEmpty) {
      establishedYear = int.tryParse(yearText);
      final thisYear = DateTime.now().year;
      if (establishedYear == null || establishedYear < 1800 || establishedYear > thisYear) {
        _tabController.animateTo(1);
        _showError('Established year must be between 1800 and $thisYear (or leave it blank).');
        return;
      }
    }
    if (!formOk) {
      _tabController.animateTo(0); // the required Basic-Info fields are here
      _showError('Please fill all required fields.');
      return;
    }

    setState(() => _isLoading = true);

    final tenantData = {
      'school_name': _schoolNameController.text.trim(),
      'address': _addressController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'principal_name': _principalNameController.text.trim(),
      'school_type': _schoolType,
      'language_of_instruction': _languageOfInstruction,
      // Only send established_year when provided (backend requires >= 1800).
      if (establishedYear != null) 'established_year': establishedYear,
      'accreditation': _accreditationController.text.trim(),
      'academic_year_start': _academicYearStart?.toIso8601String(),
      'academic_year_end': _academicYearEnd?.toIso8601String(),
      'grade_levels': _selectedGradeLevels,
      'maximum_capacity': maxCap,
      'current_enrollment': int.tryParse(_currentEnrollmentController.text) ?? 0,
      'total_students': int.tryParse(_totalStudentsController.text) ?? 0,
      'total_teachers': int.tryParse(_totalTeachersController.text) ?? 0,
      'total_staff': int.tryParse(_totalStaffController.text) ?? 0,
      'annual_tuition': double.tryParse(_annualTuitionController.text) ?? 0.0,
      'registration_fee': double.tryParse(_registrationFeeController.text) ?? 0.0,
      'is_active': true,
    };

    try {
      // Admin self-service create (the /api/v1/tenants router is super-admin
      // only). This endpoint stamps the school's owner = the creating admin.
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/auth/schools'),
        headers: AuthSession.instance.headers(),
        body: json.encode(tenantData),
      );

      if (response.statusCode == 200) {
        widget.onTenantCreated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('School "${_schoolNameController.text}" created successfully'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        _showError(_formatDetail(errorData['detail']));
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.add_business, color: Sa.accent, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add new school',
                      style: Sa.cardTitle.copyWith(fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Tab Bar (scrollable so labels never overflow on a phone)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Sa.accent,
              unselectedLabelColor: AppTheme.neutral500,
              indicatorColor: Sa.accent,
              labelStyle: Sa.value,
              tabs: const [
                Tab(text: 'Basic'),
                Tab(text: 'Academic'),
                Tab(text: 'Capacity & Finance'),
              ],
            ),

            const Divider(height: 1),

            // Tab Content
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(),
                    _buildAcademicTab(),
                    _buildCapacityFinanceTab(),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.neutral700,
                        minimumSize: const Size(0, 48),
                        side: BorderSide(color: Sa.stroke.withValues(alpha: 0.8)),
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadius12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SaPrimaryButton(
                      label: 'Create school',
                      icon: Icons.check,
                      busy: _isLoading,
                      expand: true,
                      onPressed: _isLoading ? null : _createTenant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lay [children] out as a Row on wide screens and a Column on phones
  /// (< 600px). Spacing is inserted automatically between fields.
  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 600;
        if (stack) {
          final col = <Widget>[];
          for (var i = 0; i < children.length; i++) {
            col.add(children[i]);
            if (i != children.length - 1) {
              col.add(const SizedBox(height: 16));
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: col,
          );
        }
        final row = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          row.add(Expanded(child: children[i]));
          if (i != children.length - 1) {
            row.add(const SizedBox(width: 16));
          }
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: row);
      },
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _responsiveFields([
            TextFormField(
              controller: _schoolNameController,
              decoration: const InputDecoration(
                labelText: 'School Name *',
                hintText: 'Enter school name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty == true ? 'School name is required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _schoolType,
              decoration: const InputDecoration(
                labelText: 'School Type',
                border: OutlineInputBorder(),
              ),
              items: _schoolTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) => setState(() => _schoolType = value!),
            ),
          ]),

          const SizedBox(height: 16),

          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address *',
              hintText: 'Enter complete address',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            validator: (value) => value?.isEmpty == true ? 'Address is required' : null,
          ),
          
          const SizedBox(height: 16),

          _responsiveFields([
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                hintText: '+91 98765 43210',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty == true ? 'Phone number is required' : null,
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                hintText: 'school@example.com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty == true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value!)) {
                  return 'Enter valid email';
                }
                return null;
              },
            ),
          ]),

          const SizedBox(height: 16),

          _responsiveFields([
            TextFormField(
              controller: _principalNameController,
              decoration: const InputDecoration(
                labelText: 'Principal Name *',
                hintText: 'Enter principal name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty == true ? 'Principal name is required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _languageOfInstruction,
              decoration: const InputDecoration(
                labelText: 'Language of Instruction',
                border: OutlineInputBorder(),
              ),
              items: _languages.map((lang) {
                return DropdownMenuItem(value: lang, child: Text(lang));
              }).toList(),
              onChanged: (value) =>
                  setState(() => _languageOfInstruction = value!),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildAcademicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _responsiveFields([
            TextFormField(
              controller: _establishedYearController,
              decoration: const InputDecoration(
                labelText: 'Established Year (optional)',
                hintText: 'e.g. 1995',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final t = (value ?? '').trim();
                if (t.isEmpty) return null; // optional
                final y = int.tryParse(t);
                if (y == null || y < 1800 || y > DateTime.now().year) {
                  return '1800–${DateTime.now().year}';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _accreditationController,
              decoration: const InputDecoration(
                labelText: 'Accreditation',
                hintText: 'CBSE, ICSE, IB, etc.',
                border: OutlineInputBorder(),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          _responsiveFields([
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _academicYearStart ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _academicYearStart = date);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Academic Year Start',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _academicYearStart != null
                      ? '${_academicYearStart!.day}/${_academicYearStart!.month}/${_academicYearStart!.year}'
                      : 'Select date',
                ),
              ),
            ),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _academicYearEnd ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _academicYearEnd = date);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Academic Year End',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _academicYearEnd != null
                      ? '${_academicYearEnd!.day}/${_academicYearEnd!.month}/${_academicYearEnd!.year}'
                      : 'Select date',
                ),
              ),
            ),
          ]),

          const SizedBox(height: 16),
          
          Text(
            'Grade Levels Offered *',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _selectedGradeLevels.isEmpty
                ? 'Select at least one grade level'
                : '${_selectedGradeLevels.length} selected',
            style: AppTheme.bodySmall.copyWith(
              color: _selectedGradeLevels.isEmpty ? AppTheme.error : AppTheme.neutral500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _gradeLevels.map((grade) {
              final isSelected = _selectedGradeLevels.contains(grade);
              return FilterChip(
                label: Text('Grade $grade'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGradeLevels.add(grade);
                    } else {
                      _selectedGradeLevels.remove(grade);
                    }
                  });
                },
                selectedColor: AppTheme.greenPrimary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.neutral700,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityFinanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capacity Information',
            style: Sa.cardTitle.copyWith(color: Sa.accent),
          ),
          const SizedBox(height: 16),

          _responsiveFields([
            TextFormField(
              controller: _maximumCapacityController,
              decoration: const InputDecoration(
                labelText: 'Maximum Capacity *',
                hintText: '1000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final n = int.tryParse((value ?? '').trim());
                if (n == null || n <= 0) return 'Required, must be > 0';
                return null;
              },
            ),
            TextFormField(
              controller: _currentEnrollmentController,
              decoration: const InputDecoration(
                labelText: 'Current Enrollment',
                hintText: '850',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ]),

          const SizedBox(height: 16),

          _responsiveFields([
            TextFormField(
              controller: _totalStudentsController,
              decoration: const InputDecoration(
                labelText: 'Total Students',
                hintText: '850',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _totalTeachersController,
              decoration: const InputDecoration(
                labelText: 'Total Teachers',
                hintText: '45',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _totalStaffController,
              decoration: const InputDecoration(
                labelText: 'Total Staff',
                hintText: '15',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ]),

          const SizedBox(height: 24),

          Text(
            'Financial Information',
            style: Sa.cardTitle.copyWith(color: Sa.accent),
          ),
          const SizedBox(height: 16),

          _responsiveFields([
            TextFormField(
              controller: _annualTuitionController,
              decoration: const InputDecoration(
                labelText: 'Annual Tuition (₹)',
                hintText: '50000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _registrationFeeController,
              decoration: const InputDecoration(
                labelText: 'Registration Fee (₹)',
                hintText: '5000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ]),
        ],
      ),
    );
  }
}
