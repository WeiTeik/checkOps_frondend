part of '../general/home_page.dart';

class _AdminUsersView extends StatefulWidget {
  const _AdminUsersView({required this.accessToken, required this.isActive});

  final String accessToken;
  final bool isActive;

  @override
  State<_AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<_AdminUsersView> {
  final _userApi = UserApi();
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
      final users = await _userApi.getUsers(
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

  Future<void> _openAddUser() async {
    final createdUser = await showGeneralDialog<_AdminUser>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierDismissible: true,
      barrierLabel: 'Close add user',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AddAdminUserDialog(accessToken: widget.accessToken);
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

    if (createdUser == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${createdUser.name} has been added.')),
    );
    await _loadUsers();
  }

  Future<void> _openUserDetails(_AdminUser user) async {
    var currentUser = user;

    while (mounted) {
      final userToEdit = await _showUserDetails(currentUser);
      if (userToEdit == null || !mounted) {
        return;
      }

      final updatedUser = await _openEditUser(userToEdit);
      if (updatedUser == null || !mounted) {
        currentUser = userToEdit;
        continue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updatedUser.name} has been updated.')),
      );
      await _loadUsers();
      currentUser = _latestUserById(updatedUser.id) ?? updatedUser;
    }
  }

  Future<_AdminUser?> _showUserDetails(_AdminUser user) {
    return showGeneralDialog<_AdminUser>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierDismissible: true,
      barrierLabel: 'Close user details',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AdminUserDetailsDialog(
          user: user,
          assignedQcName: _assignedQcNameFor(user),
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
  }

  Future<_AdminUser?> _openEditUser(_AdminUser user) {
    return showGeneralDialog<_AdminUser>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierDismissible: true,
      barrierLabel: 'Close edit user',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _EditAdminUserDialog(
          accessToken: widget.accessToken,
          user: user,
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
  }

  String? _assignedQcNameFor(_AdminUser user) {
    final qcId = user.qcId;
    if (qcId == null) {
      return null;
    }

    for (final candidate in _users) {
      if (candidate.id == qcId) {
        return candidate.name;
      }
    }
    return 'QC #$qcId';
  }

  _AdminUser? _latestUserById(int userId) {
    for (final user in _users) {
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdminUsersSectionHeader(
          onAddUser: _openAddUser,
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
          return _AdminUserTile(
            user: _users[index],
            onPressed: () => _openUserDetails(_users[index]),
          );
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
