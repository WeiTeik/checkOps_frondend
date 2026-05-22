part of '../home_page.dart';

class _TaskHomeView extends StatefulWidget {
  const _TaskHomeView({
    required this.role,
    required this.accessToken,
    required this.refreshRevision,
    required this.selectedTask,
    required this.onTaskSelected,
    required this.onTaskDetailBack,
    this.onAddTask,
    this.onPendingTaskEntrySelected,
    this.onCompletedTaskEntrySelected,
    this.showSummary = true,
    this.sectionTitle = 'Tasks List',
  });

  final UserRole role;
  final String accessToken;
  final int refreshRevision;
  final _Task? selectedTask;
  final ValueChanged<_Task> onTaskSelected;
  final VoidCallback onTaskDetailBack;
  final VoidCallback? onAddTask;
  final ValueChanged<_TaskEntry>? onPendingTaskEntrySelected;
  final ValueChanged<_TaskEntry>? onCompletedTaskEntrySelected;
  final bool showSummary;
  final String sectionTitle;

  @override
  State<_TaskHomeView> createState() => _TaskHomeViewState();
}

class _TaskHomeViewState extends State<_TaskHomeView> {
  final _taskApi = TaskApi();
  _TaskFilter _filter = const _TaskFilter();
  Future<List<_TaskListItem>>? _tasksFuture;
  bool _isAddButtonPressed = false;
  bool _isFilterButtonPressed = false;

