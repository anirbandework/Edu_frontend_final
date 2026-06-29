// lib/features/organisation_management/widgets/organisation_create_dialog.dart
//
// Institution-agnostic "Create organisation" form. The form adapts to the chosen
// org type (School / College / University / Coaching / Tutor / Institute / Other):
// the "levels / programs" field, the head label and the accreditation field all
// change per type (see org_levels_field.dart). Only name + contact + head are
// required, so a private tutor can register without grades/capacity/fees.
import 'dart:convert';
import 'package:flutter/material.dart';
// Route the create POST through the 401-refresh / hard-logout wrapper (this is a long
// form, so the access token may expire mid-fill — auto-refresh instead of a raw 401).
import '../../../core/network/app_http.dart' as http;
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../super_admin/widgets/sa_widgets.dart';
import 'org_levels_field.dart';

class OrganisationCreateDialog extends StatefulWidget {
  final VoidCallback onOrganisationCreated;
  /// When non-null the dialog is in EDIT mode: pre-fills from this org detail and
  /// PATCHes the admin's active org instead of creating a new one.
  final Map<String, dynamic>? existing;

  const OrganisationCreateDialog({
    super.key,
    required this.onOrganisationCreated,
    this.existing,
  });

  @override
  State<OrganisationCreateDialog> createState() => _OrganisationCreateDialogState();
}

