import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkImportDialog extends StatefulWidget {
  const BulkImportDialog({super.key});
  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog> {
  FilePickerResult? picked;

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      withReadStream: false,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (!mounted) return;
    if (res != null && res.files.isNotEmpty) {
      setState(() => picked = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = picked?.files.single.name;
    final hasFile = picked != null;
    final maxW = math.min(MediaQuery.of(context).size.width - 24, 480.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: MediaQuery.of(context).size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient header.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Sa.radius),
                ),
                boxShadow: [AppTheme.greenShadow],
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
                    child: const Icon(
                      Icons.upload_file_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: Sa.gap),
                  const Expanded(
                    child: Text(
                      'Bulk Import CSV',
                      style: Sa.headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable body.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Upload a .csv file. The first row must contain these '
                      'column headers:',
                      style: Sa.body,
                    ),
                    const SizedBox(height: Sa.gap),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.neutral50,
                        borderRadius: AppTheme.borderRadius8,
                        border: Border.all(color: Sa.stroke),
                      ),
                      child: const Text(
                        'class_name, grade_level, section, academic_year, '
                        'maximum_students, current_students, classroom, is_active',
                        style: TextStyle(
                          fontFamily: AppTheme.interFontFamily,
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Sa.gapLg),
                    // File picker / selected file surface.
                    Material(
                      color: hasFile ? AppTheme.green50 : Sa.surface,
                      borderRadius: AppTheme.borderRadius12,
                      child: InkWell(
                        onTap: _pick,
                        borderRadius: AppTheme.borderRadius12,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: AppTheme.borderRadius12,
                            border: Border.all(
                              color: hasFile ? Sa.accent : Sa.stroke,
                              width: hasFile ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasFile
                                    ? Icons.check_circle_outline
                                    : Icons.attach_file_outlined,
                                size: 22,
                                color: hasFile ? Sa.accent : AppTheme.neutral500,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  fileName ?? 'Choose CSV file',
                                  style: hasFile
                                      ? Sa.value.copyWith(color: Sa.accent)
                                      : Sa.value.copyWith(
                                          color: AppTheme.neutral600,
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
            // Actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: 'Upload',
                    icon: Icons.upload_outlined,
                    onPressed: hasFile
                        ? () => Navigator.pop<FilePickerResult>(context, picked)
                        : null,
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
