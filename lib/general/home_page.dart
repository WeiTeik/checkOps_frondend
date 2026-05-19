import 'package:flutter/material.dart';

import 'checkops_bottom_nav.dart';

enum UserRole { operator, qc, admin }

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.role, required this.displayName});

  final UserRole role;
  final String displayName;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  bool get _isAdmin => widget.role == UserRole.admin;

  String get _headerTitle {
    if (_isAdmin) {
      return switch (_selectedIndex) {
        0 => 'Dashboard',
        1 => 'Users',
        2 => 'Reports',
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
    return Scaffold(
      backgroundColor: const Color(0xFF474747),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(
              title: _headerTitle,
              role: widget.role,
              displayName: widget.displayName,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _isAdmin
                    ? const [
                        _AdminDashboardView(),
                        _PlaceholderView(
                          icon: Icons.groups_rounded,
                          title: 'Users',
                        ),
                        _PlaceholderView(
                          icon: Icons.analytics_rounded,
                          title: 'Reports',
                        ),
                        _PlaceholderView(
                          icon: Icons.person_rounded,
                          title: 'Profile',
                        ),
                      ]
                    : [
                        _TaskHomeView(role: widget.role),
                        const _PlaceholderView(
                          icon: Icons.history_rounded,
                          title: 'History',
                        ),
                        const _PlaceholderView(
                          icon: Icons.person_rounded,
                          title: 'Profile',
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
        onChanged: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.title,
    required this.role,
    required this.displayName,
  });

  final String title;
  final UserRole role;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFor(displayName);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF474747),
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8), width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            _RoleChip(role: role),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF97DBFF),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF078DFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initialsFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return 'U';
    }
    if (words.length == 1) {
      return words.first.characters.take(2).toString().toUpperCase();
    }
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF97DBFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _roleLabel(role),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF078DFF),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.operator => 'Operator',
      UserRole.qc => 'QC',
      UserRole.admin => 'Admin',
    };
  }
}

class _TaskHomeView extends StatefulWidget {
  const _TaskHomeView({required this.role});

  final UserRole role;

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
              const Center(
                child: Text(
                  'Tasks List',
                  style: TextStyle(
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
                  padding: EdgeInsets.zero,
                  itemCount: tasks.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1.5,
                    color: Color(0xFFB8B8B8),
                  ),
                  itemBuilder: (context, index) =>
                      _TaskTile(task: tasks[index]),
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
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 18, 34, 24),
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
                    const Spacer(),
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
            ),
          ],
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
  const _SearchFilterField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Colors.black, fontSize: 16),
      cursorColor: Colors.black,
      decoration: const InputDecoration(
        filled: true,
        fillColor: Color(0xFFD9D9D9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        suffixIcon: Icon(Icons.search_rounded, color: Colors.black, size: 28),
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
  const _TaskTile({required this.task});

  final _Task task;

  bool get _isCompleted => task.status == _TaskStatus.completed;

  @override
  Widget build(BuildContext context) {
    final markerColor = _isCompleted
        ? const Color(0xFF00B316)
        : const Color(0xFFFF8B2C);

    return InkWell(
      onTap: () {},
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

class _AdminDashboardView extends StatelessWidget {
  const _AdminDashboardView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      children: const [
        Row(
          children: [
            Expanded(
              child: _AdminMetricCard(
                icon: Icons.assignment_turned_in_rounded,
                value: '17',
                label: 'Active Tasks',
                color: Color(0xFF97DBFF),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _AdminMetricCard(
                icon: Icons.groups_rounded,
                value: '24',
                label: 'Users',
                color: Color(0xFF7CFF8A),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AdminMetricCard(
                icon: Icons.warning_amber_rounded,
                value: '5',
                label: 'Pending QC',
                color: Color(0xFFFFD59B),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _AdminMetricCard(
                icon: Icons.fact_check_rounded,
                value: '12',
                label: 'Completed',
                color: Color(0xFFD2B5FF),
              ),
            ),
          ],
        ),
        SizedBox(height: 22),
        _AdminSectionHeader(title: 'Operations'),
        SizedBox(height: 12),
        _AdminActionTile(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Manage Users',
          subtitle: 'Create operators, QC users, and administrators',
        ),
        _AdminActionTile(
          icon: Icons.playlist_add_check_rounded,
          title: 'Assign Tasks',
          subtitle: 'Schedule inspections and station checks',
        ),
        _AdminActionTile(
          icon: Icons.bar_chart_rounded,
          title: 'Review Reports',
          subtitle: 'Track completion status and quality findings',
        ),
      ],
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSectionHeader extends StatelessWidget {
  const _AdminSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF97DBFF), size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC7C7C7),
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white70,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFC7C7C7), size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
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

UserRole userRoleFromValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'admin' || 'administrator' => UserRole.admin,
    'qc' || 'quality control' || 'quality_control' => UserRole.qc,
    _ => UserRole.operator,
  };
}
