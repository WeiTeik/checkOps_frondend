import 'package:flutter/material.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

enum _TaskRecurrence { daily, weekly, monthly, once }

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _scrollController = ScrollController();
  final _titleKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  final _operatorKey = GlobalKey();
  final _startTimeKey = GlobalKey();
  final _endTimeKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _operatorController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _locationController = TextEditingController();
  _TaskRecurrence _recurrence = _TaskRecurrence.once;
  bool _showErrors = false;

  bool get _isComplete =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      _operatorController.text.trim().isNotEmpty &&
      _startTimeController.text.trim().isNotEmpty &&
      _endTimeController.text.trim().isNotEmpty &&
      _locationController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _titleController,
      _descriptionController,
      _operatorController,
      _startTimeController,
      _endTimeController,
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
    _operatorController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isMissing(TextEditingController controller) {
    return _showErrors && controller.text.trim().isEmpty;
  }

  GlobalKey? _firstMissingFieldKey() {
    if (_titleController.text.trim().isEmpty) {
      return _titleKey;
    }
    if (_descriptionController.text.trim().isEmpty) {
      return _descriptionKey;
    }
    if (_operatorController.text.trim().isEmpty) {
      return _operatorKey;
    }
    if (_startTimeController.text.trim().isEmpty) {
      return _startTimeKey;
    }
    if (_endTimeController.text.trim().isEmpty) {
      return _endTimeKey;
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

  Future<void> _validateAndCreateTask() async {
    if (!_isComplete) {
      setState(() => _showErrors = true);
      await _scrollToFirstMissingField();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Task created.')));
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CreateTaskHeader(onBack: widget.onBack),
        const _CreateTaskSectionTitle(title: 'Job Details'),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              _CreateTaskField(
                fieldKey: _titleKey,
                label: 'Task Title',
                controller: _titleController,
                hasError: _isMissing(_titleController),
              ),
              const SizedBox(height: 16),
              _CreateTaskField(
                fieldKey: _descriptionKey,
                label: 'Description',
                controller: _descriptionController,
                minLines: 3,
                maxLines: 4,
                hasError: _isMissing(_descriptionController),
              ),
              const SizedBox(height: 16),
              _CreateTaskField(
                fieldKey: _operatorKey,
                label: 'Assign Operator',
                controller: _operatorController,
                hasError: _isMissing(_operatorController),
              ),
              const SizedBox(height: 16),
              _CreateTaskField(
                fieldKey: _startTimeKey,
                label: 'Start Time',
                controller: _startTimeController,
                suffixIcon: Icons.calendar_today_rounded,
                hasError: _isMissing(_startTimeController),
              ),
              const SizedBox(height: 16),
              _CreateTaskField(
                fieldKey: _endTimeKey,
                label: 'End Time',
                controller: _endTimeController,
                suffixIcon: Icons.calendar_today_rounded,
                hasError: _isMissing(_endTimeController),
              ),
              const SizedBox(height: 16),
              _CreateTaskField(
                fieldKey: _locationKey,
                label: 'Location',
                controller: _locationController,
                suffixIcon: Icons.place_rounded,
                hasError: _isMissing(_locationController),
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
              const SizedBox(height: 34),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _validateAndCreateTask,
                  icon: const Icon(Icons.add_task_rounded, size: 24),
                  label: const Text(
                    'Create & Assign Task',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isComplete
                        ? const Color(0xFFD9D9D9)
                        : const Color(0xFF8E8E8E),
                    foregroundColor: _isComplete
                        ? Colors.black
                        : const Color(0xFF303030),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
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
  const _CreateTaskHeader({required this.onBack});

  final VoidCallback onBack;

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
            iconSize: 32,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Create Task',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
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
      height: 46,
      alignment: Alignment.center,
      color: const Color(0xFF303030),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
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
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final IconData? suffixIcon;
  final bool hasError;

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
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFD9D9D9),
            errorText: hasError ? '$label is required' : null,
            errorStyle: const TextStyle(
              color: Color(0xFFFFB3B3),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            suffixIcon: suffixIcon == null
                ? null
                : Icon(suffixIcon, color: const Color(0xFF474747), size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFFF4048) : Colors.transparent,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFFF4048) : Colors.transparent,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF23A8FF), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4048), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4048), width: 2),
            ),
          ),
        ),
      ],
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
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? const Color(0xFF97DBFF)
              : const Color(0xFFD9D9D9),
          foregroundColor: Colors.black,
          side: BorderSide(
            color: selected ? const Color(0xFF23A8FF) : Colors.transparent,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
