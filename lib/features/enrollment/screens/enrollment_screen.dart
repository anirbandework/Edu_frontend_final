// lib/features/enrollment/screens/enrollment_screen.dart
//
// Manage a class roster: view enrolled students, enrol new ones (from the pool
// of eligible students), and withdraw. require_authority for writes. Real
// backend, AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/enrollment_service.dart';
import '../../../services/teacher_portal_service.dart';

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
  final Map<String, String> _enrollmentByStudent = {}; // studentUuid -> enrollment id

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
      _enrollmentByStudent.clear();
    });
    try {
      final roster = await TeacherPortalService.getClassRoster(classId: _classId!);
      final enrollments = await EnrollmentService.getClassEnrollments(classId: _classId!);
      _enrollmentByStudent.clear();
      for (final en in enrollments) {
        final sid = en['student_id']?.toString();
        final eid = en['id']?.toString();
        if (sid != null && eid != null) _enrollmentByStudent[sid] = eid;
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
    final uuid = s['id']?.toString();
    final eid = uuid == null ? null : _enrollmentByStudent[uuid];
    final name = ('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}').trim();
    if (eid == null) {
      _toast('Could not resolve enrolment for $name', AppTheme.warning);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw student?'),
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
      _toast('$name withdrawn', AppTheme.success);
      _loadRoster();
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Enrolment', style: AppTheme.headingMedium)),
            ElevatedButton.icon(
              onPressed: (_classId == null || _loadingRoster) ? null : _addStudents,
              icon: const Icon(Icons.person_add_alt_1, size: AppTheme.iconSmall),
              label: const Text('Add students'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _loadingRoster ? null : _loadRoster,
              icon: const Icon(Icons.refresh),
              color: AppTheme.greenPrimary,
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _controls(),
        const SizedBox(height: 12),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _controls() {
    final total = _classInfo['total_students'];
    final cap = _classInfo['class_capacity'];
    final spots = _classInfo['available_spots'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: _loadingClasses
                ? const LinearProgressIndicator(color: AppTheme.greenPrimary)
                : DropdownButtonFormField<String>(
                    value: _classId,
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
          ),
          if (!_loadingRoster && _students.isNotEmpty) ...[
            _pill('${total ?? _students.length} enrolled', AppTheme.greenPrimary),
            if (cap != null) _pill('$cap capacity', AppTheme.neutral500),
            if (spots != null) _pill('$spots open', AppTheme.info),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: AppTheme.borderRadius8),
      child: Text(text,
          style: AppTheme.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _body() {
    if (_loadingClasses || _loadingRoster) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 40, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error!,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _loadClasses,
              icon: const Icon(Icons.refresh, size: AppTheme.iconSmall),
              label: const Text('Retry')),
        ]),
      );
    }
    if (_students.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_add, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No students enrolled in this class',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _addStudents,
              icon: const Icon(Icons.person_add_alt_1, size: AppTheme.iconSmall),
              label: const Text('Add students')),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _loadRoster,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _students.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _studentRow(_students[i]),
      ),
    );
  }

  Widget _studentRow(Map<String, dynamic> s) {
    final name = ('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}').trim();
    final roll = (s['roll_number'] ?? '').toString();
    final code = (s['student_id'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.green50,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.greenPrimary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Student' : name,
                    style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (roll.isNotEmpty || code.isNotEmpty)
                  Text([
                    if (roll.isNotEmpty) 'Roll $roll',
                    if (code.isNotEmpty) code,
                  ].join('  •  '),
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _withdraw(s),
            icon: const Icon(Icons.person_remove_alt_1, size: AppTheme.iconMedium),
            color: AppTheme.error,
            tooltip: 'Withdraw',
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
        _available = ((data['available_students'] as List?) ?? const [])
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

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _available;
    final q = _query.toLowerCase();
    return _available.where((s) {
      final name = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.toLowerCase();
      final code = (s['student_id'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  Future<void> _enroll() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await EnrollmentService.bulkEnroll(
        classId: widget.classId,
        studentIds: _selected.toList(),
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
    return AlertDialog(
      title: const Text('Add students'),
      content: SizedBox(
        width: 440,
        height: 460,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                  hintText: 'Search', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(child: _list()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: (_selected.isEmpty || _saving) ? null : _enroll,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: AppTheme.iconSmall),
          label: Text(_saving ? 'Enrolling…' : 'Enrol ${_selected.length}'),
        ),
      ],
    );
  }

  Widget _list() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.greenPrimary));
    }
    if (_error != null && _available.isEmpty) {
      return Center(
        child: Text(_error!, style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(_available.isEmpty ? 'No eligible students' : 'No matches',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final s = list[i];
        final id = s['id']?.toString() ?? '';
        final name = ('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}').trim();
        final code = (s['student_id'] ?? '').toString();
        final grade = (s['grade_level'] ?? '').toString();
        final sel = _selected.contains(id);
        return CheckboxListTile(
          value: sel,
          dense: true,
          activeColor: AppTheme.greenPrimary,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(name.isEmpty ? 'Student' : name,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text([
            if (code.isNotEmpty) code,
            if (grade.isNotEmpty) 'Grade $grade',
          ].join('  •  '), style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
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