class _OrganisationCreateDialogState extends State<OrganisationCreateDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isLoading = false;

  // Basic
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _headNameController = TextEditingController();
  String _orgType = 'School';
  String _languageOfInstruction = 'English';

  // Details
  final _establishedYearController = TextEditingController();
  final _accreditationController = TextEditingController();
  final List<String> _levelsOffered = [];

  // Capacity & fees (all optional)
  final _maximumCapacityController = TextEditingController();
  final _annualTuitionController = TextEditingController();
  final _registrationFeeController = TextEditingController();

  final List<String> _languages = [
    'English', 'Hindi', 'Tamil', 'Telugu', 'Marathi', 'Bengali', 'Other',
  ];

  OrgTypeProfile get _profile => orgProfileFor(_orgType);
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final e = widget.existing;
    if (e != null) {
      _nameController.text = (e['name'] ?? '').toString();
      _addressController.text = (e['address'] ?? '').toString();
      _phoneController.text = (e['phone'] ?? '').toString();
      _emailController.text = (e['email'] ?? '').toString();
      _headNameController.text = (e['head_name'] ?? '').toString();
      final t = (e['org_type'] ?? 'School').toString();
      _orgType = kOrgTypes.contains(t) ? t : 'School';
      final lang = (e['language_of_instruction'] ?? 'English').toString();
      _languageOfInstruction = _languages.contains(lang) ? lang : 'English';
      _establishedYearController.text = e['established_year']?.toString() ?? '';
      _accreditationController.text = (e['accreditation'] ?? '').toString();
      _maximumCapacityController.text = e['maximum_capacity']?.toString() ?? '';
      final at = e['annual_tuition'];
      _annualTuitionController.text = (at == null || at == 0) ? '' : at.toString();
      final rf = e['registration_fee'];
      _registrationFeeController.text = (rf == null || rf == 0) ? '' : rf.toString();
      if (e['levels_offered'] is List) {
        _levelsOffered.addAll((e['levels_offered'] as List).map((x) => x.toString()));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _headNameController.dispose();
    _establishedYearController.dispose();
    _accreditationController.dispose();
    _maximumCapacityController.dispose();
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
    return detail?.toString() ?? 'Failed to create organisation';
  }

  Future<void> _createOrganisation() async {
    // Only Basic-Info fields are required (name + contact + head). Levels,
    // capacity and fees are all optional so any org type fits.
    final formOk = _formKey.currentState?.validate() ?? false;

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

    // Capacity is optional, but if given it must be > 0.
    int? maxCap;
    final capText = _maximumCapacityController.text.trim();
    if (capText.isNotEmpty) {
      maxCap = int.tryParse(capText);
      if (maxCap == null || maxCap <= 0) {
        _tabController.animateTo(2);
        _showError('Capacity must be a number greater than 0 (or leave it blank).');
        return;
      }
    }

    if (!formOk) {
      _tabController.animateTo(0); // the required fields live here
      _showError('Please fill all required fields.');
      return;
    }

    setState(() => _isLoading = true);

    final organisationData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'head_name': _headNameController.text.trim(),
      'org_type': _orgType,
      'language_of_instruction': _languageOfInstruction,
      'levels_offered': _levelsOffered,
      'annual_tuition': double.tryParse(_annualTuitionController.text) ?? 0.0,
      'registration_fee': double.tryParse(_registrationFeeController.text) ?? 0.0,
      'is_active': true,
      if (establishedYear != null) 'established_year': establishedYear,
      if (_accreditationController.text.trim().isNotEmpty)
        'accreditation': _accreditationController.text.trim(),
      if (maxCap != null) 'maximum_capacity': maxCap,
    };

    try {
      // EDIT → PATCH the admin's active org; CREATE → POST (stamps owner = the admin
      // and auto-creates the org's head as a role + member).
      final uri = Uri.parse('${AppConstants.apiBaseUrl}'
          '${_isEdit ? '/api/auth/my-organisation' : '/api/auth/organisations'}');
      final response = _isEdit
          ? await http.patch(uri,
              headers: AuthSession.instance.headers(), body: json.encode(organisationData))
          : await http.post(uri,
              headers: AuthSession.instance.headers(), body: json.encode(organisationData));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // On CREATE the backend reports the auto-created head (role + member).
        final head = (!_isEdit && data is Map) ? data['head'] : null;
        final headMsg = (head is Map && head['role'] != null)
            ? ' · ${head['role']} role + "${head['member']}" added (set their login in Staff & Users)'
            : '';
        final verb = _isEdit ? 'updated' : 'created';
        widget.onOrganisationCreated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Organisation "${_nameController.text}" $verb$headMsg'),
              backgroundColor: AppTheme.greenPrimary,
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
    // Cap the width on wide web/tablet windows by centring the dialog via a large
    // horizontal inset (it otherwise stretched edge-to-edge and looked broken).
    final w = MediaQuery.of(context).size.width;
    final hInset = w > 576 ? (w - 560) / 2 : 8.0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 8),
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
                      _isEdit ? 'Edit organisation' : 'Add new organisation',
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

            // Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Sa.accent,
              unselectedLabelColor: AppTheme.neutral500,
              indicatorColor: Sa.accent,
              labelStyle: Sa.value,
              tabs: const [
                Tab(text: 'Basic'),
                Tab(text: 'Details'),
                Tab(text: 'Capacity & Fees'),
              ],
            ),

            const Divider(height: 1),

            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(),
                    _buildDetailsTab(),
                    _buildCapacityFeesTab(),
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
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                      label: _isEdit ? 'Save changes' : 'Create organisation',
                      icon: Icons.check,
                      busy: _isLoading,
                      expand: true,
                      onPressed: _isLoading ? null : _createOrganisation,
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

  /// Row on wide screens, Column on phones (< 600px), auto-spaced.
  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          final col = <Widget>[];
          for (var i = 0; i < children.length; i++) {
            col.add(children[i]);
            if (i != children.length - 1) col.add(const SizedBox(height: 16));
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: col);
        }
        final row = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          row.add(Expanded(child: children[i]));
          if (i != children.length - 1) row.add(const SizedBox(width: 16));
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Organisation Name *',
                hintText: 'Enter organisation name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Organisation name is required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _orgType,
              decoration: const InputDecoration(
                labelText: 'Organisation Type',
                border: OutlineInputBorder(),
                helperText: 'Changes what the form asks for',
              ),
              items: kOrgTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              // Changing the type re-labels the head/accreditation/levels fields.
              onChanged: (v) => setState(() => _orgType = v ?? 'School'),
            ),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address *',
              hintText: 'Address (or "Online" for a remote tutor)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            validator: (v) => v?.trim().isEmpty == true ? 'Address is required' : null,
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
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Phone number is required' : null,
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                hintText: 'organisation@example.com',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v?.trim().isEmpty == true) return 'Email is required';
                if (!RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v!)) {
                  return 'Enter valid email';
                }
                return null;
              },
            ),
          ]),
          const SizedBox(height: 16),
          _responsiveFields([
            TextFormField(
              controller: _headNameController,
              decoration: InputDecoration(
                labelText: '${_profile.headLabel} *',
                hintText: _profile.headHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v?.trim().isEmpty == true ? '${_profile.headLabel} is required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _languageOfInstruction,
              decoration: const InputDecoration(
                labelText: 'Language of Instruction',
                border: OutlineInputBorder(),
              ),
              items: _languages
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _languageOfInstruction = v ?? 'English'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The adaptive levels/programs/batches editor.
          OrgLevelsField(
            values: _levelsOffered,
            profile: _profile,
            onChanged: (v) => setState(() {
              _levelsOffered
                ..clear()
                ..addAll(v);
            }),
          ),
          const SizedBox(height: 24),
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
                if (t.isEmpty) return null;
                final y = int.tryParse(t);
                if (y == null || y < 1800 || y > DateTime.now().year) {
                  return '1800–${DateTime.now().year}';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _accreditationController,
              decoration: InputDecoration(
                labelText: '${_profile.accreditationLabel} (optional)',
                hintText: _profile.accreditationHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCapacityFeesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Capacity', style: Sa.cardTitle.copyWith(color: Sa.accent)),
          const SizedBox(height: 4),
          Text('All optional — leave blank if not applicable (e.g. a tutor).',
              style: Sa.label),
          const SizedBox(height: 16),
          TextFormField(
            controller: _maximumCapacityController,
            decoration: const InputDecoration(
              labelText: 'Maximum Capacity (optional)',
              hintText: 'Max learners, e.g. 1000',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          Text('Fees', style: Sa.cardTitle.copyWith(color: Sa.accent)),
          const SizedBox(height: 16),
          _responsiveFields([
            TextFormField(
              controller: _annualTuitionController,
              decoration: const InputDecoration(
                labelText: 'Annual Fee (₹, optional)',
                hintText: '50000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _registrationFeeController,
              decoration: const InputDecoration(
                labelText: 'Registration Fee (₹, optional)',
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
