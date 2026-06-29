// lib/features/admin/widgets/tenant_edit_dialog.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/tenant.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class TenantEditDialog extends StatefulWidget {
  final Tenant tenant;
  final VoidCallback onTenantUpdated;

  const TenantEditDialog({
    super.key,
    required this.tenant,
    required this.onTenantUpdated,
  });

  @override
  State<TenantEditDialog> createState() => _TenantEditDialogState();
}

class _TenantEditDialogState extends State<TenantEditDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isLoading = false;

  // Controllers initialized with existing data
  late final TextEditingController _schoolNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _principalNameController;
  late String _schoolType;
  late String _languageOfInstruction;
  late bool _isActive;

  // Academic Info
  late final TextEditingController _establishedYearController;
  late final TextEditingController _accreditationController;
  DateTime? _academicYearStart;
  DateTime? _academicYearEnd;
  late final List<String> _selectedGradeLevels;

  // Capacity & Financial
  late final TextEditingController _maximumCapacityController;
  late final TextEditingController _currentEnrollmentController;
  late final TextEditingController _totalStudentsController;
  late final TextEditingController _totalTeachersController;
  late final TextEditingController _totalStaffController;
  late final TextEditingController _annualTuitionController;
  late final TextEditingController _registrationFeeController;

  final List<String> _schoolTypes = ['K-12', 'Elementary', 'Middle School', 'High School', 'University', 'Preschool'];
  final List<String> _languages = ['English', 'Hindi', 'Tamil', 'Telugu', 'Marathi', 'Bengali', 'Other'];
  final List<String> _gradeLevels = ['Pre-K', 'K', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize controllers with existing tenant data
    _schoolNameController = TextEditingController(text: widget.tenant.schoolName);
    _addressController = TextEditingController(text: widget.tenant.address);
    _phoneController = TextEditingController(text: widget.tenant.phone);
    _emailController = TextEditingController(text: widget.tenant.email);
    _principalNameController = TextEditingController(text: widget.tenant.principalName);
    _schoolType = widget.tenant.schoolType;
    _languageOfInstruction = widget.tenant.languageOfInstruction;
    _isActive = widget.tenant.isActive;

    _establishedYearController = TextEditingController(
      text: widget.tenant.establishedYear?.toString() ?? ''
    );
    _accreditationController = TextEditingController(text: widget.tenant.accreditation ?? '');
    _academicYearStart = widget.tenant.academicYearStart;
    _academicYearEnd = widget.tenant.academicYearEnd;
    _selectedGradeLevels = List<String>.from(widget.tenant.gradeLevels);

    _maximumCapacityController = TextEditingController(text: widget.tenant.maximumCapacity.toString());
    _currentEnrollmentController = TextEditingController(text: widget.tenant.currentEnrollment.toString());
    _totalStudentsController = TextEditingController(text: widget.tenant.totalStudents.toString());
    _totalTeachersController = TextEditingController(text: widget.tenant.totalTeachers.toString());
    _totalStaffController = TextEditingController(text: widget.tenant.totalStaff.toString());
    _annualTuitionController = TextEditingController(text: widget.tenant.annualTuition.toString());
    _registrationFeeController = TextEditingController(text: widget.tenant.registrationFee.toString());
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

  Future<void> _updateTenant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final tenantData = {
      'school_name': _schoolNameController.text.trim(),
      'address': _addressController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'principal_name': _principalNameController.text.trim(),
      'school_type': _schoolType,
      'language_of_instruction': _languageOfInstruction,
      'is_active': _isActive,
      'established_year': int.tryParse(_establishedYearController.text) ?? 0,
      'accreditation': _accreditationController.text.trim(),
      'academic_year_start': _academicYearStart?.toIso8601String(),
      'academic_year_end': _academicYearEnd?.toIso8601String(),
      'grade_levels': _selectedGradeLevels,
      'maximum_capacity': int.tryParse(_maximumCapacityController.text) ?? 0,
      'current_enrollment': int.tryParse(_currentEnrollmentController.text) ?? 0,
      'total_students': int.tryParse(_totalStudentsController.text) ?? 0,
      'total_teachers': int.tryParse(_totalTeachersController.text) ?? 0,
      'total_staff': int.tryParse(_totalStaffController.text) ?? 0,
      'annual_tuition': double.tryParse(_annualTuitionController.text) ?? 0.0,
      'registration_fee': double.tryParse(_registrationFeeController.text) ?? 0.0,
    };

    try {
      final response = await http.put(
        Uri.parse('${AppConstants.apiBaseUrl}/api/v1/tenants/${widget.tenant.id}'),
        headers: AuthSession.instance.headers(),
        body: json.encode(tenantData),
      );

      if (response.statusCode == 200) {
        widget.onTenantUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('School "${_schoolNameController.text}" updated successfully'),
              backgroundColor: AppTheme.greenPrimary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to update school');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- Shared field decoration -------------------------------------------
  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: Sa.label,
        isDense: true,
        border: const OutlineInputBorder(borderRadius: AppTheme.borderRadius12),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: Sa.stroke),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius12,
          borderSide: BorderSide(color: AppTheme.greenPrimary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  /// Lay out children in a Row on wide viewports and a Column on phones.
  Widget _responsiveRow(double maxWidth, List<Widget> fields) {
    if (maxWidth < 600) {
      final children = <Widget>[];
      for (var i = 0; i < fields.length; i++) {
        if (i > 0) children.add(const SizedBox(height: Sa.gap));
        children.add(fields[i]);
      }
      return Column(children: children);
    }
    final children = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      if (i > 0) children.add(const SizedBox(width: Sa.gap));
      children.add(Expanded(child: fields[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 560.0);
    final maxH = size.height - 80;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabBar(),
            Flexible(
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
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit School',
                    style: Sa.headerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  widget.tenant.schoolName,
                  style: Sa.headerSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _activeToggle(),
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppTheme.greenPrimary,
            unselectedLabelColor: AppTheme.neutral500,
            indicatorColor: AppTheme.greenPrimary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontFamily: AppTheme.bauhausFontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: AppTheme.interFontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Basic Info'),
              Tab(text: 'Academic'),
              Tab(text: 'Capacity & Finance'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isActive ? 'Active' : 'Inactive',
          style: Sa.label.copyWith(
            color: _isActive ? AppTheme.greenPrimary : AppTheme.neutral500,
            fontWeight: FontWeight.w600,
          ),
        ),
        Switch(
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
          activeThumbColor: AppTheme.greenPrimary,
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Sa.stroke.withValues(alpha: 0.7))),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.neutral600,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          SaPrimaryButton(
            label: _isLoading ? 'Updating…' : 'Update School',
            icon: Icons.save_outlined,
            busy: _isLoading,
            onPressed: _isLoading ? null : _updateTenant,
          ),
        ],
      ),
    );
  }

  // The tab content builders are the same as in create dialog
  Widget _buildBasicInfoTab() {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              _responsiveRow(c.maxWidth, [
                TextFormField(
                  controller: _schoolNameController,
                  decoration: _dec('School Name *'),
                  validator: (value) => value?.isEmpty == true ? 'School name is required' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _schoolType,
                  isExpanded: true,
                  decoration: _dec('School Type'),
                  items: _schoolTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) => setState(() => _schoolType = value!),
                ),
              ]),
              const SizedBox(height: Sa.gap),
              TextFormField(
                controller: _addressController,
                decoration: _dec('Address *'),
                maxLines: 2,
                validator: (value) => value?.isEmpty == true ? 'Address is required' : null,
              ),
              const SizedBox(height: Sa.gap),
              _responsiveRow(c.maxWidth, [
                TextFormField(
                  controller: _phoneController,
                  decoration: _dec('Phone Number *'),
                  validator: (value) => value?.isEmpty == true ? 'Phone number is required' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: _dec('Email Address *'),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                      return 'Enter valid email';
                    }
                    return null;
                  },
                ),
              ]),
              const SizedBox(height: Sa.gap),
              _responsiveRow(c.maxWidth, [
                TextFormField(
                  controller: _principalNameController,
                  decoration: _dec('Principal Name *'),
                  validator: (value) => value?.isEmpty == true ? 'Principal name is required' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _languageOfInstruction,
                  isExpanded: true,
                  decoration: _dec('Language of Instruction'),
                  items: _languages.map((lang) {
                    return DropdownMenuItem(value: lang, child: Text(lang));
                  }).toList(),
                  onChanged: (value) => setState(() => _languageOfInstruction = value!),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAcademicTab() {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _responsiveRow(c.maxWidth, [
                TextFormField(
                  controller: _establishedYearController,
                  decoration: _dec('Established Year'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _accreditationController,
                  decoration: _dec('Accreditation'),
                ),
              ]),
              const SizedBox(height: Sa.gap),
              _responsiveRow(c.maxWidth, [
                _dateField(
                  label: 'Academic Year Start',
                  value: _academicYearStart,
                  onPick: (date) => setState(() => _academicYearStart = date),
                ),
                _dateField(
                  label: 'Academic Year End',
                  value: _academicYearEnd,
                  onPick: (date) => setState(() => _academicYearEnd = date),
                ),
              ]),
              const SizedBox(height: Sa.gapLg),
              const Text('Grade Levels Offered', style: Sa.cardTitle),
              const SizedBox(height: Sa.gap),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _gradeLevels.map((grade) {
                  final isSelected = _selectedGradeLevels.contains(grade);
                  return FilterChip(
                    label: Text('Grade $grade'),
                    selected: isSelected,
                    selectedColor: AppTheme.greenPrimary,
                    checkmarkColor: Colors.white,
                    backgroundColor: AppTheme.green50,
                    side: BorderSide(
                      color: isSelected ? AppTheme.greenPrimary : Sa.stroke,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: AppTheme.interFontFamily,
                      color: isSelected ? Colors.white : AppTheme.neutral700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedGradeLevels.add(grade);
                        } else {
                          _selectedGradeLevels.remove(grade);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPick,
  }) {
    return InkWell(
      borderRadius: AppTheme.borderRadius12,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (date != null) onPick(date);
      },
      child: InputDecorator(
        decoration: _dec(label).copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined,
              size: 18, color: AppTheme.greenPrimary),
        ),
        child: Text(
          value != null
              ? '${value.day}/${value.month}/${value.year}'
              : 'Select date',
          style: value != null
              ? Sa.value
              : Sa.body.copyWith(color: AppTheme.neutral500),
        ),
      ),
    );
  }

  Widget _buildCapacityFinanceTab() {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Capacity Information'),
              const SizedBox(height: Sa.gap),
              _responsiveRow(c.maxWidth, [
                TextFormField(
                  controller: _maximumCapacityController,
                  decoration: _dec('Maximum Capacity'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _currentEnrollmentController,
                  decoration: _dec('Current Enrollment'),
                  keyboardType: TextInputType.number,
                ),
              ]),
              const SizedBox(height: Sa.gap),
              _responsiveRow(c.maxWidth, [
                TextFormField(
                  controller: _totalStudentsController,
                  decoration: _dec('Total Students'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _totalTeachersController,
                  decoration: _dec('Total Teachers'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _totalStaffController,
                  decoration: _dec('Total Staff'),
                  keyboardType: TextInputType.number,
                ),
              ]),
              const SizedBox(height: Sa.gapLg),
              _sectionTitle('Financial Information'),
              const SizedBox(height: Sa.gap),
              _responsiveRow(c.maxWidth, [
                TextFormField(
                  controller: _annualTuitionController,
                  decoration: _dec('Annual Tuition (₹)'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _registrationFeeController,
                  decoration: _dec('Registration Fee (₹)'),
                  keyboardType: TextInputType.number,
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.greenPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: Sa.cardTitle),
      ],
    );
  }
}
