import 'package:flutter/material.dart';
import '../../../core/models/timetable_models.dart';
import '../../../services/timetable_service.dart';
import '../widgets/timetable_screen_dialog/create_master_timetable_dialog.dart';
import '../widgets/timetable_screen_dialog/create_class_timetable_dialog.dart';
import '../widgets/timetable_screen_dialog/bulk_schedule_dialog.dart';
import '../../../core/constants/app_theme.dart';
import '../../../services/class_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/class_model.dart';
import '../../super_admin/widgets/sa_widgets.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({
    super.key,
    required this.baseUrl,
    required this.tenantId,
    required this.currentUserId,
    required this.academicYear,
  });

  final String baseUrl;
  final UUID tenantId;
  final UUID currentUserId;
  final String academicYear;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late final TimetableService api;
  List<MasterTimetableSummary> masters = [];
  UUID? selectedMasterId;
  UUID? selectedClassId;

  WeeklySchedule? weekly;
  int totalPeriods = 8;
  List<DayOfWeek> workingDays = [
    DayOfWeek.monday,
    DayOfWeek.tuesday,
    DayOfWeek.wednesday,
    DayOfWeek.thursday,
    DayOfWeek.friday,
  ];

  bool loadingSchedule = false;

  bool get hasTenant => (widget.tenantId).toString().isNotEmpty;
  bool get canCreateClass => hasTenant && (selectedMasterId != null);
  bool get canBulkEdit => selectedClassId != null;

  @override
  void initState() {
    super.initState();
    api = TimetableService(widget.baseUrl);
    if (hasTenant) _loadMasters();
  }

  Future<void> _loadMasters() async {
    final data = await api.listMasters(
      widget.tenantId,
      academicYear: widget.academicYear,
    );
    if (!mounted) return;
    setState(() => masters = data);
  }

  Future<void> _loadClassSchedule(UUID classId) async {
    setState(() {
      loadingSchedule = true;
      selectedClassId = classId;
    });
    try {
      final res = await api.getClassWeeklySchedule(
        classId,
        widget.academicYear,
      );
      if (!mounted) return;
      setState(() {
        weekly = res.weekly;
        totalPeriods = res.totalPeriods;
        workingDays = res.workingDays;
      });
    } finally {
      if (mounted) setState(() => loadingSchedule = false);
    }
  }

  Future<void> _createMaster() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CreateMasterTimetableDialog(
        tenantId: widget.tenantId,
        userId: widget.currentUserId,
        academicYear: widget.academicYear,
        api: api,
      ),
    );
    if (created != null) {
      await _loadMasters();
      if (created["id"] != null) {
        setState(() => selectedMasterId = created["id"] as String?);
      }
    }
  }

  Future<void> _createClassTimetable() async {
    final classApi = ClassApi(
      baseUrl: widget.baseUrl,
      defaultHeaders: {'Accept': 'application/json'},
    );

    String masterIdToUse;
    if (selectedMasterId != null) {
      masterIdToUse = selectedMasterId!;
    } else {
      String temp = '';
      final got = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final maxW = MediaQuery.of(ctx).size.width - 24;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 24,
            ),
            backgroundColor: Sa.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Sa.radius),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW > 480 ? 480 : maxW),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pick Master Timetable', style: Sa.cardTitle),
                    const SizedBox(height: Sa.gap),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: null,
                      items: masters
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                '${m.timetableName} • ${m.academicYear}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => temp = v ?? '',
                    ),
                    const SizedBox(height: Sa.gapLg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.neutral600,
                            minimumSize: const Size(0, 46),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: Sa.gapXs),
                        SaPrimaryButton(
                          label: 'Use',
                          icon: Icons.check_rounded,
                          onPressed: () => Navigator.pop(ctx, temp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (got == null || got.isEmpty) return;
      masterIdToUse = got;
      setState(() => selectedMasterId = masterIdToUse);
    }

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CreateClassTimetableDialog(
        tenantId: widget.tenantId,
        userId: widget.currentUserId,
        masterId: masterIdToUse,
        academicYear: widget.academicYear,
        api: api,
        classApi: classApi,
      ),
    );
    if (res != null && res["class_id"] != null) {
      await _loadClassSchedule(res["class_id"] as String);
    }
  }

  Future<void> _bulkEdit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => BulkScheduleDialog(
        tenantId: widget.tenantId,
        classId: selectedClassId!,
        academicYear: widget.academicYear,
        api: api,
      ),
    );
    if (saved == true && selectedClassId != null) {
      await _loadClassSchedule(selectedClassId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'School Timetables',
          subtitle: 'Masters, class schedules & conflicts',
          icon: Icons.calendar_view_week_outlined,
          trailing: hasTenant
              ? SaHeaderAction(
                  icon: Icons.add,
                  tooltip: 'New master timetable',
                  onPressed: _createMaster,
                )
              : null,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 96),
        children: [
          _ActionsCard(
            hasTenant: hasTenant,
            canBulkEdit: canBulkEdit,
            onCreateMaster: _createMaster,
            onCreateClass: _createClassTimetable,
            onBulkEdit: _bulkEdit,
          ),
          const SizedBox(height: Sa.gap),
          _MastersCard(
            masters: masters,
            selectedMasterId: selectedMasterId,
            onSelect: (id) => setState(() => selectedMasterId = id),
          ),
          const SizedBox(height: Sa.gap),
          _ClassPicker(
            tenantId: widget.tenantId,
            academicYear: widget.academicYear,
            baseUrl: widget.baseUrl,
            onPick: _loadClassSchedule,
          ),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, c) {
              final oneCol = c.maxWidth < 600;
              final analytics = _AnalyticsPanel(
                api: api,
                tenantId: widget.tenantId,
                academicYear: widget.academicYear,
              );
              final conflicts = _ConflictsScrollable(
                api: api,
                tenantId: widget.tenantId,
              );
              if (oneCol) {
                return Column(
                  children: [
                    analytics,
                    const SizedBox(height: Sa.gap),
                    conflicts,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: analytics),
                  const SizedBox(width: Sa.gap),
                  Expanded(child: conflicts),
                ],
              );
            },
          ),
          const SizedBox(height: Sa.gap),
          _ScheduleCard(
            loading: loadingSchedule,
            weekly: weekly,
            totalPeriods: totalPeriods,
            workingDays: workingDays,
          ),
        ],
      ),
    );
  }
}

