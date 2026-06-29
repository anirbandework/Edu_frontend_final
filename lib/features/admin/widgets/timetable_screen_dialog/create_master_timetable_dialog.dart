import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/timetable_models.dart';
import '../../../../services/timetable_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class CreateMasterTimetableDialog extends StatefulWidget {
  const CreateMasterTimetableDialog({
    super.key,
    required this.tenantId,
    required this.userId,
    required this.academicYear,
    required this.api,
  });

  final UUID tenantId;
  final UUID userId;
  final String academicYear;
  final TimetableService api;

  @override
  State<CreateMasterTimetableDialog> createState() => _CreateMasterTimetableDialogState();
}

class _CreateMasterTimetableDialogState extends State<CreateMasterTimetableDialog> {
  final _formKey = GlobalKey<FormState>();

  // Fields
  String timetableName = "";
  String? description;
  String? term;

  DateTime effectiveFrom = DateTime.now();
  DateTime? effectiveUntil;

  String schoolStartTime = "09:00:00";
  String schoolEndTime = "16:00:00";

  int totalPeriodsPerDay = 8;
  int periodDuration = 45;
  int breakDuration = 15;
  int lunchDuration = 60;

  final Set<DayOfWeek> workingDays = {
    DayOfWeek.monday,
    DayOfWeek.tuesday,
    DayOfWeek.wednesday,
    DayOfWeek.thursday,
    DayOfWeek.friday,
  };

  bool autoGeneratePeriods = true;
  bool submitting = false;

