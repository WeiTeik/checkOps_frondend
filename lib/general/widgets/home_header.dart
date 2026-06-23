part of '../home_page.dart';

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.title,
    required this.role,
    required this.displayName,
    required this.profilePic,
    required this.showAccountActions,
    this.onBack,
    this.onTaskEdit,
    this.onTaskDelete,
  });

  final String title;
  final UserRole role;
  final String displayName;
  final String? profilePic;
  final bool showAccountActions;
  final VoidCallback? onBack;
  final VoidCallback? onTaskEdit;
  final VoidCallback? onTaskDelete;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFor(displayName);
    final showTaskActions = onTaskEdit != null || onTaskDelete != null;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF474747),
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8), width: 1)),
      ),
      child: SizedBox(
        height: 68,
        child: onBack != null
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    left: 56,
                    right: 56,
                    child: Center(child: _HeaderTitle(title: title)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      iconSize: 32,
                    ),
                  ),
                  if (showTaskActions)
                    Align(
                      alignment: Alignment.centerRight,
                      child: _TaskActionsMenu(
                        onTaskEdit: onTaskEdit,
                        onTaskDelete: onTaskDelete,
                      ),
                    ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _HeaderTitle(title: title, alignLeft: true),
                    ),
                    if (showAccountActions) ...[
                      _RoleChip(role: role),
                      const SizedBox(width: 10),
                      _HeaderProfileAvatar(
                        initials: initials,
                        profilePic: profilePic,
                      ),
                    ],
                  ],
                ),
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

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.title, this.alignLeft = false});

  final String title;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: alignLeft ? TextAlign.start : TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _TaskActionsMenu extends StatelessWidget {
  const _TaskActionsMenu({this.onTaskEdit, this.onTaskDelete});

  final VoidCallback? onTaskEdit;
  final VoidCallback? onTaskDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Task actions',
      color: const Color(0xFF303030),
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
      onSelected: (value) {
        if (value == 'edit') {
          onTaskEdit?.call();
          return;
        }
        if (onTaskDelete != null) {
          onTaskDelete?.call();
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: 'edit',
            enabled: onTaskEdit != null,
            child: const Text('Edit', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuItem(
            value: 'delete',
            enabled: onTaskDelete != null,
            child: Text(
              'Delete',
              style: TextStyle(
                color: onTaskDelete == null
                    ? const Color(0xFF777777)
                    : Colors.white,
              ),
            ),
          ),
        ];
      },
    );
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
    final style = _roleBadgeStyle(role);

    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        style.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: style.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
