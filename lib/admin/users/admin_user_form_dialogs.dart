part of '../../general/home_page.dart';

class _AddAdminUserDialog extends StatefulWidget {
  const _AddAdminUserDialog({required this.accessToken});

  final String accessToken;

  @override
  State<_AddAdminUserDialog> createState() => _AddAdminUserDialogState();
}

class _AddAdminUserDialogState extends State<_AddAdminUserDialog> {
  final _userApi = UserApi();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeIdController = TextEditingController();
  var _role = UserRole.operator;
  var _qcUsers = <_AdminUser>[];
  _AdminUser? _selectedQc;
  bool _isLoadingQcs = true;
  bool _isSubmitting = false;
  String? _qcLoadError;
  String? _submitError;

  bool get _needsQcAssignment => _role == UserRole.operator;

  @override
  void initState() {
    super.initState();
    _loadQcUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _loadQcUsers() async {
    setState(() {
      _isLoadingQcs = true;
      _qcLoadError = null;
    });

    try {
      final users = await _userApi.getUsers(
        accessToken: widget.accessToken,
        roles: const ['QC'],
        active: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _qcUsers = users.map(_AdminUser.fromJson).toList();
      });
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _qcLoadError = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoadingQcs = false);
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitError = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = await _userApi.createUser(
        accessToken: widget.accessToken,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        role: _role.backendValue,
        qcId: _needsQcAssignment ? _selectedQc?.id : null,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_AdminUser.fromJson(user));
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitError = error.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
                28,
                18,
                28,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 42,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          tooltip: 'Close add user',
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                          disabledColor: const Color(0xFF8A8A8A),
                          iconSize: 34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Add User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _FilterFieldLabel(text: 'Name'),
                      const SizedBox(height: 8),
                      _AddUserTextField(
                        controller: _nameController,
                        hintText: 'Full name',
                        textInputAction: TextInputAction.next,
                        validator: _requiredValidator('Name'),
                      ),
                      const SizedBox(height: 18),
                      const _FilterFieldLabel(text: 'Email'),
                      const SizedBox(height: 8),
                      _AddUserTextField(
                        controller: _emailController,
                        hintText: 'user@company.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 18),
                      const _FilterFieldLabel(text: 'Employee ID'),
                      const SizedBox(height: 8),
                      _AddUserTextField(
                        controller: _employeeIdController,
                        hintText: 'Employee ID',
                        textInputAction: TextInputAction.next,
                        validator: _requiredValidator('Employee ID'),
                      ),
                      const SizedBox(height: 18),
                      const _FilterFieldLabel(text: 'Role'),
                      const SizedBox(height: 8),
                      _AddUserRoleDropdown(
                        value: _role,
                        onChanged: _isSubmitting
                            ? null
                            : (role) {
                                if (role == null) {
                                  return;
                                }
                                setState(() {
                                  _role = role;
                                  if (!_needsQcAssignment) {
                                    _selectedQc = null;
                                  }
                                  _submitError = null;
                                });
                              },
                      ),
                      if (_needsQcAssignment) ...[
                        const SizedBox(height: 18),
                        const _FilterFieldLabel(text: 'Assigned QC'),
                        const SizedBox(height: 8),
                        _QcAutocompleteField(
                          qcUsers: _qcUsers,
                          selectedQc: _selectedQc,
                          isLoading: _isLoadingQcs,
                          onSelected: (user) {
                            setState(() {
                              _selectedQc = user;
                              _submitError = null;
                            });
                          },
                          onTextChanged: (value) {
                            if (_selectedQc?.name != value) {
                              setState(() => _selectedQc = null);
                            }
                          },
                          validator: (_) {
                            if (_isLoadingQcs) {
                              return 'QC users are still loading.';
                            }
                            if (_qcLoadError != null) {
                              return _qcLoadError;
                            }
                            if (_selectedQc == null) {
                              return 'Select a QC user.';
                            }
                            return null;
                          },
                        ),
                        if (_qcLoadError != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _isLoadingQcs ? null : _loadQcUsers,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry QC list'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                      if (_submitError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _submitError!,
                          style: const TextStyle(
                            color: Color(0xFFFF9B9B),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                      const SizedBox(height: 34),
                      Row(
                        children: [
                          Expanded(
                            child: _FilterActionButton(
                              label: 'Cancel',
                              onPressed: _isSubmitting
                                  ? () {}
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _AddUserSubmitButton(
                              isSubmitting: _isSubmitting,
                              label: 'Add',
                              onPressed: _submit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  FormFieldValidator<String> _requiredValidator(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName is required.';
      }
      return null;
    };
  }

  String? _emailValidator(String? value) {
    final cleanedValue = value?.trim() ?? '';
    if (cleanedValue.isEmpty) {
      return 'Email is required.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanedValue)) {
      return 'Enter a valid email.';
    }
    return null;
  }
}

class _EditAdminUserDialog extends StatefulWidget {
  const _EditAdminUserDialog({required this.accessToken, required this.user});

  final String accessToken;
  final _AdminUser user;

  @override
  State<_EditAdminUserDialog> createState() => _EditAdminUserDialogState();
}

class _EditAdminUserDialogState extends State<_EditAdminUserDialog> {
  final _userApi = UserApi();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.name,
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.user.email,
  );
  late final TextEditingController _employeeIdController =
      TextEditingController(text: widget.user.employeeId);
  late UserRole _role = widget.user.role;
  late bool _isActive = widget.user.isActive;
  late bool _isEmailVerified = widget.user.isEmailVerified;
  var _qcUsers = <_AdminUser>[];
  _AdminUser? _selectedQc;
  bool _isLoadingQcs = true;
  bool _isSubmitting = false;
  String? _qcLoadError;
  String? _submitError;

  bool get _needsQcAssignment => _role == UserRole.operator;

  @override
  void initState() {
    super.initState();
    _loadQcUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _loadQcUsers() async {
    setState(() {
      _isLoadingQcs = true;
      _qcLoadError = null;
    });

    try {
      final users = await _userApi.getUsers(
        accessToken: widget.accessToken,
        roles: const ['QC'],
        active: true,
      );
      if (!mounted) {
        return;
      }
      final qcUsers = users.map(_AdminUser.fromJson).toList();
      setState(() {
        _qcUsers = qcUsers;
        final assignedQcId = widget.user.qcId;
        if (assignedQcId != null) {
          for (final qcUser in qcUsers) {
            if (qcUser.id == assignedQcId) {
              _selectedQc = qcUser;
              break;
            }
          }
        }
      });
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _qcLoadError = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoadingQcs = false);
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitError = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = await _userApi.updateUser(
        userId: widget.user.id,
        accessToken: widget.accessToken,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        role: _role.backendValue,
        qcId: _needsQcAssignment ? _selectedQc?.id : null,
        active: _isActive,
        isEmailVerified: _isEmailVerified,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_AdminUser.fromJson(user));
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitError = error.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
                28,
                18,
                28,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 42,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          tooltip: 'Close edit user',
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                          disabledColor: const Color(0xFF8A8A8A),
                          iconSize: 34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Edit User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _FilterFieldLabel(text: 'Name'),
                      const SizedBox(height: 8),
                      _AddUserTextField(
                        controller: _nameController,
                        hintText: 'Full name',
                        textInputAction: TextInputAction.next,
                        validator: _requiredValidator('Name'),
                      ),
                      const SizedBox(height: 18),
                      const _FilterFieldLabel(text: 'Email'),
                      const SizedBox(height: 8),
                      _AddUserTextField(
                        controller: _emailController,
                        hintText: 'user@company.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 18),
                      const _FilterFieldLabel(text: 'Employee ID'),
                      const SizedBox(height: 8),
                      _AddUserTextField(
                        controller: _employeeIdController,
                        hintText: 'Employee ID',
                        textInputAction: TextInputAction.next,
                        validator: _requiredValidator('Employee ID'),
                      ),
                      const SizedBox(height: 18),
                      const _FilterFieldLabel(text: 'Role'),
                      const SizedBox(height: 8),
                      _AddUserRoleDropdown(
                        value: _role,
                        onChanged: _isSubmitting
                            ? null
                            : (role) {
                                if (role == null) {
                                  return;
                                }
                                setState(() {
                                  _role = role;
                                  if (!_needsQcAssignment) {
                                    _selectedQc = null;
                                  }
                                  _submitError = null;
                                });
                              },
                      ),
                      if (_needsQcAssignment) ...[
                        const SizedBox(height: 18),
                        const _FilterFieldLabel(text: 'Assigned QC'),
                        const SizedBox(height: 8),
                        _QcAutocompleteField(
                          qcUsers: _qcUsers,
                          selectedQc: _selectedQc,
                          isLoading: _isLoadingQcs,
                          onSelected: (user) {
                            setState(() {
                              _selectedQc = user;
                              _submitError = null;
                            });
                          },
                          onTextChanged: (value) {
                            if (_selectedQc?.name != value) {
                              setState(() => _selectedQc = null);
                            }
                          },
                          validator: (_) {
                            if (_isLoadingQcs) {
                              return 'QC users are still loading.';
                            }
                            if (_qcLoadError != null) {
                              return _qcLoadError;
                            }
                            if (_selectedQc == null) {
                              return 'Select a QC user.';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 18),
                      _EditUserSwitchRow(
                        title: 'Active',
                        value: _isActive,
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _isActive = value),
                      ),
                      const SizedBox(height: 10),
                      _EditUserSwitchRow(
                        title: 'Email Verified',
                        value: _isEmailVerified,
                        onChanged: _isSubmitting
                            ? null
                            : (value) =>
                                  setState(() => _isEmailVerified = value),
                      ),
                      if (_submitError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _submitError!,
                          style: const TextStyle(
                            color: Color(0xFFFF9B9B),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                      const SizedBox(height: 34),
                      Row(
                        children: [
                          Expanded(
                            child: _FilterActionButton(
                              label: 'Cancel',
                              onPressed: _isSubmitting
                                  ? () {}
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _AddUserSubmitButton(
                              isSubmitting: _isSubmitting,
                              label: 'Save',
                              onPressed: _submit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  FormFieldValidator<String> _requiredValidator(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName is required.';
      }
      return null;
    };
  }

  String? _emailValidator(String? value) {
    final cleanedValue = value?.trim() ?? '';
    if (cleanedValue.isEmpty) {
      return 'Email is required.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanedValue)) {
      return 'Enter a valid email.';
    }
    return null;
  }
}

class _EditUserSwitchRow extends StatelessWidget {
  const _EditUserSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      tileColor: const Color(0xFF3F3F3F),
      activeThumbColor: const Color(0xFF67D8FF),
      inactiveThumbColor: const Color(0xFFCFCFCF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AddUserTextField extends StatelessWidget {
  const _AddUserTextField({
    required this.controller,
    required this.hintText,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(color: Colors.black, fontSize: 16),
      cursorColor: Colors.black,
      validator: validator,
      decoration: _addUserInputDecoration(hintText),
    );
  }
}

class _AddUserRoleDropdown extends StatelessWidget {
  const _AddUserRoleDropdown({required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<UserRole>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 180,
      dropdownColor: const Color(0xFFD9D9D9),
      iconEnabledColor: Colors.black,
      iconDisabledColor: const Color(0xFF777777),
      style: const TextStyle(color: Colors.black, fontSize: 16),
      decoration: _addUserInputDecoration('Select role'),
      items: UserRole.values
          .map(
            (role) => DropdownMenuItem<UserRole>(
              value: role,
              child: Text(
                role.roleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _QcAutocompleteField extends StatelessWidget {
  const _QcAutocompleteField({
    required this.qcUsers,
    required this.selectedQc,
    required this.isLoading,
    required this.onSelected,
    required this.onTextChanged,
    required this.validator,
  });

  final List<_AdminUser> qcUsers;
  final _AdminUser? selectedQc;
  final bool isLoading;
  final ValueChanged<_AdminUser> onSelected;
  final ValueChanged<String> onTextChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<_AdminUser>(
      displayStringForOption: (user) => user.name,
      optionsBuilder: (textEditingValue) {
        final keyword = textEditingValue.text.trim().toLowerCase();
        if (keyword.isEmpty || isLoading) {
          return const Iterable<_AdminUser>.empty();
        }

        final matches = qcUsers.where((user) {
          return user.name.toLowerCase().contains(keyword) ||
              user.email.toLowerCase().contains(keyword) ||
              user.employeeId.toLowerCase().contains(keyword);
        }).toList();

        matches.sort((first, second) {
          final firstName = first.name.toLowerCase();
          final secondName = second.name.toLowerCase();
          final firstStarts = firstName.startsWith(keyword) ? 0 : 1;
          final secondStarts = secondName.startsWith(keyword) ? 0 : 1;
          final startCompare = firstStarts.compareTo(secondStarts);
          if (startCompare != 0) {
            return startCompare;
          }
          return firstName.compareTo(secondName);
        });

        return matches.take(8);
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (selectedQc != null &&
                textEditingController.text != selectedQc!.name) {
              textEditingController.text = selectedQc!.name;
            }

            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.black, fontSize: 16),
              cursorColor: Colors.black,
              onChanged: onTextChanged,
              validator: validator,
              decoration:
                  _addUserInputDecoration(
                    isLoading ? 'Loading QC users...' : 'Type QC name',
                  ).copyWith(
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.search_rounded,
                            color: Colors.black,
                            size: 26,
                          ),
                  ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.sizeOf(context).width - 56,
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Text(
                        option.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddUserSubmitButton extends StatelessWidget {
  const _AddUserSubmitButton({
    required this.isSubmitting,
    required this.label,
    required this.onPressed,
  });

  final bool isSubmitting;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: isSubmitting ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF67D8FF),
          disabledBackgroundColor: const Color(0xFF6B8791),
          foregroundColor: const Color(0xFF003F59),
          disabledForegroundColor: const Color(0xFF1F343B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF003F59),
                ),
              )
            : Text(
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

InputDecoration _addUserInputDecoration(String hintText) {
  return InputDecoration(
    filled: true,
    fillColor: const Color(0xFFD9D9D9),
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFF666666)),
    errorMaxLines: 2,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide.none,
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide.none,
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide.none,
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFFFF9B9B), width: 1.6),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFFFF9B9B), width: 1.8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  );
}
