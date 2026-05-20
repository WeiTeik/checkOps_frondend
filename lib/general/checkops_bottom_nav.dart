import 'package:flutter/material.dart';

class CheckOpsBottomNav extends StatelessWidget {
  const CheckOpsBottomNav({
    super.key,
    required this.isAdmin,
    required this.currentIndex,
    required this.onChanged,
  });

  final bool isAdmin;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = isAdmin
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_rounded),
              label: 'Users',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.check_box_outlined),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ];

    return Transform.translate(
      offset: const Offset(0, 16),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onChanged,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF474747),
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color(0xFFC7C7C7),
          selectedLabelStyle: const TextStyle(fontSize: 11, letterSpacing: 0),
          unselectedLabelStyle: const TextStyle(fontSize: 11, letterSpacing: 0),
          iconSize: 25,
          enableFeedback: false,
          items: items,
        ),
      ),
    );
  }
}
