import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../authentication/auth_api.dart';
import 'checkops_bottom_nav.dart';

enum UserRole { operator, qc, admin }

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

  bool get _isAdmin => _role == UserRole.admin;

  String get _headerTitle {
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
    return Scaffold(
      backgroundColor: const Color(0xFF474747),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(
              title: _headerTitle,
              role: _role,
              displayName: _displayName,
              profilePic: _profilePic,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _isAdmin
                    ? [
                        const _AdminDashboardView(),
                        const _PlaceholderView(
                          icon: Icons.groups_rounded,
                          title: 'Users',
                        ),
                        const _PlaceholderView(
                          icon: Icons.check_box_outlined,
                          title: 'Tasks',
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
                        _TaskHomeView(role: _role),
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
        onChanged: (index) => setState(() => _selectedIndex = index),
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
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.title,
    required this.role,
    required this.displayName,
    required this.profilePic,
  });

  final String title;
  final UserRole role;
  final String displayName;
  final String? profilePic;

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
            _HeaderProfileAvatar(initials: initials, profilePic: profilePic),
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

class _HeaderProfileAvatar extends StatelessWidget {
  const _HeaderProfileAvatar({
    required this.initials,
    required this.profilePic,
  });

  final String initials;
  final String? profilePic;

  @override
  Widget build(BuildContext context) {
    final image = _profileImage(profilePic);

    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF97DBFF),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          image ??
          Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Color(0xFF078DFF),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
    );
  }

  Widget? _profileImage(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.startsWith('data:image/')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) {
        return null;
      }
      return Image.memory(
        base64Decode(value.substring(commaIndex + 1)),
        key: ValueKey(value),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    return Image.network(
      value,
      key: ValueKey(value),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
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
      padding: EdgeInsets.zero,
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AdminMetricCard(
                      value: '3',
                      label: 'Pending',
                      color: Color(0xFFFF8B2C),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: _AdminMetricCard(
                      value: '2',
                      label: 'Completed',
                      color: Color(0xFF00B316),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: _AdminMetricCard(
                      value: '1',
                      label: 'Failed',
                      color: Color(0xFFFF1E1E),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AdminMetricCard(
                      value: '3',
                      label: 'Approved',
                      color: Color(0xFF00B316),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: _AdminMetricCard(
                      value: '2',
                      label: 'Rejected',
                      color: Color(0xFFFF1E1E),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: _AdminMetricCard(
                      value: '1',
                      label: 'Expired',
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _AdminOverviewHeader(),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: _AdminChartCard(
            axisLabel: 'Submission',
            title: 'Operator Task Submission',
            accentColor: Color(0xFF67D8FF),
            values: [0, 2, 1, 3.5, 2.8, 1, 4.2, 0, 1.8],
          ),
        ),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: _AdminChartCard(
            axisLabel: 'Reviews',
            title: 'Tasks Reviewed by QC',
            accentColor: Color(0xFF7CFF8A),
            values: [0, 2, 1, 3.5, 2.8, 1, 4.2, 0, 1.8],
          ),
        ),
        SizedBox(height: 30),
      ],
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF303030),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminOverviewHeader extends StatelessWidget {
  const _AdminOverviewHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      color: const Color(0xFF303030),
      alignment: Alignment.center,
      child: const Text(
        'Operation Overview',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AdminChartCard extends StatefulWidget {
  const _AdminChartCard({
    required this.axisLabel,
    required this.title,
    required this.accentColor,
    required this.values,
  });

  final String axisLabel;
  final String title;
  final Color accentColor;
  final List<double> values;

  @override
  State<_AdminChartCard> createState() => _AdminChartCardState();
}

class _AdminChartCardState extends State<_AdminChartCard> {
  int? _activePointIndex;

  void _setActivePoint(Offset position, Size size) {
    final nextIndex = _nearestPointIndex(position, size);
    if (nextIndex == _activePointIndex) {
      return;
    }
    setState(() => _activePointIndex = nextIndex);
  }

  void _clearActivePoint() {
    if (_activePointIndex == null) {
      return;
    }
    setState(() => _activePointIndex = null);
  }

  int? _nearestPointIndex(Offset position, Size size) {
    if (widget.values.length < 2) {
      return null;
    }

    final plotRect = _AdminLineChartPainter.plotRectFor(size);
    if (!plotRect.inflate(14).contains(position)) {
      return null;
    }

    final chartWidth = plotRect.width;
    final chartHeight = plotRect.height;
    final originY = plotRect.bottom;
    var nearestIndex = 0;
    var nearestDistance = double.infinity;

    for (var index = 0; index < widget.values.length; index += 1) {
      final x =
          plotRect.left + (index / (widget.values.length - 1)) * chartWidth;
      final y = originY - (widget.values[index] / 4.5) * chartHeight;
      final distance = (Offset(x, y) - position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestDistance <= 24 ? nearestIndex : null;
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => _clearActivePoint(),
      child: Container(
        height: 176,
        padding: const EdgeInsets.fromLTRB(12, 11, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF303030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3B3B3B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              widget.axisLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chartSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onHover: (event) =>
                        _setActivePoint(event.localPosition, chartSize),
                    onExit: (_) => _clearActivePoint(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) =>
                          _setActivePoint(details.localPosition, chartSize),
                      child: CustomPaint(
                        painter: _AdminLineChartPainter(
                          values: widget.values,
                          accentColor: widget.accentColor,
                          activePointIndex: _activePointIndex,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLineChartPainter extends CustomPainter {
  const _AdminLineChartPainter({
    required this.values,
    required this.accentColor,
    required this.activePointIndex,
  });

  static const _leftInset = 26.0;
  static const _rightInset = 4.0;
  static const _bottomInset = 17.0;
  static const _topInset = 7.0;

  final List<double> values;
  final Color accentColor;
  final int? activePointIndex;

  static Rect plotRectFor(Size size) {
    return Rect.fromLTWH(
      _leftInset,
      _topInset,
      size.width - _leftInset - _rightInset,
      size.height - _topInset - _bottomInset,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = plotRectFor(size);
    final chartWidth = plotRect.width;
    final chartHeight = plotRect.height;
    final origin = Offset(plotRect.left, plotRect.bottom);
    final plotRRect = RRect.fromRectAndRadius(
      plotRect,
      const Radius.circular(7),
    );
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.26),
          accentColor.withValues(alpha: 0.03),
        ],
      ).createShader(plotRect);
    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.2;
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7;
    final pointPaint = Paint()..color = accentColor;
    final pointBorderPaint = Paint()..color = const Color(0xFF303030);
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    canvas.drawRRect(plotRRect, Paint()..color = const Color(0xFF292929));

    for (final tick in [1, 2, 3, 4]) {
      final y = origin.dy - (tick / 4.5) * chartHeight;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(size.width - 4, y),
        gridPaint,
      );
    }

    for (var index = 1; index < values.length - 1; index += 2) {
      final x = plotRect.left + (index / (values.length - 1)) * chartWidth;
      canvas.drawLine(Offset(x, plotRect.top), Offset(x, origin.dy), gridPaint);
    }

    canvas.drawLine(Offset(plotRect.left, plotRect.top), origin, axisPaint);
    canvas.drawLine(origin, Offset(size.width - 4, origin.dy), axisPaint);

    for (final tick in [1, 2, 3]) {
      final y = origin.dy - (tick / 4.5) * chartHeight;
      labelPainter.text = TextSpan(
        text: tick.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout(minWidth: 12, maxWidth: 12);
      labelPainter.paint(canvas, Offset(4, y - labelPainter.height / 2));
    }

    if (values.length < 2) {
      return;
    }

    final points = <Offset>[];
    for (var index = 0; index < values.length; index += 1) {
      final x = plotRect.left + (index / (values.length - 1)) * chartWidth;
      final y = origin.dy - (values[index] / 4.5) * chartHeight;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index += 1) {
      path.lineTo(points[index].dx, points[index].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, origin.dy)
      ..lineTo(points.first.dx, origin.dy)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    if (activePointIndex case final activeIndex?
        when activeIndex >= 0 && activeIndex < points.length) {
      final point = points[activeIndex];
      final guidePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.34)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(point.dx, plotRect.top),
        Offset(point.dx, origin.dy),
        guidePaint,
      );
      canvas.drawCircle(point, 6.8, pointBorderPaint);
      canvas.drawCircle(point, 4, pointPaint);
      _paintTooltip(
        canvas: canvas,
        size: size,
        point: point,
        label: 'Point ${activeIndex + 1}',
        value: values[activeIndex],
      );
    }

    final monthLabels = ['W1', 'W2', 'W3'];
    for (var index = 0; index < monthLabels.length; index += 1) {
      final x = plotRect.left + (index / (monthLabels.length - 1)) * chartWidth;
      labelPainter.text = TextSpan(
        text: monthLabels[index],
        style: const TextStyle(
          color: Color(0xFFBDBDBD),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout();
      var labelX = x - labelPainter.width / 2;
      if (index == 0) {
        labelX = plotRect.left;
      } else if (index == monthLabels.length - 1) {
        labelX = size.width - 4 - labelPainter.width;
      } else {
        labelX = labelX.clamp(
          plotRect.left,
          size.width - 4 - labelPainter.width,
        );
      }
      labelPainter.paint(canvas, Offset(labelX, origin.dy + 5));
    }
  }

  void _paintTooltip({
    required Canvas canvas,
    required Size size,
    required Offset point,
    required String label,
    required double value,
  }) {
    final tooltipPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label\n',
            style: const TextStyle(
              color: Color(0xFFCFCFCF),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value.toStringAsFixed(
              value.truncateToDouble() == value ? 0 : 1,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout();
    final tooltipSize = Size(
      tooltipPainter.width + 16,
      tooltipPainter.height + 10,
    );
    var left = point.dx - tooltipSize.width / 2;
    var top = point.dy - tooltipSize.height - 12;
    left = left.clamp(2, size.width - tooltipSize.width - 2);
    if (top < 2) {
      top = point.dy + 12;
    }

    final tooltipRect = Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      tooltipSize.width,
      tooltipSize.height,
    );
    final tooltipRRect = RRect.fromRectAndRadius(
      tooltipRect,
      const Radius.circular(8),
    );
    canvas.drawRRect(tooltipRRect, Paint()..color = const Color(0xFF1F1F1F));
    canvas.drawRRect(
      tooltipRRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tooltipPainter.paint(canvas, Offset(left + 8, top + 5));
  }

  @override
  bool shouldRepaint(covariant _AdminLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.activePointIndex != activePointIndex;
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView({
    required this.isActive,
    required this.displayName,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.userId,
    required this.accessToken,
    this.profilePic,
    this.onLogout,
    this.loginBuilder,
    this.onProfileChanged,
  });

  final bool isActive;
  final String displayName;
  final String email;
  final String employeeId;
  final UserRole role;
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
  onProfileChanged;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  static const _notificationKey = 'profile_notifications_enabled';
  static const _storage = FlutterSecureStorage();
  final _authApi = AuthApi();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.displayName,
  );

  bool _notificationsEnabled = true;
  bool _isLoggingOut = false;
  bool _isEditing = false;
  bool _isRefreshing = false;
  bool _isSaving = false;
  String? _draftProfilePic;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
    if (widget.isActive) {
      _refreshProfile();
    }
  }

  @override
  void didUpdateWidget(covariant _ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.displayName != oldWidget.displayName) {
      _nameController.text = widget.displayName;
    }
    if (widget.isActive && !oldWidget.isActive) {
      _refreshProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final value = await _storage.read(key: _notificationKey);
      if (!mounted || value == null) {
        return;
      }
      setState(() => _notificationsEnabled = value != 'false');
    } on Object {
      // Keep notification enabled by default if local storage is unavailable.
    }
  }

  Future<void> _setNotificationSetting(bool value) async {
    setState(() => _notificationsEnabled = value);
    try {
      await _storage.write(key: _notificationKey, value: value.toString());
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save notification setting.')),
      );
    }
  }

  Future<void> _refreshProfile() async {
    if (_isRefreshing || widget.accessToken.isEmpty) {
      return;
    }

    setState(() => _isRefreshing = true);
    try {
      final user = await _authApi.getUser(
        userId: widget.userId,
        accessToken: widget.accessToken,
      );
      await _applyUser(user);
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _applyUser(Map<String, dynamic> user) async {
    final displayName = user['name']?.toString() ?? widget.displayName;
    final email = user['email']?.toString() ?? widget.email;
    final employeeId =
        user['employee_id']?.toString() ??
        user['employeeId']?.toString() ??
        widget.employeeId;
    final profilePic =
        user['profile_pic']?.toString() ??
        user['profilePic']?.toString() ??
        widget.profilePic;
    final role = userRoleFromValue(user['role'] ?? widget.role.name);

    await widget.onProfileChanged?.call(
      displayName: displayName,
      email: email,
      employeeId: employeeId,
      role: role,
      profilePic: profilePic,
    );

    if (!mounted || _isEditing) {
      return;
    }
    _nameController.text = displayName;
  }

  Future<void> _pickProfileImage() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (pickedImage == null) {
      return;
    }

    final bytes = await pickedImage.readAsBytes();
    final extension = pickedImage.name.toLowerCase().endsWith('.png')
        ? 'png'
        : 'jpeg';
    setState(() {
      _draftProfilePic = 'data:image/$extension;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = await _authApi.updateUser(
        userId: widget.userId,
        accessToken: widget.accessToken,
        name: name,
        profilePic: _draftProfilePic,
      );
      await _applyUser(user);
      if (!mounted) {
        return;
      }
      setState(() {
        _isEditing = false;
        _draftProfilePic = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _draftProfilePic = widget.profilePic;
      _nameController.text = widget.displayName;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _draftProfilePic = null;
      _nameController.text = widget.displayName;
    });
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout?.call();
      if (!mounted) {
        return;
      }
      final loginBuilder = widget.loginBuilder;
      if (loginBuilder == null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: loginBuilder),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: _isSaving
                ? null
                : (_isEditing ? _cancelEditing : _startEditing),
            tooltip: _isEditing ? 'Cancel edit' : 'Edit profile',
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded),
            color: Colors.white,
            iconSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: _ProfileAvatar(
            displayName: widget.displayName,
            profilePic: _isEditing ? _draftProfilePic : widget.profilePic,
            isEditing: _isEditing,
            onPickImage: _pickProfileImage,
          ),
        ),
        const SizedBox(height: 6),
        _ProfileField(
          label: 'Name',
          value: widget.displayName,
          controller: _nameController,
          isEditable: _isEditing,
        ),
        const SizedBox(height: 10),
        _ProfileField(label: 'Email', value: widget.email),
        const SizedBox(height: 10),
        _ProfileField(
          label: 'Employee ID',
          value: widget.employeeId.isEmpty ? '-' : widget.employeeId,
        ),
        const SizedBox(height: 22),
        _ProfileRoleRow(role: widget.role),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Notification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
            ),
            Switch(
              value: _notificationsEnabled,
              onChanged: _setNotificationSetting,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF8EDCFF),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFF7A7A7A),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (_isEditing) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _cancelEditing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1796D2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_isSaving ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _isLoggingOut ? null : _logout,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            backgroundColor: const Color(0xFFD94343),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _isLoggingOut ? 'Logging out...' : 'Logout',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Color(0xFF8EDCFF),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.displayName,
    required this.profilePic,
    required this.isEditing,
    required this.onPickImage,
  });

  final String displayName;
  final String? profilePic;
  final bool isEditing;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final image = _profileImage(profilePic);

    return Stack(
      children: [
        Container(
          width: 148,
          height: 148,
          decoration: const BoxDecoration(
            color: Color(0xFFD9D9D9),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child:
              image ??
              Center(
                child: Text(
                  _initialsFor(displayName),
                  style: const TextStyle(
                    color: Color(0xFF8F8F8F),
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
        ),
        if (isEditing)
          Positioned(
            right: 6,
            bottom: 8,
            child: IconButton.filled(
              onPressed: onPickImage,
              tooltip: 'Upload profile picture',
              icon: const Icon(Icons.camera_alt_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF1796D2),
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget? _profileImage(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.startsWith('data:image/')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) {
        return null;
      }
      return Image.memory(
        base64Decode(value.substring(commaIndex + 1)),
        key: ValueKey(value),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    return Image.network(
      value,
      key: ValueKey(value),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.value,
    this.controller,
    this.isEditable = false,
  });

  final String label;
  final String value;
  final TextEditingController? controller;
  final bool isEditable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 40,
          child: isEditable
              ? TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Color(0xFF202020)),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFFD9D9D9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      borderSide: BorderSide(color: Colors.white, width: 1.5),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                )
              : Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF202020),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProfileRoleRow extends StatelessWidget {
  const _ProfileRoleRow({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Role',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF97DBFF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _roleLabel(role),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF078DFF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
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
