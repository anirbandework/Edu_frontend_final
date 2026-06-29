// lib/features/admin/widgets/student_screen_dialog/bulk_operations_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/school_session.dart';
import '../../../../services/student_bulk_operations_service.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkOperationsDialog extends StatefulWidget {
  final List<String> selectedStudentIds;
  final VoidCallback onOperationComplete;

  const BulkOperationsDialog({
    super.key,
    required this.selectedStudentIds,
    required this.onOperationComplete,
  });

  @override
  State<BulkOperationsDialog> createState() => _BulkOperationsDialogState();
}

class _BulkOperationsDialogState extends State<BulkOperationsDialog> {
  String _selectedOperation = 'update_status';
  String _newStatus = 'active';
  String _newSection = 'A';
  int _currentGrade = 1;
  String _academicYear = '';
  bool _isLoading = false;

  // No bulk "delete" — to disable many students at once, use Update status -> inactive.
  final List<String> _operations = [
    'update_status',
    'update_sections',
    'promote',
  ];

  final List<String> _statusOptions = ['active', 'inactive', 'suspended', 'graduated'];
  final List<String> _sections = ['A', 'B', 'C', 'D', 'E'];
  final List<int> _grades = List.generate(12, (index) => index + 1);

  bool get _isDelete => false;

  Future<void> _executeOperation() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      switch (_selectedOperation) {
        case 'update_status':
          await StudentBulkOperationsService.updateStatus(
            tenantId: SchoolSession.tenantId!,
            studentIds: widget.selectedStudentIds,
            newStatus: _newStatus,
          );
          break;

        case 'update_sections':
          final sectionUpdates = widget.selectedStudentIds.map((id) => {
            'student_id': id,
            'new_section': _newSection,
          }).toList();

          await StudentBulkOperationsService.updateSections(
            tenantId: SchoolSession.tenantId!,
            sectionUpdates: sectionUpdates,
          );
          break;

        case 'promote':
          await StudentBulkOperationsService.promoteStudents(
            tenantId: SchoolSession.tenantId!,
            currentGrade: _currentGrade,
            academicYear: _academicYear,
          );
          break;

      }

      if (mounted) {
        Navigator.pop(context);
        widget.onOperationComplete();
        _showSuccessSnackBar('Operation completed successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to execute operation: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateInputs() {
    if (_selectedOperation == 'promote' && _academicYear.trim().isEmpty) {
      _showErrorSnackBar('Academic year is required for promotion');
      return false;
    }
    return true;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: Sa.body.copyWith(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: AppTheme.greenPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: Sa.body.copyWith(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getOperationDescription() {
    switch (_selectedOperation) {
      case 'update_status':
        return 'Change the status of ${widget.selectedStudentIds.length} students';
      case 'update_sections':
        return 'Move ${widget.selectedStudentIds.length} students to a new section';
      case 'promote':
        return 'Promote all students from grade $_currentGrade to grade ${_currentGrade + 1}';
      case 'delete':
        return 'Soft delete ${widget.selectedStudentIds.length} students';
      default:
        return '';
    }
  }

  String _getOperationDisplayName(String operation) {
    switch (operation) {
      case 'update_status':
        return 'Update Status';
      case 'update_sections':
        return 'Update Sections';
      case 'promote':
        return 'Promote Students';
      case 'delete':
        return 'Delete Students';
      default:
        return operation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxW = math.min(media.size.width - 24, 520.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: media.size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Operation Selection
                    const Text('Select Operation', style: Sa.label),
                    const SizedBox(height: Sa.gapXs),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedOperation,
                      style: Sa.value,
                      decoration: _fieldDecoration(),
                      items: _operations
                          .map((op) => DropdownMenuItem(
                                value: op,
                                child: Text(_getOperationDisplayName(op)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedOperation = value!;
                        });
                      },
                    ),
                    const SizedBox(height: Sa.gapLg),

                    // Operation Description
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.green50,
                        borderRadius: AppTheme.borderRadius12,
                        border: Border.all(color: AppTheme.greenPrimary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppTheme.greenPrimary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getOperationDescription(),
                              style: Sa.body.copyWith(color: AppTheme.greenPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Sa.gapLg),

                    // Operation-specific fields
                    if (_selectedOperation == 'update_status')
                      ..._buildStatusUpdateFields(),
                    if (_selectedOperation == 'update_sections')
                      ..._buildSectionUpdateFields(),
                    if (_selectedOperation == 'promote') ..._buildPromoteFields(),
                    if (_selectedOperation == 'delete') ..._buildDeleteWarning(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
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
            child: const Icon(Icons.settings, color: Colors.white, size: 24),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bulk Operations',
                  style: Sa.headerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.selectedStudentIds.length} students selected',
                  style: Sa.headerSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Sa.stroke)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.neutral600,
                minimumSize: const Size(0, 48),
              ),
              child: Text('Cancel', style: Sa.value.copyWith(color: AppTheme.neutral600)),
            ),
          ),
          const SizedBox(width: Sa.gapLg),
          Expanded(
            child: SaPrimaryButton(
              label: _isLoading
                  ? 'Processing…'
                  : (_isDelete ? 'Delete' : 'Execute'),
              icon: _isDelete ? Icons.delete_outline : Icons.check_rounded,
              busy: _isLoading,
              expand: true,
              color: _isDelete ? AppTheme.error : AppTheme.greenPrimary,
              onPressed: _isLoading ? null : _executeOperation,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: Sa.body.copyWith(color: AppTheme.neutral400),
      filled: true,
      fillColor: Sa.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.stroke),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: Sa.stroke),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppTheme.borderRadius12,
        borderSide: BorderSide(color: AppTheme.greenPrimary, width: 1.5),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sa.gapXs),
      child: Text(text, style: Sa.label),
    );
  }

