import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
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
import 'notifications/local_notification_service.dart';
import 'notifications/push_notification_service.dart';

part '../admin/admin_dashboard_view.dart';
part '../admin/admin_users_view.dart';
part '../admin/users/admin_user_filter_dialog.dart';
part '../admin/users/admin_user_form_dialogs.dart';
part '../admin/users/admin_user_widgets.dart';
part 'notifications/notification_view.dart';
part 'profile/profile_view.dart';
part 'tasks/task_home_view.dart';
part 'widgets/home_header.dart';

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
  static const _storage = FlutterSecureStorage();
  final _taskApi = TaskApi();
  final _userApi = UserApi();
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  int _selectedIndex = 0;
  late String _displayName = widget.displayName;
  late String _email = widget.email;
  late String _employeeId = widget.employeeId;
  late UserRole _role = widget.role;
  late String? _profilePic = widget.profilePic;
  _TaskEntry? _selectedTaskEntry;
  _TaskEntry? _reviewTaskEntry;
  _Task? _taskDetailTask;
  _Task? _editingTask;
  bool _showCreateTask = false;
  int _taskRefreshRevision = 0;

  @override
  void initState() {
    super.initState();
    _syncLocalTaskReminders();
    _notificationTapSubscription = PushNotificationService
        .instance
        .notificationTaps
        .listen(_openNotificationTarget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = PushNotificationService.instance
          .takePendingNotificationTap();
      if (pending != null) {
        _openNotificationTarget(pending);
      }
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.accessToken != widget.accessToken) {
      _syncLocalTaskReminders();
    }
  }

  Future<void> _syncLocalTaskReminders() async {
    try {
      final setting = await _storage.read(
        key: LocalNotificationService.enabledStorageKey,
      );
      if (setting == 'false') {
        await LocalNotificationService.instance.cancelUserReminders(
          widget.userId,
        );
        return;
      }

      final permitted = await LocalNotificationService.instance
          .requestPermission();
      if (!permitted) {
        return;
      }

      final taskPayloads = await _taskApi.getTasks(
        accessToken: widget.accessToken,
        isActive: true,
      );
      final tasks = taskPayloads.map(_Task.fromJson).toList();
      final entryGroups = await Future.wait(
        tasks.map((task) async {
          final payloads = await _taskApi.getTaskEntriesLite(
            taskId: task.id,
            accessToken: widget.accessToken,
            status: 'Pending',
          );
          return payloads.map((payload) => _TaskEntry.fromJson(payload, task));
        }),
      );
      final reminders = <LocalTaskReminder>[];
      for (final entry in entryGroups.expand((entries) => entries)) {
        if (entry.userId != widget.userId ||
            entry.status != _TaskStatus.pending ||
            !entry.task.isActive) {
          continue;
        }
        reminders.add(
          LocalTaskReminder(
            entryId: entry.id,
            title: 'Task ready for submission',
            body: entry.task.title,
            scheduledAt: entry.startAt,
            kind: LocalTaskReminderKind.ready,
          ),
        );
        reminders.add(
          LocalTaskReminder(
            entryId: entry.id,
            title: 'Task due in 24 hours',
            body: entry.task.title,
            scheduledAt: entry.dueAt.subtract(const Duration(hours: 24)),
            kind: LocalTaskReminderKind.dueSoon,
          ),
        );
      }
      await LocalNotificationService.instance.replaceUserReminders(
        userId: widget.userId,
        reminders: reminders,
      );
    } on Object {
      // Reminder sync is best-effort and must not block the main task UI.
    }
  }

  Future<void> _openNotificationTarget(Map<String, dynamic> payload) async {
    final taskId = int.tryParse(payload['related_task_id']?.toString() ?? '');
    final entryId = int.tryParse(
      payload['related_task_entry_id']?.toString() ?? '',
    );
    if (taskId == null || taskId <= 0) {
      return;
    }

    try {
      final taskPayloads = await _taskApi.getTasks(
        accessToken: widget.accessToken,
      );
      _Task? targetTask;
      for (final taskPayload in taskPayloads) {
        final task = _Task.fromJson(taskPayload);
        if (task.id == taskId) {
          targetTask = task;
          break;
        }
      }
      if (targetTask == null || !mounted) {
        if (entryId != null && entryId > 0 && mounted) {
          _showRemovedTaskEntryMessage();
        }
        return;
      }

      _TaskEntry? targetEntry;
      if (entryId != null && entryId > 0) {
        final entryPayloads = await _taskApi.getTaskEntries(
          taskId: taskId,
          accessToken: widget.accessToken,
        );
        for (final entryPayload in entryPayloads) {
          final entry = _TaskEntry.fromJson(entryPayload, targetTask);
          if (entry.id == entryId) {
            final userPayload = await _userApi.getUser(
              userId: entry.userId,
              accessToken: widget.accessToken,
            );
            targetEntry = entry.withAssigneeFromUser(userPayload);
            break;
          }
        }
      }
      if (!mounted) {
        return;
      }
      if (entryId != null && entryId > 0 && targetEntry == null) {
        _showRemovedTaskEntryMessage();
        return;
      }

      setState(() {
        _selectedIndex = _isAdmin ? 2 : 0;
        _taskDetailTask = targetTask;
        _selectedTaskEntry = null;
        _reviewTaskEntry = null;
      });
      if (targetEntry != null) {
        _openTaskEntry(targetEntry);
      }
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showRemovedTaskEntryMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This task entry has been removed.')),
    );
  }

  bool get _isAdmin => _role == UserRole.admin;

  bool get _isProfileTab => _selectedIndex == (_isAdmin ? 4 : 2);

  bool get _isTaskTab => _selectedIndex == (_isAdmin ? 2 : 0);

  bool get _showTaskDetailHeader => _isTaskTab && _taskDetailTask != null;

  bool get _canEditTask => _role == UserRole.admin || _role == UserRole.qc;

  bool get _canDeleteTaskEntry => _role == UserRole.admin;

  bool _canEditTaskEntry(_TaskEntry entry) {
    return (_role == UserRole.admin || _role == UserRole.qc) &&
        entry.status == _TaskStatus.pending;
  }

  String get _headerTitle {
    if (_showTaskDetailHeader) {
      return 'Task Detail';
    }

    if (_isAdmin) {
      return switch (_selectedIndex) {
        0 => 'Dashboard',
        1 => 'Users',
        2 => 'Tasks',
        3 => 'Notification',
        _ => 'Profile',
      };
    }

    return switch (_selectedIndex) {
      0 => 'My Tasks',
      1 => 'Notification',
      _ => 'Profile',
    };
  }

  @override
  Widget build(BuildContext context) {
    final showSubmitProof = _isTaskTab && _selectedTaskEntry != null;
    final showReviewSubmission = _isTaskTab && _reviewTaskEntry != null;
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
                initialValues: _editingTask == null
                    ? null
                    : CreateTaskInitialValues(
                        taskId: _editingTask!.id,
                        title: _editingTask!.title,
                        description: _editingTask!.description,
                        userId: _editingTask!.userId,
                        location: _editingTask!.location,
                        recurrenceType: _editingTask!.recurrenceType,
                        recurrenceStartAt: _editingTask!.recurrenceStartAt,
                        dueInterval: _editingTask!.dueInterval,
                        dueIntervalUnit: _editingTask!.dueIntervalUnit,
                        isActive: _editingTask!.isActive,
                      ),
                onBack: () => setState(() {
                  _showCreateTask = false;
                  _editingTask = null;
                }),
                onTaskCreated: () {
                  setState(() {
                    _taskRefreshRevision++;
                    _showCreateTask = false;
                    _editingTask = null;
                    _taskDetailTask = null;
                  });
                  _syncLocalTaskReminders();
                },
              )
            : showReviewSubmission
            ? ReviewSubmissionPage(
                taskTitle: _reviewTaskEntry!.task.title,
                startTimeLabel: _reviewTaskEntry!.startTimeLabel,
                dueTimeLabel: _reviewTaskEntry!.timeLabel,
                submittedTimeLabel: _reviewTaskEntry!.submittedTimeLabel,
                statusLabel: _statusStyle(_reviewTaskEntry!.status).label,
                statusBackgroundColor: _statusStyle(
                  _reviewTaskEntry!.status,
                ).backgroundColor,
                statusForegroundColor: _statusStyle(
                  _reviewTaskEntry!.status,
                ).foregroundColor,
                onReview: (accepted, reviewRemark) async {
                  final message = await _taskApi.reviewTaskEntry(
                    entryId: _reviewTaskEntry!.id,
                    accessToken: widget.accessToken,
                    accepted: accepted,
                    reviewRemark: reviewRemark,
                  );
                  if (mounted) {
                    setState(() => _taskRefreshRevision++);
                  }
                  return message;
                },
                operatorName: _reviewTaskEntry!.assignedUserLabel,
                operatorEmployeeId: _reviewTaskEntry!.assignedEmployeeLabel,
                operatorRemarks: _reviewTaskEntry!.submissionRemark,
                qcFeedback: _reviewTaskEntry!.reviewRemark,
                submittedEvidence: _reviewTaskEntry!.evidence,
                onEditEntry: _canEditTaskEntry(_reviewTaskEntry!)
                    ? () => _editTaskEntry(_reviewTaskEntry!)
                    : null,
                onDeleteEntry: _canDeleteTaskEntry
                    ? () => _confirmAndDeleteTaskEntry(_reviewTaskEntry!)
                    : null,
                showReviewActions:
                    _role != UserRole.operator &&
                    _reviewTaskEntry!.status == _TaskStatus.submitted,
                onBack: () => setState(() => _reviewTaskEntry = null),
              )
            : showSubmitProof
            ? SubmitProofPage(
                taskTitle: _selectedTaskEntry!.task.title,
                startTimeLabel: _selectedTaskEntry!.startTimeLabel,
                taskTimeLabel: _selectedTaskEntry!.timeLabel,
                assignedUserName: _selectedTaskEntry!.assignedUserLabel,
                assignedEmployeeId: _selectedTaskEntry!.assignedEmployeeLabel,
                statusLabel: _statusStyle(_selectedTaskEntry!.status).label,
                statusBackgroundColor: _statusStyle(
                  _selectedTaskEntry!.status,
                ).backgroundColor,
                statusForegroundColor: _statusStyle(
                  _selectedTaskEntry!.status,
                ).foregroundColor,
                showReviewerFeedback:
                    _selectedTaskEntry!.status == _TaskStatus.approved ||
                    _selectedTaskEntry!.status == _TaskStatus.rejected ||
                    _selectedTaskEntry!.status == _TaskStatus.failed,
                operatorRemarks: _selectedTaskEntry!.submissionRemark,
                reviewerFeedback: _selectedTaskEntry!.reviewRemark,
                submittedEvidence: _selectedTaskEntry!.evidence,
                canSubmit:
                    _selectedTaskEntry!.status == _TaskStatus.pending &&
                    _selectedTaskEntry!.userId == widget.userId,
                accessToken: widget.accessToken,
                entryId: _selectedTaskEntry!.id,
                onBack: () => setState(() => _selectedTaskEntry = null),
                onSubmitted: () {
                  setState(() {
                    _selectedTaskEntry = null;
                    _taskRefreshRevision++;
                  });
                  _syncLocalTaskReminders();
                },
                onEditEntry: _canEditTaskEntry(_selectedTaskEntry!)
                    ? () => _editTaskEntry(_selectedTaskEntry!)
                    : null,
                onDeleteEntry: _canDeleteTaskEntry
                    ? () => _confirmAndDeleteTaskEntry(_selectedTaskEntry!)
                    : null,
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
                    onTaskEdit: _showTaskDetailHeader && _canEditTask
                        ? () => setState(() {
                            _editingTask = _taskDetailTask;
                            _showCreateTask = true;
                          })
                        : null,
                    onTaskDelete: _showTaskDetailHeader && _isAdmin
                        ? _confirmAndDeleteTask
                        : null,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _isAdmin
                          ? [
                              _AdminDashboardView(
                                accessToken: widget.accessToken,
                                isActive: _selectedIndex == 0,
                              ),
                              _AdminUsersView(
                                accessToken: widget.accessToken,
                                isActive: _selectedIndex == 1,
                              ),
                              _TaskHomeView(
                                role: _role,
                                currentUserId: widget.userId,
                                accessToken: widget.accessToken,
                                refreshRevision: _taskRefreshRevision,
                                selectedTask: _taskDetailTask,
                                onTaskSelected: (task) =>
                                    setState(() => _taskDetailTask = task),
                                onTaskDetailBack: () =>
                                    setState(() => _taskDetailTask = null),
                                showSummary: false,
                                sectionTitle: 'Tasks List',
                                onAddTask: () => setState(() {
                                  _editingTask = null;
                                  _showCreateTask = true;
                                }),
                                onSubmittedTaskEntrySelected: (entry) =>
                                    _openTaskEntry(entry),
                                onPendingTaskEntrySelected: (entry) =>
                                    _openTaskEntry(entry),
                              ),
                              _NotificationView(
                                role: _role,
                                userId: widget.userId,
                                accessToken: widget.accessToken,
                                isActive: _selectedIndex == 3,
                                onTaskSelected: (task) => setState(() {
                                  _selectedIndex = 2;
                                  _taskDetailTask = task;
                                }),
                                onEntrySelected: (entry) => setState(() {
                                  _selectedIndex = 2;
                                  _selectedTaskEntry = null;
                                  _reviewTaskEntry = null;
                                  if (_role != UserRole.operator &&
                                      entry.status == _TaskStatus.submitted) {
                                    _reviewTaskEntry = entry;
                                    return;
                                  }
                                  _selectedTaskEntry = entry;
                                }),
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
                                onNotificationSettingChanged:
                                    _syncLocalTaskReminders,
                              ),
                            ]
                          : [
                              _TaskHomeView(
                                role: _role,
                                currentUserId: widget.userId,
                                accessToken: widget.accessToken,
                                refreshRevision: _taskRefreshRevision,
                                selectedTask: _taskDetailTask,
                                onTaskSelected: (task) =>
                                    setState(() => _taskDetailTask = task),
                                onTaskDetailBack: () =>
                                    setState(() => _taskDetailTask = null),
                                onAddTask: _role == UserRole.qc
                                    ? () => setState(() {
                                        _editingTask = null;
                                        _showCreateTask = true;
                                      })
                                    : null,
                                onPendingTaskEntrySelected: (entry) =>
                                    _openTaskEntry(entry),
                                onSubmittedTaskEntrySelected: (entry) =>
                                    _openTaskEntry(entry),
                              ),
                              _NotificationView(
                                role: _role,
                                userId: widget.userId,
                                accessToken: widget.accessToken,
                                isActive: _selectedIndex == 1,
                                onTaskSelected: (task) => setState(() {
                                  _selectedIndex = 0;
                                  _taskDetailTask = task;
                                }),
                                onEntrySelected: (entry) => setState(() {
                                  _selectedIndex = 0;
                                  _selectedTaskEntry = null;
                                  _reviewTaskEntry = null;
                                  if (_role != UserRole.operator &&
                                      entry.status == _TaskStatus.submitted) {
                                    _reviewTaskEntry = entry;
                                    return;
                                  }
                                  _selectedTaskEntry = entry;
                                }),
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
                                onNotificationSettingChanged:
                                    _syncLocalTaskReminders,
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
          _editingTask = null;
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

  void _openTaskEntry(_TaskEntry entry) {
    setState(() {
      _selectedTaskEntry = null;
      _reviewTaskEntry = null;

      if (_role != UserRole.operator && entry.status == _TaskStatus.submitted) {
        _reviewTaskEntry = entry;
        return;
      }

      _selectedTaskEntry = entry;
    });
  }

  Future<void> _editTaskEntry(_TaskEntry entry) async {
    final updated = await showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierDismissible: false,
      barrierLabel: 'Edit task entry',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AddTaskEntryDialog(
          taskId: entry.task.id,
          accessToken: widget.accessToken,
          currentUserId: widget.userId,
          currentUserRole: _role,
          defaultUserId: entry.task.userId,
          taskStartAt: entry.task.recurrenceStartAt,
          initialValues: _TaskEntryEditValues(
            entryId: entry.id,
            userId: entry.userId,
            startAt: entry.startAt,
            dueAt: entry.dueAt,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );

    if (updated == true && mounted) {
      setState(() {
        _selectedTaskEntry = null;
        _reviewTaskEntry = null;
        _taskRefreshRevision++;
      });
      await _syncLocalTaskReminders();
    }
  }

  Future<void> _confirmAndDeleteTaskEntry(_TaskEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF303030),
          title: const Text(
            'Delete task entry?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Deleting this task entry will permanently remove it from "${entry.task.title}".',
            style: const TextStyle(color: Color(0xFFEAEAEA)),
          ),
          actions: [
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('Delete'),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final message = await _taskApi.deleteTaskEntry(
        entryId: entry.id,
        accessToken: widget.accessToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedTaskEntry = null;
        _reviewTaskEntry = null;
        _taskRefreshRevision++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _syncLocalTaskReminders();
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _confirmAndDeleteTask() async {
    final task = _taskDetailTask;
    if (task == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF303030),
          title: const Text(
            'Delete task?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Deleting "${task.title}" will permanently remove the task and all task entries under it.',
            style: const TextStyle(color: Color(0xFFEAEAEA)),
          ),
          actions: [
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('Delete'),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final message = await _taskApi.deleteTask(
        taskId: task.id,
        accessToken: widget.accessToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _taskDetailTask = null;
        _taskRefreshRevision++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _syncLocalTaskReminders();
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
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
