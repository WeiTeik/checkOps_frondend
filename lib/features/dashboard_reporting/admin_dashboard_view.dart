part of 'home_page.dart';

class _AdminDashboardView extends StatefulWidget {
  const _AdminDashboardView({
    required this.accessToken,
    required this.isActive,
  });

  final String accessToken;
  final bool isActive;

  @override
  State<_AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<_AdminDashboardView> {
  final _taskApi = TaskApi();
  Future<_AdminDashboardData>? _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void didUpdateWidget(covariant _AdminDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken ||
        (widget.isActive && !oldWidget.isActive)) {
      _loadDashboard();
    }
  }

  void _loadDashboard() {
    _dashboardFuture = _loadDashboardData();
  }

  Future<void> _refreshDashboard() async {
    setState(_loadDashboard);
    await _dashboardFuture;
  }

  Future<_AdminDashboardData> _loadDashboardData() async {
    final taskPayloads = await _taskApi.getTasks(
      accessToken: widget.accessToken,
    );
    final tasks = taskPayloads.map(_Task.fromJson).toList();
    final nestedEntries = await Future.wait(
      tasks.map((task) async {
        final entryPayloads = await _taskApi.getTaskEntries(
          taskId: task.id,
          accessToken: widget.accessToken,
        );
        return entryPayloads
            .map((entry) => _TaskEntry.fromJson(entry, task))
            .toList();
      }),
    );
    final entries = nestedEntries.expand((entries) => entries).toList();
    return _AdminDashboardData.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminDashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF8EDCFF)),
          );
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return _TaskErrorView(
            message: _errorMessage(snapshot.error),
            onRetry: _refreshDashboard,
          );
        }

        final data = snapshot.data ?? _AdminDashboardData.empty();
        return RefreshIndicator(
          color: const Color(0xFF67D8FF),
          backgroundColor: const Color(0xFF303030),
          onRefresh: _refreshDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AdminMetricCard(
                            value: data.countFor(_TaskStatus.pending),
                            label: 'Pending',
                            color: const Color(0xFFFF8B2C),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _AdminMetricCard(
                            value: data.countFor(_TaskStatus.submitted),
                            label: 'Submitted',
                            color: const Color(0xFF00B316),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _AdminMetricCard(
                            value: data.countFor(_TaskStatus.failed),
                            label: 'Failed',
                            color: const Color(0xFFFF1E1E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminMetricCard(
                            value: data.countFor(_TaskStatus.approved),
                            label: 'Approved',
                            color: const Color(0xFF00B316),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _AdminMetricCard(
                            value: data.countFor(_TaskStatus.rejected),
                            label: 'Rejected',
                            color: const Color(0xFFFF1E1E),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _AdminMetricCard(
                            value: data.countFor(_TaskStatus.expired),
                            label: 'Expired',
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _AdminOverviewHeader(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _AdminChartCard(
                  axisLabel: 'Submissions',
                  title: 'Assignee Task Submission',
                  accentColor: const Color(0xFF67D8FF),
                  values: data.submissionValues,
                  labels: data.dayLabels,
                  tooltipLabels: data.dateLabels,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _AdminChartCard(
                  axisLabel: 'Reviews',
                  title: 'Tasks Reviewed',
                  accentColor: const Color(0xFF7CFF8A),
                  values: data.reviewValues,
                  labels: data.dayLabels,
                  tooltipLabels: data.dateLabels,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.statusCounts,
    required this.submissionValues,
    required this.reviewValues,
    required this.dayLabels,
    required this.dateLabels,
  });

  factory _AdminDashboardData.empty() {
    final days = _recentDays();
    return _AdminDashboardData(
      statusCounts: const {},
      submissionValues: List<double>.filled(days.length, 0),
      reviewValues: List<double>.filled(days.length, 0),
      dayLabels: days.map(_weekdayLabel).toList(),
      dateLabels: days.map(_dateLabel).toList(),
    );
  }

  factory _AdminDashboardData.fromEntries(List<_TaskEntry> entries) {
    final counts = <_TaskStatus, int>{};
    for (final status in _TaskStatus.values) {
      counts[status] = 0;
    }
    for (final entry in entries) {
      counts[entry.status] = (counts[entry.status] ?? 0) + 1;
    }

    final days = _recentDays();
    final submissionCounts = List<int>.filled(days.length, 0);
    final reviewCounts = List<int>.filled(days.length, 0);
    for (final entry in entries) {
      final submittedAt = entry.submittedAt;
      if (submittedAt != null &&
          (entry.status == _TaskStatus.submitted ||
              entry.status == _TaskStatus.failed ||
              entry.status == _TaskStatus.approved ||
              entry.status == _TaskStatus.rejected)) {
        final index = _dayIndex(days, submittedAt);
        if (index != null) {
          submissionCounts[index] += 1;
        }
      }

      final reviewedAt = entry.reviewedAt;
      if (reviewedAt != null &&
          (entry.status == _TaskStatus.approved ||
              entry.status == _TaskStatus.rejected)) {
        final index = _dayIndex(days, reviewedAt);
        if (index != null) {
          reviewCounts[index] += 1;
        }
      }
    }

    return _AdminDashboardData(
      statusCounts: counts,
      submissionValues: submissionCounts
          .map((value) => value.toDouble())
          .toList(),
      reviewValues: reviewCounts.map((value) => value.toDouble()).toList(),
      dayLabels: days.map(_weekdayLabel).toList(),
      dateLabels: days.map(_dateLabel).toList(),
    );
  }

  final Map<_TaskStatus, int> statusCounts;
  final List<double> submissionValues;
  final List<double> reviewValues;
  final List<String> dayLabels;
  final List<String> dateLabels;

  String countFor(_TaskStatus status) {
    return (statusCounts[status] ?? 0).toString();
  }

  static List<DateTime> _recentDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var offset = 6; offset >= 0; offset -= 1)
        today.subtract(Duration(days: offset)),
    ];
  }

  static int? _dayIndex(List<DateTime> days, DateTime value) {
    final date = value.toLocal();
    final day = DateTime(date.year, date.month, date.day);
    for (var index = 0; index < days.length; index += 1) {
      if (days[index] == day) {
        return index;
      }
    }
    return null;
  }

  static String _dateLabel(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  static String _weekdayLabel(DateTime value) {
    return switch (value.weekday) {
      DateTime.monday => 'Mon',
      DateTime.tuesday => 'Tue',
      DateTime.wednesday => 'Wed',
      DateTime.thursday => 'Thu',
      DateTime.friday => 'Fri',
      DateTime.saturday => 'Sat',
      _ => 'Sun',
    };
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF303030),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminOverviewHeader extends StatelessWidget {
  const _AdminOverviewHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      color: const Color(0xFF303030),
      alignment: Alignment.center,
      child: const Text(
        'Operation Overview',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AdminChartCard extends StatefulWidget {
  const _AdminChartCard({
    required this.axisLabel,
    required this.title,
    required this.accentColor,
    required this.values,
    required this.labels,
    required this.tooltipLabels,
  });

  final String axisLabel;
  final String title;
  final Color accentColor;
  final List<double> values;
  final List<String> labels;
  final List<String> tooltipLabels;

  @override
  State<_AdminChartCard> createState() => _AdminChartCardState();
}

class _AdminChartCardState extends State<_AdminChartCard> {
  int? _activePointIndex;

  void _setActivePoint(Offset position, Size size) {
    final nextIndex = _nearestPointIndex(position, size);
    if (nextIndex == _activePointIndex) {
      return;
    }
    setState(() => _activePointIndex = nextIndex);
  }

  void _clearActivePoint() {
    if (_activePointIndex == null) {
      return;
    }
    setState(() => _activePointIndex = null);
  }

  int? _nearestPointIndex(Offset position, Size size) {
    if (widget.values.length < 2) {
      return null;
    }

    final plotRect = _AdminLineChartPainter.plotRectFor(size);
    if (!plotRect.inflate(14).contains(position)) {
      return null;
    }

    final chartWidth = plotRect.width;
    final chartHeight = plotRect.height;
    final originY = plotRect.bottom;
    var nearestIndex = 0;
    var nearestDistance = double.infinity;

    for (var index = 0; index < widget.values.length; index += 1) {
      final x =
          plotRect.left + (index / (widget.values.length - 1)) * chartWidth;
      final y = originY - (widget.values[index] / _maxValue) * chartHeight;
      final distance = (Offset(x, y) - position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestDistance <= 24 ? nearestIndex : null;
  }

  double get _maxValue {
    final highestValue = widget.values.fold<double>(
      0,
      (highest, value) => value > highest ? value : highest,
    );
    return highestValue < 4 ? 4 : highestValue;
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => _clearActivePoint(),
      child: Container(
        height: 176,
        padding: const EdgeInsets.fromLTRB(12, 11, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF303030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3B3B3B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              widget.axisLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chartSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onHover: (event) =>
                        _setActivePoint(event.localPosition, chartSize),
                    onExit: (_) => _clearActivePoint(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) =>
                          _setActivePoint(details.localPosition, chartSize),
                      child: CustomPaint(
                        painter: _AdminLineChartPainter(
                          values: widget.values,
                          labels: widget.labels,
                          tooltipLabels: widget.tooltipLabels,
                          maxValue: _maxValue,
                          accentColor: widget.accentColor,
                          activePointIndex: _activePointIndex,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLineChartPainter extends CustomPainter {
  const _AdminLineChartPainter({
    required this.values,
    required this.labels,
    required this.tooltipLabels,
    required this.maxValue,
    required this.accentColor,
    required this.activePointIndex,
  });

  static const _leftInset = 26.0;
  static const _rightInset = 4.0;
  static const _bottomInset = 17.0;
  static const _topInset = 7.0;

  final List<double> values;
  final List<String> labels;
  final List<String> tooltipLabels;
  final double maxValue;
  final Color accentColor;
  final int? activePointIndex;

  static Rect plotRectFor(Size size) {
    return Rect.fromLTWH(
      _leftInset,
      _topInset,
      size.width - _leftInset - _rightInset,
      size.height - _topInset - _bottomInset,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = plotRectFor(size);
    final chartWidth = plotRect.width;
    final chartHeight = plotRect.height;
    final origin = Offset(plotRect.left, plotRect.bottom);
    final plotRRect = RRect.fromRectAndRadius(
      plotRect,
      const Radius.circular(7),
    );
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.26),
          accentColor.withValues(alpha: 0.03),
        ],
      ).createShader(plotRect);
    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.2;
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7;
    final pointPaint = Paint()..color = accentColor;
    final pointBorderPaint = Paint()..color = const Color(0xFF303030);
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    canvas.drawRRect(plotRRect, Paint()..color = const Color(0xFF292929));

    for (var tick = 1; tick <= 4; tick += 1) {
      final y = origin.dy - (tick / 4) * chartHeight;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(size.width - 4, y),
        gridPaint,
      );
    }

    for (var index = 1; index < values.length - 1; index += 2) {
      final x = plotRect.left + (index / (values.length - 1)) * chartWidth;
      canvas.drawLine(Offset(x, plotRect.top), Offset(x, origin.dy), gridPaint);
    }

    canvas.drawLine(Offset(plotRect.left, plotRect.top), origin, axisPaint);
    canvas.drawLine(origin, Offset(size.width - 4, origin.dy), axisPaint);

    for (var tick = 1; tick <= 3; tick += 1) {
      final tickValue = (maxValue / 4 * tick).ceil();
      final y = origin.dy - (tick / 4) * chartHeight;
      labelPainter.text = TextSpan(
        text: tickValue.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout(minWidth: 12, maxWidth: 12);
      labelPainter.paint(canvas, Offset(4, y - labelPainter.height / 2));
    }

    if (values.length < 2) {
      return;
    }

    final points = <Offset>[];
    for (var index = 0; index < values.length; index += 1) {
      final x = plotRect.left + (index / (values.length - 1)) * chartWidth;
      final y = origin.dy - (values[index] / maxValue) * chartHeight;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index += 1) {
      path.lineTo(points[index].dx, points[index].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, origin.dy)
      ..lineTo(points.first.dx, origin.dy)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    if (activePointIndex case final activeIndex?
        when activeIndex >= 0 && activeIndex < points.length) {
      final point = points[activeIndex];
      final guidePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.34)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(point.dx, plotRect.top),
        Offset(point.dx, origin.dy),
        guidePaint,
      );
      canvas.drawCircle(point, 6.8, pointBorderPaint);
      canvas.drawCircle(point, 4, pointPaint);
      _paintTooltip(
        canvas: canvas,
        size: size,
        point: point,
        label: labels.length == values.length
            ? (tooltipLabels.length == values.length
                  ? tooltipLabels[activeIndex]
                  : labels[activeIndex])
            : 'Day ${activeIndex + 1}',
        value: values[activeIndex],
      );
    }

    final chartLabels = labels.length == values.length ? labels : const [];
    for (var index = 0; index < chartLabels.length; index += 1) {
      final x = plotRect.left + (index / (chartLabels.length - 1)) * chartWidth;
      labelPainter.text = TextSpan(
        text: chartLabels[index],
        style: const TextStyle(
          color: Color(0xFFBDBDBD),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout();
      var labelX = x - labelPainter.width / 2;
      if (index == 0) {
        labelX = plotRect.left;
      } else if (index == chartLabels.length - 1) {
        labelX = size.width - 4 - labelPainter.width;
      } else {
        labelX = labelX.clamp(
          plotRect.left,
          size.width - 4 - labelPainter.width,
        );
      }
      labelPainter.paint(canvas, Offset(labelX, origin.dy + 5));
    }
  }

  void _paintTooltip({
    required Canvas canvas,
    required Size size,
    required Offset point,
    required String label,
    required double value,
  }) {
    final tooltipPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label\n',
            style: const TextStyle(
              color: Color(0xFFCFCFCF),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value.toStringAsFixed(
              value.truncateToDouble() == value ? 0 : 1,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout();
    final tooltipSize = Size(
      tooltipPainter.width + 16,
      tooltipPainter.height + 10,
    );
    var left = point.dx - tooltipSize.width / 2;
    var top = point.dy - tooltipSize.height - 12;
    left = left.clamp(2, size.width - tooltipSize.width - 2);
    if (top < 2) {
      top = point.dy + 12;
    }

    final tooltipRect = Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      tooltipSize.width,
      tooltipSize.height,
    );
    final tooltipRRect = RRect.fromRectAndRadius(
      tooltipRect,
      const Radius.circular(8),
    );
    canvas.drawRRect(tooltipRRect, Paint()..color = const Color(0xFF1F1F1F));
    canvas.drawRRect(
      tooltipRRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tooltipPainter.paint(canvas, Offset(left + 8, top + 5));
  }

  @override
  bool shouldRepaint(covariant _AdminLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.tooltipLabels != tooltipLabels ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.activePointIndex != activePointIndex;
  }
}
