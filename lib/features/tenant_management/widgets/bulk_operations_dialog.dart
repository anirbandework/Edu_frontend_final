// lib/features/tenant_management/widgets/bulk_operations_dialog.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../super_admin/widgets/sa_widgets.dart';

enum BulkOperationType {
  updateStatus,
  updateCapacity,
  updateFinancial,
  updateStatistics,
  delete,
}

class BulkOperationsDialog extends StatefulWidget {
  final List<String> selectedTenantIds;
  final VoidCallback onOperationComplete;

  const BulkOperationsDialog({
    super.key,
    required this.selectedTenantIds,
    required this.onOperationComplete,
  });

  @override
  State<BulkOperationsDialog> createState() => _BulkOperationsDialogState();
}

class _BulkOperationsDialogState extends State<BulkOperationsDialog> {
  BulkOperationType? _selectedOperation;
  bool _isLoading = false;

  // Status Update
  bool _newStatus = true;

  // Capacity Update
  final _capacityController = TextEditingController();

  // Financial Update
  final _tuitionController = TextEditingController();
  final _feeController = TextEditingController();

  // Statistics Update
  final _studentsController = TextEditingController();
  final _teachersController = TextEditingController();
  final _staffController = TextEditingController();

  @override
  void dispose() {
    _capacityController.dispose();
    _tuitionController.dispose();
    _feeController.dispose();
    _studentsController.dispose();
    _teachersController.dispose();
    _staffController.dispose();
    super.dispose();
  }

