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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF474747),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(
              title: _isAdmin ? 'Dashboard' : 'My Tasks',
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

class _TaskHomeView extends StatelessWidget {
  const _TaskHomeView({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final tasks = _tasksFor(role);
    final pendingCount = tasks
        .where((task) => task.status == _TaskStatus.pending)
        .length;
    final completedCount = tasks
        .where((task) => task.status == _TaskStatus.completed)
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
          child: Row(
            children: [
              Expanded(
                child: _StatusSummaryCard(
                  value: pendingCount,
                  label: 'Pending',
                  color: const Color(0xFFFF8B2C),
                ),
              ),
              const SizedBox(width: 24),
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
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              const Spacer(),
              const Text(
                'Tasks List',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                tooltip: 'Filter tasks',
                icon: const Icon(Icons.filter_list_rounded),
                color: Colors.white,
                iconSize: 21,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 1.5,
              color: Color(0xFFB8B8B8),
            ),
            itemBuilder: (context, index) => _TaskTile(task: tasks[index]),
          ),
        ),
      ],
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
      aspectRatio: 1.14,
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
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
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
    required this.status,
  });

  final String title;
  final String timeLabel;
  final _TaskStatus status;
}

List<_Task> _tasksFor(UserRole role) {
  if (role == UserRole.qc) {
    return const [
      _Task(
        title: 'Pump Station BR - Pump 67 Quality Review',
        timeLabel: '1/5/2026 9:00 pm',
        status: _TaskStatus.completed,
      ),
      _Task(
        title: 'Recycling Station AI - Shredder Audit',
        timeLabel: '2/5/2026 3:00 pm',
        status: _TaskStatus.completed,
      ),
      _Task(
        title: 'Assembly Station N - Robot Arm 101 Validation',
        timeLabel: '15/5/2026 9:00 am',
        status: _TaskStatus.pending,
      ),
      _Task(
        title: 'Validation Station O - Laser Machine Quality Check',
        timeLabel: '30/5/2026 2:00 pm',
        status: _TaskStatus.pending,
      ),
    ];
  }

  return const [
    _Task(
      title: 'Pump Station BR - Pump 67 Inspection',
      timeLabel: '1/5/2026 9:00 pm',
      status: _TaskStatus.completed,
    ),
    _Task(
      title: 'Recycling Station AI - Shredder Inspection',
      timeLabel: '2/5/2026 3:00 pm',
      status: _TaskStatus.completed,
    ),
    _Task(
      title: 'Assembly Station N - Robot Arm 101 Inspection',
      timeLabel: '15/5/2026 9:00 am',
      status: _TaskStatus.pending,
    ),
    _Task(
      title: 'Cleaning Station R - Mop Inspection',
      timeLabel: '18/5/2026 11:00 am',
      status: _TaskStatus.completed,
    ),
    _Task(
      title: 'Validation Station O - Laser Machine Inspection',
      timeLabel: '30/5/2026 2:00 pm',
      status: _TaskStatus.pending,
    ),
    _Task(
      title: 'Tung Tung Station T - Tire Inspection',
      timeLabel: '2/6/2026 10:30 am',
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
