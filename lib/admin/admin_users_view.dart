part of '../general/home_page.dart';

class _AdminUsersView extends StatefulWidget {
  const _AdminUsersView({required this.accessToken, required this.isActive});

  final String accessToken;
  final bool isActive;

  @override
  State<_AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<_AdminUsersView> {
  final _authApi = AuthApi();
  var _users = <_AdminUser>[];
  _AdminUserFilter _filter = const _AdminUserFilter();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void didUpdateWidget(covariant _AdminUsersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    if (widget.accessToken.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _authApi.getUsers(
        accessToken: widget.accessToken,
        search: _filter.searchText,
        roles: _filter.roles.map((role) => role.backendValue).toList(),
        active: _filter.isActive,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users.map(_AdminUser.fromJson).toList();
      });
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature coming soon.')));
  }

  Future<void> _openFilter() async {
    final nextFilter = await showGeneralDialog<_AdminUserFilter>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierDismissible: true,
      barrierLabel: 'Close filter',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AdminUserFilterDialog(initialFilter: _filter);
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

    if (nextFilter == null) {
      return;
    }

    setState(() => _filter = nextFilter);
    await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdminUsersSectionHeader(
          onAddUser: () => _showComingSoon('Add user'),
          onFilter: _openFilter,
        ),
        Expanded(child: _buildUsersContent()),
      ],
    );
  }

  Widget _buildUsersContent() {
    if (_isLoading && _users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8EDCFF)),
      );
    }

    if (_errorMessage != null && _users.isEmpty) {
      return _AdminUsersMessage(
        icon: Icons.error_outline_rounded,
        message: _errorMessage!,
        onRetry: _loadUsers,
      );
    }

    if (_users.isEmpty) {
      return _AdminUsersMessage(
        icon: Icons.groups_rounded,
        message: 'No users found.',
        onRetry: _loadUsers,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF67D8FF),
      backgroundColor: const Color(0xFF303030),
      onRefresh: _loadUsers,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: _users.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, thickness: 1, color: Color(0xFF5E5E5E)),
        itemBuilder: (context, index) {
          return _AdminUserTile(user: _users[index]);
        },
      ),
    );
  }
}

class _AdminUsersSectionHeader extends StatelessWidget {
  const _AdminUsersSectionHeader({
    required this.onAddUser,
    required this.onFilter,
  });

  final VoidCallback onAddUser;
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
            child: IconButton(
              onPressed: onAddUser,
              tooltip: 'Add user',
              icon: const Icon(Icons.add_rounded),
              color: Colors.white,
              iconSize: 24,
            ),
          ),
          const Center(
            child: Text(
              'Users List',
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
            child: IconButton(
              onPressed: onFilter,
              tooltip: 'Filter users',
              icon: const Icon(Icons.filter_list_rounded),
              color: Colors.white,
              iconSize: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserFilterDialog extends StatefulWidget {
  const _AdminUserFilterDialog({required this.initialFilter});

  final _AdminUserFilter initialFilter;

  @override
  State<_AdminUserFilterDialog> createState() => _AdminUserFilterDialogState();
}

class _AdminUserFilterDialogState extends State<_AdminUserFilterDialog> {
  late final Set<_AdminFilterRole> _roles = {...widget.initialFilter.roles};
  late bool? _isActive = widget.initialFilter.isActive;
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialFilter.searchText,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).pop(
      _AdminUserFilter(
        roles: _roles,
        isActive: _isActive,
        searchText: _searchController.text,
      ),
    );
  }

  void _clear() {
    Navigator.of(context).pop(const _AdminUserFilter());
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
                      'Filter By Role',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminFilterChip(
                            label: 'Admin',
                            isSelected: _roles.contains(_AdminFilterRole.admin),
                            onPressed: () =>
                                _toggleRole(_AdminFilterRole.admin),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AdminFilterChip(
                            label: 'Operator',
                            isSelected: _roles.contains(
                              _AdminFilterRole.operator,
                            ),
                            onPressed: () =>
                                _toggleRole(_AdminFilterRole.operator),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AdminFilterChip(
                            label: 'QC',
                            isSelected: _roles.contains(_AdminFilterRole.qc),
                            onPressed: () => _toggleRole(_AdminFilterRole.qc),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Filter By Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminFilterChip(
                            label: 'Active',
                            isSelected: _isActive == true,
                            onPressed: () => setState(() {
                              _isActive = _isActive == true ? null : true;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AdminFilterChip(
                            label: 'Inactive',
                            isSelected: _isActive == false,
                            onPressed: () => setState(() {
                              _isActive = _isActive == false ? null : false;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const _FilterFieldLabel(text: 'Search'),
                    const SizedBox(height: 10),
                    _SearchFilterField(
                      controller: _searchController,
                      hintText: 'Search by Name',
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
                            label: 'Clear',
                            onPressed: _clear,
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

  void _toggleRole(_AdminFilterRole role) {
    setState(() {
      if (_roles.contains(role)) {
        _roles.remove(role);
        return;
      }
      _roles.add(role);
    });
  }
}

class _AdminFilterChip extends StatelessWidget {
  const _AdminFilterChip({
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminUsersMessage extends StatelessWidget {
  const _AdminUsersMessage({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
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
            Icon(icon, color: const Color(0xFFC7C7C7), size: 34),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserTile extends StatelessWidget {
  const _AdminUserTile({required this.user});

  final _AdminUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: const Color(0xFF3F3F3F),
      child: Row(
        children: [
          _AdminUserAvatar(user: user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                _UserActiveState(isActive: user.isActive),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _UserRoleBadge(role: user.role),
        ],
      ),
    );
  }
}

class _AdminUserAvatar extends StatelessWidget {
  const _AdminUserAvatar({required this.user});

  final _AdminUser user;

  @override
  Widget build(BuildContext context) {
    final image = _profileImage(user.profilePic);

    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFF97DBFF),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          image ??
          Center(
            child: Text(
              user.initials,
              style: const TextStyle(
                color: Color(0xFF078DFF),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
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

class _UserActiveState extends StatelessWidget {
  const _UserActiveState({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF7CFF8A) : const Color(0xFFFF5C5C);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          isActive ? 'Active' : 'Inactive',
          style: const TextStyle(
            color: Color(0xFFCFCFCF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _UserRoleBadge extends StatelessWidget {
  const _UserRoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final style = _roleBadgeStyle(role);

    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        style.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: style.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AdminUser {
  const _AdminUser({
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.profilePic,
  });

  final String name;
  final String email;
  final UserRole role;
  final bool isActive;
  final String? profilePic;

  String get initials {
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

  static _AdminUser fromJson(Map<String, dynamic> json) {
    final email = json['email']?.toString() ?? '';
    return _AdminUser(
      name: json['name']?.toString() ?? email,
      email: email,
      role: userRoleFromValue(json['role']),
      isActive: json['active'] == true,
      profilePic:
          json['profile_pic']?.toString() ?? json['profilePic']?.toString(),
    );
  }
}

enum _AdminFilterRole {
  admin('Admin'),
  operator('Operator'),
  qc('QC');

  const _AdminFilterRole(this.backendValue);

  final String backendValue;
}

class _AdminUserFilter {
  const _AdminUserFilter({
    this.roles = const {},
    this.isActive,
    this.searchText = '',
  });

  final Set<_AdminFilterRole> roles;
  final bool? isActive;
  final String searchText;
}