/// Quick-actions card: create master, create class timetable, bulk edit.
class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.hasTenant,
    required this.canBulkEdit,
    required this.onCreateMaster,
    required this.onCreateClass,
    required this.onBulkEdit,
  });

  final bool hasTenant;
  final bool canBulkEdit;
  final VoidCallback onCreateMaster;
  final VoidCallback onCreateClass;
  final VoidCallback onBulkEdit;

  @override
  Widget build(BuildContext context) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.bolt_outlined,
            title: 'Quick actions',
          ),
          const SizedBox(height: Sa.gap),
          SaPrimaryButton(
            label: 'New Master',
            icon: Icons.add,
            expand: true,
            onPressed: hasTenant ? onCreateMaster : null,
          ),
          const SizedBox(height: Sa.gapXs),
          _OutlinedAction(
            label: 'Create Class Timetable',
            icon: Icons.class_outlined,
            onPressed: onCreateClass,
          ),
          const SizedBox(height: Sa.gapXs),
          _OutlinedAction(
            label: 'Bulk Edit',
            icon: Icons.edit_calendar_outlined,
            onPressed: canBulkEdit ? onBulkEdit : null,
          ),
        ],
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Sa.accent,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: Sa.accent.withValues(alpha: 0.6), width: 1.4),
          shape: const RoundedRectangleBorder(
            borderRadius: AppTheme.borderRadius12,
          ),
        ),
      ),
    );
  }
}

class _MastersCard extends StatelessWidget {
  const _MastersCard({
    required this.masters,
    required this.selectedMasterId,
    required this.onSelect,
  });

  final List<MasterTimetableSummary> masters;
  final UUID? selectedMasterId;
  final void Function(UUID id) onSelect;

