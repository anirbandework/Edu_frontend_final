import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../services/class_service.dart';
import '../../../services/timetable_service.dart';
import '../../../core/constants/app_constants.dart';
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
      total = (res is Map && res['total'] is int) ? res['total'] as int : items.length;
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

  Widget _filters(BuildContext context) {
    return Card(
      elevation: 1,
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius12),
      child: Padding(
        padding: EdgeInsets.all(context.responsive(ResponsiveSize.cardPadding)),
        child: Column(
          children: [
            Row(
              children: [
                Flexible(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Academic Year', hintText: '2025-26'),
                    onChanged: (v) => filterYear = v.isEmpty ? null : v,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Section'),
                    onChanged: (v) => filterSection = v.isEmpty ? null : v,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Grade'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => filterGrade = v.isEmpty ? null : int.tryParse(v),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: DropdownButtonFormField<bool?>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem<bool?>(value: null, child: Text('All')),
                      DropdownMenuItem<bool?>(value: true, child: Text('Active')),
                      DropdownMenuItem<bool?>(value: false, child: Text('Inactive')),
                    ],
                    onChanged: (v) => filterActive = v,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _resetAndReload, child: const Text('Apply')),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () {
                    filterYear = null;
                    filterSection = null;
                    filterGrade = null;
                    filterActive = null;
                    _resetAndReload();
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('New Class'),
          onPressed: _isSubmitting ? null : () => _createOrEdit(),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.file_upload),
          label: const Text('Bulk Import CSV'),
          onPressed: _isSubmitting ? null : _bulkImport,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.roofing),
          label: const Text('Rollover'),
          onPressed: _isSubmitting ? null : _rollover,
        ),
        const SizedBox(width: 8),
        // NEW: Create Class Timetable
        OutlinedButton.icon(
          icon: const Icon(Icons.schedule),
          label: const Text('Create Class Timetable'),
          onPressed: selectedIds.length == 1 ? _createClassTimetableForSelected : null,
        ),
        const Spacer(),
        if (selectedIds.isNotEmpty) ...[
          Text('${selectedIds.length} selected'),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _bulkCapacity, child: const Text('Update Capacity')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _assignClassrooms, child: const Text('Assign Classrooms')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _bulkStatus, child: const Text('Toggle Status')),
          const SizedBox(width: 8),
          TextButton(onPressed: _bulkDelete, child: const Text('Delete')),
        ],
      ],
    );
  }

  DataRow _row(ClassModel m) {
    final selected = selectedIds.contains(m.id);
    return DataRow(
      selected: selected,
      onSelectChanged: (v) {
        setState(() {
          if (v == true) {
            selectedIds.add(m.id);
          } else {
            selectedIds.remove(m.id);
          }
        });
      },
      cells: [
        DataCell(Text(m.className)),
        DataCell(Text('${m.gradeLevel}-${m.section}')),
        DataCell(Text(m.academicYear)),
        DataCell(Text(m.classroom ?? '-')),
        DataCell(Text('${m.currentStudents}/${m.maximumStudents}')),
        DataCell(Text(m.isActive ? 'Active' : 'Inactive')),
        DataCell(Row(
          children: [
            IconButton(icon: const Icon(Icons.visibility), onPressed: () => _showDetails(m)),
            IconButton(icon: const Icon(Icons.group), onPressed: () => _updateCount(m)),
            IconButton(icon: const Icon(Icons.edit), onPressed: () => _createOrEdit(m)),
            IconButton(icon: const Icon(Icons.delete), onPressed: _isSubmitting ? null : () => _delete(m)),
          ],
        )),
      ],
    );
  }

  Widget _errorPanel(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.class_outlined, size: 48, color: AppTheme.neutral400),
          const SizedBox(height: 12),
          Text('No classes found', style: AppTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New Class'),
            onPressed: _isSubmitting ? null : () => _createOrEdit(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // web stability
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.hasBoundedHeight ? constraints.maxHeight : MediaQuery.of(context).size.height;
          return SizedBox(
            height: h,
            child: Container(
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
              child: SafeArea(
                child: ResponsiveContainer(
                  maxWidth: context.responsive(ResponsiveSize.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Classes', style: Theme.of(context).textTheme.headlineLarge!.copyWith(color: Colors.white)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(context.responsive(ResponsiveSize.cardPadding)),
                            child: Column(
                              children: [
                                _toolbar(context),
                                const SizedBox(height: 12),
                                _filters(context),
                                const Divider(),
                                if (loading) const LinearProgressIndicator(),
                                Expanded(
                                  child: _error != null
                                      ? _errorPanel(context)
                                      : (!loading && items.isEmpty)
                                          ? _emptyState(context)
                                          : SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(minWidth: 600),
                                                child: SingleChildScrollView(
                                                  scrollDirection: Axis.vertical,
                                                  child: DataTable(
                                                    columns: const [
                                                      DataColumn(label: Text('Name')),
                                                      DataColumn(label: Text('Grade-Section')),
                                                      DataColumn(label: Text('Year')),
                                                      DataColumn(label: Text('Room')),
                                                      DataColumn(label: Text('Students')),
                                                      DataColumn(label: Text('Status')),
                                                      DataColumn(label: Text('Actions')),
                                                    ],
                                                    rows: items.map(_row).toList(),
                                                  ),
                                                ),
                                              ),
                                            ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('Total: $total'),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: page > 1
                                          ? () {
                                              setState(() => page--);
                                              _load();
                                            }
                                          : null,
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    Text('Page $page'),
                                    IconButton(
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.greenPrimary,
        onPressed: () => _createOrEdit(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
