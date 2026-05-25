part of '../home_page.dart';

class _NotificationView extends StatefulWidget {
  const _NotificationView({
    required this.role,
    required this.userId,
    required this.accessToken,
    required this.isActive,
    required this.onTaskSelected,
    required this.onEntrySelected,
  });

  final UserRole role;
  final int userId;
  final String accessToken;
  final bool isActive;
  final ValueChanged<_Task> onTaskSelected;
  final ValueChanged<_TaskEntry> onEntrySelected;

  @override
  State<_NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<_NotificationView> {
  static const _storage = FlutterSecureStorage();

  final _taskApi = TaskApi();
  Future<List<_CheckOpsNotification>>? _notificationsFuture;
  Set<String> _readNotificationIds = const {};

  @override
  void initState() {
    super.initState();
    _loadReadState();
    _loadNotifications();
  }

  @override
  void didUpdateWidget(covariant _NotificationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken ||
        oldWidget.role != widget.role ||
        oldWidget.userId != widget.userId) {
      _loadReadState();
      _loadNotifications();
    } else if (widget.isActive && !oldWidget.isActive) {
      _loadNotifications();
    }
  }

  String get _readStorageKey {
    return 'notifications_read_${widget.userId}_${widget.role.name}';
  }

  Future<void> _loadReadState() async {
    try {
      final rawValue = await _storage.read(key: _readStorageKey);
      if (!mounted) {
        return;
      }
      setState(() {
        _readNotificationIds = rawValue == null || rawValue.isEmpty
            ? const {}
            : rawValue.split('|').where((id) => id.isNotEmpty).toSet();
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _readNotificationIds = const {});
    }
  }

  Future<void> _saveReadState(Set<String> ids) async {
    setState(() => _readNotificationIds = ids);
    try {
      await _storage.write(key: _readStorageKey, value: ids.join('|'));
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save notification state.')),
      );
    }
  }

  void _loadNotifications() {
    _notificationsFuture = _loadNotificationItems();
  }

  Future<void> _refreshNotifications() async {
    setState(_loadNotifications);
    await _notificationsFuture;
  }

  Future<List<_CheckOpsNotification>> _loadNotificationItems() async {
    final taskPayloads = await _taskApi.getTasks(
      accessToken: widget.accessToken,
    );
    final tasks = taskPayloads.map(_Task.fromJson).toList();
    final now = DateTime.now();

    final nestedItems = await Future.wait(
      tasks.map((task) async {
        final entryPayloads = await _taskApi.getTaskEntries(
          taskId: task.id,
          accessToken: widget.accessToken,
        );
        final entries = entryPayloads
            .map((entry) => _TaskEntry.fromJson(entry, task))
            .toList();
        return _notificationsForTask(task, entries, now);
      }),
    );

    final notifications = nestedItems.expand((items) => items).toList()
      ..sort(_compareNotifications);
    return notifications;
  }

  List<_CheckOpsNotification> _notificationsForTask(
    _Task task,
    List<_TaskEntry> entries,
    DateTime now,
  ) {
    final items = <_CheckOpsNotification>[];

    if (!task.isActive) {
      items.add(
        _CheckOpsNotification(
          id: 'task-${task.id}-inactive',
          kind: _NotificationKind.inactiveTask,
          title: 'Task inactive',
          message: task.title,
          timestamp: task.recurrenceStartAt,
          task: task,
        ),
      );
    }

    for (final entry in entries) {
      final dueSoon =
          entry.status == _TaskStatus.pending &&
          entry.dueAt.isAfter(now) &&
          entry.dueAt.difference(now) <= const Duration(hours: 24);
      final overdue =
          entry.status == _TaskStatus.pending && entry.dueAt.isBefore(now);

      if (entry.status == _TaskStatus.submitted) {
        items.add(
          _CheckOpsNotification(
            id: 'entry-${entry.id}-submitted',
            kind: _NotificationKind.submitted,
            title: widget.role == UserRole.operator
                ? 'Proof submitted'
                : 'Submission waiting for review',
            message: entry.task.title,
            timestamp: entry.submittedAt ?? entry.dueAt,
            task: task,
            entry: entry,
          ),
        );
      } else if (overdue) {
        items.add(
          _CheckOpsNotification(
            id: 'entry-${entry.id}-overdue',
            kind: _NotificationKind.overdue,
            title: 'Task overdue',
            message: entry.task.title,
            timestamp: entry.dueAt,
            task: task,
            entry: entry,
          ),
        );
      } else if (entry.isAvailableForSubmission) {
        items.add(
          _CheckOpsNotification(
            id: 'entry-${entry.id}-ready',
            kind: _NotificationKind.ready,
            title: 'Task ready for proof',
            message: entry.task.title,
            timestamp: entry.startAt,
            task: task,
            entry: entry,
          ),
        );
      } else if (dueSoon) {
        items.add(
          _CheckOpsNotification(
            id: 'entry-${entry.id}-due-soon',
            kind: _NotificationKind.dueSoon,
            title: 'Task due soon',
            message: entry.task.title,
            timestamp: entry.dueAt,
            task: task,
            entry: entry,
          ),
        );
      } else if (entry.status == _TaskStatus.approved ||
          entry.status == _TaskStatus.rejected ||
          entry.status == _TaskStatus.failed) {
        final statusStyle = _statusStyle(entry.status);
        items.add(
          _CheckOpsNotification(
            id: 'entry-${entry.id}-${statusStyle.label.toLowerCase()}',
            kind: _NotificationKind.result,
            title: 'Submission ${statusStyle.label.toLowerCase()}',
            message: entry.task.title,
            timestamp: entry.submittedAt ?? entry.dueAt,
            task: task,
            entry: entry,
          ),
        );
      }
    }

    return items;
  }

