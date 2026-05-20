import 'package:flutter/foundation.dart';
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
    final rawBottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPadding = switch (defaultTargetPlatform) {
      TargetPlatform.android => rawBottomPadding < 12 ? 12.0 : rawBottomPadding,
      TargetPlatform.iOS => rawBottomPadding.clamp(10.0, 24.0).toDouble(),
      _ => rawBottomPadding,
    };
    final items = isAdmin
        ? const <_BottomNavItem>[
            _BottomNavItem(
              icon: Icon(Icons.show_chart_rounded),
              label: 'Overview',
            ),
            _BottomNavItem(icon: Icon(Icons.groups_rounded), label: 'Users'),
            _BottomNavItem(
              icon: Icon(Icons.check_box_outlined),
              label: 'Tasks',
            ),
            _BottomNavItem(icon: Icon(Icons.history_rounded), label: 'History'),
            _BottomNavItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ]
        : const <_BottomNavItem>[
            _BottomNavItem(
              icon: Icon(Icons.check_box_outlined),
              label: 'Tasks',
            ),
            _BottomNavItem(icon: Icon(Icons.history_rounded), label: 'History'),
            _BottomNavItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ];
    final iconSize = isAdmin ? 22.0 : 25.0;

    return Material(
      color: const Color(0xFF474747),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFB8B8B8)),
          SizedBox(
            height: 63,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _BottomNavButton(
                      item: items[index],
                      iconSize: iconSize,
                      isSelected: index == currentIndex,
                      onTap: () => onChanged(index),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({required this.icon, required this.label});

  final Icon icon;
  final String label;
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.iconSize,
    required this.isSelected,
    required this.onTap,
  });

  final _BottomNavItem item;
  final double iconSize;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : const Color(0xFFC7C7C7);

    return InkResponse(
      onTap: onTap,
      containedInkWell: true,
      highlightShape: BoxShape.rectangle,
      radius: 28,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: color, size: iconSize),
              child: item.icon,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
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