  @override
  Widget build(BuildContext context) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.event_note_outlined,
            title: 'Master Timetables',
          ),
          const SizedBox(height: Sa.gap),
          if (masters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No masters yet',
                style: Sa.body,
                textAlign: TextAlign.center,
              ),
            )
          else
            ...masters.map((m) {
              final selected = m.id == selectedMasterId;
              return Padding(
                padding: const EdgeInsets.only(bottom: Sa.gapXs),
                child: Material(
                  color: selected
                      ? Sa.accent.withValues(alpha: 0.10)
                      : AppTheme.neutral50,
                  borderRadius: AppTheme.borderRadius12,
                  child: InkWell(
                    onTap: () => onSelect(m.id),
                    borderRadius: AppTheme.borderRadius12,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.borderRadius12,
                        border: Border.all(
                          color: selected
                              ? Sa.accent.withValues(alpha: 0.5)
                              : Sa.stroke.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.timetableName,
                                  style: Sa.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${m.academicYear} • ${m.totalPeriodsPerDay} periods/day',
                                  style: Sa.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Sa.accent,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ClassPicker extends StatefulWidget {
  const _ClassPicker({
    required this.tenantId,
    required this.academicYear,
    required this.baseUrl,
    required this.onPick,
  });

  final UUID tenantId;
  final String academicYear;
  final String baseUrl;
  final Function(UUID) onPick;

  @override
  State<_ClassPicker> createState() => _ClassPickerState();
}

class _ClassPickerState extends State<_ClassPicker> {
  List<Map<String, String>> classes = [];
  String? selected;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    if ((widget.tenantId).toString().isEmpty) return;
    setState(() => loading = true);
    try {
      final api = ClassApi(
        baseUrl: widget.baseUrl.isNotEmpty
            ? widget.baseUrl
            : AppConstants.apiBaseUrl,
        defaultHeaders: {'Accept': 'application/json'},
      );
      final res = await api.getPaginated(
        page: 1,
        pageSize: 200,
        tenantId: widget.tenantId,
        academicYear: widget.academicYear, // or null if you want all
        isActive: true,
      );
      final list = ClassModel.listFromPaginated(res);
      classes = list
          .map(
            (c) => {
              "id": c.id,
              "name": "${c.className} (${c.gradeLevel}-${c.section})",
            },
          )
          .toList();
      if (classes.isNotEmpty) selected = classes.first["id"];
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load classes: $e"),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.groups_outlined,
            title: 'Pick Class',
          ),
          const SizedBox(height: Sa.gap),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: Sa.gapXs),
              child: ClipRRect(
                borderRadius: AppTheme.borderRadius8,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: AppTheme.neutral200,
                  valueColor: AlwaysStoppedAnimation(AppTheme.greenPrimary),
                ),
              ),
            ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            isDense: true,
            initialValue: selected,
            hint: const Text("Select class"),
            items: classes
                .map(
                  (e) => DropdownMenuItem(
                    value: e["id"],
                    child: Text(
                      e["name"] ?? e["id"]!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => selected = v),
          ),
          const SizedBox(height: Sa.gap),
          SaPrimaryButton(
            label: 'Load Schedule',
            icon: Icons.download_outlined,
            expand: true,
            onPressed: selected == null
                ? null
                : () => widget.onPick(selected!),
          ),
        ],
      ),
    );
  }
}

/// Weekly schedule card with day-wise, never-overflowing layout.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.loading,
    required this.weekly,
    required this.totalPeriods,
    required this.workingDays,
  });

  final bool loading;
  final WeeklySchedule? weekly;
  final int totalPeriods;
  final List<DayOfWeek> workingDays;

  @override
  Widget build(BuildContext context) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.calendar_month_outlined,
            title: 'Weekly Schedule',
          ),
          const SizedBox(height: Sa.gap),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: Sa.gap),
              child: ClipRRect(
                borderRadius: AppTheme.borderRadius8,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: AppTheme.neutral200,
                  valueColor: AlwaysStoppedAnimation(AppTheme.greenPrimary),
                ),
              ),
            ),
          if (weekly == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 32,
                      color: AppTheme.neutral400,
                    ),
                    SizedBox(height: Sa.gapXs),
                    Text('No class selected', style: Sa.body),
                  ],
                ),
              ),
            )
          else
            _WeeklyDayWise(
              weekly: weekly!,
              totalPeriods: totalPeriods,
              workingDays: workingDays,
            ),
        ],
      ),
    );
  }
}

