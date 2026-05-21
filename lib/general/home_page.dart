import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../authentication/auth_api.dart';
import '../authentication/task_api.dart';
import '../authentication/user_api.dart';
import 'checkops_bottom_nav.dart';
import 'create_task_page.dart';
import 'review_submission_page.dart';
import 'submit_proof_page.dart';

part '../admin/admin_dashboard_view.dart';
part '../admin/admin_users_view.dart';
part '../admin/users/admin_user_filter_dialog.dart';
part '../admin/users/admin_user_form_dialogs.dart';
part '../admin/users/admin_user_widgets.dart';
part 'profile/profile_view.dart';
part 'tasks/task_home_view.dart';
part 'widgets/home_header.dart';
part 'widgets/placeholder_view.dart';

enum UserRole { operator, qc, admin }

({Color background, Color foreground, String label}) _roleBadgeStyle(
  UserRole role,
) {
  return switch (role) {
    UserRole.admin => (
      background: const Color(0xFFFFD166),
      foreground: const Color(0xFF6B4A00),
      label: 'Admin',
    ),
    UserRole.operator => (
      background: const Color(0xFF67D8FF),
      foreground: const Color(0xFF005F88),
      label: 'Operator',
    ),
    UserRole.qc => (
      background: const Color(0xFF7CFF8A),
      foreground: const Color(0xFF007C12),
      label: 'QC',
    ),
  };
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.role,
    required this.displayName,
    required this.email,
    required this.employeeId,
    required this.userId,
    required this.accessToken,
    this.profilePic,
    this.onLogout,
    this.loginBuilder,
    this.onProfileUpdated,
  });

  final UserRole role;
  final String displayName;
  final String email;
  final String employeeId;
  final int userId;
  final String accessToken;
  final String? profilePic;
  final Future<void> Function()? onLogout;
  final WidgetBuilder? loginBuilder;
  final Future<void> Function({
    required String displayName,
    required String email,
    required String employeeId,
    required UserRole role,
    String? profilePic,
  })?
  onProfileUpdated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late String _displayName = widget.displayName;
  late String _email = widget.email;
  late String _employeeId = widget.employeeId;
  late UserRole _role = widget.role;
  late String? _profilePic = widget.profilePic;
  _TaskEntry? _selectedTaskEntry;
  _TaskEntry? _reviewTaskEntry;
  _Task? _taskDetailTask;
  bool _showCreateTask = false;
  int _taskRefreshRevision = 0;

  bool get _isAdmin => _role == UserRole.admin;

  bool get _isProfileTab => _selectedIndex == (_isAdmin ? 4 : 2);

  bool get _isTaskTab => _selectedIndex == (_isAdmin ? 2 : 0);

  bool get _showTaskDetailHeader => _isTaskTab && _taskDetailTask != null;

  String get _headerTitle {
    if (_showTaskDetailHeader) {
      return 'Task Detail';
    }

    if (_isAdmin) {
      return switch (_selectedIndex) {
        0 => 'Dashboard',
        1 => 'Users',
        2 => 'Tasks',
        3 => 'History',
        _ => 'Profile',
      };
    }

    return switch (_selectedIndex) {
      0 => 'My Tasks',
      1 => 'History',
      _ => 'Profile',
    };
  }

  @override
  Widget build(BuildContext context) {
    final showSubmitProof =
        !_isAdmin && _selectedIndex == 0 && _selectedTaskEntry != null;
    final showReviewSubmission =
        _reviewTaskEntry != null &&
        (_isAdmin ? _selectedIndex == 2 : _selectedIndex == 0);
    final showCreateTask =
        _showCreateTask &&
        (_isAdmin ? _selectedIndex == 2 : _selectedIndex == 0);

    return Scaffold(
      backgroundColor: const Color(0xFF474747),
      body: SafeArea(
        bottom: false,
        child: showCreateTask
            ? CreateTaskPage(
                accessToken: widget.accessToken,
                currentUserId: widget.userId,
                currentUserRole: _role.name,
                onBack: () => setState(() => _showCreateTask = false),
                onTaskCreated: () => setState(() {
                  _taskRefreshRevision++;
                  _showCreateTask = false;
                }),
              )
            : showReviewSubmission
            ? ReviewSubmissionPage(
                taskTitle: _reviewTaskEntry!.task.title,
                submittedTimeLabel: _reviewTaskEntry!.submittedTimeLabel,
                showOperatorDetails: _role != UserRole.operator,
                showQcFeedback: _role != UserRole.operator,
                showReviewActions: _role != UserRole.operator,
                operatorRemarks: _reviewTaskEntry!.submissionRemark,
                qcFeedback: _reviewTaskEntry!.reviewRemark,
                onBack: () => setState(() => _reviewTaskEntry = null),
              )
            : showSubmitProof
            ? SubmitProofPage(
                taskTitle: _selectedTaskEntry!.task.title,
                taskTimeLabel: _selectedTaskEntry!.timeLabel,
                onBack: () => setState(() => _selectedTaskEntry = null),
              )
            : Column(
                children: [
                  _HomeHeader(
                    title: _headerTitle,
                    role: _role,
                    displayName: _displayName,
                    profilePic: _profilePic,
                    showAccountActions:
                        !_isProfileTab && !_showTaskDetailHeader,
                    onBack: _showTaskDetailHeader
                        ? () => setState(() => _taskDetailTask = null)
                        : null,
                    onTaskEdit: _showTaskDetailHeader
                        ? () => _showTaskAction('Edit')
                        : null,
                    onTaskDelete: _showTaskDetailHeader
                        ? () => _showTaskAction('Delete')
                        : null,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _isAdmin
                          ? [
                              const _AdminDashboardView(),
                              _AdminUsersView(
                                accessToken: widget.accessToken,
                                isActive: _selectedIndex == 1,
                              ),
                              _TaskHomeView(
                                role: _role,
                                accessToken: widget.accessToken,
                                refreshRevision: _taskRefreshRevision,
                                selectedTask: _taskDetailTask,
                                onTaskSelected: (task) =>
                                    setState(() => _taskDetailTask = task),
                                onTaskDetailBack: () =>
                                    setState(() => _taskDetailTask = null),
                                showSummary: false,
                                sectionTitle: 'Tasks List',
                                onAddTask: () =>
                                    setState(() => _showCreateTask = true),
                                onCompletedTaskEntrySelected: (entry) =>
                                    setState(() => _reviewTaskEntry = entry),
                              ),
                              const _PlaceholderView(
                                icon: Icons.history_rounded,
                                title: 'History',
                              ),
                              _ProfileView(
                                isActive: _selectedIndex == 4,
                                displayName: _displayName,
                                email: _email,
                                employeeId: _employeeId,
                                role: _role,
                                userId: widget.userId,
                                accessToken: widget.accessToken,
                                profilePic: _profilePic,
                                onLogout: widget.onLogout,
                                loginBuilder: widget.loginBuilder,
                                onProfileChanged: _updateProfile,
                              ),
                            ]
                          : [
                              _TaskHomeView(
                                role: _role,
                                accessToken: widget.accessToken,
                                refreshRevision: _taskRefreshRevision,
                                selectedTask: _taskDetailTask,
                                onTaskSelected: (task) =>
                                    setState(() => _taskDetailTask = task),
                                onTaskDetailBack: () =>
                                    setState(() => _taskDetailTask = null),
                                onAddTask: _role == UserRole.qc
                                    ? () =>
                                          setState(() => _showCreateTask = true)
                                    : null,
                                onPendingTaskEntrySelected:
                                    _role == UserRole.operator
                                    ? (entry) => setState(
                                        () => _selectedTaskEntry = entry,
                                      )
                                    : null,
                                onCompletedTaskEntrySelected: (entry) =>
                                    setState(() => _reviewTaskEntry = entry),
                              ),
                              const _PlaceholderView(
                                icon: Icons.history_rounded,
                                title: 'History',
                              ),
                              _ProfileView(
                                isActive: _selectedIndex == 2,
                                displayName: _displayName,
                                email: _email,
                                employeeId: _employeeId,
                                role: _role,
                                userId: widget.userId,
                                accessToken: widget.accessToken,
                                profilePic: _profilePic,
                                onLogout: widget.onLogout,
                                loginBuilder: widget.loginBuilder,
                                onProfileChanged: _updateProfile,
                              ),
                            ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: CheckOpsBottomNav(
        isAdmin: _isAdmin,
        currentIndex: _selectedIndex,
        onChanged: (index) => setState(() {
          _selectedTaskEntry = null;
          _reviewTaskEntry = null;
          _taskDetailTask = null;
          _showCreateTask = false;
          _selectedIndex = index;
        }),
      ),
    );
  }

  Future<void> _updateProfile({
    required String displayName,
    required String email,
    required String employeeId,
    required UserRole role,
    String? profilePic,
  }) async {
    setState(() {
      _displayName = displayName;
      _email = email;
      _employeeId = employeeId;
      _role = role;
      _profilePic = profilePic;
    });
    await widget.onProfileUpdated?.call(
      displayName: displayName,
      email: email,
      employeeId: employeeId,
      role: role,
      profilePic: profilePic,
    );
  }

  void _showTaskAction(String action) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$action task selected.')));
  }
}

UserRole userRoleFromValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'admin' || 'administrator' => UserRole.admin,
    'qc' || 'quality control' || 'quality_control' => UserRole.qc,
    _ => UserRole.operator,
  };
}
