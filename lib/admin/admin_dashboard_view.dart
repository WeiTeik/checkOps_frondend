part of '../general/home_page.dart';

class _AdminDashboardView extends StatelessWidget {
  const _AdminDashboardView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AdminMetricCard(
                      value: '3',
                      label: 'Pending',
                      color: Color(0xFFFF8B2C),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: _AdminMetricCard(
                      value: '2',
                      label: 'Submitted',
                      color: Color(0xFF00B316),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: _AdminMetricCard(
                      value: '1',
                      label: 'Failed',
                      color: Color(0xFFFF1E1E),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AdminMetricCard(
                      value: '3',
                      label: 'Approved',
                      color: Color(0xFF00B316),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: _AdminMetricCard(
                      value: '2',
                      label: 'Rejected',
                      color: Color(0xFFFF1E1E),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: _AdminMetricCard(
                      value: '1',
                      label: 'Expired',
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _AdminOverviewHeader(),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: _AdminChartCard(
            axisLabel: 'Submission',
            title: 'Operator Task Submission',
            accentColor: Color(0xFF67D8FF),
            values: [0, 2, 1, 3.5, 2.8, 1, 4.2, 0, 1.8],
          ),
        ),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: _AdminChartCard(
            axisLabel: 'Reviews',
            title: 'Tasks Reviewed by QC',
            accentColor: Color(0xFF7CFF8A),
            values: [0, 2, 1, 3.5, 2.8, 1, 4.2, 0, 1.8],
          ),
        ),
        SizedBox(height: 30),
      ],
    );
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
  });

  final String axisLabel;
  final String title;
  final Color accentColor;
  final List<double> values;

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
      final y = originY - (widget.values[index] / 4.5) * chartHeight;
      final distance = (Offset(x, y) - position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestDistance <= 24 ? nearestIndex : null;
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
    required this.accentColor,
    required this.activePointIndex,
  });

  static const _leftInset = 26.0;
  static const _rightInset = 4.0;
  static const _bottomInset = 17.0;
  static const _topInset = 7.0;

  final List<double> values;
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

    for (final tick in [1, 2, 3, 4]) {
      final y = origin.dy - (tick / 4.5) * chartHeight;
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

    for (final tick in [1, 2, 3]) {
      final y = origin.dy - (tick / 4.5) * chartHeight;
      labelPainter.text = TextSpan(
        text: tick.toString(),
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
      final y = origin.dy - (values[index] / 4.5) * chartHeight;
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
        label: 'Point ${activeIndex + 1}',
        value: values[activeIndex],
      );
    }

    final monthLabels = ['W1', 'W2', 'W3'];
    for (var index = 0; index < monthLabels.length; index += 1) {
      final x = plotRect.left + (index / (monthLabels.length - 1)) * chartWidth;
      labelPainter.text = TextSpan(
        text: monthLabels[index],
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
      } else if (index == monthLabels.length - 1) {
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
        oldDelegate.accentColor != accentColor ||
        oldDelegate.activePointIndex != activePointIndex;
  }
}
