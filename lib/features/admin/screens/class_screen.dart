import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_theme.dart';
import '../../super_admin/widgets/sa_widgets.dart';
import '../../../services/class_service.dart';
import '../../../services/timetable_service.dart';
import '../../../core/models/class_model.dart';
import '../widgets/class_screen_dialog/add_edit_class_dialog.dart';
import '../widgets/class_screen_dialog/bulk_import_dialog.dart';
import '../widgets/class_screen_dialog/bulk_update_capacity_dialog.dart';
import '../widgets/class_screen_dialog/bulk_update_status_dialog.dart';
import '../widgets/class_screen_dialog/assign_classrooms_dialog.dart';
import '../widgets/class_screen_dialog/rollover_dialog.dart';
import '../widgets/class_screen_dialog/confirm_bulk_delete_dialog.dart';
import '../widgets/class_screen_dialog/update_student_count_dialog.dart';
import '../widgets/class_screen_dialog/class_details_dialog.dart';
import '../widgets/timetable_screen_dialog/create_class_timetable_dialog.dart';

class ClassScreen extends StatefulWidget {
  final String baseUrl;
  final String tenantId;
  final Map<String, String> headers;

  const ClassScreen({
    super.key,
    required this.baseUrl,
    required this.tenantId,
    this.headers = const {},
  });

  @override
  State<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<ClassScreen> {
  late final ClassApi api;
  int page = 1;
  int pageSize = 20;
  bool loading = false;
  bool _isSubmitting = false;
  String? _error;
  List<ClassModel> items = [];
  int total = 0;

  // filters
  int? filterGrade;
  String? filterSection;
  String? filterYear;
  bool? filterActive;

  // selection
  final Set<String> selectedIds = {};

  @override
  void initState() {
    super.initState();
    api = ClassApi(baseUrl: widget.baseUrl, defaultHeaders: {
      'Accept': 'application/json',
      ...widget.headers,
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      _error = null;
    });
    try {
      final res = await api.getPaginated(
        page: page,
        pageSize: pageSize,
        tenantId: widget.tenantId,
        gradeLevel: filterGrade,
        section: filterSection,
        academicYear: filterYear,
        isActive: filterActive,
      );
      items = ClassModel.listFromPaginated(res);
      total = (res['total'] is int) ? res['total'] as int : items.length;
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'We could not load classes. Please try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _resetAndReload() {
    page = 1;
    _load();
  }

  Future<void> _createOrEdit([ClassModel? model]) async {
    final result = await showDialog<ClassModel>(
      context: context,
      builder: (_) => AddEditClassDialog(
        initial: model,
        tenantId: widget.tenantId,
      ),
    );
    if (result != null) {
      if (model == null) {
        await api.create(result.toCreateJson());
      } else {
        await api.update(model.id, result.toUpdateJson());
      }
      _resetAndReload();
    }
  }

  Future<void> _delete(ClassModel m) async {
    if (_isSubmitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class'),
        content: Text('Delete ${m.className}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSubmitting = true);
    try {
      await api.delete(m.id);
      _resetAndReload();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateCount(ClassModel m) async {
    final newCount = await showDialog<int>(
      context: context,
      builder: (_) => UpdateStudentCountDialog(
        maxCount: m.maximumStudents,
        current: m.currentStudents,
      ),
    );
    if (newCount != null) {
      await api.updateStudentCount(m.id, newCount);
      _load();
    }
  }

  // Web-safe CSV import
  Future<void> _bulkImport() async {
    final pick = await showDialog<FilePickerResult?>(
      context: context,
      builder: (_) => const BulkImportDialog(),
    );
    if (pick != null) {
      await api.bulkImportWithPickerResult(
        tenantId: widget.tenantId,
        pick: pick,
      );
      _resetAndReload();
    }
  }

  Future<void> _bulkCapacity() async {
    final updates = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => BulkUpdateCapacityDialog(
        selectedIds: selectedIds.toList(),
        items: items,
      ),
    );
    if (updates != null && updates.isNotEmpty) {
      await api.bulkUpdateCapacity(
        tenantId: widget.tenantId,
        updates: updates,
      );
      _resetAndReload();
    }
  }

  Future<void> _bulkStatus() async {
    final isActive = await showDialog<bool>(
      context: context,
      builder: (_) => const BulkUpdateStatusDialog(),
    );
    if (isActive != null) {
      await api.bulkUpdateStatus(
        tenantId: widget.tenantId,
        classIds: selectedIds.toList(),
        isActive: isActive,
      );
      _resetAndReload();
    }
  }

  Future<void> _assignClassrooms() async {
    final map = await showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => AssignClassroomsDialog(
        selectedIds: selectedIds.toList(),
        items: items,
      ),
    );
    if (map != null && map.isNotEmpty) {
      await api.assignClassrooms(
        tenantId: widget.tenantId,
        classroomMap: map,
      );
      _resetAndReload();
    }
  }

  Future<void> _rollover() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RolloverDialog(selectedIds: selectedIds.toList()),
    );
    if (payload != null) {
      await api.rollover(
        tenantId: widget.tenantId,
        fromYear: payload['from'] as String,
        toYear: payload['to'] as String,
        classIds: payload['ids'] as List<String>?,
      );
      _resetAndReload();
    }
  }

  Future<void> _bulkDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmBulkDeleteDialog(count: selectedIds.length),
    );
    if (ok == true) {
      await api.bulkDelete(
        tenantId: widget.tenantId,
        classIds: selectedIds.toList(),
      );
      selectedIds.clear();
      _resetAndReload();
    }
  }

