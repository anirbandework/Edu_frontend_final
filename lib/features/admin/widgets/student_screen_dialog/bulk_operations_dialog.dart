// lib/features/school_authority/widgets/bulk_operations_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/school_session.dart';
import '../../../../services/student_bulk_operations_service.dart';

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
  int _newGrade = 1;
  int _currentGrade = 1;
  String _academicYear = '';
  bool _isLoading = false;

  final List<String> _operations = [
    'update_status',
    'update_sections',
    'promote',
    'delete',
  ];

  final List<String> _statusOptions = ['active', 'inactive', 'suspended', 'graduated'];
  final List<String> _sections = ['A', 'B', 'C', 'D', 'E'];
  final List<int> _grades = List.generate(12, (index) => index + 1);

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

        case 'delete':
          await StudentBulkOperationsService.deleteStudents(
            tenantId: SchoolSession.tenantId!,
            studentIds: widget.selectedStudentIds,
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
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message, style: AppTheme.bodySmall.copyWith(color: Colors.white)),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: AppTheme.bodySmall.copyWith(color: Colors.white))),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getOperationTitle() {
    switch (_selectedOperation) {
      case 'update_status': return 'Update Status';
      case 'update_sections': return 'Update Sections';
      case 'promote': return 'Promote Students';
      case 'delete': return 'Delete Students';
      default: return 'Bulk Operation';
    }
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
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: screenSize.width > 600 ? 500 : screenSize.width * 0.9,
        decoration: AppTheme.getCompactDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.neutral200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulk Operations',
                          style: AppTheme.headingSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.selectedStudentIds.length} students selected',
                          style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Operation Selection
                  Text(
                    'Select Operation',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.neutral800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedOperation,
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral800),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.borderRadius12,
                      ),
                    ),
                    items: _operations.map((op) => DropdownMenuItem(
                      value: op,
                      child: Text(_getOperationDisplayName(op)),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedOperation = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Operation Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withOpacity(0.1),
                      borderRadius: AppTheme.borderRadius12,
                      border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                    ),
                    child: Text(
                      _getOperationDescription(),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.info,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Operation-specific fields
                  if (_selectedOperation == 'update_status')
                    ..._buildStatusUpdateFields(),
                  if (_selectedOperation == 'update_sections')
                    ..._buildSectionUpdateFields(),
                  if (_selectedOperation == 'promote')
                    ..._buildPromoteFields(),
                  if (_selectedOperation == 'delete')
                    ..._buildDeleteWarning(),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.neutral200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _executeOperation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedOperation == 'delete' 
                            ? AppTheme.error 
                            : AppTheme.greenPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadius12,
                        ),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('Processing...', style: AppTheme.bodyMedium),
                              ],
                            )
                          : Text('Execute', style: AppTheme.bodyMedium),
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

  String _getOperationDisplayName(String operation) {
    switch (operation) {
      case 'update_status': return 'Update Status';
      case 'update_sections': return 'Update Sections';
      case 'promote': return 'Promote Students';
      case 'delete': return 'Delete Students';
      default: return operation;
    }
  }

  List<Widget> _buildStatusUpdateFields() {
    return [
      Text(
        'New Status',
        style: AppTheme.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.neutral700,
        ),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _newStatus,
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral800),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: AppTheme.borderRadius12,
          ),
        ),
        items: _statusOptions.map((status) => DropdownMenuItem(
          value: status,
          child: Text(status.toUpperCase()),
        )).toList(),
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
      Text(
        'New Section',
        style: AppTheme.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.neutral700,
        ),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _newSection,
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral800),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: AppTheme.borderRadius12,
          ),
        ),
        items: _sections.map((section) => DropdownMenuItem(
          value: section,
          child: Text('Section $section'),
        )).toList(),
        onChanged: (value) {
          setState(() {
            _newSection = value!;
          });
        },
      ),
    ];
  }

  List<Widget> _buildPromoteFields() {
    return [
      Text(
        'Current Grade',
        style: AppTheme.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.neutral700,
        ),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
        value: _currentGrade,
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral800),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: AppTheme.borderRadius12,
          ),
        ),
        items: _grades.map((grade) => DropdownMenuItem(
          value: grade,
          child: Text('Grade $grade'),
        )).toList(),
        onChanged: (value) {
          setState(() {
            _currentGrade = value!;
          });
        },
      ),
      const SizedBox(height: 16),
      Text(
        'Academic Year',
        style: AppTheme.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.neutral700,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        style: AppTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'e.g., 2024-2025',
          border: OutlineInputBorder(
            borderRadius: AppTheme.borderRadius12,
          ),
        ),
        onChanged: (value) {
          _academicYear = value;
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
          color: AppTheme.error.withOpacity(0.1),
          borderRadius: AppTheme.borderRadius12,
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.warning, color: AppTheme.error, size: 32),
            const SizedBox(height: 8),
            Text(
              'Warning!',
              style: AppTheme.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will soft delete ${widget.selectedStudentIds.length} students. They can be restored later.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ];
  }
}
