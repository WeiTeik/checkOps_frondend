part of '../home_page.dart';

class _TaskHomeView extends StatefulWidget {
  const _TaskHomeView({
    required this.role,
    this.onPendingTaskSelected,
    this.showSummary = true,
    this.sectionTitle = 'Tasks List',
  });

  final UserRole role;
  final ValueChanged<_Task>? onPendingTaskSelected;
  final bool showSummary;
  final String sectionTitle;

  @override
  State<_TaskHomeView> createState() => _TaskHomeViewState();
}

class _TaskHomeViewState extends State<_TaskHomeView> {
  _TaskFilter _filter = const _TaskFilter();
  bool _isFilterButtonPressed = false;

  List<_Task> _filteredTasks(List<_Task> tasks) {
    final searchText = _filter.searchText.trim().toLowerCase();

    return tasks.where((task) {
      final matchesStatus =
          _filter.statuses.isEmpty || _filter.statuses.contains(task.status);
      final matchesStart =
          _filter.startDate == null || !task.dueAt.isBefore(_filter.startDate!);
      final matchesEnd =
          _filter.endDate == null ||
          task.dueAt.isBefore(_filter.endDate!.add(const Duration(days: 1)));
      final matchesSearch =
          searchText.isEmpty || task.title.toLowerCase().contains(searchText);

      return matchesStatus && matchesStart && matchesEnd && matchesSearch;
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

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks(_tasksFor(widget.role));
    final pendingCount = tasks
        .where((task) => task.status == _TaskStatus.pending)
        .length;
    final completedCount = tasks
        .where((task) => task.status == _TaskStatus.completed)
        .length;

    return Column(
      children: [
        if (widget.showSummary)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 22),
            child: Row(
              children: [
                Expanded(
                  child: _StatusSummaryCard(
                    value: pendingCount,
                    label: 'Pending',
                    color: const Color(0xFFFF8B2C),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _StatusSummaryCard(
                    value: completedCount,
                    label: 'Completed',
                    color: const Color(0xFF00B316),
                  ),
                ),
              ],
            ),
          ),
        Container(
          height: 46,
          color: const Color(0xFF303030),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  widget.sectionTitle,
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
                  scale: _isFilterButtonPressed ? 0.82 : 1,
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOut,
                  child: AnimatedRotation(
                    turns: _isFilterButtonPressed ? -0.06 : 0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: IconButton(
                      onPressed: _openFilter,
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
        ),
        Expanded(
          child: tasks.isEmpty
              ? const _EmptyTasksView()
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
                      task: task,
                      onTap: task.status == _TaskStatus.pending
                          ? () => widget.onPendingTaskSelected?.call(task)
                          : null,
                    );
                  },
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
  late final Set<_TaskStatus> _statuses = {...widget.initialFilter.statuses};
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
    final initialDate =
        (isStartDate ? _startDate : _endDate) ?? DateTime(2026, 5);
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
      if (isStartDate) {
        _startDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
        );
        return;
      }
      _endDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      _TaskFilter(
        statuses: _statuses,
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterStatusChip(
                            label: 'Pending',
                            isSelected: _statuses.contains(_TaskStatus.pending),
                            onPressed: () {
                              setState(() {
                                if (_statuses.contains(_TaskStatus.pending)) {
                                  _statuses.remove(_TaskStatus.pending);
                                  return;
                                }
                                _statuses.add(_TaskStatus.pending);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _FilterStatusChip(
                            label: 'Completed',
                            isSelected: _statuses.contains(
                              _TaskStatus.completed,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_statuses.contains(_TaskStatus.completed)) {
                                  _statuses.remove(_TaskStatus.completed);
                                  return;
                                }
                                _statuses.add(_TaskStatus.completed);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 52),
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
                    const SizedBox(height: 8),
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
  const _EmptyTasksView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No tasks found',
        style: TextStyle(
          color: Color(0xFFC7C7C7),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
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
  const _TaskTile({required this.task, this.onTap});

  final _Task task;
  final VoidCallback? onTap;

  bool get _isCompleted => task.status == _TaskStatus.completed;

  @override
  Widget build(BuildContext context) {
    final markerColor = _isCompleted
        ? const Color(0xFF00B316)
        : const Color(0xFFFF8B2C);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 18, 14),
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
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isCompleted ? task.timeLabel : 'Due ${task.timeLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC7C7C7),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(status: task.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == _TaskStatus.completed;

    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF7CFF8A) : const Color(0xFFFFD59B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isCompleted ? 'Completed' : 'Pending',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isCompleted
              ? const Color(0xFF008F13)
              : const Color(0xFFFF8B2C),
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

enum _TaskStatus { pending, completed }

class _Task {
  const _Task({
    required this.title,
    required this.timeLabel,
    required this.dueAt,
    required this.status,
  });

  final String title;
  final String timeLabel;
  final DateTime dueAt;
  final _TaskStatus status;
}

class _TaskFilter {
  const _TaskFilter({
    this.statuses = const {},
    this.startDate,
    this.endDate,
    this.searchText = '',
  });

  final Set<_TaskStatus> statuses;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchText;
}

List<_Task> _tasksFor(UserRole role) {
  if (role == UserRole.qc) {
    return [
      _Task(
        title: 'Pump Station BR - Pump 67 Quality Review',
        timeLabel: '1/5/2026 9:00 pm',
        dueAt: DateTime(2026, 5, 1, 21),
        status: _TaskStatus.completed,
      ),
      _Task(
        title: 'Recycling Station AI - Shredder Audit',
        timeLabel: '2/5/2026 3:00 pm',
        dueAt: DateTime(2026, 5, 2, 15),
        status: _TaskStatus.completed,
      ),
      _Task(
        title: 'Assembly Station N - Robot Arm 101 Validation',
        timeLabel: '15/5/2026 9:00 am',
        dueAt: DateTime(2026, 5, 15, 9),
        status: _TaskStatus.pending,
      ),
      _Task(
        title: 'Validation Station O - Laser Machine Quality Check',
        timeLabel: '30/5/2026 2:00 pm',
        dueAt: DateTime(2026, 5, 30, 14),
        status: _TaskStatus.pending,
      ),
    ];
  }

  return [
    _Task(
      title: 'Pump Station BR - Pump 67 Inspection',
      timeLabel: '1/5/2026 9:00 pm',
      dueAt: DateTime(2026, 5, 1, 21),
      status: _TaskStatus.completed,
    ),
    _Task(
      title: 'Recycling Station AI - Shredder Inspection',
      timeLabel: '2/5/2026 3:00 pm',
      dueAt: DateTime(2026, 5, 2, 15),
      status: _TaskStatus.completed,
    ),
    _Task(
      title: 'Assembly Station N - Robot Arm 101 Inspection',
      timeLabel: '15/5/2026 9:00 am',
      dueAt: DateTime(2026, 5, 15, 9),
      status: _TaskStatus.pending,
    ),
    _Task(
      title: 'Cleaning Station R - Mop Inspection',
      timeLabel: '18/5/2026 11:00 am',
      dueAt: DateTime(2026, 5, 18, 11),
      status: _TaskStatus.completed,
    ),
    _Task(
      title: 'Validation Station O - Laser Machine Inspection',
      timeLabel: '30/5/2026 2:00 pm',
      dueAt: DateTime(2026, 5, 30, 14),
      status: _TaskStatus.pending,
    ),
    _Task(
      title: 'Tung Tung Station T - Tire Inspection',
      timeLabel: '2/6/2026 10:30 am',
      dueAt: DateTime(2026, 6, 2, 10, 30),
      status: _TaskStatus.pending,
    ),
  ];
}