  Future<void> _pickDate(BuildContext ctx, {required bool from}) async {
    final initial = from ? effectiveFrom : (effectiveUntil ?? effectiveFrom.add(const Duration(days: 90)));
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          effectiveFrom = picked;
          if (effectiveUntil != null && effectiveUntil!.isBefore(effectiveFrom)) {
            effectiveUntil = effectiveFrom;
          }
        } else {
          effectiveUntil = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final payload = MasterTimetableCreate(
      tenantId: widget.tenantId,
      createdBy: widget.userId,
      timetableName: timetableName,
      description: description,
      academicYear: widget.academicYear,
      term: term,
      effectiveFrom: effectiveFrom.toIso8601String().substring(0, 10),
      effectiveUntil: effectiveUntil?.toIso8601String().substring(0, 10),
      totalPeriodsPerDay: totalPeriodsPerDay,
      schoolStartTime: schoolStartTime,
      schoolEndTime: schoolEndTime,
      periodDuration: periodDuration,
      breakDuration: breakDuration,
      lunchDuration: lunchDuration,
      workingDays: workingDays.toList(),
      autoGeneratePeriods: autoGeneratePeriods,
    );

    setState(() => submitting = true);
    try {
      final res = await widget.api.createMaster(payload);
      if (mounted) Navigator.of(context).pop(res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$e"),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 520.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Basic info'),
                      const SizedBox(height: Sa.gapXs),
                      TextFormField(
                        decoration: _dec('Timetable name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                        onSaved: (v) => timetableName = v!.trim(),
                      ),
                      const SizedBox(height: Sa.gap),
                      TextFormField(
                        decoration: _dec('Description'),
                        onSaved: (v) => description = v?.trim().isEmpty == true ? null : v?.trim(),
                      ),
                      const SizedBox(height: Sa.gap),
                      TextFormField(
                        decoration: _dec('Term (optional)'),
                        onSaved: (v) => term = v?.trim().isEmpty == true ? null : v?.trim(),
                      ),

                      const SizedBox(height: Sa.gapLg),
                      _sectionLabel('Dates'),
                      const SizedBox(height: Sa.gapXs),
                      LayoutBuilder(
                        builder: (context, c) {
                          final fromTile = _dateTile(
                            label: 'Effective from',
                            value: effectiveFrom.toIso8601String().substring(0, 10),
                            onTap: () => _pickDate(context, from: true),
                          );
                          final untilTile = _dateTile(
                            label: 'Effective until',
                            value: effectiveUntil == null
                                ? '—'
                                : effectiveUntil!.toIso8601String().substring(0, 10),
                            onTap: () => _pickDate(context, from: false),
                          );
                          return c.maxWidth < 600
                              ? Column(
                                  children: [
                                    fromTile,
                                    const SizedBox(height: Sa.gap),
                                    untilTile,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: fromTile),
                                    const SizedBox(width: Sa.gap),
                                    Expanded(child: untilTile),
                                  ],
                                );
                        },
                      ),

                      const SizedBox(height: Sa.gapLg),
                      _sectionLabel('Times & durations'),
                      const SizedBox(height: Sa.gapXs),
                      _responsivePair(
                        TextFormField(
                          initialValue: schoolStartTime,
                          decoration: _dec('School start time (HH:mm:ss)'),
                          onSaved: (v) => schoolStartTime = v!.trim(),
                        ),
                        TextFormField(
                          initialValue: schoolEndTime,
                          decoration: _dec('School end time (HH:mm:ss)'),
                          onSaved: (v) => schoolEndTime = v!.trim(),
                        ),
                      ),
                      const SizedBox(height: Sa.gap),
                      _responsivePair(
                        TextFormField(
                          initialValue: "$totalPeriodsPerDay",
                          decoration: _dec('Total periods/day'),
                          keyboardType: TextInputType.number,
                          onSaved: (v) => totalPeriodsPerDay = int.tryParse(v ?? "") ?? 8,
                        ),
                        TextFormField(
                          initialValue: "$periodDuration",
                          decoration: _dec('Period duration (min)'),
                          keyboardType: TextInputType.number,
                          onSaved: (v) => periodDuration = int.tryParse(v ?? "") ?? 45,
                        ),
                      ),
                      const SizedBox(height: Sa.gap),
                      _responsivePair(
                        TextFormField(
                          initialValue: "$breakDuration",
                          decoration: _dec('Break duration (min)'),
                          keyboardType: TextInputType.number,
                          onSaved: (v) => breakDuration = int.tryParse(v ?? "") ?? 15,
                        ),
                        TextFormField(
                          initialValue: "$lunchDuration",
                          decoration: _dec('Lunch duration (min)'),
                          keyboardType: TextInputType.number,
                          onSaved: (v) => lunchDuration = int.tryParse(v ?? "") ?? 60,
                        ),
                      ),

                      const SizedBox(height: Sa.gapLg),
                      _sectionLabel('Working days'),
                      const SizedBox(height: Sa.gapXs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DayOfWeek.values.map((d) {
                          final selected = workingDays.contains(d);
                          return FilterChip(
                            label: Text(d.name[0].toUpperCase() + d.name.substring(1)),
                            selected: selected,
                            selectedColor: AppTheme.greenPrimary,
                            checkmarkColor: Colors.white,
                            backgroundColor: AppTheme.neutral50,
                            side: BorderSide(
                              color: selected ? AppTheme.greenPrimary : Sa.stroke,
                            ),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppTheme.neutral700,
                              fontWeight: FontWeight.w500,
                            ),
                            onSelected: (v) => setState(() {
                              v ? workingDays.add(d) : workingDays.remove(d);
                            }),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: Sa.gap),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.neutral50,
                          borderRadius: AppTheme.borderRadius12,
                          border: Border.all(color: Sa.stroke),
                        ),
                        child: SwitchListTile(
                          value: autoGeneratePeriods,
                          activeThumbColor: Sa.accent,
                          onChanged: (v) => setState(() => autoGeneratePeriods = v),
                          title: const Text('Auto-generate periods', style: Sa.value),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
        boxShadow: [AppTheme.greenShadow],
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
            child: const Icon(Icons.calendar_view_week_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create Master Timetable',
                    style: Sa.headerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('Academic year ${widget.academicYear}',
                    style: Sa.headerSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.neutral600,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          SaPrimaryButton(
            label: submitting ? 'Creating…' : 'Create',
            icon: Icons.check_rounded,
            busy: submitting,
            onPressed: submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text.toUpperCase(), style: Sa.label);

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  Widget _responsivePair(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, c) {
        return c.maxWidth < 600
            ? Column(
                children: [a, const SizedBox(height: Sa.gap), b],
              )
            : Row(
                children: [
                  Expanded(child: a),
                  const SizedBox(width: Sa.gap),
                  Expanded(child: b),
                ],
              );
      },
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.neutral50,
      borderRadius: AppTheme.borderRadius12,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius12,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadius12,
            border: Border.all(color: Sa.stroke),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: Sa.label),
                    const SizedBox(height: 2),
                    Text(value,
                        style: Sa.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.date_range, size: 20, color: Sa.accent),
            ],
          ),
        ),
      ),
    );
  }
}