  Future<void> _showDetails(ClassModel m) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ClassDetailsDialog(model: m, fetch: () => api.getById(m.id)),
    );
  }

  // NEW: Create Class Timetable for the selected class
  Future<void> _createClassTimetableForSelected() async {
    if (selectedIds.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select exactly one class')));
      return;
    }
    final selectedClassId = selectedIds.first;
    final selectedClass = items.where((c) => c.id == selectedClassId).isNotEmpty
        ? items.firstWhere((c) => c.id == selectedClassId)
        : null;

    // TODO: Provide a valid master timetable id from your app state or a picker
    final masterId = await _askMasterId();
    if (masterId == null || masterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Master timetable is required')));
      return;
    }

    final timetableApi = TimetableService(widget.baseUrl);
    final classApi = ClassApi(baseUrl: widget.baseUrl, defaultHeaders: {'Accept':'application/json', ...widget.headers});

    // Optionally pass the selected class id to preselect/lock the dropdown
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CreateClassTimetableDialog(
        tenantId: widget.tenantId,
        userId: (widget.headers['x-user-id'] ?? widget.headers['userId'] ?? 'system'),
        masterId: masterId,
        academicYear: selectedClass?.academicYear.isNotEmpty == true
            ? selectedClass!.academicYear
            : (filterYear ?? ''),
        api: timetableApi,
        classApi: classApi,
      ),
    );

    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class timetable created')));
    }
  }

  // Simple input dialog to capture master id; replace with a real master picker if available
  Future<String?> _askMasterId() async {
    String temp = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Master Timetable ID'),
        content: TextField(
          onChanged: (v) => temp = v.trim(),
          decoration: const InputDecoration(hintText: 'master_timetable_id'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('Use')),
        ],
      ),
    );
  }

  void _openFilters() {
    String? tmpYear = filterYear;
    String? tmpSection = filterSection;
    int? tmpGrade = filterGrade;
    bool? tmpActive = filterActive;
    final yearCtrl = TextEditingController(text: tmpYear ?? '');
    final sectionCtrl = TextEditingController(text: tmpSection ?? '');
    final gradeCtrl =
        TextEditingController(text: tmpGrade != null ? '$tmpGrade' : '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter classes', style: Sa.cardTitle),
                  const SizedBox(height: Sa.gapLg),
                  TextField(
                    controller: yearCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Academic Year', hintText: '2025-26'),
                    onChanged: (v) => tmpYear = v.isEmpty ? null : v,
                  ),
                  const SizedBox(height: Sa.gap),
                  TextField(
                    controller: sectionCtrl,
                    decoration: const InputDecoration(labelText: 'Section'),
                    onChanged: (v) => tmpSection = v.isEmpty ? null : v,
                  ),
                  const SizedBox(height: Sa.gap),
                  TextField(
                    controller: gradeCtrl,
                    decoration: const InputDecoration(labelText: 'Grade'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        tmpGrade = v.isEmpty ? null : int.tryParse(v),
                  ),
                  const SizedBox(height: Sa.gap),
                  DropdownButtonFormField<bool?>(
                    isExpanded: true,
                    initialValue: tmpActive,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem<bool?>(value: null, child: Text('All')),
                      DropdownMenuItem<bool?>(
                          value: true, child: Text('Active')),
                      DropdownMenuItem<bool?>(
                          value: false, child: Text('Inactive')),
                    ],
                    onChanged: (v) => setSheet(() => tmpActive = v),
                  ),
                  const SizedBox(height: Sa.gapLg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            filterYear = null;
                            filterSection = null;
                            filterGrade = null;
                            filterActive = null;
                            _resetAndReload();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.neutral600,
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: Sa.stroke),
                            shape: const RoundedRectangleBorder(
                                borderRadius: AppTheme.borderRadius12),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: Sa.gap),
                      Expanded(
                        child: SaPrimaryButton(
                          label: 'Apply',
                          icon: Icons.filter_alt_outlined,
                          onPressed: () {
                            Navigator.pop(ctx);
                            filterYear = tmpYear;
                            filterSection = tmpSection;
                            filterGrade = tmpGrade;
                            filterActive = tmpActive;
                            _resetAndReload();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openActions() {
    final hasSelection = selectedIds.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Text(
                  hasSelection
                      ? '${selectedIds.length} selected'
                      : 'Class actions',
                  style: Sa.cardTitle,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.file_upload,
                    color: AppTheme.greenPrimary),
                title: const Text('Bulk Import CSV'),
                onTap: _isSubmitting
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _bulkImport();
                      },
              ),
              ListTile(
                leading:
                    const Icon(Icons.roofing, color: AppTheme.greenPrimary),
                title: const Text('Rollover'),
                onTap: _isSubmitting
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _rollover();
                      },
              ),
              ListTile(
                leading:
                    const Icon(Icons.schedule, color: AppTheme.greenPrimary),
                title: const Text('Create Class Timetable'),
                subtitle: const Text('Select exactly one class'),
                enabled: selectedIds.length == 1,
                onTap: selectedIds.length == 1
                    ? () {
                        Navigator.pop(ctx);
                        _createClassTimetableForSelected();
                      }
                    : null,
              ),
              if (hasSelection) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.people_outline,
                      color: AppTheme.greenPrimary),
                  title: const Text('Update Capacity'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _bulkCapacity();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.meeting_room_outlined,
                      color: AppTheme.greenPrimary),
                  title: const Text('Assign Classrooms'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _assignClassrooms();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.toggle_on_outlined,
                      color: AppTheme.greenPrimary),
                  title: const Text('Toggle Status'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _bulkStatus();
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: AppTheme.error),
                  title: const Text('Delete selected',
                      style: TextStyle(color: AppTheme.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _bulkDelete();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _classCard(ClassModel m) {
    final selected = selectedIds.contains(m.id);
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(
            icon: Icons.class_outlined,
            title: m.className,
            trailing: SaStatusPill(
              text: m.isActive ? 'Active' : 'Inactive',
              color: m.isActive ? AppTheme.greenPrimary : AppTheme.neutral400,
              icon: m.isActive
                  ? Icons.check_circle_outline
                  : Icons.remove_circle_outline,
            ),
          ),
          const SizedBox(height: Sa.gap),
          SaInfoRow(label: 'Grade / Section', value: '${m.gradeLevel}-${m.section}'),
          SaInfoRow(label: 'Academic Year', value: m.academicYear),
          SaInfoRow(label: 'Classroom', value: m.classroom ?? '—'),
          SaInfoRow(
              label: 'Students',
              value: '${m.currentStudents}/${m.maximumStudents}'),
          const SizedBox(height: Sa.gapXs),
          Row(
            children: [
              Tooltip(
                message: 'Select',
                child: Checkbox(
                  value: selected,
                  activeColor: AppTheme.greenPrimary,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        selectedIds.add(m.id);
                      } else {
                        selectedIds.remove(m.id);
                      }
                    });
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'View',
                icon: const Icon(Icons.visibility_outlined,
                    color: AppTheme.greenPrimary),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => _showDetails(m),
              ),
              IconButton(
                tooltip: 'Update count',
                icon: const Icon(Icons.group_outlined,
                    color: AppTheme.greenPrimary),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => _updateCount(m),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.neutral600),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => _createOrEdit(m),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: _isSubmitting ? null : () => _delete(m),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pagination() {
    return SaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Flexible(
            child: Text('Total: $total',
                style: Sa.label, overflow: TextOverflow.ellipsis),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Previous',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: page > 1
                ? () {
                    setState(() => page--);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page $page', style: Sa.value),
          IconButton(
            tooltip: 'Next',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: (page * pageSize) < total
                ? () {
                    setState(() => page++);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (loading) return const SaLoading(message: 'Loading classes…');
    if (_error != null) {
      return SaStateView.error(message: _error!, onRetry: _load);
    }
    if (items.isEmpty) {
      return SaStateView(
        icon: Icons.class_outlined,
        title: 'No classes found',
        subtitle: 'Create a class to get started.',
        action: SaPrimaryButton(
          label: 'New Class',
          icon: Icons.add,
          onPressed: _isSubmitting ? null : () => _createOrEdit(),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('Filter'),
                onPressed: _openFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Sa.accent,
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: Sa.accent, width: 1.5),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadius12),
                ),
              ),
            ),
            const SizedBox(width: Sa.gap),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.more_horiz, size: 18),
                label: Text(selectedIds.isNotEmpty
                    ? 'Actions (${selectedIds.length})'
                    : 'Actions'),
                onPressed: _openActions,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Sa.accent,
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: Sa.accent, width: 1.5),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadius12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sa.gap),
        ...items.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: Sa.gap),
              child: _classCard(m),
            )),
        _pagination(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Classes',
          subtitle: 'Manage classes, capacity & timetables',
          icon: Icons.class_outlined,
          trailing: SaHeaderAction(
            icon: Icons.add,
            tooltip: 'New class',
            onPressed: _isSubmitting ? null : () => _createOrEdit(),
          ),
        ),
      ),
      child: _body(),
    );
  }
}