  bool get _canAddTask => widget.onAddTask != null;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void didUpdateWidget(covariant _TaskHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken ||
        oldWidget.role != widget.role ||
        oldWidget.refreshRevision != widget.refreshRevision) {
      widget.onTaskDetailBack();
      _loadTasks();
    }
  }

  void _loadTasks() {
    _tasksFuture = _loadTaskListItems();
  }

  Future<List<_TaskListItem>> _loadTaskListItems() async {
    final taskPayloads = await _taskApi.getTasks(
      accessToken: widget.accessToken,
    );
    final tasks = taskPayloads.map(_Task.fromJson).toList();
    return Future.wait(
      tasks.map((task) async {
        final now = DateTime.now();
        final entryPayloads = await _taskApi.getTaskEntries(
          taskId: task.id,
          accessToken: widget.accessToken,
        );
        final entries = entryPayloads
            .map((entry) => _TaskEntry.fromJson(entry, task))
            .where((entry) => entry.isCurrentActiveCycleEntry(now))
            .toList();
        return _TaskListItem(
          task: task,
          closestEntryDueAt: _closestEntryDueAt(entries),
        );
      }),
    );
  }

  List<_TaskListItem> _filteredTasks(List<_TaskListItem> items) {
    final searchText = _filter.searchText.trim().toLowerCase();
    return items.where((item) {
      final task = item.task;
      final filterDate = item.closestEntryDueAt ?? task.recurrenceStartAt;
      final matchesActiveState =
          _filter.activeStates.isEmpty ||
          _filter.activeStates.contains(task.isActive);
      final matchesStart =
          _filter.startDate == null || !filterDate.isBefore(_filter.startDate!);
      final matchesEnd =
          _filter.endDate == null ||
          filterDate.isBefore(_filter.endDate!.add(const Duration(days: 1)));
      final matchesSearch =
          searchText.isEmpty ||
          task.title.toLowerCase().contains(searchText) ||
          task.location.toLowerCase().contains(searchText) ||
          task.description.toLowerCase().contains(searchText);
      return matchesActiveState && matchesStart && matchesEnd && matchesSearch;
    }).toList();
  }

  Future<void> _openFilter() async {
    setState(() => _isFilterButtonPressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted) {
      return;
    }
    setState(() => _isFilterButtonPressed = false);

    final nextFilter = await showGeneralDialog<_TaskFilter>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierDismissible: true,
      barrierLabel: 'Close filter',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _TaskFilterDialog(initialFilter: _filter);
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

    if (nextFilter != null) {
      setState(() => _filter = nextFilter);
    }
  }

  Future<void> _openAddTask() async {
    if (!_canAddTask) {
      return;
    }
    setState(() => _isAddButtonPressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted) {
      return;
    }
    setState(() => _isAddButtonPressed = false);
    widget.onAddTask?.call();
  }

  void _refreshTasks() {
    setState(() {
      widget.onTaskDetailBack();
      _loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedTask != null) {
      return _TaskEntryListView(
        task: widget.selectedTask!,
        accessToken: widget.accessToken,
        role: widget.role,
        onPendingTaskEntrySelected: widget.onPendingTaskEntrySelected,
        onCompletedTaskEntrySelected: widget.onCompletedTaskEntrySelected,
      );
    }

    return FutureBuilder<List<_TaskListItem>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _TaskLoadingView();
        }
        if (snapshot.hasError) {
          return _TaskErrorView(
            message: _errorMessage(snapshot.error),
            onRetry: _refreshTasks,
          );
        }

        final tasks = _filteredTasks(snapshot.data ?? const []);
        final activeCount = tasks.where((item) => item.task.isActive).length;
        final inactiveCount = tasks.length - activeCount;

        return Column(
          children: [
            if (widget.showSummary)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 22),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusSummaryCard(
                        value: activeCount,
                        label: 'Active',
                        color: const Color(0xFF00B316),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _StatusSummaryCard(
                        value: inactiveCount,
                        label: 'Inactive',
                        color: const Color(0xFFFF8B2C),
                      ),
                    ),
                  ],
                ),
              ),
            _TaskListHeader(
              title: widget.sectionTitle,
              canAddTask: _canAddTask,
              isAddButtonPressed: _isAddButtonPressed,
              isFilterButtonPressed: _isFilterButtonPressed,
              onAddTask: _openAddTask,
              onFilter: _openFilter,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshTasks();
                  await _tasksFuture;
                },
                child: tasks.isEmpty
                    ? const _EmptyTasksView(label: 'No tasks found')
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: tasks.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 1.5,
                          color: Color(0xFFB8B8B8),
                        ),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _TaskTile(
                            item: task,
                            onTap: () => widget.onTaskSelected(task.task),
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

class _TaskEntryListView extends StatefulWidget {
  const _TaskEntryListView({
    required this.task,
    required this.accessToken,
    required this.role,
    this.onPendingTaskEntrySelected,
    this.onCompletedTaskEntrySelected,
  });

  final _Task task;
  final String accessToken;
  final UserRole role;
  final ValueChanged<_TaskEntry>? onPendingTaskEntrySelected;
  final ValueChanged<_TaskEntry>? onCompletedTaskEntrySelected;

  @override
  State<_TaskEntryListView> createState() => _TaskEntryListViewState();
}

class _TaskEntryListViewState extends State<_TaskEntryListView> {
  final _taskApi = TaskApi();
  final _userApi = UserApi();
  _TaskEntryFilter _entryFilter = const _TaskEntryFilter();
  Future<_TaskDetailData>? _detailFuture;
  bool _isAddEntryButtonPressed = false;
  bool _isEntryFilterButtonPressed = false;

  bool get _canAddEntry => widget.role != UserRole.operator;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() {
    _detailFuture = _loadTaskDetail();
  }

  Future<_TaskDetailData> _loadTaskDetail() async {
    final results = await Future.wait<Object>([
      _taskApi.getTaskEntries(
        taskId: widget.task.id,
        accessToken: widget.accessToken,
      ),
      _userApi.getUser(
        userId: widget.task.userId,
        accessToken: widget.accessToken,
      ),
    ]);
    final entryPayloads = results[0] as List<Map<String, dynamic>>;
    final userPayload = results[1] as Map<String, dynamic>;
    return _TaskDetailData(
      assignedUserName:
          userPayload['name']?.toString() ?? 'User #${widget.task.userId}',
      entries: entryPayloads
          .map((entry) => _TaskEntry.fromJson(entry, widget.task))
          .toList(),
    );
  }

  void _refreshDetail() {
    setState(_loadDetail);
  }

  List<_TaskEntry> _filteredEntries(List<_TaskEntry> entries) {
    return entries.where((entry) {
      final matchesStatus =
          _entryFilter.statuses.isEmpty ||
          _entryFilter.statuses.contains(entry.status);
      final matchesStart =
          _entryFilter.startDate == null ||
          !entry.startAt.isBefore(_entryFilter.startDate!);
      final matchesEnd =
          _entryFilter.endDate == null ||
          entry.dueAt.isBefore(
            _entryFilter.endDate!.add(const Duration(days: 1)),
          );

      return matchesStatus && matchesStart && matchesEnd;
    }).toList();
  }

  Future<void> _openAddEntry() async {
    if (!_canAddEntry) {
      return;
    }

    setState(() => _isAddEntryButtonPressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted) {
      return;
    }
    setState(() => _isAddEntryButtonPressed = false);

    final created = await showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierDismissible: false,
      barrierLabel: 'Add task entry',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AddTaskEntryDialog(
          taskId: widget.task.id,
          accessToken: widget.accessToken,
          defaultUserId: widget.task.userId,
          taskStartAt: widget.task.recurrenceStartAt,
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

    if (created == true && mounted) {
      _refreshDetail();
    }
  }

  Future<void> _openEntryFilter() async {
    setState(() => _isEntryFilterButtonPressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted) {
      return;
    }
    setState(() => _isEntryFilterButtonPressed = false);

    final nextFilter = await showGeneralDialog<_TaskEntryFilter>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierDismissible: true,
      barrierLabel: 'Close entry filter',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _TaskEntryFilterDialog(initialFilter: _entryFilter);
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

    if (nextFilter != null) {
      setState(() => _entryFilter = nextFilter);
    }
  }

  VoidCallback? _entryTap(_TaskEntry entry) {
    if (entry.status == _TaskStatus.pending) {
      if (widget.role == UserRole.operator && entry.isAvailableForSubmission) {
        return () => widget.onPendingTaskEntrySelected?.call(entry);
      }
      return null;
    }
    if (entry.status == _TaskStatus.completed) {
      return () => widget.onCompletedTaskEntrySelected?.call(entry);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<_TaskDetailData>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _TaskLoadingView();
              }
              if (snapshot.hasError) {
                return _TaskErrorView(
                  message: _errorMessage(snapshot.error),
                  onRetry: _refreshDetail,
                );
              }

              final detail = snapshot.data;
              final entries = _filteredEntries(detail?.entries ?? const []);
              return RefreshIndicator(
                onRefresh: () async {
                  _refreshDetail();
                  await _detailFuture;
                },
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                      child: _TaskDetailSummary(
                        task: widget.task,
                        assignedUserName: detail?.assignedUserName ?? '',
                      ),
                    ),
                    _TaskListHeader(
                      title: 'Task Entry',
                      canAddTask: _canAddEntry,
                      isAddButtonPressed: _isAddEntryButtonPressed,
                      isFilterButtonPressed: _isEntryFilterButtonPressed,
                      onAddTask: _openAddEntry,
                      onFilter: _openEntryFilter,
                    ),
                    if (entries.isEmpty)
                      const SizedBox(
                        height: 180,
                        child: _EmptyTasksView(label: 'No task entries found'),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < entries.length;
                              index++
                            ) ...[
                              _TaskEntryTile(
                                entry: entries[index],
                                onTap: _entryTap(entries[index]),
                              ),
                              if (index != entries.length - 1)
                                const Divider(
                                  height: 1,
                                  thickness: 1.5,
                                  color: Color(0xFF5F5F5F),
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskListHeader extends StatelessWidget {
  const _TaskListHeader({
    required this.title,
    required this.canAddTask,
    required this.isAddButtonPressed,
    required this.isFilterButtonPressed,
    required this.onAddTask,
    required this.onFilter,
  });

  final String title;
  final bool canAddTask;
  final bool isAddButtonPressed;
  final bool isFilterButtonPressed;
  final VoidCallback onAddTask;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: const Color(0xFF303030),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            child: AnimatedScale(
              scale: isAddButtonPressed ? 0.82 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: AnimatedRotation(
                turns: isAddButtonPressed ? 0.06 : 0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: IconButton(
                  onPressed: canAddTask ? onAddTask : null,
                  tooltip: 'Add task',
                  icon: const Icon(Icons.add_rounded),
                  color: Colors.white,
                  disabledColor: const Color(0xFF777777),
                  iconSize: 25,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Positioned(
            right: 18,
            child: AnimatedScale(
              scale: isFilterButtonPressed ? 0.82 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: AnimatedRotation(
                turns: isFilterButtonPressed ? -0.06 : 0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: IconButton(
                  onPressed: onFilter,
                  tooltip: 'Filter tasks',
                  icon: const Icon(Icons.filter_list_rounded),
                  color: Colors.white,
                  iconSize: 21,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDetailSummary extends StatelessWidget {
  const _TaskDetailSummary({
    required this.task,
    required this.assignedUserName,
  });

  final _Task task;
  final String assignedUserName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _ActivePill(isActive: task.isActive),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TaskDetailInfoTile(
                  icon: Icons.repeat_rounded,
                  label: 'Recurrence',
                  value: task.recurrenceLabel,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _TaskDetailInfoTile(
                  icon: Icons.schedule_rounded,
                  label: 'Start at',
                  value: _formatDateTimeWithLineBreak(task.recurrenceStartAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TaskDetailInfoTile(
                  icon: Icons.person_rounded,
                  label: 'Assigned user',
                  value: assignedUserName.isEmpty
                      ? 'Loading...'
                      : assignedUserName,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _TaskDetailInfoTile(
                  icon: Icons.place_rounded,
                  label: 'Location',
                  value: task.location.trim().isEmpty ? '-' : task.location,
                ),
              ),
            ],
          ),
          if (task.description.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            _TaskDetailTextBlock(
              icon: Icons.notes_rounded,
              label: 'Description',
              value: task.description,
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskDetailInfoTile extends StatelessWidget {
  const _TaskDetailInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF303030),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFC7C7C7), size: 18),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFC7C7C7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskDetailTextBlock extends StatelessWidget {
  const _TaskDetailTextBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF303030),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFC7C7C7), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFC7C7C7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskFilterDialog extends StatefulWidget {
  const _TaskFilterDialog({required this.initialFilter});

  final _TaskFilter initialFilter;

  @override
  State<_TaskFilterDialog> createState() => _TaskFilterDialogState();
}

class _TaskFilterDialogState extends State<_TaskFilterDialog> {
  late final Set<bool> _activeStates = {...widget.initialFilter.activeStates};
  late DateTime? _startDate = widget.initialFilter.startDate;
  late DateTime? _endDate = widget.initialFilter.endDate;
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialFilter.searchText,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final initialDate = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF97DBFF),
              onPrimary: Color(0xFF303030),
              surface: Color(0xFF474747),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      final value = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
      if (isStartDate) {
        _startDate = value;
        return;
      }
      _endDate = value;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      _TaskFilter(
        activeStates: _activeStates,
        startDate: _startDate,
        endDate: _endDate,
        searchText: _searchController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF474747),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                34,
                18,
                34,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 42,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close filter',
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        iconSize: 34,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Filter By',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterStatusChip(
                            label: 'Active',
                            isSelected: _activeStates.contains(true),
                            onPressed: () {
                              setState(() {
                                if (_activeStates.contains(true)) {
                                  _activeStates.remove(true);
                                  return;
                                }
                                _activeStates.clear();
                                _activeStates.add(true);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _FilterStatusChip(
                            label: 'Inactive',
                            isSelected: _activeStates.contains(false),
                            onPressed: () {
                              setState(() {
                                if (_activeStates.contains(false)) {
                                  _activeStates.remove(false);
                                  return;
                                }
                                _activeStates.clear();
                                _activeStates.add(false);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _FilterFieldLabel(text: 'Start Date'),
                    const SizedBox(height: 10),
                    _DateFilterField(
                      value: _formatDate(_startDate),
                      onTap: () => _pickDate(isStartDate: true),
                    ),
                    const SizedBox(height: 22),
                    _FilterFieldLabel(text: 'End Date'),
                    const SizedBox(height: 10),
                    _DateFilterField(
                      value: _formatDate(_endDate),
                      onTap: () => _pickDate(isStartDate: false),
                    ),
                    const SizedBox(height: 22),
                    _FilterFieldLabel(text: 'Search'),
                    const SizedBox(height: 10),
                    _SearchFilterField(controller: _searchController),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterActionButton(
                            label: 'Apply',
                            onPressed: _apply,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _FilterActionButton(
                            label: 'Cancel',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _TaskEntryFilterDialog extends StatefulWidget {
  const _TaskEntryFilterDialog({required this.initialFilter});

  final _TaskEntryFilter initialFilter;

  @override
  State<_TaskEntryFilterDialog> createState() => _TaskEntryFilterDialogState();
}

class _TaskEntryFilterDialogState extends State<_TaskEntryFilterDialog> {
  late final Set<_TaskStatus> _statuses = {...widget.initialFilter.statuses};
  late DateTime? _startDate = widget.initialFilter.startDate;
  late DateTime? _endDate = widget.initialFilter.endDate;

  Future<void> _pickDate({required bool isStartDate}) async {
    final initialDate = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF97DBFF),
              onPrimary: Color(0xFF303030),
              surface: Color(0xFF474747),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      final value = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
      if (isStartDate) {
        _startDate = value;
        return;
      }
      _endDate = value;
    });
  }

  void _toggleStatus(_TaskStatus status) {
    setState(() {
      if (_statuses.contains(status)) {
        _statuses.remove(status);
        return;
      }
      _statuses.add(status);
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      _TaskEntryFilter(
        statuses: _statuses,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF474747),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                34,
                18,
                34,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 42,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close filter',
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        iconSize: 34,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Filter By',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final status in _TaskStatus.values)
                          SizedBox(
                            width: 142,
                            child: _FilterStatusChip(
                              label: _statusStyle(status).label,
                              isSelected: _statuses.contains(status),
                              onPressed: () => _toggleStatus(status),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _FilterFieldLabel(text: 'Start Date'),
                    const SizedBox(height: 10),
                    _DateFilterField(
                      value: _formatFilterDate(_startDate),
                      onTap: () => _pickDate(isStartDate: true),
                    ),
                    const SizedBox(height: 22),
                    _FilterFieldLabel(text: 'End Date'),
                    const SizedBox(height: 10),
                    _DateFilterField(
                      value: _formatFilterDate(_endDate),
                      onTap: () => _pickDate(isStartDate: false),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterActionButton(
                            label: 'Apply',
                            onPressed: _apply,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _FilterActionButton(
                            label: 'Cancel',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AddTaskEntryDialog extends StatefulWidget {
  const _AddTaskEntryDialog({
    required this.taskId,
    required this.accessToken,
    required this.defaultUserId,
    required this.taskStartAt,
  });

  final int taskId;
  final String accessToken;
  final int defaultUserId;
  final DateTime taskStartAt;

  @override
  State<_AddTaskEntryDialog> createState() => _AddTaskEntryDialogState();
}

class _AddTaskEntryDialogState extends State<_AddTaskEntryDialog> {
  final _taskApi = TaskApi();
  final _userApi = UserApi();
  final _assigneeKey = GlobalKey();
  final _startController = TextEditingController();
  final _dueController = TextEditingController();
  Future<List<_EntryAssignee>>? _assigneesFuture;
  _EntryAssignee? _selectedAssignee;
  DateTime? _startAt;
  DateTime? _dueAt;
  bool _showErrors = false;
  bool _isSubmitting = false;
  String? _submitError;

  bool get _isComplete =>
      _selectedAssignee != null &&
      _startAt != null &&
      _dueAt != null &&
      _dueAt!.isAfter(_startAt!);

  @override
  void initState() {
    super.initState();
    _assigneesFuture = _loadAssignees();
  }

  @override
  void dispose() {
    _startController.dispose();
    _dueController.dispose();
    super.dispose();
  }

  Future<List<_EntryAssignee>> _loadAssignees() async {
    final users = await _userApi.getUsers(
      accessToken: widget.accessToken,
      active: true,
    );
    final assignees = users
        .map(_EntryAssignee.fromJson)
        .where((user) => !user.isAdmin)
        .toList();
    _EntryAssignee? defaultAssignee;
    for (final assignee in assignees) {
      if (assignee.id == widget.defaultUserId) {
        defaultAssignee = assignee;
        break;
      }
    }
    if (mounted && defaultAssignee != null) {
      setState(() => _selectedAssignee = defaultAssignee);
    }
    return assignees;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final currentValue =
        (isStart ? _startAt : _dueAt) ??
        (isStart ? widget.taskStartAt : _startAt);
    final initialValue = currentValue ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialValue,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF97DBFF),
              onPrimary: Color(0xFF303030),
              surface: Color(0xFF474747),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF97DBFF),
              onPrimary: Color(0xFF303030),
              surface: Color(0xFF474747),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) {
      return;
    }

    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = value;
        _startController.text = _formatDateTime(value);
        if (_dueAt != null && !_dueAt!.isAfter(value)) {
          _dueAt = null;
          _dueController.clear();
        }
        return;
      }
      _dueAt = value;
      _dueController.text = _formatDateTime(value);
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _showErrors = true;
      _submitError = null;
    });

    if (!_isComplete) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _taskApi.createTaskEntry(
        taskId: widget.taskId,
        accessToken: widget.accessToken,
        userId: _selectedAssignee!.id,
        startAt: _startAt!,
        dueAt: _dueAt!,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task entry created.')));
      Navigator.of(context).pop(true);
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitError = error.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueError =
        _showErrors &&
        _dueAt != null &&
        _startAt != null &&
        !_dueAt!.isAfter(_startAt!);

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF474747),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            18,
            10,
            18,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  tooltip: 'Close',
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                  disabledColor: const Color(0xFF8E8E8E),
                  iconSize: 32,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Add Task Entry',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<_EntryAssignee>>(
              future: _assigneesFuture,
              builder: (context, snapshot) {
                return _EntryAssigneeAutocomplete(
                  fieldKey: _assigneeKey,
                  value: _selectedAssignee,
                  assignees: snapshot.data ?? const [],
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                  errorText: _showErrors && _selectedAssignee == null
                      ? 'Assign User is required'
                      : snapshot.hasError
                      ? _errorMessage(snapshot.error)
                      : null,
                  onRetry: () => setState(() {
                    _assigneesFuture = _loadAssignees();
                  }),
                  onChanged: (assignee) {
                    setState(() => _selectedAssignee = assignee);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            _TaskEntryDateTimeField(
              label: 'Start Time',
              controller: _startController,
              hasError: _showErrors && _startAt == null,
              errorText: 'Start Time is required',
              onTap: _isSubmitting ? null : () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 16),
            _TaskEntryDateTimeField(
              label: 'Due Time',
              controller: _dueController,
              hasError: (_showErrors && _dueAt == null) || dueError,
              errorText: _dueAt == null
                  ? 'Due Time is required'
                  : 'Due Time must be after Start Time',
              onTap: _isSubmitting ? null : () => _pickDateTime(isStart: false),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 18),
              Text(
                _submitError!,
                style: const TextStyle(
                  color: Color(0xFFFFB3B3),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
            const SizedBox(height: 34),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _isComplete
                      ? const Color(0xFFD9D9D9)
                      : const Color(0xFF8E8E8E),
                  foregroundColor: _isComplete
                      ? Colors.black
                      : const Color(0xFF303030),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF303030),
                        ),
                      )
                    : const Text(
                        'Create Entry',
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskEntryDateTimeField extends StatelessWidget {
  const _TaskEntryDateTimeField({
    required this.label,
    required this.controller,
    required this.hasError,
    required this.errorText,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final bool hasError;
  final String errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFD9D9D9),
            errorText: hasError ? errorText : null,
            errorStyle: const TextStyle(
              color: Color(0xFFFFB3B3),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            suffixIcon: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF474747),
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFFF4048) : Colors.transparent,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFFF4048)
                    : const Color(0xFF23A8FF),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4048), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4048), width: 2),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryAssigneeAutocomplete extends StatelessWidget {
  const _EntryAssigneeAutocomplete({
    required this.fieldKey,
    required this.value,
    required this.assignees,
    required this.isLoading,
    required this.onChanged,
    this.errorText,
    this.onRetry,
  });

  final Key fieldKey;
  final _EntryAssignee? value;
  final List<_EntryAssignee> assignees;
  final bool isLoading;
  final ValueChanged<_EntryAssignee?> onChanged;
  final String? errorText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assign User',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        RawAutocomplete<_EntryAssignee>(
          key: ValueKey(value?.id),
          initialValue: TextEditingValue(text: value?.label ?? ''),
          displayStringForOption: (assignee) => assignee.label,
          optionsBuilder: (textEditingValue) {
            if (isLoading || assignees.isEmpty) {
              return const Iterable<_EntryAssignee>.empty();
            }

            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) {
              return assignees;
            }
            return assignees.where((assignee) {
              return assignee.searchText.contains(query);
            });
          },
          onSelected: onChanged,
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  enabled: !isLoading,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  onChanged: (text) {
                    if (value != null && text != value!.label) {
                      onChanged(null);
                    }
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFD9D9D9),
                    hintText: isLoading ? 'Loading users...' : 'Search by name',
                    errorText: errorText,
                    errorStyle: const TextStyle(
                      color: Color(0xFFFFB3B3),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                    suffixIcon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF474747),
                                ),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.manage_search_rounded,
                            color: Color(0xFF474747),
                            size: 22,
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: errorText == null
                            ? Colors.transparent
                            : const Color(0xFFFF4048),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: errorText == null
                            ? const Color(0xFF23A8FF)
                            : const Color(0xFFFF4048),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF4048),
                        width: 2,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF4048),
                        width: 2,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: const Color(0xFFD9D9D9),
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 240,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final assignee = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(assignee),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Text(
                            assignee.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (errorText != null && onRetry != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry loading users'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ],
    );
  }
}

class _FilterFieldLabel extends StatelessWidget {
  const _FilterFieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _FilterStatusChip extends StatelessWidget {
  const _FilterStatusChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: isSelected
              ? const Color(0xFF3A3A3A)
              : const Color(0xFF333333),
          side: BorderSide(
            color: isSelected ? Colors.white : const Color(0xFF333333),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  letterSpacing: 0,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_month_rounded,
              color: Colors.black,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFilterField extends StatelessWidget {
  const _SearchFilterField({required this.controller, this.hintText});

  final TextEditingController controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Colors.black, fontSize: 16),
      cursorColor: Colors.black,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFD9D9D9),
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF666666)),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        suffixIcon: const Icon(
          Icons.search_rounded,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }
}

class _FilterActionButton extends StatelessWidget {
  const _FilterActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _EmptyTasksView extends StatelessWidget {
  const _EmptyTasksView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC7C7C7),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskLoadingView extends StatelessWidget {
  const _TaskLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFC7C7C7)),
    );
  }
}

class _TaskErrorView extends StatelessWidget {
  const _TaskErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC7C7C7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  const _StatusSummaryCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.item, required this.onTap});

  final _TaskListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 18, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC7C7C7),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ActivePill(isActive: task.isActive),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF7CFF8A) : const Color(0xFFFFD59B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isActive ? const Color(0xFF008F13) : const Color(0xFFFF8B2C),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TaskEntryTile extends StatelessWidget {
  const _TaskEntryTile({required this.entry, this.onTap});

  final _TaskEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(entry.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF3F3F3F),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: style.markerColor, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _EntryMetaLine(
                        icon: Icons.play_arrow_rounded,
                        label: 'Start',
                        value: entry.startTimeLabel,
                      ),
                      const SizedBox(height: 8),
                      _EntryMetaLine(
                        icon: Icons.flag_rounded,
                        label: 'Due',
                        value: entry.timeLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(status: entry.status),
              ],
            ),
            if (onTap != null) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC7C7C7),
                  size: 24,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryMetaLine extends StatelessWidget {
  const _EntryMetaLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC7C7C7), size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC7C7C7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(status);
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        style.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: style.foregroundColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

enum _TaskStatus { pending, completed, failed, approved, rejected, expired }

class _TaskDetailData {
  const _TaskDetailData({
    required this.assignedUserName,
    required this.entries,
  });

  final String assignedUserName;
  final List<_TaskEntry> entries;
}

class _TaskListItem {
  const _TaskListItem({required this.task, required this.closestEntryDueAt});

  final _Task task;
  final DateTime? closestEntryDueAt;

  String get subtitle {
    final dueAt = closestEntryDueAt;
    if (dueAt == null) {
      return 'No active task entry';
    }
    return 'Due ${_formatDateTime(dueAt)}';
  }
}

class _Task {
  const _Task({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.location,
    required this.recurrenceType,
    required this.recurrenceInterval,
    required this.recurrenceUnit,
    required this.recurrenceStartAt,
    required this.dueInterval,
    required this.dueIntervalUnit,
    required this.isActive,
  });

  factory _Task.fromJson(Map<String, dynamic> json) {
    return _Task(
      id: _intFrom(json['id']),
      title: json['name']?.toString() ?? 'Untitled task',
      description: json['description']?.toString() ?? '',
      userId: _intFrom(json['user_id']),
      location: json['location']?.toString() ?? '',
      recurrenceType: json['recurrence_type']?.toString() ?? 'Once',
      recurrenceInterval: _intFrom(json['recurrence_interval']),
      recurrenceUnit: json['recurrence_unit']?.toString(),
      recurrenceStartAt: _dateFrom(json['recurrence_start_at']),
      dueInterval: _intFrom(json['due_interval']),
      dueIntervalUnit: json['due_interval_unit']?.toString() ?? 'Day',
      isActive: json['is_active'] == true,
    );
  }

  final int id;
  final String title;
  final String description;
  final int userId;
  final String location;
  final String recurrenceType;
  final int recurrenceInterval;
  final String? recurrenceUnit;
  final DateTime recurrenceStartAt;
  final int dueInterval;
  final String dueIntervalUnit;
  final bool isActive;

  String get recurrenceLabel {
    if (recurrenceType == 'Once') {
      return 'Once';
    }
    final unit = recurrenceUnit ?? 'cycle';
    final interval = recurrenceInterval <= 1 ? '' : '$recurrenceInterval ';
    return 'Every $interval${unit.toLowerCase()}';
  }

  String get subtitle {
    final pieces = <String>[
      if (location.isNotEmpty) location,
      recurrenceType,
      'Starts ${_formatDateTime(recurrenceStartAt)}',
    ];
    return pieces.join(' • ');
  }
}

class _TaskEntry {
  const _TaskEntry({
    required this.id,
    required this.task,
    required this.startAt,
    required this.dueAt,
    required this.status,
    required this.isAvailableForSubmission,
    required this.submissionRemark,
    required this.reviewRemark,
    required this.submittedAt,
  });

  factory _TaskEntry.fromJson(Map<String, dynamic> json, _Task task) {
    return _TaskEntry(
      id: _intFrom(json['id']),
      task: task,
      startAt: _dateFrom(json['start_at']),
      dueAt: _dateFrom(json['due_at']),
      status: _statusFrom(json['status']),
      isAvailableForSubmission: json['is_available_for_submission'] == true,
      submissionRemark: json['submission_remark']?.toString() ?? '',
      reviewRemark: json['review_remark']?.toString() ?? '',
      submittedAt: _nullableDateFrom(json['submitted_at']),
    );
  }

  final int id;
  final _Task task;
  final DateTime startAt;
  final DateTime dueAt;
  final _TaskStatus status;
  final bool isAvailableForSubmission;
  final String submissionRemark;
  final String reviewRemark;
  final DateTime? submittedAt;

  String get timeLabel => _formatDateTime(dueAt);
  String get startTimeLabel => _formatDateTime(startAt);
  String get submittedTimeLabel => _formatDateTime(submittedAt ?? dueAt);

  bool isCurrentActiveCycleEntry(DateTime now) {
    final isActiveStatus =
        status == _TaskStatus.pending || status == _TaskStatus.completed;
    return isActiveStatus && !now.isBefore(startAt) && !now.isAfter(dueAt);
  }
}

class _TaskFilter {
  const _TaskFilter({
    this.activeStates = const {},
    this.startDate,
    this.endDate,
    this.searchText = '',
  });

  final Set<bool> activeStates;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchText;
}

class _TaskEntryFilter {
  const _TaskEntryFilter({
    this.statuses = const {},
    this.startDate,
    this.endDate,
  });

  final Set<_TaskStatus> statuses;
  final DateTime? startDate;
  final DateTime? endDate;
}

class _EntryAssignee {
  const _EntryAssignee({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.role,
  });

  factory _EntryAssignee.fromJson(Map<String, dynamic> json) {
    return _EntryAssignee(
      id: _intFrom(json['id']),
      name: json['name']?.toString() ?? 'User',
      employeeId: json['employee_id']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
    );
  }

  final int id;
  final String name;
  final String employeeId;
  final String role;

  String get label {
    return name;
  }

  String get searchText {
    return '$name $employeeId'.toLowerCase();
  }

  bool get isAdmin {
    return role.trim().toLowerCase() == 'admin';
  }
}

({
  Color backgroundColor,
  Color foregroundColor,
  Color markerColor,
  String label,
})
_statusStyle(_TaskStatus status) {
  return switch (status) {
    _TaskStatus.completed => (
      backgroundColor: const Color(0xFF7CFF8A),
      foregroundColor: const Color(0xFF008F13),
      markerColor: const Color(0xFF00B316),
      label: 'Completed',
    ),
    _TaskStatus.approved => (
      backgroundColor: const Color(0xFFB9F6CA),
      foregroundColor: const Color(0xFF007C12),
      markerColor: const Color(0xFF00B316),
      label: 'Approved',
    ),
    _TaskStatus.failed => (
      backgroundColor: const Color(0xFFFFB3B3),
      foregroundColor: const Color(0xFFC93535),
      markerColor: const Color(0xFFFF4048),
      label: 'Failed',
    ),
    _TaskStatus.rejected => (
      backgroundColor: const Color(0xFFFFB3B3),
      foregroundColor: const Color(0xFFC93535),
      markerColor: const Color(0xFFFF4048),
      label: 'Rejected',
    ),
    _TaskStatus.expired => (
      backgroundColor: const Color(0xFFD9D9D9),
      foregroundColor: const Color(0xFF565656),
      markerColor: const Color(0xFF8E8E8E),
      label: 'Expired',
    ),
    _TaskStatus.pending => (
      backgroundColor: const Color(0xFFFFD59B),
      foregroundColor: const Color(0xFFFF8B2C),
      markerColor: const Color(0xFFFF8B2C),
      label: 'Pending',
    ),
  };
}

_TaskStatus _statusFrom(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'completed' => _TaskStatus.completed,
    'failed' => _TaskStatus.failed,
    'approved' => _TaskStatus.approved,
    'rejected' => _TaskStatus.rejected,
    'expired' => _TaskStatus.expired,
    _ => _TaskStatus.pending,
  };
}

DateTime _dateFrom(Object? value) {
  return _nullableDateFrom(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDateFrom(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _intFrom(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatDateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'pm' : 'am';
  return '${value.day}/${value.month}/${value.year} $hour:$minute $period';
}

String _formatDateTimeWithLineBreak(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'pm' : 'am';
  return '${value.day}/${value.month}/${value.year}\n$hour:$minute $period';
}

String _formatFilterDate(DateTime? date) {
  if (date == null) {
    return '';
  }
  return '${date.day}/${date.month}/${date.year}';
}

DateTime? _closestEntryDueAt(List<_TaskEntry> entries) {
  if (entries.isEmpty) {
    return null;
  }

  final now = DateTime.now();
  entries.sort((a, b) {
    final aDistance = a.dueAt.difference(now).abs();
    final bDistance = b.dueAt.difference(now).abs();
    return aDistance.compareTo(bDistance);
  });
  return entries.first.dueAt;
}

String _errorMessage(Object? error) {
  if (error is AuthApiException) {
    return error.message;
  }
  return 'Unable to load tasks. Please try again.';
}