/// Day-wise rendering of the weekly schedule so it never overflows on a phone.
class _WeeklyDayWise extends StatelessWidget {
  const _WeeklyDayWise({
    required this.weekly,
    required this.totalPeriods,
    required this.workingDays,
  });
  final WeeklySchedule weekly;
  final int totalPeriods;
  final List<DayOfWeek> workingDays;

  String _dayLabel(DayOfWeek d) =>
      d.name[0].toUpperCase() + d.name.substring(1);

  @override
  Widget build(BuildContext context) {
    final days = workingDays.isEmpty
        ? DayOfWeek.values.where((d) => d != DayOfWeek.sunday).toList()
        : workingDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in days) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Sa.gapXs, top: Sa.gapXs),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Sa.accent.withValues(alpha: 0.12),
                    borderRadius: AppTheme.borderRadius8,
                  ),
                  child: Text(
                    _dayLabel(d),
                    style: Sa.label.copyWith(
                      color: Sa.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(totalPeriods, (i) {
            final p = i + 1;
            final cells = weekly.days[d] ?? [];
            final cell = cells
                .where((c) => c.periodNumber == p)
                .cast<ScheduleCell?>()
                .firstWhere((_) => true, orElse: () => null);
            return _PeriodRow(period: p, cell: cell);
          }),
          const SizedBox(height: Sa.gapXs),
          const Divider(height: 1, color: AppTheme.neutral200),
        ],
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.cell});
  final int period;
  final ScheduleCell? cell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              'P$period',
              style: Sa.label.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: Sa.gapXs),
          Expanded(
            child: cell == null
                ? const Text('—', style: Sa.body)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${cell!.periodName} • ${cell!.startTime}-${cell!.endTime}",
                        style: Sa.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cell!.subjectName != null)
                        Text(
                          cell!.subjectName!,
                          style: Sa.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (cell!.teacherName != null)
                        Text(
                          cell!.teacherName!,
                          style: Sa.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (cell!.roomNumber != null)
                        Text(
                          "Room ${cell!.roomNumber!}",
                          style: Sa.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsPanel extends StatefulWidget {
  const _AnalyticsPanel({
    required this.api,
    required this.tenantId,
    required this.academicYear,
  });
  final TimetableService api;
  final UUID tenantId;
  final String academicYear;

  @override
  State<_AnalyticsPanel> createState() => _AnalyticsPanelState();
}

class _AnalyticsPanelState extends State<_AnalyticsPanel> {
  Map<String, dynamic>? data;
  @override
  void initState() {
    super.initState();
    widget.api
        .getAnalytics(widget.tenantId, widget.academicYear)
        .then((v) {
          if (mounted) setState(() => data = v);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SaCardHeader(
            icon: Icons.insights_outlined,
            title: 'Analytics',
          ),
          const SizedBox(height: Sa.gap),
          if (data == null)
            const Text('No analytics', style: Sa.body)
          else ...[
            SaInfoRow(
              label: 'Total classes',
              value: '${data!["total_classes"] ?? "-"}',
            ),
            SaInfoRow(
              label: 'Total teachers',
              value: '${data!["total_teachers"] ?? "-"}',
            ),
            SaInfoRow(
              label: 'Entries',
              value: '${data!["total_schedule_entries"] ?? "-"}',
            ),
          ],
        ],
      ),
    );
  }
}

class _ConflictsScrollable extends StatefulWidget {
  const _ConflictsScrollable({required this.api, required this.tenantId});
  final TimetableService api;
  final UUID tenantId;

  @override
  State<_ConflictsScrollable> createState() => _ConflictsScrollableState();
}

class _ConflictsScrollableState extends State<_ConflictsScrollable> {
  List<ConflictItem> items = [];
  @override
  void initState() {
    super.initState();
    widget.api
        .getConflicts(widget.tenantId)
        .then((v) {
          if (mounted) setState(() => items = v);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaCardHeader(
            icon: Icons.report_problem_outlined,
            title: 'Conflicts',
            color: items.isEmpty ? Sa.accent : AppTheme.error,
          ),
          const SizedBox(height: Sa.gap),
          if (items.isEmpty)
            const Text('No conflicts', style: Sa.body)
          else
            ...items.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: Sa.gapXs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: Sa.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${c.conflictType} • ${c.severity}",
                      style: Sa.label.copyWith(color: AppTheme.error),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
