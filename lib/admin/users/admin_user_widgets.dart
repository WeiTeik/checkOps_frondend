part of '../../general/home_page.dart';

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

class _AdminUserDetailsDialog extends StatelessWidget {
  const _AdminUserDetailsDialog({required this.user, this.assignedQcName});

  final _AdminUser user;
  final String? assignedQcName;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF474747),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close user details',
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  iconSize: 34,
                ),
              ),
              const SizedBox(height: 10),
              Center(child: _AdminUserAvatar(user: user, size: 88)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(child: _UserRoleBadge(role: user.role)),
              const SizedBox(height: 28),
              _UserDetailRow(
                icon: Icons.badge_rounded,
                label: 'Employee ID',
                value: user.employeeId.isEmpty ? '-' : user.employeeId,
              ),
              _UserDetailRow(
                icon: Icons.email_rounded,
                label: 'Email',
                value: user.email.isEmpty ? '-' : user.email,
              ),
              _UserDetailRow(
                icon: Icons.toggle_on_rounded,
                label: 'Status',
                value: user.isActive ? 'Active' : 'Inactive',
                valueColor: user.isActive
                    ? const Color(0xFF7CFF8A)
                    : const Color(0xFFFF9B9B),
              ),
              _UserDetailRow(
                icon: Icons.verified_user_rounded,
                label: 'Email Verification',
                value: user.isEmailVerified ? 'Verified' : 'Not verified',
                valueColor: user.isEmailVerified
                    ? const Color(0xFF7CFF8A)
                    : const Color(0xFFFFD166),
              ),
              if (user.role == UserRole.operator)
                _UserDetailRow(
                  icon: Icons.supervisor_account_rounded,
                  label: 'Assigned QC',
                  value: assignedQcName ?? '-',
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(user),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF67D8FF),
                    foregroundColor: const Color(0xFF003F59),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserDetailRow extends StatelessWidget {
  const _UserDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3F3F3F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5E5E5E)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8EDCFF), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFCFCFCF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserTile extends StatelessWidget {
  const _AdminUserTile({required this.user, required this.onPressed});

  final _AdminUser user;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF3F3F3F),
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCFCFCF),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminUserAvatar extends StatelessWidget {
  const _AdminUserAvatar({required this.user, this.size = 46});

  final _AdminUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = _profileImage(user.profilePic);

    return Container(
      width: size,
      height: size,
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
              style: TextStyle(
                color: const Color(0xFF078DFF),
                fontSize: size >= 70 ? 28 : 15,
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
    required this.id,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.isActive,
    required this.isEmailVerified,
    this.qcId,
    this.profilePic,
  });

  final int id;
  final String name;
  final String email;
  final String employeeId;
  final UserRole role;
  final bool isActive;
  final bool isEmailVerified;
  final int? qcId;
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
      id: _intFromJson(json['id']),
      name: json['name']?.toString() ?? email,
      email: email,
      employeeId:
          json['employee_id']?.toString() ??
          json['employeeId']?.toString() ??
          '',
      role: userRoleFromValue(json['role']),
      isActive: json['active'] == true,
      isEmailVerified:
          json['is_email_verified'] == true || json['isEmailVerified'] == true,
      qcId: _nullableIntFromJson(json['qc_id'] ?? json['qcId']),
      profilePic:
          json['profile_pic']?.toString() ?? json['profilePic']?.toString(),
    );
  }

  static int _intFromJson(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableIntFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}

extension _UserRoleBackendValue on UserRole {
  String get backendValue {
    return switch (this) {
      UserRole.admin => 'Admin',
      UserRole.operator => 'Operator',
      UserRole.qc => 'QC',
    };
  }

  String get roleLabel => _roleBadgeStyle(this).label;
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
