// lib/features/enrollment/screens/enrollment_screen.dart
//
// Manage a class roster: view enrolled members, enrol new ones (from the pool
// of eligible members), and withdraw. require_authority for writes. Real
// backend, AppTheme only. An enrolled "student" is a MEMBER (members table)
// with an Enrollment row — roster items carry member_id/member_name/member_hrid.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/enrollment_service.dart';
import '../../../services/teacher_portal_service.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class EnrollmentScreen extends StatefulWidget {
  final String? tenantId;
  const EnrollmentScreen({super.key, this.tenantId});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  String? _tenantId;
  List<Map<String, dynamic>> _classes = [];
  String? _classId;

  /// Academic year of the currently-selected class (the enrolment must match the
  /// class's year). Falls back to the current default only if the class omits it.
  String get _academicYear {
    final cls = _classes.firstWhere(
      (c) => c['id']?.toString() == _classId,
      orElse: () => const <String, dynamic>{},
    );
    final y = (cls['academic_year'] ?? '').toString();
    return y.isNotEmpty ? y : '2025-26';
  }

  bool _loadingClasses = true;
  bool _loadingRoster = false;
  String? _error;

  Map<String, dynamic> _classInfo = {};
  List<Map<String, dynamic>> _students = [];
  final Map<String, String> _enrollmentByMember = {}; // memberUuid -> enrollment id

  @override
  void initState() {
    super.initState();
    _tenantId = widget.tenantId ?? AuthSession.instance.tenantId;
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    if ((_tenantId ?? '').isEmpty) {
      setState(() {
        _loadingClasses = false;
        _error = 'No school session found. Please sign in again.';
      });
      return;
    }
    setState(() {
      _loadingClasses = true;
      _error = null;
    });
    try {
      final classes = await TeacherPortalService.getClasses(tenantId: _tenantId!);
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _loadingClasses = false;
        if (classes.isNotEmpty) _classId = classes.first['id']?.toString();
      });
      if (_classId != null) _loadRoster();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadRoster() async {
    if (_classId == null) return;
    setState(() {
      _loadingRoster = true;
      _error = null;
      _students = [];
      _enrollmentByMember.clear();
    });
    try {
      final roster = await TeacherPortalService.getClassRoster(classId: _classId!);
      final enrollments = await EnrollmentService.getClassEnrollments(classId: _classId!);
      _enrollmentByMember.clear();
      for (final en in enrollments) {
        final mid = en['member_id']?.toString();
        final eid = en['id']?.toString();
        if (mid != null && eid != null) _enrollmentByMember[mid] = eid;
      }
      if (!mounted) return;
      setState(() {
        _classInfo = (roster['class_info'] as Map?)?.cast<String, dynamic>() ?? {};
        _classInfo['total_students'] = roster['total_students'];
        _classInfo['class_capacity'] = roster['class_capacity'];
        _classInfo['available_spots'] = roster['available_spots'];
        _students = ((roster['students'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _loadingRoster = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRoster = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _addStudents() async {
    if (_classId == null) return;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddStudentsDialog(
        classId: _classId!,
        academicYear: _academicYear,
      ),
    );
    if (added == true) _loadRoster();
  }

  Future<void> _withdraw(Map<String, dynamic> s) async {
    final uuid = (s['member_id'] ?? s['id'])?.toString();
    final eid = uuid == null ? null : _enrollmentByMember[uuid];
    final name = _memberName(s);
    if (eid == null) {
      _toast('Could not resolve enrolment for $name', AppTheme.error);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw member?'),
        content: Text('Remove $name from this class?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await EnrollmentService.removeEnrollment(enrollmentId: eid);
      _toast('$name withdrawn', AppTheme.greenPrimary);
      _loadRoster();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  /// Member display name: prefer the server-supplied `member_name`, otherwise
  /// fall back to joining first + last name.
  static String _memberName(Map<String, dynamic> m) {
    final n = (m['member_name'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    return ('${m['first_name'] ?? ''} ${m['last_name'] ?? ''}').trim();
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Enrolment',
          subtitle: 'Manage a class roster',
          icon: Icons.how_to_reg_outlined,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
        children: [
          _controls(),
          const SizedBox(height: Sa.gap),
          _body(),
        ],
      ),
    );
  }

  Widget _controls() {
    final total = _classInfo['total_students'];
    final cap = _classInfo['class_capacity'];
    final spots = _classInfo['available_spots'];
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _loadingClasses
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(color: AppTheme.greenPrimary),
                )
              : DropdownButtonFormField<String>(
                  initialValue: _classId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Class', prefixIcon: Icon(Icons.class_), isDense: true),
                  items: _classes.map((c) {
                    final name = (c['class_name'] ?? 'Class').toString();
                    final sec = (c['section'] ?? '').toString();
                    return DropdownMenuItem(
                        value: c['id']?.toString(),
                        child: Text(sec.isEmpty ? name : '$name • $sec',
                            overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) {
                    setState(() => _classId = v);
                    _loadRoster();
                  },
                ),
          if (!_loadingRoster && _students.isNotEmpty) ...[
            const SizedBox(height: Sa.gap),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SaStatusPill(
                    text: '${total ?? _students.length} enrolled',
                    color: AppTheme.greenPrimary),
                if (cap != null)
                  SaStatusPill(text: '$cap capacity', color: AppTheme.neutral500),
                if (spots != null)
                  SaStatusPill(text: '$spots open', color: AppTheme.greenPrimary),
              ],
            ),
          ],
          const SizedBox(height: Sa.gap),
          SaPrimaryButton(
            label: 'Add members',
            icon: Icons.person_add_alt_1,
            expand: true,
            onPressed: (_classId == null || _loadingRoster) ? null : _addStudents,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loadingClasses || _loadingRoster) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: SaLoading(message: 'Loading…'),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: SaStateView.error(message: _error!, onRetry: _loadClasses),
      );
    }
    if (_students.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: SaStateView(
          icon: Icons.group_add,
          title: 'No members enrolled',
          subtitle: 'No members enrolled in this class yet.',
          action: SaPrimaryButton(
            label: 'Add members',
            icon: Icons.person_add_alt_1,
            onPressed: _addStudents,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _students.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (context, i) => _studentRow(_students[i]),
    );
  }

  Widget _studentRow(Map<String, dynamic> s) {
    final name = _memberName(s);
    final roll = (s['roll_number'] ?? '').toString();
    final code = (s['member_hrid'] ?? s['staff_id'] ?? '').toString();
    return SaCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.green50,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: Sa.value.copyWith(color: AppTheme.greenPrimary)),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Member' : name,
                    style: Sa.value,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (roll.isNotEmpty || code.isNotEmpty)
                  Text([
                    if (roll.isNotEmpty) 'Roll $roll',
                    if (code.isNotEmpty) code,
                  ].join('  •  '),
                      style: Sa.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _withdraw(s),
            icon: const Icon(Icons.person_remove_alt_1, size: AppTheme.iconMedium),
            color: AppTheme.error,
            tooltip: 'Withdraw',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}

class _AddStudentsDialog extends StatefulWidget {
  final String classId;
  final String academicYear;
  const _AddStudentsDialog({required this.classId, required this.academicYear});

  @override
  State<_AddStudentsDialog> createState() => _AddStudentsDialogState();
}

class _AddStudentsDialogState extends State<_AddStudentsDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _available = [];
  final Set<String> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await EnrollmentService.getAvailableForClass(classId: widget.classId);
      if (!mounted) return;
      setState(() {
        _available = ((data['available_members'] ?? data['available_students']) as List? ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// Member display name: prefer `member_name`, else join first + last.
  static String _memberName(Map<String, dynamic> m) {
    final n = (m['member_name'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    return ('${m['first_name'] ?? ''} ${m['last_name'] ?? ''}').trim();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _available;
    final q = _query.toLowerCase();
    return _available.where((s) {
      final name = _memberName(s).toLowerCase();
      final code = (s['member_hrid'] ?? s['staff_id'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  Future<void> _enroll() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await EnrollmentService.bulkEnroll(
        classId: widget.classId,
        memberIds: _selected.toList(),
        academicYear: widget.academicYear,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = size.width - 24;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW > 480 ? 480 : maxW,
          maxHeight: size.height - 80,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add members', style: Sa.cardTitle.copyWith(fontSize: 17)),
              const SizedBox(height: Sa.gap),
              TextField(
                decoration: const InputDecoration(
                    hintText: 'Search', prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: Sa.gapXs),
              Flexible(child: _list()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: Sa.label.copyWith(color: AppTheme.error)),
                ),
              const SizedBox(height: Sa.gap),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.neutral600,
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: Sa.stroke),
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadius12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: SaPrimaryButton(
                      label: _saving ? 'Enrolling…' : 'Enrol ${_selected.length}',
                      icon: Icons.check,
                      busy: _saving,
                      expand: true,
                      onPressed: (_selected.isEmpty || _saving) ? null : _enroll,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: SaLoading(message: 'Loading…'),
      );
    }
    if (_error != null && _available.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SaStateView.error(message: _error!, onRetry: _load),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SaStateView(
          icon: Icons.group_outlined,
          title: _available.isEmpty ? 'No eligible members' : 'No matches',
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (context, i) {
        final s = list[i];
        final id = (s['member_id'] ?? s['id'])?.toString() ?? '';
        final name = _memberName(s);
        final code = (s['member_hrid'] ?? s['staff_id'] ?? '').toString();
        final position = (s['position'] ?? '').toString();
        final sel = _selected.contains(id);
        return CheckboxListTile(
          value: sel,
          dense: true,
          activeColor: AppTheme.greenPrimary,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(name.isEmpty ? 'Member' : name,
              style: Sa.value, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text([
            if (code.isNotEmpty) code,
            if (position.isNotEmpty) position,
          ].join('  •  '), style: Sa.label,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          onChanged: (v) => setState(() {
            if (v == true) {
              _selected.add(id);
            } else {
              _selected.remove(id);
            }
          }),
        );
      },
    );
  }
}
