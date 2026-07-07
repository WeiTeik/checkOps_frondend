part of '../../dashboard_reporting/home_page.dart';

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
