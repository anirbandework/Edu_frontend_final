import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/class_model.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class AddEditClassDialog extends StatefulWidget {
  final ClassModel? initial;
  final String tenantId;
  const AddEditClassDialog({super.key, this.initial, required this.tenantId});

  @override
  State<AddEditClassDialog> createState() => _AddEditClassDialogState();
}

class _AddEditClassDialogState extends State<AddEditClassDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController name;
  late TextEditingController grade;
  late TextEditingController section;
  late TextEditingController year;
  late TextEditingController max;
  late TextEditingController current;
  late TextEditingController classroom;
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    name = TextEditingController(text: i?.className ?? '');
    grade = TextEditingController(text: i?.gradeLevel.toString() ?? '');
    section = TextEditingController(text: i?.section ?? '');
    year = TextEditingController(text: i?.academicYear ?? '');
    max = TextEditingController(text: i?.maximumStudents.toString() ?? '40');
    current = TextEditingController(text: i?.currentStudents.toString() ?? '0');
    classroom = TextEditingController(text: i?.classroom ?? '');
    isActive = i?.isActive ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    grade.dispose();
    section.dispose();
    year.dispose();
    max.dispose();
    current.dispose();
    classroom.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      final m = ClassModel(
        id: widget.initial?.id ?? '',
        tenantId: widget.tenantId,
        className: name.text.trim(),
        gradeLevel: int.parse(grade.text),
        section: section.text.trim(),
        academicYear: year.text.trim(),
        maximumStudents: int.parse(max.text),
        currentStudents: int.parse(current.text),
        classroom: classroom.text.trim().isEmpty ? null : classroom.text.trim(),
        isActive: isActive,
      );
      Navigator.pop(context, m);
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: Sa.label,
      hintStyle: Sa.label,
      isDense: true,
      filled: true,
      fillColor: AppTheme.neutral50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Sa.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.6),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool number = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: Sa.value,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: _dec(label, hint: hint),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = math.min(media.size.width - 24, 520.0);
    final maxH = media.size.height - 80;
    final isEdit = widget.initial != null;

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
          children: [
            // Gradient hero header.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Sa.radius),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: AppTheme.borderRadius12,
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_outlined : Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isEdit ? 'Edit Class' : 'Create Class',
                          style: Sa.headerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEdit
                              ? 'Update this class\'s details'
                              : 'Add a new class to your school',
                          style: Sa.headerSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    splashRadius: 22,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Scrollable form body.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Form(
                  key: _form,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final oneCol = c.maxWidth < 600;
                      final gradeField = _field(
                        controller: grade,
                        label: 'Grade Level',
                        number: true,
                        validator: (v) => v == null || int.tryParse(v) == null
                            ? 'Number'
                            : null,
                      );
                      final sectionField = _field(
                        controller: section,
                        label: 'Section',
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      );
                      final maxField = _field(
                        controller: max,
                        label: 'Maximum Students',
                        number: true,
                        validator: (v) => v == null || int.tryParse(v) == null
                            ? 'Number'
                            : null,
                      );
                      final currentField = _field(
                        controller: current,
                        label: 'Current Students',
                        number: true,
                        validator: (v) => v == null || int.tryParse(v) == null
                            ? 'Number'
                            : null,
                      );

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(
                            controller: name,
                            label: 'Class Name',
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: Sa.gap),
                          // Grade + Section (2 cols on wide, stacked on phone).
                          if (oneCol) ...[
                            gradeField,
                            const SizedBox(height: Sa.gap),
                            sectionField,
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: gradeField),
                                const SizedBox(width: Sa.gap),
                                Expanded(child: sectionField),
                              ],
                            ),
                          const SizedBox(height: Sa.gap),
                          _field(
                            controller: year,
                            label: 'Academic Year',
                            hint: 'e.g., 2025-26',
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: Sa.gap),
                          // Max + Current (2 cols on wide, stacked on phone).
                          if (oneCol) ...[
                            maxField,
                            const SizedBox(height: Sa.gap),
                            currentField,
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: maxField),
                                const SizedBox(width: Sa.gap),
                                Expanded(child: currentField),
                              ],
                            ),
                          const SizedBox(height: Sa.gap),
                          _field(
                            controller: classroom,
                            label: 'Classroom (optional)',
                          ),
                          const SizedBox(height: Sa.gap),
                          // Active toggle inside a neutral surface.
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.neutral50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Sa.stroke.withValues(alpha: 0.7),
                              ),
                            ),
                            child: SwitchListTile(
                              value: isActive,
                              onChanged: (v) => setState(() => isActive = v),
                              activeThumbColor: Sa.accent,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              title: const Text('Active', style: Sa.value),
                              subtitle: Text(
                                isActive
                                    ? 'Class is currently active'
                                    : 'Class is inactive',
                                style: Sa.label,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            // Actions footer.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.neutral600,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: SaPrimaryButton(
                      label: 'Save',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: _submit,
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
}