  Future<void> _performBulkOperation() async {
    if (_selectedOperation == null) return;

    setState(() => _isLoading = true);

    try {
      String endpoint;
      Map<String, dynamic> requestBody;

      switch (_selectedOperation!) {
        case BulkOperationType.updateStatus:
          endpoint = 'bulk/update-status';
          requestBody = {
            'tenant_ids': widget.selectedTenantIds,
            'is_active': _newStatus,
          };
          break;

        case BulkOperationType.updateCapacity:
          if (_capacityController.text.isEmpty) {
            throw Exception('Capacity value is required');
          }
          endpoint = 'bulk/update-capacity';
          requestBody = {
            'capacity_updates': widget.selectedTenantIds.map((id) => {
              'tenant_id': id,
              'maximum_capacity': int.parse(_capacityController.text),
            }).toList(),
          };
          break;

        case BulkOperationType.updateFinancial:
          endpoint = 'bulk/update-financial';
          requestBody = {
            'financial_updates': widget.selectedTenantIds.map((id) => {
              'tenant_id': id,
              if (_tuitionController.text.isNotEmpty)
                'annual_tuition': double.parse(_tuitionController.text),
              if (_feeController.text.isNotEmpty)
                'registration_fee': double.parse(_feeController.text),
            }).toList(),
          };
          break;

        case BulkOperationType.updateStatistics:
          endpoint = 'bulk/update-statistics';
          requestBody = {
            'stats_updates': widget.selectedTenantIds.map((id) => {
              'tenant_id': id,
              if (_studentsController.text.isNotEmpty)
                'total_students': int.parse(_studentsController.text),
              if (_teachersController.text.isNotEmpty)
                'total_teachers': int.parse(_teachersController.text),
              if (_staffController.text.isNotEmpty)
                'total_staff': int.parse(_staffController.text),
            }).toList(),
          };
          break;

        case BulkOperationType.delete:
          endpoint = 'bulk/delete';
          requestBody = {
            'tenant_ids': widget.selectedTenantIds,
          };
          break;
      }

      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/v1/tenants/$endpoint'),
        headers: AuthSession.instance.headers(),
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        widget.onOperationComplete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Bulk operation completed successfully on ${widget.selectedTenantIds.length} schools'),
              backgroundColor: AppTheme.greenPrimary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to perform bulk operation');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 520.0);
    final isDelete = _selectedOperation == BulkOperationType.delete;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sa.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.greenPrimary.withValues(alpha: 0.10),
                      borderRadius: AppTheme.borderRadius12,
                    ),
                    child: const Icon(Icons.settings,
                        color: AppTheme.greenPrimary, size: 22),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bulk Operations',
                          style: Sa.cardTitle.copyWith(fontSize: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.selectedTenantIds.length} schools selected',
                          style: Sa.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.neutral600),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.neutral200),

            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Operation', style: Sa.cardTitle),
                    const SizedBox(height: Sa.gap),
                    _buildOperationCard(
                      BulkOperationType.updateStatus,
                      'Update Status',
                      'Activate or deactivate selected schools',
                      Icons.toggle_on_outlined,
                    ),
                    _buildOperationCard(
                      BulkOperationType.updateCapacity,
                      'Update Capacity',
                      'Set maximum capacity for selected schools',
                      Icons.people_outline,
                    ),
                    _buildOperationCard(
                      BulkOperationType.updateFinancial,
                      'Update Financial Info',
                      'Update tuition and fees for selected schools',
                      Icons.currency_rupee,
                    ),
                    _buildOperationCard(
                      BulkOperationType.updateStatistics,
                      'Update Statistics',
                      'Update student, teacher, and staff counts',
                      Icons.analytics_outlined,
                    ),
                    _buildOperationCard(
                      BulkOperationType.delete,
                      'Delete Schools',
                      'Permanently delete selected schools',
                      Icons.delete_outline,
                      destructive: true,
                    ),
                    if (_selectedOperation != null) ...[
                      const SizedBox(height: Sa.gapLg),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.neutral50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.neutral200),
                        ),
                        child: _buildOperationForm(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: AppTheme.neutral200),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  if (_selectedOperation != null)
                    SaPrimaryButton(
                      label: isDelete ? 'Delete Schools' : 'Apply Changes',
                      icon: isDelete ? Icons.delete_outline : Icons.check,
                      busy: _isLoading,
                      color: isDelete
                          ? AppTheme.error
                          : AppTheme.greenPrimary,
                      onPressed:
                          _isLoading ? null : _performBulkOperation,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard(
    BulkOperationType operation,
    String title,
    String description,
    IconData icon, {
    bool destructive = false,
  }) {
    final isSelected = _selectedOperation == operation;
    final Color accent =
        destructive ? AppTheme.error : AppTheme.greenPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: Sa.gap),
      child: Material(
        color: isSelected ? accent.withValues(alpha: 0.06) : Sa.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _selectedOperation = operation),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? accent : AppTheme.neutral200,
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: Sa.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Sa.value.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? accent : AppTheme.neutral800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: Sa.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: Sa.gapXs),
                  Icon(Icons.check_circle, color: accent, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperationForm() {
    switch (_selectedOperation!) {
      case BulkOperationType.updateStatus:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Status', style: Sa.value),
            const SizedBox(height: Sa.gapXs),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _newStatus,
                  onChanged: (value) => setState(() => _newStatus = value!),
                  activeColor: AppTheme.greenPrimary,
                ),
                const Text('Active', style: Sa.body),
                const SizedBox(width: Sa.gapLg),
                Radio<bool>(
                  value: false,
                  groupValue: _newStatus,
                  onChanged: (value) => setState(() => _newStatus = value!),
                  activeColor: AppTheme.greenPrimary,
                ),
                const Text('Inactive', style: Sa.body),
              ],
            ),
          ],
        );

      case BulkOperationType.updateCapacity:
        return TextField(
          controller: _capacityController,
          decoration: const InputDecoration(
            labelText: 'Maximum Capacity',
            hintText: 'Enter capacity for all selected schools',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        );

      case BulkOperationType.updateFinancial:
        return Column(
          children: [
            TextField(
              controller: _tuitionController,
              decoration: const InputDecoration(
                labelText: 'Annual Tuition (₹)',
                hintText: 'Leave empty to keep current value',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: Sa.gapLg),
            TextField(
              controller: _feeController,
              decoration: const InputDecoration(
                labelText: 'Registration Fee (₹)',
                hintText: 'Leave empty to keep current value',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        );

      case BulkOperationType.updateStatistics:
        return Column(
          children: [
            TextField(
              controller: _studentsController,
              decoration: const InputDecoration(
                labelText: 'Total Students',
                hintText: 'Leave empty to keep current value',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: Sa.gapLg),
            TextField(
              controller: _teachersController,
              decoration: const InputDecoration(
                labelText: 'Total Teachers',
                hintText: 'Leave empty to keep current value',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: Sa.gapLg),
            TextField(
              controller: _staffController,
              decoration: const InputDecoration(
                labelText: 'Total Staff',
                hintText: 'Leave empty to keep current value',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        );

      case BulkOperationType.delete:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.error, size: 20),
                  const SizedBox(width: Sa.gapXs),
                  Expanded(
                    child: Text(
                      'Warning: This action cannot be undone!',
                      style: Sa.value.copyWith(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sa.gapXs),
              Text(
                'This will permanently delete ${widget.selectedTenantIds.length} schools and all their associated data.',
                style: Sa.body.copyWith(color: AppTheme.error),
              ),
            ],
          ),
        );
    }
  }
}
