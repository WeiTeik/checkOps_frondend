import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../authentication/auth_api.dart';
import '../authentication/task_api.dart';
import '../authentication/user_api.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({
    super.key,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onBack,
    required this.onTaskCreated,
    this.initialValues,
  });

  final String accessToken;
  final int currentUserId;
  final String currentUserRole;
  final VoidCallback onBack;
  final VoidCallback onTaskCreated;
  final CreateTaskInitialValues? initialValues;

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class CreateTaskInitialValues {
  const CreateTaskInitialValues({
    required this.taskId,
    required this.title,
    required this.description,
    required this.userId,
    required this.location,
    required this.recurrenceType,
    required this.recurrenceStartAt,
    required this.dueInterval,
    required this.dueIntervalUnit,
    required this.isActive,
  });

  final int taskId;
  final String title;
  final String description;
  final int userId;
  final String location;
  final String recurrenceType;
  final DateTime recurrenceStartAt;
  final int dueInterval;
  final String dueIntervalUnit;
  final bool isActive;
}

enum _TaskRecurrence { daily, weekly, monthly, once }

enum _IntervalUnit {
  day('Day'),
  week('Week'),
  month('Month'),
  year('Year');

  const _IntervalUnit(this.backendValue);

  final String backendValue;

  String get label => backendValue;
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _taskApi = TaskApi();
  final _userApi = UserApi();
  final _scrollController = ScrollController();
  final _titleKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  final _operatorKey = GlobalKey();
  final _startTimeKey = GlobalKey();
  final _dueIntervalKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _dueIntervalController = TextEditingController(text: '1');
  final _locationController = TextEditingController();
  Future<List<_TaskOperator>>? _assignableUsersFuture;
  _TaskOperator? _selectedAssignee;
  DateTime? _recurrenceStartAt;
  _TaskRecurrence _recurrence = _TaskRecurrence.once;
  _IntervalUnit _dueIntervalUnit = _IntervalUnit.day;
  bool _isActive = true;
  bool _showErrors = false;
  bool _isSubmitting = false;
  String? _submitError;

  bool get _isEditing => widget.initialValues != null;

  bool get _isComplete =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      _selectedAssignee != null &&
      _recurrenceStartAt != null &&
      (_isEditing || !_isStartInPast) &&
      _dueInterval > -1 &&
      _locationController.text.trim().isNotEmpty;

