import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/student.dart';
import '../../../core/utils/school_session.dart';
import '../../../services/student_management_service.dart';

// Dialogs
import '../widgets/student_screen_dialog/add_student_dialog.dart';
import '../widgets/student_screen_dialog/bulk_operations_dialog.dart';
import '../widgets/student_screen_dialog/student_details_dialog.dart';
import '../widgets/student_screen_dialog/bulk_import_students_dialog.dart';

// GLOBAL: root messenger key
import '../../../shared/root_scaffold_messenger.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  Set<String> _selectedStudents = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;

  // Filters
  int? _selectedGrade;
  String? _selectedSection;
  String _selectedStatus = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;

  final List<int> _grades = List.generate(12, (index) => index + 1);
  final List<String> _sections = ['A', 'B', 'C', 'D', 'E'];
  final List<String> _statusOptions = ['all', 'active', 'inactive', 'suspended', 'graduated'];

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStudents();
    _searchController.addListener(_filterStudents);
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _animationController?.forward());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (_hasMoreData && !_isLoadingMore) {
        _loadStudents();
      }
    }
  }

  Future<void> _loadStudents({bool refresh = false}) async {
    if (!mounted) return;

    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _students.clear();
      _selectedStudents.clear();
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
      final response = await StudentManagementService.getStudents(
        page: _currentPage,
        size: _pageSize,
        tenantId: SchoolSession.hasSchoolData && SchoolSession.tenantId != null
            ? SchoolSession.tenantId!
            : null,
        gradeLevel: _selectedGrade,
        section: _selectedSection,
      );

      if (!mounted) return;

      List<dynamic> newStudentsData;
      if (response.containsKey('items')) {
        newStudentsData = response['items'] as List<dynamic>;
        final int totalItems = response['total'] ?? 0;
        final int totalPages = (totalItems / _pageSize).ceil();
        _hasMoreData = _currentPage < totalPages;
      } else if (response.containsKey('students')) {
        newStudentsData = response['students'] as List<dynamic>;
        _hasMoreData = false;
      } else {
        throw Exception('Unexpected response format');
      }

      final List<Student> newStudents =
          newStudentsData.map((json) => Student.fromJson(json)).toList();

      if (refresh) {
        _students = newStudents;
      } else {
        _students.addAll(newStudents);
      }

      _filterStudents();
      _currentPage++;
    } catch (e) {
      if (!mounted) return;
      _error = _friendlyErrorMessage(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _filterStudents() {
    if (!mounted) return;

    final query = _searchController.text.toLowerCase();
    List<Student> filtered = _students.where((student) {
      final matchesSearch =
          student.fullName.toLowerCase().contains(query) ||
              student.studentId.toLowerCase().contains(query) ||
              (student.rollNumber?.toLowerCase().contains(query) ?? false) ||
              (student.admissionNumber?.toLowerCase().contains(query) ?? false) ||
              (student.email?.toLowerCase().contains(query) ?? false);

      final matchesStatus =
          _selectedStatus == 'all' || student.status.toLowerCase() == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.fullName.compareTo(b.fullName);
          break;
        case 'grade':
          comparison = a.gradeLevel.compareTo(b.gradeLevel);
          if (comparison == 0 && a.section != null && b.section != null) {
            comparison = a.section!.compareTo(b.section!);
          }
          break;
        case 'roll_number':
          final aRoll = int.tryParse(a.rollNumber ?? '0') ?? 0;
          final bRoll = int.tryParse(b.rollNumber ?? '0') ?? 0;
          comparison = aRoll.compareTo(bRoll);
          break;
        case 'created_at':
          comparison = (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now());
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() => _filteredStudents = filtered);
  }

  Future<void> _deleteStudent(String studentId) async {
    try {
      await StudentManagementService.deleteStudent(studentId);
      await _loadStudents(refresh: true);
      if (mounted) {
        _showSuccessSnackBar('Student deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(_friendlyErrorMessage(e));
      }
    }
  }

  // ==================================================
  // Error message mapping
  // ==================================================
  String _friendlyErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network') ||
        raw.contains('connection') ||
        raw.contains('timeout') ||
        raw.contains('timed out') ||
        raw.contains('handshake') ||
        raw.contains('unreachable')) {
      return "Couldn't reach the server. Check your connection and try again.";
    }
    return 'Something went wrong. Please try again.';
  }

  // ==================================================
  // Global ScaffoldMessenger-based SnackBars (no ctx)
  // ==================================================
  void _showSuccessSnackBar(String message) {
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
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
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius8),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
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
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius8),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final availableHeight = screenSize.height - statusBarHeight;

    if (_animationController == null || _fadeAnimation == null) {
      return Container(
        width: screenSize.width,
        height: availableHeight,
        color: AppTheme.backgroundPrimary,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: screenSize.width,
      height: availableHeight,
      color: AppTheme.backgroundPrimary,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation!,
          child: Column(
            children: [
              _buildHeader(),
              _buildFiltersSection(),
              _buildSearchSection(),
              if (_selectedStudents.isNotEmpty) _buildBulkActions(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  // ======================
  // Builders
  // ======================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Management',
                  style: AppTheme.headingSmall.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_filteredStudents.length} students found',
                  style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          // Bulk Import Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showBulkImportDialog,
              borderRadius: AppTheme.borderRadius12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: AppTheme.borderRadius12,
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.upload_file, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Bulk Import',
                      style: AppTheme.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Add Student Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAddStudentDialog,
              borderRadius: AppTheme.borderRadius12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: AppTheme.borderRadius12,
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add Student',
                      style: AppTheme.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.neutral200, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown<int>(
                  label: 'Grade',
                  value: _selectedGrade,
                  items: _grades,
                  onChanged: (value) {
                    setState(() => _selectedGrade = value);
                    _loadStudents(refresh: true);
                  },
                  itemBuilder: (grade) => 'Grade $grade',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown<String>(
                  label: 'Section',
                  value: _selectedSection,
                  items: _sections,
                  onChanged: (value) {
                    setState(() => _selectedSection = value);
                    _loadStudents(refresh: true);
                  },
                  itemBuilder: (section) => 'Section $section',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown<String>(
                  label: 'Status',
                  value: _selectedStatus,
                  items: _statusOptions,
                  onChanged: (value) {
                    setState(() => _selectedStatus = value ?? 'all');
                    _filterStudents();
                  },
                  itemBuilder: (status) => status == 'all' ? 'All Status' : status.toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown<String>(
                  label: 'Sort By',
                  value: _sortBy,
                  items: const ['name', 'grade', 'roll_number', 'created_at'],
                  onChanged: (value) {
                    setState(() => _sortBy = value ?? 'name');
                    _filterStudents();
                  },
                  itemBuilder: (sort) {
                    switch (sort) {
                      case 'name':
                        return 'Name';
                      case 'grade':
                        return 'Grade';
                      case 'roll_number':
                        return 'Roll Number';
                      case 'created_at':
                        return 'Date Added';
                      default:
                        return sort;
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTheme.bodyMicro.copyWith(fontWeight: FontWeight.w500, color: AppTheme.neutral600)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.neutral300),
            borderRadius: AppTheme.borderRadius8,
            color: AppTheme.neutral50,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral800),
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              onChanged: onChanged,
              items: [
                if (label != 'Status' && label != 'Sort By')
                  DropdownMenuItem<T>(
                    value: null,
                    child: Text('All ${label}s', style: AppTheme.bodySmall),
                  ),
                ...items.map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemBuilder(item), style: AppTheme.bodySmall),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.neutral200, width: 0.5)),
      ),
      child: TextField(
        controller: _searchController,
        style: AppTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search by name, student ID, roll number, or email...',
          hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.neutral400),
          prefixIcon: Icon(Icons.search, color: AppTheme.greenPrimary, size: 20),
          filled: true,
          fillColor: AppTheme.neutral50,
          border: OutlineInputBorder(
            borderRadius: AppTheme.borderRadius12,
            borderSide: BorderSide(color: AppTheme.neutral300, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppTheme.borderRadius12,
            borderSide: BorderSide(color: AppTheme.neutral300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.borderRadius12,
            borderSide: BorderSide(color: AppTheme.greenPrimary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBulkActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.getCompactDecoration(
        color: AppTheme.green50,
        border: Border.all(color: AppTheme.greenPrimary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.checklist, size: 20, color: AppTheme.greenPrimary),
          const SizedBox(width: 8),
          Text(
            '${_selectedStudents.length} students selected',
            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppTheme.greenPrimary),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selectedStudents.clear()),
            child: Text('Clear', style: AppTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _showBulkOperationsDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.greenPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text('Actions', style: AppTheme.bodySmall.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_filteredStudents.isEmpty) return _buildEmptyState();
    return _buildStudentsList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.greenPrimary.withOpacity(0.1),
              borderRadius: AppTheme.borderRadius12,
            ),
            child: const CircularProgressIndicator(color: AppTheme.greenPrimary, strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text('Loading students...', style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.getCompactDecoration(
          color: AppTheme.error.withOpacity(0.1),
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: AppTheme.borderRadius12,
              ),
              child: Icon(Icons.error_outline, size: 40, color: AppTheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load students',
              style: AppTheme.labelLarge.copyWith(color: AppTheme.error, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadStudents(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.greenPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Try Again', style: AppTheme.bodySmall.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.getCompactDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.neutral100,
                borderRadius: AppTheme.borderRadius12,
              ),
              child: Icon(Icons.people_outline, size: 48, color: AppTheme.neutral400),
            ),
            const SizedBox(height: 16),
            Text(
              'No students found',
              style: AppTheme.labelLarge.copyWith(color: AppTheme.neutral600, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty || _selectedGrade != null || _selectedSection != null
                  ? 'Try adjusting your search or filters.'
                  : 'Add your first student to get started.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_searchController.text.isNotEmpty || _selectedGrade != null || _selectedSection != null)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedGrade = null;
                    _selectedSection = null;
                    _selectedStatus = 'all';
                  });
                  _loadStudents(refresh: true);
                },
                child: Text('Clear Filters', style: AppTheme.bodySmall),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _showAddStudentDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.greenPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child:
                        Text('Add Student', style: AppTheme.bodySmall.copyWith(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _showBulkImportDialog,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text('Bulk Import', style: AppTheme.bodySmall),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredStudents.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredStudents.length) return _buildLoadMoreWidget();
        final student = _filteredStudents[index];
        return _buildStudentCard(student);
      },
    );
  }

  Widget _buildLoadMoreWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: AppTheme.greenPrimary, strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Loading more...', style: AppTheme.bodySmall.copyWith(color: AppTheme.neutral600)),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final bool isSelected = _selectedStudents.contains(student.id);
    final bool isInactive = !student.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStudentDetails(student),
          borderRadius: AppTheme.borderRadius12,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.getCompactDecoration(
              color: isSelected
                  ? AppTheme.green50
                  : isInactive
                      ? AppTheme.neutral50.withOpacity(0.5)
                      : AppTheme.surfacePrimary,
              border: Border.all(
                color: isSelected
                    ? AppTheme.greenPrimary.withOpacity(0.5)
                    : isInactive
                        ? AppTheme.neutral300
                        : AppTheme.neutral200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Opacity(
              opacity: isInactive ? 0.6 : 1.0,
              child: Row(
                children: [
                  Transform.scale(
                    scale: 1.0,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedStudents.add(student.id);
                          } else {
                            _selectedStudents.remove(student.id);
                          }
                        });
                      },
                      activeColor: AppTheme.greenPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        isInactive ? AppTheme.neutral300 : AppTheme.greenPrimary.withOpacity(0.1),
                    child: Text(
                      student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : 'S',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isInactive ? AppTheme.neutral600 : AppTheme.greenPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                student.fullName,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isInactive ? AppTheme.neutral600 : AppTheme.neutral900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isInactive) _buildStatusChip(student),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              student.gradeText,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.neutral600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (student.rollNumber != null) ...[
                              const SizedBox(width: 12),
                              Text('Roll: ${student.rollNumber}',
                                  style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral500)),
                            ],
                          ],
                        ),
                        if (student.studentId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('ID: ${student.studentId}',
                              style: AppTheme.bodyMicro.copyWith(color: AppTheme.neutral500)),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (student.age > 0)
                              _buildInfoBadge('${student.age} yrs', Icons.cake, AppTheme.info),
                            if (student.age > 0 && student.email != null) const SizedBox(width: 8),
                            if (student.email != null)
                              _buildInfoBadge('Email', Icons.email, AppTheme.success),
                            if ((student.age > 0 || student.email != null) &&
                                student.phone != null)
                              const SizedBox(width: 8),
                            if (student.phone != null)
                              _buildInfoBadge('Phone', Icons.phone, AppTheme.warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildActionsMenu(student),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Student student) {
    Color statusColor;
    switch (student.status.toLowerCase()) {
      case 'active':
        statusColor = AppTheme.success;
        break;
      case 'inactive':
        statusColor = AppTheme.neutral600;
        break;
      case 'suspended':
        statusColor = AppTheme.error;
        break;
      case 'graduated':
        statusColor = AppTheme.info;
        break;
      default:
        statusColor = AppTheme.neutral500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: AppTheme.borderRadius8,
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        student.statusText,
        style: AppTheme.bodyMicro.copyWith(color: statusColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppTheme.borderRadius8,
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: AppTheme.bodyMicro.copyWith(fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  Widget _buildActionsMenu(Student student) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 20, color: AppTheme.neutral600),
      padding: const EdgeInsets.all(4),
      onSelected: (value) async {
        switch (value) {
          case 'details':
            _showStudentDetails(student);
            break;
          case 'delete':
            final confirm = await _showDeleteConfirmation(student);
            if (confirm == true) {
              await _deleteStudent(student.id);
            }
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem(
          value: 'details',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18, color: AppTheme.info),
              const SizedBox(width: 12),
              Text('View Details', style: AppTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever, size: 18, color: AppTheme.error),
              const SizedBox(width: 12),
              Text('Delete', style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool?> _showDeleteConfirmation(Student student) {
    return showDialog<bool>(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 40, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Delete Student',
              style: AppTheme.labelLarge.copyWith(color: AppTheme.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to delete ${student.fullName}?\n\nThis action cannot be undone.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel', style: AppTheme.bodySmall),
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
                      style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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

  // ======================
  // Dialog launchers
  // ======================

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => AddStudentDialog(
        onStudentCreated: () => _loadStudents(refresh: true),
      ),
    );
  }

  void _showBulkImportDialog() {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => BulkImportStudentsDialog(
        onImportComplete: () => _loadStudents(refresh: true),
        onSuccess: (message) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showSuccessSnackBar(message));
        },
        onError: (message) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showErrorSnackBar(message));
        },
      ),
    );
  }

  void _showStudentDetails(Student student) {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => StudentDetailsDialog(student: student),
    );
  }

  void _showBulkOperationsDialog() {
    showDialog(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => BulkOperationsDialog(
        selectedStudentIds: _selectedStudents.toList(),
        onOperationComplete: () {
          _selectedStudents.clear();
          _loadStudents(refresh: true);
        },
      ),
    );
  }
}