  List<Widget> _buildStatusUpdateFields() {
    return [
      _fieldLabel('New Status'),
      DropdownButtonFormField<String>(
        initialValue: _newStatus,
        style: Sa.value,
        decoration: _fieldDecoration(),
        items: _statusOptions
            .map((status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.toUpperCase()),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _newStatus = value!;
          });
        },
      ),
    ];
  }

  List<Widget> _buildSectionUpdateFields() {
    return [
      _fieldLabel('New Section'),
      DropdownButtonFormField<String>(
        initialValue: _newSection,
        style: Sa.value,
        decoration: _fieldDecoration(),
        items: _sections
            .map((section) => DropdownMenuItem(
                  value: section,
                  child: Text('Section $section'),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _newSection = value!;
          });
        },
      ),
    ];
  }

  List<Widget> _buildPromoteFields() {
    final gradeField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Current Grade'),
        DropdownButtonFormField<int>(
          initialValue: _currentGrade,
          style: Sa.value,
          decoration: _fieldDecoration(),
          items: _grades
              .map((grade) => DropdownMenuItem(
                    value: grade,
                    child: Text('Grade $grade'),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _currentGrade = value!;
            });
          },
        ),
      ],
    );

    final yearField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Academic Year'),
        TextFormField(
          style: Sa.value,
          decoration: _fieldDecoration(hintText: 'e.g., 2024-2025'),
          onChanged: (value) {
            _academicYear = value;
          },
        ),
      ],
    );

    return [
      LayoutBuilder(
        builder: (context, c) {
          final oneCol = c.maxWidth < 600;
          if (oneCol) {
            return Column(
              children: [
                gradeField,
                const SizedBox(height: Sa.gapLg),
                yearField,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: gradeField),
              const SizedBox(width: Sa.gap),
              Expanded(child: yearField),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _buildDeleteWarning() {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: AppTheme.borderRadius12,
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 32),
            const SizedBox(height: Sa.gapXs),
            Text(
              'Warning!',
              style: Sa.cardTitle.copyWith(color: AppTheme.error),
            ),
            const SizedBox(height: Sa.gapXs),
            Text(
              'This will soft delete ${widget.selectedStudentIds.length} students. They can be restored later.',
              style: Sa.body.copyWith(color: AppTheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ];
  }
}
