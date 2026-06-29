import 'package:flutter/material.dart';

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

// Phone-first design system
import '../../super_admin/widgets/sa_widgets.dart';

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
  final Set<String> _selectedStudents = {};
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
  final bool _sortAscending = true;

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

  Future<void> _deactivateStudent(String studentId) async {
    try {
      await StudentManagementService.updateStudent(studentId, {'status': 'inactive'});
      await _loadStudents(refresh: true);
      if (mounted) {
        _showSuccessSnackBar('Student deactivated');
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
        backgroundColor: AppTheme.greenPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius8),
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
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadius8),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // NO Scaffold / AppBar — the MainLayout shell provides them.
    return SaScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SaGradientHeader(
          title: 'Student Management',
          subtitle: '${_filteredStudents.length} students found',
          icon: Icons.school_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SaHeaderAction(
                icon: Icons.upload_file,
                tooltip: 'Bulk import',
                onPressed: _showBulkImportDialog,
              ),
              const SizedBox(width: Sa.gapXs),
              SaHeaderAction(
                icon: Icons.add,
                tooltip: 'Add student',
                onPressed: _showAddStudentDialog,
              ),
            ],
          ),
        ),
      ),
      child: _animationController == null || _fadeAnimation == null
          ? _buildBodyScaffold()
          : FadeTransition(opacity: _fadeAnimation!, child: _buildBodyScaffold()),
    );
  }

  Widget _buildBodyScaffold() {
    return Column(
      children: [
        _buildFiltersSection(),
        _buildSearchSection(),
        if (_selectedStudents.isNotEmpty) _buildBulkActions(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ======================
  // Builders
  // ======================

  Widget _buildFiltersSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: SaCard(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            final oneCol = c.maxWidth < 600;
            final grade = _buildDropdown<int>(
              label: 'Grade',
              value: _selectedGrade,
              items: _grades,
              onChanged: (value) {
                setState(() => _selectedGrade = value);
                _loadStudents(refresh: true);
              },
              itemBuilder: (grade) => 'Grade $grade',
            );
            final section = _buildDropdown<String>(
              label: 'Section',
              value: _selectedSection,
              items: _sections,
              onChanged: (value) {
                setState(() => _selectedSection = value);
                _loadStudents(refresh: true);
              },
              itemBuilder: (section) => 'Section $section',
            );
            final status = _buildDropdown<String>(
              label: 'Status',
              value: _selectedStatus,
              items: _statusOptions,
              onChanged: (value) {
                setState(() => _selectedStatus = value ?? 'all');
                _filterStudents();
              },
              itemBuilder: (status) => status == 'all' ? 'All Status' : status.toUpperCase(),
            );
            final sort = _buildDropdown<String>(
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
            );

            if (oneCol) {
              return Column(
                children: [
                  grade,
                  const SizedBox(height: Sa.gap),
                  section,
                  const SizedBox(height: Sa.gap),
                  status,
                  const SizedBox(height: Sa.gap),
                  sort,
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: grade),
                    const SizedBox(width: Sa.gap),
                    Expanded(child: section),
                  ],
                ),
                const SizedBox(height: Sa.gap),
                Row(
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: Sa.gap),
                    Expanded(child: sort),
                  ],
                ),
              ],
            );
          },
        ),
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
        Text(label, style: Sa.label),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.neutral300),
            borderRadius: AppTheme.borderRadius8,
            color: AppTheme.neutral50,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              style: Sa.value,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.neutral600),
              onChanged: onChanged,
              items: [
                if (label != 'Status' && label != 'Sort By')
                  DropdownMenuItem<T>(
                    value: null,
                    child: Text('All ${label}s', style: Sa.value),
                  ),
                ...items.map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemBuilder(item), style: Sa.value),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: TextField(
        controller: _searchController,
        style: Sa.value,
        decoration: const InputDecoration(
          hintText: 'Search by name, ID, roll number, or email…',
          hintStyle: Sa.label,
          prefixIcon: Icon(Icons.search, color: AppTheme.greenPrimary, size: 20),
          filled: true,
          fillColor: Colors.white,
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
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildBulkActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: SaCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.checklist, size: 20, color: AppTheme.greenPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_selectedStudents.length} selected',
                style: Sa.value.copyWith(
                    fontWeight: FontWeight.w700, color: AppTheme.greenPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedStudents.clear()),
              child: const Text('Clear', style: Sa.label),
            ),
            const SizedBox(width: 4),
            SaPrimaryButton(
              label: 'Actions',
              icon: Icons.tune_rounded,
              onPressed: _showBulkOperationsDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const SaLoading(message: 'Loading students…');
    if (_error != null) {
      return SaStateView.error(
        message: _error!,
        onRetry: () => _loadStudents(refresh: true),
      );
    }
    if (_filteredStudents.isEmpty) return _buildEmptyState();
    return _buildStudentsList();
  }

  Widget _buildEmptyState() {
    final filtering = _searchController.text.isNotEmpty ||
        _selectedGrade != null ||
        _selectedSection != null;
    if (filtering) {
      return SaStateView(
        icon: Icons.search_off_rounded,
        title: 'No students found',
        subtitle: 'Try adjusting your search or filters.',
        action: TextButton(
          onPressed: () {
            _searchController.clear();
            setState(() {
              _selectedGrade = null;
              _selectedSection = null;
              _selectedStatus = 'all';
            });
            _loadStudents(refresh: true);
          },
          child: Text('Clear filters',
              style: Sa.value.copyWith(color: AppTheme.greenPrimary)),
        ),
      );
    }
    return SaStateView(
      icon: Icons.people_outline,
      title: 'No students yet',
      subtitle: 'Add your first student to get started.',
      action: Wrap(
        spacing: Sa.gap,
        runSpacing: Sa.gapXs,
        alignment: WrapAlignment.center,
        children: [
          SaPrimaryButton(
            label: 'Add student',
            icon: Icons.add,
            onPressed: _showAddStudentDialog,
          ),
          TextButton.icon(
            onPressed: _showBulkImportDialog,
            icon: const Icon(Icons.upload_file, size: 18, color: AppTheme.neutral600),
            label: Text('Bulk import',
                style: Sa.value.copyWith(color: AppTheme.neutral600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 96),
      itemCount: _filteredStudents.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
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
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: AppTheme.greenPrimary, strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading more…', style: Sa.label),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final bool isSelected = _selectedStudents.contains(student.id);
    final bool isInactive = !student.isActive;

    return SaCard(
      onTap: () => _showStudentDetails(student),
      padding: const EdgeInsets.all(12),
      child: Opacity(
        opacity: isInactive ? 0.7 : 1.0,
        child: Row(
          children: [
            Checkbox(
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
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  isInactive ? AppTheme.neutral200 : AppTheme.greenPrimary.withValues(alpha: 0.10),
              child: Text(
                student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : 'S',
                style: Sa.cardTitle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isInactive ? AppTheme.neutral600 : AppTheme.greenPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          student.fullName,
                          style: Sa.cardTitle.copyWith(
                            color: isInactive ? AppTheme.neutral600 : AppTheme.neutral900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isInactive) _buildStatusChip(student),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          student.gradeText,
                          style: Sa.value.copyWith(color: AppTheme.neutral600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (student.rollNumber != null) ...[
                        const SizedBox(width: 12),
                        Text('Roll: ${student.rollNumber}', style: Sa.label),
                      ],
                    ],
                  ),
                  if (student.studentId.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('ID: ${student.studentId}',
                        style: Sa.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (student.age > 0)
                        _buildInfoBadge('${student.age} yrs', Icons.cake_outlined),
                      if (student.email != null)
                        _buildInfoBadge('Email', Icons.email_outlined),
                      if (student.phone != null)
                        _buildInfoBadge('Phone', Icons.phone_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _buildActionsMenu(student),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Student student) {
    // green for active/positive states; neutral for inactive/graduated;
    // red only for suspended (a punitive/negative state).
    Color statusColor;
    switch (student.status.toLowerCase()) {
      case 'active':
        statusColor = AppTheme.greenPrimary;
        break;
      case 'suspended':
        statusColor = AppTheme.error;
        break;
      case 'inactive':
      case 'graduated':
      default:
        statusColor = AppTheme.neutral500;
    }
    return SaStatusPill(text: student.statusText, color: statusColor);
  }

  Widget _buildInfoBadge(String label, IconData icon) {
    // neutral, single-accent badges (no off-brand blue/amber/teal).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: AppTheme.borderRadius8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.neutral600, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: Sa.label.copyWith(fontWeight: FontWeight.w600, color: AppTheme.neutral700)),
        ],
      ),
    );
  }

  Widget _buildActionsMenu(Student student) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.neutral600),
      padding: const EdgeInsets.all(4),
      onSelected: (value) async {
        switch (value) {
          case 'details':
            _showStudentDetails(student);
            break;
          case 'deactivate':
            final confirm = await _showDeactivateConfirmation(student);
            if (confirm == true) {
              await _deactivateStudent(student.id);
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
              Text('View Details', style: Sa.value),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // No "Delete" — deactivate instead (keeps the student + their academic history).
        PopupMenuItem(
          value: 'deactivate',
          child: Row(
            children: [
              const Icon(Icons.block, size: 18, color: AppTheme.error),
              const SizedBox(width: 12),
              Text('Deactivate', style: Sa.value.copyWith(color: AppTheme.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool?> _showDeactivateConfirmation(Student student) {
    final maxW = MediaQuery.of(context).size.width - 24;
    return showDialog<bool>(
      context: context,
      barrierColor: AppTheme.surfaceOverlay,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        backgroundColor: Sa.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW > 420 ? 420 : maxW),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, size: 30, color: AppTheme.error),
                ),
                const SizedBox(height: Sa.gapLg),
                Text(
                  'Deactivate Student',
                  style: Sa.cardTitle.copyWith(color: AppTheme.error, fontSize: 16),
                ),
                const SizedBox(height: Sa.gap),
                Text(
                  'Deactivate ${student.fullName}? They lose access immediately, but their '
                  'record and academic history are kept. You can reactivate them anytime by '
                  'editing their profile.',
                  style: Sa.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Sa.gapLg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.neutral700,
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(color: AppTheme.neutral300),
                          shape: const RoundedRectangleBorder(
                              borderRadius: AppTheme.borderRadius12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: Sa.gap),
                    Expanded(
                      child: SaPrimaryButton(
                        label: 'Deactivate',
                        icon: Icons.block,
                        color: AppTheme.error,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
