part of '../dashboard_reporting/home_page.dart';

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
  final _taskApi = TaskApi();
  Future<List<_CheckOpsNotification>>? _notificationsFuture;
  Set<String> _readNotificationIds = const {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void didUpdateWidget(covariant _NotificationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken ||
        oldWidget.role != widget.role ||
        oldWidget.userId != widget.userId) {
      _loadNotifications();
    } else if (widget.isActive && !oldWidget.isActive) {
      _loadNotifications();
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
    final notificationFuture = _taskApi.getNotifications(
      accessToken: widget.accessToken,
    );
    final taskFuture = _taskApi.getTasks(accessToken: widget.accessToken);
    final notificationPayloads = await notificationFuture;
    final taskPayloads = await taskFuture;
    final tasksById = {
      for (final payload in taskPayloads)
        _intFrom(payload['id']): _Task.fromJson(payload),
    };

    final notifications =
        notificationPayloads.map((payload) {
          final taskId = _nullableNotificationId(payload['related_task_id']);
          final type = payload['type']?.toString() ?? '';
          return _CheckOpsNotification(
            id: _intFrom(payload['id']).toString(),
            kind: _notificationKindFromType(type),
            title: type.toLowerCase().contains('failed')
                ? 'Task entry submission failed'
                : payload['title']?.toString() ?? 'Notification',
            message: payload['message']?.toString() ?? '',
            timestamp: _dateFrom(payload['created_at']),
            task: taskId == null ? null : tasksById[taskId],
            relatedTaskId: taskId,
            relatedEntryId: _nullableNotificationId(
              payload['related_task_entry_id'],
            ),
            relatedEntryDeleted: payload['related_task_entry_deleted'] == true,
            isRead: payload['read_at'] != null,
          );
        }).toList()..sort(
          (first, second) => second.timestamp.compareTo(first.timestamp),
        );

    _readNotificationIds = {
      for (final notification in notifications)
        if (notification.isRead) notification.id,
    };
    return notifications;
  }

  Future<void> _markRead(_CheckOpsNotification notification) async {
    if (_readNotificationIds.contains(notification.id)) {
      return;
    }
    try {
      await _taskApi.markNotificationRead(
        notificationId: int.parse(notification.id),
        accessToken: widget.accessToken,
      );
      if (mounted) {
        setState(() {
          _readNotificationIds = {..._readNotificationIds, notification.id};
        });
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _markAllRead(List<_CheckOpsNotification> notifications) async {
    try {
      await _taskApi.markAllNotificationsRead(accessToken: widget.accessToken);
      if (mounted) {
        setState(() {
          _readNotificationIds = {
            for (final notification in notifications) notification.id,
          };
        });
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openNotification(_CheckOpsNotification notification) async {
    await _markRead(notification);
    final entryId = notification.relatedEntryId;
    if (entryId != null) {
      if (notification.relatedEntryDeleted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This task entry has been removed.')),
          );
        }
        return;
      }
      try {
        final task = notification.task;
        if (task == null) {
          throw AuthApiException('This task is no longer available.');
        }
        final payload = await _taskApi.getTaskEntry(
          entryId: entryId,
          accessToken: widget.accessToken,
        );
        if (mounted) {
          widget.onEntrySelected(_TaskEntry.fromJson(payload, task));
        }
      } on AuthApiException catch (error) {
        if (!mounted) {
          return;
        }
        final message = error.statusCode == 404
            ? 'This task entry has been removed.'
            : error.message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    final task = notification.task;
    if (task != null) {
      widget.onTaskSelected(task);
    }
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
    final statusColor = style.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFF3A3A3A) : const Color(0xFF404040),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: statusColor, size: 22),
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
    required this.relatedTaskId,
    required this.relatedEntryId,
    required this.relatedEntryDeleted,
    required this.isRead,
  });

  final String id;
  final _NotificationKind kind;
  final String title;
  final String message;
  final DateTime timestamp;
  final _Task? task;
  final int? relatedTaskId;
  final int? relatedEntryId;
  final bool relatedEntryDeleted;
  final bool isRead;

  String get timeLabel {
    return '${_relativeDateLabel(timestamp)} - ${_formatDateTime(timestamp)}';
  }
}

enum _NotificationKind {
  pending,
  submitted,
  approved,
  failed,
  rejected,
  expired,
}

extension _NotificationKindDetails on _NotificationKind {
  ({Color color, IconData icon}) get style {
    return switch (this) {
      _NotificationKind.pending => (
        color: const Color(0xFFFF8B2C),
        icon: Icons.assignment_ind_rounded,
      ),
      _NotificationKind.submitted => (
        color: const Color(0xFF00B316),
        icon: Icons.assignment_turned_in_rounded,
      ),
      _NotificationKind.approved => (
        color: const Color(0xFF00B316),
        icon: Icons.check_circle_rounded,
      ),
      _NotificationKind.failed => (
        color: const Color(0xFFFF1E1E),
        icon: Icons.error_rounded,
      ),
      _NotificationKind.rejected => (
        color: const Color(0xFFFF1E1E),
        icon: Icons.cancel_rounded,
      ),
      _NotificationKind.expired => (
        color: const Color(0xFF8E8E8E),
        icon: Icons.timer_off_rounded,
      ),
    };
  }
}

_NotificationKind _notificationKindFromType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('expired')) {
    return _NotificationKind.expired;
  }
  if (normalized.contains('rejected')) {
    return _NotificationKind.rejected;
  }
  if (normalized.contains('failed')) {
    return _NotificationKind.failed;
  }
  if (normalized.contains('approved')) {
    return _NotificationKind.approved;
  }
  if (normalized.contains('submitted')) {
    return _NotificationKind.submitted;
  }
  return _NotificationKind.pending;
}

int? _nullableNotificationId(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
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