  int _compareNotifications(
    _CheckOpsNotification first,
    _CheckOpsNotification second,
  ) {
    final firstPriority = first.kind.priority;
    final secondPriority = second.kind.priority;
    if (firstPriority != secondPriority) {
      return firstPriority.compareTo(secondPriority);
    }
    return second.timestamp.compareTo(first.timestamp);
  }

  Future<void> _markRead(_CheckOpsNotification notification) async {
    if (_readNotificationIds.contains(notification.id)) {
      return;
    }
    await _saveReadState({..._readNotificationIds, notification.id});
  }

  Future<void> _markAllRead(List<_CheckOpsNotification> notifications) async {
    await _saveReadState({
      ..._readNotificationIds,
      for (final notification in notifications) notification.id,
    });
  }

  Future<void> _openNotification(_CheckOpsNotification notification) async {
    await _markRead(notification);
    final entry = notification.entry;
    if (entry != null) {
      widget.onEntrySelected(entry);
      return;
    }
    widget.onTaskSelected(notification.task);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_CheckOpsNotification>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _TaskLoadingView();
        }

        if (snapshot.hasError) {
          return _TaskErrorView(
            message: _notificationErrorMessage(snapshot.error),
            onRetry: () => setState(_loadNotifications),
          );
        }

        final notifications = snapshot.data ?? const [];
        final unreadCount = notifications
            .where(
              (notification) => !_readNotificationIds.contains(notification.id),
            )
            .length;

        return Column(
          children: [
            _NotificationSummaryBar(
              unreadCount: unreadCount,
              totalCount: notifications.length,
              onMarkAllRead: notifications.isEmpty || unreadCount == 0
                  ? null
                  : () => _markAllRead(notifications),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshNotifications,
                child: notifications.isEmpty
                    ? const _EmptyNotificationsView()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                        itemCount: notifications.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return _NotificationTile(
                            notification: notification,
                            isRead: _readNotificationIds.contains(
                              notification.id,
                            ),
                            onTap: () => _openNotification(notification),
                            onMarkRead: () => _markRead(notification),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationSummaryBar extends StatelessWidget {
  const _NotificationSummaryBar({
    required this.unreadCount,
    required this.totalCount,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final int totalCount;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: const Color(0xFF303030),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$unreadCount unread - $totalCount total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            onPressed: onMarkAllRead,
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all_rounded),
            color: Colors.white,
            disabledColor: const Color(0xFF777777),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
    required this.onMarkRead,
  });

  final _CheckOpsNotification notification;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final style = notification.kind.style;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFF3A3A3A) : const Color(0xFF404040),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: style.color, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: style.color, size: 22),
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
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8EDCFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE7E7E7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    notification.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC7C7C7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: isRead ? null : onMarkRead,
              tooltip: 'Mark as read',
              icon: const Icon(Icons.check_circle_outline_rounded),
              color: const Color(0xFFC7C7C7),
              disabledColor: Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.23),
        const Icon(
          Icons.notifications_none_rounded,
          color: Color(0xFFC7C7C7),
          size: 40,
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'No notifications',
            style: TextStyle(
              color: Color(0xFFC7C7C7),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckOpsNotification {
  const _CheckOpsNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.task,
    this.entry,
  });

  final String id;
  final _NotificationKind kind;
  final String title;
  final String message;
  final DateTime timestamp;
  final _Task task;
  final _TaskEntry? entry;

  String get timeLabel {
    return '${_relativeDateLabel(timestamp)} - ${_formatDateTime(timestamp)}';
  }
}

enum _NotificationKind {
  overdue,
  submitted,
  ready,
  dueSoon,
  result,
  inactiveTask,
}

extension _NotificationKindDetails on _NotificationKind {
  int get priority {
    return switch (this) {
      _NotificationKind.overdue => 0,
      _NotificationKind.submitted => 1,
      _NotificationKind.ready => 2,
      _NotificationKind.dueSoon => 3,
      _NotificationKind.result => 4,
      _NotificationKind.inactiveTask => 5,
    };
  }

  ({Color color, IconData icon}) get style {
    return switch (this) {
      _NotificationKind.overdue => (
        color: const Color(0xFFFF6B6B),
        icon: Icons.warning_rounded,
      ),
      _NotificationKind.submitted => (
        color: const Color(0xFF7CFF8A),
        icon: Icons.assignment_turned_in_rounded,
      ),
      _NotificationKind.ready => (
        color: const Color(0xFF8EDCFF),
        icon: Icons.upload_file_rounded,
      ),
      _NotificationKind.dueSoon => (
        color: const Color(0xFFFFD166),
        icon: Icons.schedule_rounded,
      ),
      _NotificationKind.result => (
        color: const Color(0xFFD9D9D9),
        icon: Icons.fact_check_rounded,
      ),
      _NotificationKind.inactiveTask => (
        color: const Color(0xFFFFB36B),
        icon: Icons.pause_circle_filled_rounded,
      ),
    };
  }
}

String _relativeDateLabel(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final dayDifference = date.difference(today).inDays;

  if (dayDifference == 0) {
    return 'Today';
  }
  if (dayDifference == 1) {
    return 'Tomorrow';
  }
  if (dayDifference == -1) {
    return 'Yesterday';
  }
  if (dayDifference < -1) {
    return '${dayDifference.abs()} days ago';
  }
  return 'In $dayDifference days';
}

String _notificationErrorMessage(Object? error) {
  if (error is AuthApiException) {
    return error.message;
  }
  return 'Unable to load notifications. Please try again.';
}
