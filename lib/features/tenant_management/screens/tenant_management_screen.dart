// lib/features/admin/screens/tenant_management_screen.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/tenant.dart';
import '../../super_admin/widgets/sa_widgets.dart';
// tenant_create_dialog is now used by the admin SchoolSwitcher, not here.
import '../widgets/tenant_edit_dialog.dart';
import '../widgets/tenant_details_dialog.dart';
import '../widgets/tenant_stats_dialog.dart' as stats;
import '../widgets/bulk_operations_dialog.dart';

class TenantManagementScreen extends StatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  State<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> 
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Tenant> _tenants = [];
  List<Tenant> _filteredTenants = [];
  final Set<String> _selectedTenants = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;
  
  bool _includeInactive = false;
  String _selectedSchoolType = 'All';
  String _sortBy = 'school_name';
  bool _sortAscending = true;
  
  final List<String> _schoolTypes = ['All', 'K-12', 'Elementary', 'Middle School', 'High School', 'University'];

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadTenants();
    _searchController.addListener(_filterTenants);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOut,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController?.forward();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (_hasMoreData && !_isLoadingMore) {
        _loadTenants();
      }
    }
  }

  // Keep all your API methods exactly the same...
  Future<void> _loadTenants({bool refresh = false}) async {
    if (!mounted) return;

    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _tenants.clear();
      _selectedTenants.clear();
    }

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _error = null;
    });

    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/v1/tenants/').replace(
        queryParameters: {
          'page': _currentPage.toString(),
          'size': _pageSize.toString(),
          'include_inactive': _includeInactive.toString(),
        },
      );
      
      final response = await http
          .get(uri, headers: AuthSession.instance.headers(json: false))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic decodedResponse = json.decode(response.body);
        
        List<dynamic> newTenantsData;
        
        if (decodedResponse is Map<String, dynamic>) {
          if (decodedResponse.containsKey('items')) {
            newTenantsData = decodedResponse['items'] as List<dynamic>;
            final int totalItems = decodedResponse['total'] ?? 0;
            final int totalPages = (totalItems / _pageSize).ceil();
            _hasMoreData = _currentPage < totalPages;
          } else {
            throw Exception('Unexpected response format');
          }
        } else if (decodedResponse is List<dynamic>) {
          newTenantsData = decodedResponse;
          _hasMoreData = false;
        } else {
          throw Exception('Unexpected response format');
        }

        final List<Tenant> newTenants = newTenantsData
            .map((json) => Tenant.fromJson(json))
            .toList();

        if (refresh) {
          _tenants = newTenants;
        } else {
          _tenants.addAll(newTenants);
        }
        
        _filterTenants();
        _currentPage++;
      } else {
        _error = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      if (!mounted) return;
      _error = _friendlyError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  // Convert raw exceptions into user-friendly messages.
  // Raw technical detail is appended only in debug builds.
  String _friendlyError(Object e) {
    const friendly =
        'Unable to connect. Please check your internet connection and try again.';
    return kDebugMode ? '$friendly\n\nDetails: $e' : friendly;
  }

  void _filterTenants() {
    if (!mounted) return;

    final query = _searchController.text.toLowerCase();
    List<Tenant> filtered = _tenants.where((tenant) {
      final matchesSearch = tenant.schoolName.toLowerCase().contains(query) ||
                           tenant.address.toLowerCase().contains(query) ||
                           tenant.principalName.toLowerCase().contains(query) ||
                           tenant.email.toLowerCase().contains(query);
      
      final matchesType = _selectedSchoolType == 'All' || tenant.schoolType == _selectedSchoolType;
      
      return matchesSearch && matchesType;
    }).toList();

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'school_name':
          comparison = a.schoolName.compareTo(b.schoolName);
          break;
        case 'created_at':
          comparison = (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now());
          break;
        case 'total_students':
          comparison = a.totalStudents.compareTo(b.totalStudents);
          break;
        case 'capacity_utilization':
          comparison = a.capacityUtilization.compareTo(b.capacityUtilization);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredTenants = filtered;
    });
  }

  Future<void> _deleteTenant(String tenantId, {bool hardDelete = false}) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/v1/tenants/$tenantId').replace(
        queryParameters: hardDelete ? {'hard_delete': 'true'} : null,
      );
      
      final response = await http.delete(uri, headers: AuthSession.instance.headers(json: false));

      if (response.statusCode == 200) {
        await _loadTenants(refresh: true);
        if (mounted) {
          _showSuccessSnackBar(hardDelete ? 'Tenant permanently deleted' : 'Tenant deactivated');
        }
      } else {
        throw Exception('Failed to delete tenant');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(_friendlyError(e));
      }
    }
  }

  Future<void> _reactivateTenant(String tenantId) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/v1/tenants/$tenantId/reactivate');
      final response = await http.patch(uri, headers: AuthSession.instance.headers(json: false));

      if (response.statusCode == 200) {
        await _loadTenants(refresh: true);
        if (mounted) {
          _showSuccessSnackBar('Tenant reactivated successfully');
        }
      } else {
        throw Exception('Failed to reactivate tenant');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(_friendlyError(e));
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodySmall.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.greenPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius8),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodySmall.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius8),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_animationController == null || _fadeAnimation == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.greenPrimary),
      );
    }

    return SaScreen(
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Organisations',
          subtitle: 'Schools created by your admins',
          icon: Icons.business,
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation!,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _searchController,
        style: Sa.value,
        decoration: InputDecoration(
          hintText: 'Search schools by name, address, or principal...',
          hintStyle: Sa.label,
          prefixIcon: const Icon(Icons.search, color: Sa.accent, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Sa.radius),
            borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Sa.radius),
            borderSide: BorderSide(color: Sa.stroke.withValues(alpha: 0.7), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Sa.radius),
            borderSide: const BorderSide(color: Sa.accent, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // Quick school-type filter chips + a "sort & options" sheet. Restores the
  // type filter, sort and include-inactive controls in a phone-first form.
  Widget _buildFilterBar() {
    final bool optionsActive =
        _includeInactive || _sortBy != 'school_name' || !_sortAscending;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _schoolTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = _schoolTypes[i];
                  final selected = _selectedSchoolType == t;
                  return ChoiceChip(
                    label: Text(t),
                    selected: selected,
                    showCheckmark: false,
                    labelStyle: Sa.label.copyWith(
                      color: selected ? Colors.white : AppTheme.neutral600,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: Sa.accent,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color:
                            selected ? Sa.accent : Sa.stroke.withValues(alpha: 0.7)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    onSelected: (_) {
                      setState(() => _selectedSchoolType = t);
                      _filterTenants();
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: optionsActive ? Sa.accent : Sa.stroke.withValues(alpha: 0.7)),
            ),
            child: IconButton(
              tooltip: 'Sort & options',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(Icons.tune,
                  size: 20,
                  color: optionsActive ? Sa.accent : AppTheme.neutral600),
              onPressed: _showSortSheet,
            ),
          ),
        ],
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Widget sortOption(String key, String label) {
              final sel = _sortBy == key;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(label, style: Sa.value),
                trailing: sel
                    ? const Icon(Icons.check_rounded, color: Sa.accent, size: 20)
                    : null,
                onTap: () {
                  setSheet(() => _sortBy = key);
                  setState(() => _sortBy = key);
                  _filterTenants();
                },
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sort & options', style: Sa.cardTitle),
                    const SizedBox(height: 4),
                    const Divider(height: 20, color: Sa.stroke),
                    const Text('SORT BY', style: Sa.label),
                    sortOption('school_name', 'School name'),
                    sortOption('created_at', 'Date created'),
                    sortOption('total_students', 'Students'),
                    sortOption('capacity_utilization', 'Capacity used'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeThumbColor: Sa.accent,
                      title: const Text('Ascending order', style: Sa.value),
                      subtitle: Text(_sortAscending ? 'A → Z / low → high' : 'Z → A / high → low',
                          style: Sa.label),
                      value: _sortAscending,
                      onChanged: (v) {
                        setSheet(() => _sortAscending = v);
                        setState(() => _sortAscending = v);
                        _filterTenants();
                      },
                    ),
                    const Divider(height: 20, color: Sa.stroke),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeThumbColor: Sa.accent,
                      title: const Text('Include inactive schools', style: Sa.value),
                      subtitle:
                          const Text('Show deactivated organisations', style: Sa.label),
                      value: _includeInactive,
                      onChanged: (v) {
                        setSheet(() => _includeInactive = v);
                        setState(() => _includeInactive = v);
                        _loadTenants(refresh: true);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBulkActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SaCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.checklist, size: 20, color: Sa.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_selectedTenants.length} selected',
                style: Sa.value.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Sa.accent,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedTenants.clear()),
              child: const Text('Clear', style: Sa.label),
            ),
            const SizedBox(width: 4),
            SaPrimaryButton(
              label: 'Actions',
              icon: Icons.bolt,
              onPressed: () => _showBulkOperationsDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const SaLoading(message: 'Loading schools...');
    if (_error != null) {
      return SaStateView.error(
        message: _error!,
        onRetry: () => _loadTenants(refresh: true),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchSection(),
          _buildFilterBar(),
          if (_selectedTenants.isNotEmpty) _buildBulkActions(),
          Expanded(
            child: _filteredTenants.isEmpty
                ? _buildEmptyState()
                : _buildTenantsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isNotEmpty) {
      return SaStateView(
        icon: Icons.search_off_rounded,
        title: 'No schools found',
        subtitle: 'Try adjusting your search terms or clear the search.',
        action: TextButton(
          onPressed: () {
            _searchController.clear();
            _filterTenants();
          },
          child: const Text('Clear search', style: Sa.label),
        ),
      );
    }
    return const SaStateView(
      icon: Icons.school_outlined,
      title: 'No schools found',
      subtitle: 'Schools appear here once your admins create them.',
    );
  }

  Widget _buildTenantsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
      itemCount: _filteredTenants.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredTenants.length) {
          return _buildLoadMoreWidget();
        }

        final tenant = _filteredTenants[index];
        return _buildTenantCard(tenant);
      },
    );
  }

  Widget _buildLoadMoreWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Sa.accent,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text('Loading more...', style: Sa.body),
        ],
      ),
    );
  }

  Widget _buildTenantCard(Tenant tenant) {
    final bool isSelected = _selectedTenants.contains(tenant.id);
    final bool isInactive = !tenant.isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SaCard(
        onTap: () => _showDetailsDialog(tenant),
        child: Opacity(
          opacity: isInactive ? 0.7 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selection checkbox
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedTenants.add(tenant.id);
                          } else {
                            _selectedTenants.remove(tenant.id);
                          }
                        });
                      },
                      activeColor: Sa.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // School icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isInactive
                          ? AppTheme.neutral200
                          : Sa.accent.withValues(alpha: 0.10),
                      borderRadius: AppTheme.borderRadius12,
                    ),
                    child: Icon(
                      Icons.school,
                      size: 22,
                      color: isInactive ? AppTheme.neutral600 : Sa.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.schoolName,
                          style: Sa.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tenant.address,
                          style: Sa.body.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tenant.principalName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Principal: ${tenant.principalName}',
                            style: Sa.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Kebab
                  _buildActionsMenu(tenant),
                ],
              ),
              const SizedBox(height: 12),
              // Status + stats — Wrap so they never overflow on a phone.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SaStatusPill(
                    text: tenant.statusText,
                    color: tenant.isActive ? AppTheme.greenPrimary : AppTheme.error,
                    icon: tenant.isActive
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                  ),
                  _buildStatBadge(
                      '${tenant.totalStudents}', Icons.people, AppTheme.greenPrimary),
                  _buildStatBadge(
                      '${tenant.totalTeachers}', Icons.person, AppTheme.greenPrimary),
                  _buildStatBadge(
                      '${tenant.capacityUtilization.toStringAsFixed(1)}%',
                      Icons.donut_small,
                      AppTheme.greenPrimary),
                ],
              ),
              const SizedBox(height: 12),
              // Primary action surfaced; the rest live in the kebab.
              SaPrimaryButton(
                label: 'Edit',
                icon: Icons.edit,
                expand: true,
                onPressed: () => _showEditDialog(tenant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppTheme.borderRadius8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.interFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsMenu(Tenant tenant) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.neutral600),
      padding: const EdgeInsets.all(4),
      onSelected: (value) async {
        switch (value) {
          case 'details':
            _showDetailsDialog(tenant);
            break;
          case 'edit':
            _showEditDialog(tenant);
            break;
          case 'stats':
            _showStatsDialog(tenant);
            break;
          case 'deactivate':
            await _deleteTenant(tenant.id);
            break;
          case 'reactivate':
            await _reactivateTenant(tenant.id);
            break;
          case 'delete':
            final confirm = await _showDeleteConfirmation(tenant);
            if (confirm == true) {
              await _deleteTenant(tenant.id, hardDelete: true);
            }
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        const PopupMenuItem(
          value: 'details',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18, color: AppTheme.greenPrimary),
              SizedBox(width: 12),
              Text('Details', style: AppTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: AppTheme.neutral600),
              SizedBox(width: 12),
              Text('Edit', style: AppTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'stats',
          child: Row(
            children: [
              Icon(Icons.analytics, size: 18, color: AppTheme.greenPrimary),
              SizedBox(width: 12),
              Text('Stats', style: AppTheme.bodySmall),
            ],
          ),
        ),
        if (tenant.isActive)
          const PopupMenuItem(
            value: 'deactivate',
            child: Row(
              children: [
                Icon(Icons.visibility_off, size: 18, color: AppTheme.neutral600),
                SizedBox(width: 12),
                Text('Deactivate', style: AppTheme.bodySmall),
              ],
            ),
          )
        else
          const PopupMenuItem(
            value: 'reactivate',
            child: Row(
              children: [
                Icon(Icons.visibility, size: 18, color: AppTheme.greenPrimary),
                SizedBox(width: 12),
                Text('Reactivate', style: AppTheme.bodySmall),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_forever, size: 18, color: AppTheme.error),
              const SizedBox(width: 12),
              Text('Delete', style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool?> _showDeleteConfirmation(Tenant tenant) {
    return showDialog<bool>(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, size: 40, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Confirm Deletion',
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Delete "${tenant.schoolName}"?',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.neutral700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This permanently deletes the school and ALL its data and cannot be undone.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel', style: AppTheme.bodySmall),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Delete',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Schools are created by their admin (see SchoolSwitcher), not the super-admin.
  void _showEditDialog(Tenant tenant) {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => TenantEditDialog(
        tenant: tenant,
        onTenantUpdated: () => _loadTenants(refresh: true),
      ),
    );
  }

  void _showDetailsDialog(Tenant tenant) {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => TenantDetailsDialog(tenant: tenant),
    );
  }

  void _showStatsDialog(Tenant tenant) {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => stats.TenantStatsDialog(tenant: tenant),
    );
  }

  void _showBulkOperationsDialog() {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => BulkOperationsDialog(
        selectedTenantIds: _selectedTenants.toList(),
        onOperationComplete: () {
          _selectedTenants.clear();
          _loadTenants(refresh: true);
        },
      ),
    );
  }
}
