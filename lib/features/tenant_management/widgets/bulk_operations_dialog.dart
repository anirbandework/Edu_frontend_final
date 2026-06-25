// lib/features/admin/widgets/bulk_operations_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';

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
              content: Text('Bulk operation completed successfully on ${widget.selectedTenantIds.length} schools'),
              backgroundColor: AppTheme.primaryGreen,
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.settings, color: AppTheme.primaryGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Operations',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      Text(
                        '${widget.selectedTenantIds.length} schools selected',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Operation Selection
            Text(
              'Select Operation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildOperationCard(
                      BulkOperationType.updateStatus,
                      'Update Status',
                      'Activate or deactivate selected schools',
                      Icons.toggle_on,
                      AppTheme.info,
                    ),
                    _buildOperationCard(
                      BulkOperationType.updateCapacity,
                      'Update Capacity',
                      'Set maximum capacity for selected schools',
                      Icons.people,
                      AppTheme.greenLight,
                    ),
                    _buildOperationCard(
                      BulkOperationType.updateFinancial,
                      'Update Financial Info',
                      'Update tuition and fees for selected schools',
                      Icons.attach_money,
                      AppTheme.warning,
                    ),
                    _buildOperationCard(
                      BulkOperationType.updateStatistics,
                      'Update Statistics',
                      'Update student, teacher, and staff counts',
                      Icons.analytics,
                      Colors.purple,
                    ),
                    _buildOperationCard(
                      BulkOperationType.delete,
                      'Delete Schools',
                      'Permanently delete selected schools',
                      Icons.delete,
                      AppTheme.error,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Operation Form
            if (_selectedOperation != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.neutral50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neutral300),
                ),
                child: _buildOperationForm(),
              ),
              
              const SizedBox(height: 24),
            ],
            
            // Actions
            Row(
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                if (_selectedOperation != null)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _performBulkOperation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedOperation == BulkOperationType.delete 
                          ? AppTheme.error 
                          : AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_selectedOperation == BulkOperationType.delete 
                            ? 'Delete Schools' 
                            : 'Apply Changes'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard(BulkOperationType operation, String title, String description, IconData icon, Color color) {
    final isSelected = _selectedOperation == operation;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: color, width: 2) 
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedOperation = operation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : AppTheme.neutral800,
                      ),
                    ),
                    Text(
                      description,
                      style: AppTheme.bodyMicro,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: color),
            ],
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
            Text('New Status', style: AppTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _newStatus,
                  onChanged: (value) => setState(() => _newStatus = value!),
                  activeColor: AppTheme.primaryGreen,
                ),
                const Text('Active'),
                const SizedBox(width: 16),
                Radio<bool>(
                  value: false,
                  groupValue: _newStatus,
                  onChanged: (value) => setState(() => _newStatus = value!),
                  activeColor: AppTheme.primaryGreen,
                ),
                const Text('Inactive'),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            TextField(
              controller: _teachersController,
              decoration: const InputDecoration(
                labelText: 'Total Teachers',
                hintText: 'Leave empty to keep current value',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
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
            color: AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.error.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Warning: This action cannot be undone!',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete ${widget.selectedTenantIds.length} schools and all their associated data.',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
              ),
            ],
          ),
        );
    }
  }
}