  int get _dueInterval {
    return int.tryParse(_dueIntervalController.text.trim()) ?? -1;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
    _assignableUsersFuture = _loadAssignableUsers();
    for (final controller in [
      _titleController,
      _descriptionController,
      _startTimeController,
      _dueIntervalController,
      _locationController,
    ]) {
      controller.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _startTimeController.dispose();
    _dueIntervalController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<List<_TaskOperator>> _loadAssignableUsers() async {
    final users = await _userApi.getUsers(
      accessToken: widget.accessToken,
      active: true,
    );
    final assignableUsers = users
        .map(_TaskOperator.fromJson)
        .where(_isAssignableUser)
        .toList();
    final initialUserId = widget.initialValues?.userId;
    if (initialUserId != null && mounted) {
      for (final user in assignableUsers) {
        if (user.id == initialUserId) {
          setState(() => _selectedAssignee = user);
          break;
        }
      }
    }
    return assignableUsers;
  }

  void _loadInitialValues() {
    final values = widget.initialValues;
    if (values == null) {
      return;
    }

    _titleController.text = values.title;
    _descriptionController.text = values.description;
    _locationController.text = values.location;
    _dueIntervalController.text = values.dueInterval.toString();
    _recurrenceStartAt = values.recurrenceStartAt;
    _startTimeController.text = _formatDateTime(values.recurrenceStartAt);
    _isActive = values.isActive;
    _recurrence = switch (values.recurrenceType.trim().toLowerCase()) {
      'recurring' => _TaskRecurrence.daily,
      'daily' => _TaskRecurrence.daily,
      'weekly' => _TaskRecurrence.weekly,
      'monthly' => _TaskRecurrence.monthly,
      _ => _TaskRecurrence.once,
    };
    _dueIntervalUnit = _intervalUnitFrom(values.dueIntervalUnit);
  }

  bool _isAssignableUser(_TaskOperator user) {
    if (user.id == widget.currentUserId) {
      return true;
    }

    return switch (widget.currentUserRole.trim().toLowerCase()) {
      'admin' => !user.isAdmin,
      'qc' => user.isOperator && user.qcId == widget.currentUserId,
      _ => false,
    };
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isMissingText(TextEditingController controller) {
    return _showErrors && controller.text.trim().isEmpty;
  }

  bool get _isOperatorMissing => _showErrors && _selectedAssignee == null;
  bool get _isStartMissing => _showErrors && _recurrenceStartAt == null;
  bool get _isStartInPast {
    final startAt = _recurrenceStartAt;
    return startAt != null && startAt.isBefore(DateTime.now());
  }

  bool get _isStartInvalid =>
      _showErrors && (_isStartMissing || (!_isEditing && _isStartInPast));
  bool get _isDueIntervalInvalid => _showErrors && _dueInterval < 0;

  GlobalKey? _firstMissingFieldKey() {
    if (_titleController.text.trim().isEmpty) {
      return _titleKey;
    }
    if (_descriptionController.text.trim().isEmpty) {
      return _descriptionKey;
    }
    if (_selectedAssignee == null) {
      return _operatorKey;
    }
    if (_recurrenceStartAt == null) {
      return _startTimeKey;
    }
    if (!_isEditing && _isStartInPast) {
      return _startTimeKey;
    }
    if (_dueInterval < 0) {
      return _dueIntervalKey;
    }
    if (_locationController.text.trim().isEmpty) {
      return _locationKey;
    }
    return null;
  }

  Future<void> _scrollToFirstMissingField() async {
    final key = _firstMissingFieldKey();
    final fieldContext = key?.currentContext;
    if (fieldContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final currentValue = _recurrenceStartAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: currentValue,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
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
    if (date == null || !mounted) {
      return;
    }

    final time = await _pickTaskTime(TimeOfDay.fromDateTime(currentValue));
    if (time == null) {
      return;
    }

    final nextValue = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _recurrenceStartAt = nextValue;
      _startTimeController.text = _formatDateTime(nextValue);
    });
  }

  Future<TimeOfDay?> _pickTaskTime(TimeOfDay initialTime) async {
    var selectedHour = initialTime.hourOfPeriod == 0
        ? 12
        : initialTime.hourOfPeriod;
    var selectedMinute = initialTime.minute;
    var selectedPeriod = initialTime.period;
    final hourController = FixedExtentScrollController(
      initialItem: selectedHour - 1,
    );
    final minuteController = FixedExtentScrollController(
      initialItem: selectedMinute,
    );
    final periodController = FixedExtentScrollController(
      initialItem: selectedPeriod == DayPeriod.am ? 0 : 1,
    );

    final pickedTime = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: const Color(0xFF303030),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E8E8E),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Start Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 174,
                      child: Row(
                        children: [
                          Expanded(
                            child: _TimeWheel(
                              controller: hourController,
                              children: [
                                for (var hour = 1; hour <= 12; hour++)
                                  Text(hour.toString().padLeft(2, '0')),
                              ],
                              onSelectedItemChanged: (index) {
                                setSheetState(() => selectedHour = index + 1);
                              },
                            ),
                          ),
                          const Text(
                            ':',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                          Expanded(
                            child: _TimeWheel(
                              controller: minuteController,
                              children: [
                                for (var minute = 0; minute < 60; minute++)
                                  Text(minute.toString().padLeft(2, '0')),
                              ],
                              onSelectedItemChanged: (index) {
                                setSheetState(() => selectedMinute = index);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 82,
                            child: _TimeWheel(
                              controller: periodController,
                              children: const [Text('AM'), Text('PM')],
                              onSelectedItemChanged: (index) {
                                setSheetState(
                                  () => selectedPeriod = index == 0
                                      ? DayPeriod.am
                                      : DayPeriod.pm,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFFC7C7C7),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final hour = selectedPeriod == DayPeriod.am
                                  ? (selectedHour == 12 ? 0 : selectedHour)
                                  : (selectedHour == 12
                                        ? 12
                                        : selectedHour + 12);
                              Navigator.of(context).pop(
                                TimeOfDay(hour: hour, minute: selectedMinute),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD9D9D9),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Set Time'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    hourController.dispose();
    minuteController.dispose();
    periodController.dispose();
    return pickedTime;
  }

  Future<void> _validateAndCreateTask() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitError = null);

    if (!_isComplete) {
      setState(() => _showErrors = true);
      await _scrollToFirstMissingField();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        await _taskApi.updateTask(
          taskId: widget.initialValues!.taskId,
          accessToken: widget.accessToken,
          name: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          userId: _selectedAssignee!.id,
          location: _locationController.text.trim(),
          recurrenceType: _recurrenceType,
          recurrenceInterval: 1,
          recurrenceUnit: _recurrenceUnit,
          recurrenceStartAt: _recurrenceStartAt!,
          dueInterval: _dueInterval,
          dueIntervalUnit: _dueIntervalUnit.backendValue,
          isActive: _isActive,
        );
      } else {
        await _taskApi.createTask(
          accessToken: widget.accessToken,
          name: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          userId: _selectedAssignee!.id,
          location: _locationController.text.trim(),
          recurrenceType: _recurrenceType,
          recurrenceInterval: 1,
          recurrenceUnit: _recurrenceUnit,
          recurrenceStartAt: _recurrenceStartAt!,
          dueInterval: _dueInterval,
          dueIntervalUnit: _dueIntervalUnit.backendValue,
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Task updated.' : 'Task created.')),
      );
      widget.onTaskCreated();
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

  String get _recurrenceType {
    return _recurrence == _TaskRecurrence.once ? 'Once' : 'Recurring';
  }

  String? get _recurrenceUnit {
    return switch (_recurrence) {
      _TaskRecurrence.daily => 'Day',
      _TaskRecurrence.weekly => 'Week',
      _TaskRecurrence.monthly => 'Month',
      _TaskRecurrence.once => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CreateTaskHeader(
          title: _isEditing ? 'Edit Task' : 'Create Task',
          onBack: _isSubmitting ? null : widget.onBack,
        ),
        const _CreateTaskSectionTitle(title: 'Job Details'),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            children: [
              _CreateTaskField(
                fieldKey: _titleKey,
                label: 'Task Title',
                controller: _titleController,
                hasError: _isMissingText(_titleController),
              ),
              const SizedBox(height: 16),
              _CreateTaskField(
                fieldKey: _descriptionKey,
                label: 'Description',
                controller: _descriptionController,
                minLines: 3,
                maxLines: 4,
                hasError: _isMissingText(_descriptionController),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<_TaskOperator>>(
                future: _assignableUsersFuture,
                builder: (context, snapshot) {
                  return _AssigneeAutocomplete(
                    fieldKey: _operatorKey,
                    value: _selectedAssignee,
                    operators: snapshot.data ?? const [],
                    isLoading:
                        snapshot.connectionState == ConnectionState.waiting,
                    errorText: _isOperatorMissing
                        ? 'Assignee is required'
                        : snapshot.hasError
                        ? _errorMessage(snapshot.error)
                        : null,
                    onRetry: () => setState(() {
                      _assignableUsersFuture = _loadAssignableUsers();
                    }),
                    onChanged: (operator) {
                      setState(() => _selectedAssignee = operator);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              _CreateTaskField(
                fieldKey: _startTimeKey,
                label: 'Start Time',
                controller: _startTimeController,
                suffixIcon: Icons.calendar_today_rounded,
                readOnly: true,
                onTap: _pickStartTime,
                hasError: _isStartInvalid,
                errorText: _isStartMissing
                    ? 'Start Time is required'
                    : 'Start Time cannot be earlier than now',
              ),
              const SizedBox(height: 16),
              _DueIntervalField(
                fieldKey: _dueIntervalKey,
                controller: _dueIntervalController,
                unit: _dueIntervalUnit,
                hasError: _isDueIntervalInvalid,
                onUnitChanged: (unit) {
                  setState(() => _dueIntervalUnit = unit);
                },
              ),
              const SizedBox(height: 16),
              _CreateTaskField(
                fieldKey: _locationKey,
                label: 'Location',
                controller: _locationController,
                suffixIcon: Icons.place_rounded,
                hasError: _isMissingText(_locationController),
              ),
              const SizedBox(height: 18),
              const Text(
                'Recurrence',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _RecurrenceChip(
                    label: 'Daily',
                    selected: _recurrence == _TaskRecurrence.daily,
                    onPressed: () {
                      setState(() => _recurrence = _TaskRecurrence.daily);
                    },
                  ),
                  _RecurrenceChip(
                    label: 'Weekly',
                    selected: _recurrence == _TaskRecurrence.weekly,
                    onPressed: () {
                      setState(() => _recurrence = _TaskRecurrence.weekly);
                    },
                  ),
                  _RecurrenceChip(
                    label: 'Monthly',
                    selected: _recurrence == _TaskRecurrence.monthly,
                    onPressed: () {
                      setState(() => _recurrence = _TaskRecurrence.monthly);
                    },
                  ),
                  _RecurrenceChip(
                    label: 'Once',
                    selected: _recurrence == _TaskRecurrence.once,
                    onPressed: () {
                      setState(() => _recurrence = _TaskRecurrence.once);
                    },
                  ),
                ],
              ),
              if (_isEditing) ...[
                const SizedBox(height: 24),
                const _CreateTaskSubheading(title: 'Task Status'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TaskStatusChoice(
                        label: 'Active',
                        icon: Icons.check_circle_rounded,
                        selected: _isActive,
                        selectedColor: const Color(0xFF7CFF8A),
                        selectedTextColor: const Color(0xFF008F13),
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _isActive = true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _TaskStatusChoice(
                        label: 'Inactive',
                        icon: Icons.pause_circle_filled_rounded,
                        selected: !_isActive,
                        selectedColor: const Color(0xFFFFD59B),
                        selectedTextColor: const Color(0xFFFF8B2C),
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _isActive = false),
                      ),
                    ),
                  ],
                ),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: 20),
                Text(
                  _submitError!,
                  style: const TextStyle(
                    color: Color(0xFFFFB3B3),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 34),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _validateAndCreateTask,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF8E8E8E),
                    side: BorderSide(
                      color: _isSubmitting
                          ? const Color(0xFF8E8E8E)
                          : Colors.white,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Save Task' : 'Create Task',
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreateTaskHeader extends StatelessWidget {
  const _CreateTaskHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF474747),
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F), width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            disabledColor: Color(0xFF8E8E8E),
            iconSize: 32,
          ),
          const SizedBox(width: 8),
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
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _CreateTaskSectionTitle extends StatelessWidget {
  const _CreateTaskSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      color: const Color(0xFF303030),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFC7C7C7),
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CreateTaskField extends StatelessWidget {
  const _CreateTaskField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
    this.suffixIcon,
    this.hasError = false,
    this.errorText,
    this.readOnly = false,
    this.onTap,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final IconData? suffixIcon;
  final bool hasError;
  final String? errorText;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          cursorColor: Colors.black,
          style: const TextStyle(color: Colors.black, fontSize: 16),
          decoration: _taskInputDecoration(
            hasError: hasError,
            errorText: hasError ? errorText ?? '$label is required' : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _AssigneeAutocomplete extends StatelessWidget {
  const _AssigneeAutocomplete({
    required this.fieldKey,
    required this.value,
    required this.operators,
    required this.isLoading,
    required this.onChanged,
    this.errorText,
    this.onRetry,
  });

  final Key fieldKey;
  final _TaskOperator? value;
  final List<_TaskOperator> operators;
  final bool isLoading;
  final ValueChanged<_TaskOperator?> onChanged;
  final String? errorText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assign User',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        RawAutocomplete<_TaskOperator>(
          key: ValueKey(value?.id),
          initialValue: TextEditingValue(text: value?.label ?? ''),
          displayStringForOption: (operator) => operator.label,
          optionsBuilder: (textEditingValue) {
            if (isLoading || operators.isEmpty) {
              return const Iterable<_TaskOperator>.empty();
            }

            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) {
              return operators;
            }
            return operators.where((operator) {
              return operator.searchText.contains(query);
            });
          },
          onSelected: onChanged,
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  enabled: !isLoading,
                  cursorColor: Colors.black,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  onChanged: (text) {
                    if (value != null && text != value!.label) {
                      onChanged(null);
                    }
                  },
                  decoration:
                      _taskInputDecoration(
                        hasError: errorText != null,
                        errorText: errorText,
                        suffixIcon: isLoading
                            ? null
                            : Icons.manage_search_rounded,
                      ).copyWith(
                        hintText: isLoading
                            ? 'Loading users...'
                            : 'Search by name',
                        suffixIcon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF474747),
                                    ),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.manage_search_rounded,
                                color: Color(0xFF474747),
                                size: 22,
                              ),
                      ),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: const Color(0xFFD9D9D9),
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 240,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final operator = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(operator),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                operator.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (errorText != null && onRetry != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry loading users'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ],
    );
  }
}

class _DueIntervalField extends StatelessWidget {
  const _DueIntervalField({
    required this.fieldKey,
    required this.controller,
    required this.unit,
    required this.hasError,
    required this.onUnitChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final _IntervalUnit unit;
  final bool hasError;
  final ValueChanged<_IntervalUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Due After',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                cursorColor: Colors.black,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                decoration: _taskInputDecoration(
                  hasError: hasError,
                  errorText: hasError ? 'Due interval must be 0 or more' : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 132,
              child: DropdownButtonFormField<_IntervalUnit>(
                initialValue: unit,
                dropdownColor: const Color(0xFFD9D9D9),
                decoration: _taskInputDecoration(hasError: false),
                items: _IntervalUnit.values
                    .map(
                      (unit) => DropdownMenuItem<_IntervalUnit>(
                        value: unit,
                        child: Text(unit.label),
                      ),
                    )
                    .toList(),
                onChanged: (unit) {
                  if (unit != null) {
                    onUnitChanged(unit);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.controller,
    required this.children,
    required this.onSelectedItemChanged,
  });

  final FixedExtentScrollController controller;
  final List<Widget> children;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    const pickerTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF474747),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5F5F5F)),
      ),
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 42,
        magnification: 1.08,
        squeeze: 1.05,
        useMagnifier: true,
        selectionOverlay: Container(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(
                color: const Color(0xFF97DBFF).withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
          ),
        ),
        onSelectedItemChanged: onSelectedItemChanged,
        children: [
          for (final child in children)
            Center(
              child: DefaultTextStyle(style: pickerTextStyle, child: child),
            ),
        ],
      ),
    );
  }
}

class _RecurrenceChip extends StatelessWidget {
  const _RecurrenceChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: selected
              ? const Color(0xFF3A3A3A)
              : const Color(0xFF333333),
          side: BorderSide(
            color: selected ? Colors.white : const Color(0xFF333333),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _CreateTaskSubheading extends StatelessWidget {
  const _CreateTaskSubheading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _TaskStatusChoice extends StatelessWidget {
  const _TaskStatusChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color selectedTextColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? selectedColor : const Color(0xFF333333),
          foregroundColor: selected ? selectedTextColor : Colors.white,
          disabledForegroundColor: const Color(0xFF8E8E8E),
          side: BorderSide(
            color: selected ? selectedColor : const Color(0xFF5A5A5A),
            width: 1.5,
          ),
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
    );
  }
}

class _TaskOperator {
  const _TaskOperator({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.email,
    required this.role,
    required this.qcId,
  });

  factory _TaskOperator.fromJson(Map<String, dynamic> json) {
    return _TaskOperator(
      id: _intFrom(json['id']),
      name: json['name']?.toString() ?? 'User',
      employeeId: json['employee_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      qcId: _nullableIntFrom(json['qc_id'] ?? json['qcId']),
    );
  }

  final int id;
  final String name;
  final String employeeId;
  final String email;
  final String role;
  final int? qcId;

  String get label {
    return name;
  }

  String get searchText {
    return name.toLowerCase();
  }

  bool get isAdmin {
    return role.trim().toLowerCase() == 'admin';
  }

  bool get isOperator {
    return role.trim().toLowerCase() == 'operator';
  }
}

_IntervalUnit _intervalUnitFrom(String value) {
  final normalized = value.trim().toLowerCase();
  for (final unit in _IntervalUnit.values) {
    if (unit.backendValue.toLowerCase() == normalized) {
      return unit;
    }
  }
  return _IntervalUnit.day;
}

InputDecoration _taskInputDecoration({
  required bool hasError,
  String? errorText,
  IconData? suffixIcon,
}) {
  return InputDecoration(
    filled: true,
    fillColor: const Color(0xFFD9D9D9),
    errorText: errorText,
    errorMaxLines: 2,
    suffixIcon: suffixIcon == null
        ? null
        : Icon(suffixIcon, color: const Color(0xFF474747), size: 20),
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

int _intFrom(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableIntFrom(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

String _formatDateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'pm' : 'am';
  return '${value.day}/${value.month}/${value.year} $hour:$minute $period';
}

String _errorMessage(Object? error) {
  if (error is AuthApiException) {
    return error.message;
  }
  return 'Unable to load data. Please try again.';
}
