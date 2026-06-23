part of '../home_page.dart';

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
    this.onNotificationSettingChanged,
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
  final Future<void> Function()? onNotificationSettingChanged;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  static const _storage = FlutterSecureStorage();
  final _userApi = UserApi();
  final _imagePicker = ImagePicker();

  bool _notificationsEnabled = true;
  bool _isLoggingOut = false;
  bool _isRefreshing = false;
  bool _isUploadingProfilePic = false;

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
    if (widget.isActive && !oldWidget.isActive) {
      _refreshProfile();
    }
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final value = await _storage.read(
        key: LocalNotificationService.enabledStorageKey,
      );
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
      if (value) {
        final permitted = await LocalNotificationService.instance
            .requestPermission();
        if (!permitted) {
          if (mounted) {
            setState(() => _notificationsEnabled = false);
          }
          await _storage.write(
            key: LocalNotificationService.enabledStorageKey,
            value: 'false',
          );
          return;
        }
      }
      await _storage.write(
        key: LocalNotificationService.enabledStorageKey,
        value: value.toString(),
      );
      if (!value) {
        await LocalNotificationService.instance.cancelUserReminders(
          widget.userId,
        );
      } else {
        await widget.onNotificationSettingChanged?.call();
      }
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
      final user = await _userApi.getUser(
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
  }

  Future<void> _openProfileImageOptions() async {
    if (_isUploadingProfilePic) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF303030),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Take photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _pickAndUploadProfileImage(source);
  }

  Future<void> _pickAndUploadProfileImage(ImageSource source) async {
    final pickedImage = await _imagePicker.pickImage(
      source: source,
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
    final profilePic = 'data:image/$extension;base64,${base64Encode(bytes)}';

    setState(() => _isUploadingProfilePic = true);
    try {
      final user = await _userApi.updateUser(
        userId: widget.userId,
        accessToken: widget.accessToken,
        profilePic: profilePic,
      );
      await _applyUser(user);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePic = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() => _isLoggingOut = true);
    try {
      await LocalNotificationService.instance.cancelUserReminders(
        widget.userId,
      );
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
        const SizedBox(height: 32),
        Center(
          child: _ProfileAvatar(
            displayName: widget.displayName,
            profilePic: widget.profilePic,
            isUploading: _isUploadingProfilePic,
            onPickImage: _openProfileImageOptions,
          ),
        ),
        const SizedBox(height: 6),
        _ProfileField(label: 'Name', value: widget.displayName),
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
    required this.isUploading,
    required this.onPickImage,
  });

  final String displayName;
  final String? profilePic;
  final bool isUploading;
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
            color: Color(0xFF97DBFF),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child:
              image ??
              Center(
                child: Text(
                  _initialsFor(displayName),
                  style: const TextStyle(
                    color: Color(0xFF078DFF),
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
        ),
        Positioned(
          right: 6,
          bottom: 8,
          child: IconButton.filled(
            onPressed: isUploading ? null : onPickImage,
            tooltip: 'Change profile picture',
            icon: isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.camera_alt_rounded),
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
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

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
          child: Container(
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
    final style = _roleBadgeStyle(role);

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
            color: style.background,
            borderRadius: BorderRadius.circular(8),
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
        ),
      ],
    );
  }
}
