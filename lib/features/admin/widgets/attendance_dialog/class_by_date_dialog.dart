// lib/features/admin/widgets/attendance_dialog/class_by_date_dialog.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../services/attendance_service.dart';
import '../../../../core/models/attendance_models.dart';

// Reuse your ClassModel and ClassApi (paste.txt) by importing the file where you placed them.
// If ClassApi is in lib/features/admin/services/class_api.dart, update the import accordingly.
import '../../../../core/models/class_model.dart'; // <-- adjust to your actual path
import '../../../../services/class_service.dart'; // <-- adjust to your actual path
import '../../../super_admin/widgets/sa_widgets.dart';

class ClassByDateDialog extends StatefulWidget {
  final AttendanceService service;
  final String? tenantId; // optional, try to read from query/session if null
  final DateTime? initialDate;

  const ClassByDateDialog({
    super.key,
    required this.service,
    this.tenantId,
    this.initialDate,
  });

  @override
  State<ClassByDateDialog> createState() => _ClassByDateDialogState();
}

class _ClassByDateDialogState extends State<ClassByDateDialog> {
  final _periodCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadingClasses = false;

  // Data
  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;
  List<AttendanceRecord> _rows = [];

  late final ClassApi _classApi;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _classApi = const ClassApi(baseUrl: AppConstants.apiBaseUrl);
    _loadClasses();
  }

  @override
  void dispose() {
    _periodCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    if (widget.tenantId == null || widget.tenantId!.isEmpty) return;
    setState(() {
      _loadingClasses = true;
      _classes = [];
      _selectedClass = null;
    });
    try {
      // Get first page with a large page_size to avoid pagination for dialog selection
      final body = await _classApi.getPaginated(
        tenantId: widget.tenantId,
        page: 1,
        pageSize: 200,
        isActive: true,
      );
      final list = ClassModel.listFromPaginated(body);
      setState(() {
        _classes = list;
        if (_classes.isNotEmpty) _selectedClass = _classes.first;
      });
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to load classes: $e', ok: false);
    } finally {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _loadAttendance() async {
    if (_selectedClass == null) return;
    final period = int.tryParse(_periodCtrl.text.trim());
    setState(() {
      _loading = true;
      _rows = [];
    });
    try {
      final rows = await widget.service.getClassByDate(
        classId: _selectedClass!.id,
        attendanceDate: _date,
        periodNumber: period,
      );
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to load attendance: $e', ok: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppTheme.greenPrimary : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _dateLabel(DateTime d) => d.toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = math.min(media.size.width - 24, 520.0);
    final maxH = media.size.height - 80;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Sa.gapLg, Sa.gapLg, Sa.gapLg, Sa.gapLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _filtersCard(),
                    const SizedBox(height: Sa.gapLg),
                    _results(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Gradient header -------------------------------------------------------
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(Sa.gapLg, Sa.gap, Sa.gap, Sa.gap),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Sa.radius),
          topRight: Radius.circular(Sa.radius),
        ),
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
            child: const Icon(Icons.people_alt_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: Sa.gap),
          const Expanded(
            child: Text(
              'Class attendance by date',
              style: Sa.headerTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  // --- Filters ---------------------------------------------------------------
  Widget _filtersCard() {
    return SaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SaCardHeader(
            icon: Icons.tune_rounded,
            title: 'Filters',
          ),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, c) {
              final oneCol = c.maxWidth < 600;
              final tenantField = _tenantField();
              final classField = _classField();
              final dateField = _dateField();
              final periodField = _periodField();

              if (oneCol) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tenantField,
                    const SizedBox(height: Sa.gap),
                    classField,
                    const SizedBox(height: Sa.gap),
                    dateField,
                    const SizedBox(height: Sa.gap),
                    periodField,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tenantField),
                      const SizedBox(width: Sa.gap),
                      Expanded(child: classField),
                    ],
                  ),
                  const SizedBox(height: Sa.gap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: dateField),
                      const SizedBox(width: Sa.gap),
                      Expanded(child: periodField),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Sa.gapLg),
          SaPrimaryButton(
            label: _loading ? 'Loading…' : 'Load attendance',
            icon: Icons.search_rounded,
            busy: _loading,
            expand: true,
            onPressed: (_selectedClass == null || _loading) ? null : _loadAttendance,
          ),
        ],
      ),
    );
  }

  Widget _tenantField() {
    return InputDecorator(
      decoration: _dec('Tenant'),
      child: Text(
        widget.tenantId?.isNotEmpty == true ? widget.tenantId! : '—',
        style: Sa.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _classField() {
    if (_loadingClasses) {
      return InputDecorator(
        decoration: _dec('Class'),
        child: const SizedBox(
          height: 20,
          child: Center(
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: AppTheme.neutral200,
              valueColor: AlwaysStoppedAnimation(AppTheme.greenPrimary),
            ),
          ),
        ),
      );
    }
    return DropdownButtonFormField<ClassModel>(
      initialValue: _selectedClass,
      isExpanded: true,
      decoration: _dec('Class'),
      style: Sa.value,
      items: _classes
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(
                '${c.className} • Grade ${c.gradeLevel}${c.section.isNotEmpty ? ' - ${c.section}' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedClass = v),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: AppTheme.borderRadius12,
      child: InputDecorator(
        decoration: _dec('Date').copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined,
              size: 18, color: AppTheme.neutral500),
        ),
        child: Text(
          _dateLabel(_date),
          style: Sa.value,
        ),
      ),
    );
  }

  Widget _periodField() {
    return TextFormField(
      controller: _periodCtrl,
      style: Sa.value,
      decoration: _dec('Period (optional)'),
      keyboardType: TextInputType.number,
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: Sa.label,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      border: OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: AppTheme.greenPrimary, width: 1.5),
      ),
    );
  }

  // --- Results ---------------------------------------------------------------
  Widget _results() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: SaLoading(message: 'Loading attendance…'),
      );
    }
    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: SaStateView(
          icon: Icons.inbox_outlined,
          title: 'No records',
          subtitle: 'Pick a class and date, then load attendance.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Sa.gap),
          child: Row(
            children: [
              const Text('Results', style: Sa.cardTitle),
              const SizedBox(width: Sa.gapXs),
              SaStatusPill(text: '${_rows.length}'),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
          itemBuilder: (_, i) => _recordCard(_rows[i]),
        ),
      ],
    );
  }

  Widget _recordCard(AttendanceRecord r) {
    return SaCard(
      padding: const EdgeInsets.all(Sa.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.userId} • ${r.subjectName ?? '-'}',
                  style: Sa.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Sa.gapXs),
              Text(
                _dateLabel(r.attendanceDate),
                style: Sa.label,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              SaStatusPill(
                text: r.status.name,
                color: _statusColor(r.status.name),
              ),
              SaStatusPill(
                text: r.attendanceType.name,
                color: AppTheme.neutral500,
              ),
              SaStatusPill(
                text: 'Period ${r.periodNumber ?? '-'}',
                color: AppTheme.neutral500,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('absent')) return AppTheme.error;
    return AppTheme.greenPrimary;
  }
}
