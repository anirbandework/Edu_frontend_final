import 'package:flutter/material.dart';
import '../../../core/models/timetable_models.dart';
import '../../../services/timetable_service.dart';
import '../widgets/timetable_screen_dialog/create_master_timetable_dialog.dart';
import '../widgets/timetable_screen_dialog/create_class_timetable_dialog.dart';
import '../widgets/timetable_screen_dialog/bulk_schedule_dialog.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../services/class_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/class_model.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return SizedBox(
            height: height,
            child: Container(
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
              child: SafeArea(
                child: ResponsiveContainer(
                  maxWidth: context.responsive(ResponsiveSize.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Timetables',
                        style: Theme.of(context).textTheme.headlineLarge!
                            .copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(
                              context.responsive(ResponsiveSize.cardPadding),
                            ),
                            child: Column(
                              children: [
                                _toolbar(context),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _MastersCard(
                                        masters: masters,
                                        selectedMasterId: selectedMasterId,
                                        onSelect: (id) => setState(
                                          () => selectedMasterId = id,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _RightColumn(
                                        api: api,
                                        tenantId: widget.tenantId,
                                        academicYear: widget.academicYear,
                                        baseUrl: widget.baseUrl,
                                        onPickClass: (id) =>
                                            _loadClassSchedule(id),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                if (loadingSchedule)
                                  const LinearProgressIndicator(),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 720,
                                      ),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: weekly == null
                                              ? const Center(
                                                  child: Text(
                                                    "No class selected",
                                                  ),
                                                )
                                              : _WeeklyGridTable(
                                                  weekly: weekly!,
                                                  totalPeriods: totalPeriods,
                                                  workingDays: workingDays,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
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
      floatingActionButton: hasTenant
          ? FloatingActionButton(
              backgroundColor: AppTheme.greenPrimary,
              onPressed: () async {
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
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _toolbar(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: hasTenant
              ? () async {
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
                      setState(
                        () => selectedMasterId = created["id"] as String?,
                      );
                    }
                  }
                }
              : null,
          icon: const Icon(Icons.add),
          label: const Text("New Master"),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () async {
            final classApi = ClassApi(
              baseUrl: widget.baseUrl,
              defaultHeaders: {'Accept': 'application/json'},
            );

            // If no master selected, optionally prompt the user for a master id, or let the dialog handle it.
            String masterIdToUse;
            if (selectedMasterId != null) {
              masterIdToUse = selectedMasterId!;
            } else {
              // Simple inline prompt; replace with a proper picker if you have one
              String temp = '';
              final got = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Pick Master Timetable'),
                  content: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: null,
                    items: masters
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              '${m.timetableName} • ${m.academicYear}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => temp = v ?? '',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, temp),
                      child: const Text('Use'),
                    ),
                  ],
                ),
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
          },
          child: const Text("Create Class Timetable"),
        ),

        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: canBulkEdit
              ? () async {
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
              : null,
          child: const Text("Bulk Edit"),
        ),
      ],
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
    return Card(
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: AppTheme.borderRadius12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Master Timetables",
              style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: masters.isEmpty
                  ? const Center(child: Text("No masters"))
                  : ListView.builder(
                      itemCount: masters.length,
                      itemBuilder: (ctx, i) {
                        final m = masters[i];
                        final selected = m.id == selectedMasterId;
                        return ListTile(
                          dense: true,
                          title: Text(m.timetableName),
                          subtitle: Text(
                            "${m.academicYear} • ${m.totalPeriodsPerDay} periods/day",
                          ),
                          selected: selected,
                          onTap: () => onSelect(m.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({
    required this.api,
    required this.tenantId,
    required this.academicYear,
    required this.baseUrl,
    required this.onPickClass,
  });

  final TimetableService api;
  final UUID tenantId;
  final String academicYear;
  final String baseUrl;
  final void Function(UUID) onPickClass;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppTheme.borderRadius12,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 140,
              child: _ClassPicker(
                tenantId: tenantId,
                academicYear: academicYear,
                baseUrl: baseUrl,
                onPick: onPickClass,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadius12,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      child: _AnalyticsPanel(
                        api: api,
                        tenantId: tenantId,
                        academicYear: academicYear,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadius12,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      child: _ConflictsScrollable(api: api, tenantId: tenantId),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load classes: $e")));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pick Class",
          style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (loading) const LinearProgressIndicator(),
        DropdownButtonFormField<String>(
          isDense: true,
          value: selected,
          hint: const Text("Select class"),
          items: classes
              .map(
                (e) => DropdownMenuItem(
                  value: e["id"],
                  child: Text(e["name"] ?? e["id"]!),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => selected = v),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: selected == null ? null : () => widget.onPick(selected!),
          child: const Text("Load Schedule"),
        ),
      ],
    );
  }
}

class _WeeklyGridTable extends StatelessWidget {
  const _WeeklyGridTable({
    required this.weekly,
    required this.totalPeriods,
    required this.workingDays,
  });
  final WeeklySchedule weekly;
  final int totalPeriods;
  final List<DayOfWeek> workingDays;

  @override
  Widget build(BuildContext context) {
    final days = workingDays.isEmpty
        ? DayOfWeek.values.where((d) => d != DayOfWeek.sunday).toList()
        : workingDays;

    return DataTable(
      columns: [
        const DataColumn(label: Text("Period")),
        ...days.map(
          (d) => DataColumn(
            label: Text(d.name[0].toUpperCase() + d.name.substring(1)),
          ),
        ),
      ],
      rows: List.generate(totalPeriods, (i) {
        final p = i + 1;
        return DataRow(
          cells: [
            DataCell(Text("$p")),
            ...days.map((d) {
              final cells = weekly.days[d] ?? [];
              final cell = cells
                  .where((c) => c.periodNumber == p)
                  .cast<ScheduleCell?>()
                  .firstWhere((_) => true, orElse: () => null);
              if (cell == null) return const DataCell(Text("—"));
              return DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${cell.periodName} • ${cell.startTime}-${cell.endTime}",
                        style: AppTheme.bodyMicro,
                      ),
                      if (cell.subjectName != null)
                        Text(
                          cell.subjectName!,
                          style: AppTheme.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (cell.teacherName != null)
                        Text(
                          cell.teacherName!,
                          style: AppTheme.bodyMicro.copyWith(
                            color: AppTheme.neutral500,
                          ),
                        ),
                      if (cell.roomNumber != null)
                        Text(
                          "Room ${cell.roomNumber!}",
                          style: AppTheme.bodyMicro.copyWith(
                            color: AppTheme.neutral500,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      }),
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
    return data == null
        ? const Text("No analytics")
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Analytics",
                style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text("Total classes: ${data!["total_classes"] ?? "-"}"),
              Text("Total teachers: ${data!["total_teachers"] ?? "-"}"),
              Text("Entries: ${data!["total_schedule_entries"] ?? "-"}"),
            ],
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
    if (items.isEmpty) return const Text("No conflicts");
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final c = items[i];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(c.title),
          subtitle: Text("${c.conflictType} • ${c.severity}"),
        );
      },
    );
  }
}
