// lib/features/teacher/screens/teacher_students_screen.dart
//
// Class roster: pick a class, see the students enrolled in it. Read-only for
// teachers (enrolment is an authority action). Real backend; AppTheme only.
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/teacher_portal_service.dart';

class TeacherStudentsScreen extends StatefulWidget {
  final String? tenantId;
  const TeacherStudentsScreen({super.key, this.tenantId});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  String? _tenantId;
  List<Map<String, dynamic>> _classes = [];
  String? _classId;

  bool _loadingClasses = true;
  bool _loadingRoster = false;
  String? _error;

  List<Map<String, dynamic>> _students = [];
  String _query = '';

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
    });
    try {
      final data = await TeacherPortalService.getClassRoster(classId: _classId!);
      if (!mounted) return;
      setState(() {
        _students = ((data['students'] as List?) ?? const [])
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

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _students;
    final q = _query.toLowerCase();
    return _students.where((s) {
      final name = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.toLowerCase();
      final code = (s['student_id'] ?? '').toString().toLowerCase();
      final roll = (s['roll_number'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || roll.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Students', style: AppTheme.headingMedium)),
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
                      labelText: 'Class',
                      prefixIcon: Icon(Icons.class_),
                      isDense: true,
                    ),
                    items: _classes.map((c) {
                      final name = (c['class_name'] ?? 'Class').toString();
                      final sec = (c['section'] ?? '').toString();
                      return DropdownMenuItem(
                        value: c['id']?.toString(),
                        child: Text(sec.isEmpty ? name : '$name • $sec',
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _classId = v);
                      _loadRoster();
                    },
                  ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search name / roll',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (!_loadingRoster && _students.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.green50,
                borderRadius: AppTheme.borderRadius8,
              ),
              child: Text('${_students.length} enrolled',
                  style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.greenPrimary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
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
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline, size: 40, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text(_students.isEmpty ? 'No students enrolled in this class' : 'No matches',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral500)),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppTheme.greenPrimary,
      onRefresh: _loadRoster,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 1000 ? 3 : (c.maxWidth > 620 ? 2 : 1);
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 132,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) => _studentCard(list[i]),
        );
      }),
    );
  }

  Widget _studentCard(Map<String, dynamic> s) {
    final name = ('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}').trim();
    final roll = (s['roll_number'] ?? '').toString();
    final code = (s['student_id'] ?? '').toString();
    final email = (s['email'] ?? '').toString();
    final phone = (s['phone'] ?? '').toString();
    final status = (s['status'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.green50,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTheme.labelLarge.copyWith(color: AppTheme.greenPrimary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Student' : name,
                        style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (roll.isNotEmpty)
                        Text('Roll $roll',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500)),
                      if (roll.isNotEmpty && code.isNotEmpty)
                        Text('  •  ',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral400)),
                      if (code.isNotEmpty)
                        Flexible(
                          child: Text(code,
                              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ]),
                  ],
                ),
              ),
              if (status.isNotEmpty) _statusChip(status),
            ],
          ),
          const Spacer(),
          if (email.isNotEmpty) _meta(Icons.email, email),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            _meta(Icons.phone, phone),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final active = status.toLowerCase() == 'active';
    final color = active ? AppTheme.success : AppTheme.neutral400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppTheme.borderRadius8,
      ),
      child: Text(status,
          style: AppTheme.bodyMicro.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: AppTheme.iconSmall, color: AppTheme.neutral400),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
