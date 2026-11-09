import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';

/// One series of a [DayChart]: bars or a 2px line with dots.
class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.values,
    required this.color,
    this.asBars = false,
    this.barColors,
  });

  final String label;
  final List<double?> values;
  final Color color;
  final bool asBars;

  /// Optional per-bar color (e.g. by planned action).
  final List<Color>? barColors;
}

/// Small single-axis chart over the days of the planning. Tapping a day
/// shows its values.
class DayChart extends StatefulWidget {
  const DayChart({
    super.key,
    required this.labels,
    required this.series,
    required this.unit,
    this.fixedMax,
    this.format,
    this.height = 170,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final String unit;

  /// Forces the axis maximum (e.g. 100 for a percentage).
  final double? fixedMax;
  final String Function(double value)? format;
  final double height;

  @override
  State<DayChart> createState() => _DayChartState();
}

class _DayChartState extends State<DayChart> {
  int? _selected;

  String _fmt(double v) =>
      widget.format?.call(v) ??
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}'
          ' ${widget.unit}';

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final index = _ChartPainter.indexAt(
                details.localPosition.dx,
                constraints.maxWidth,
                widget.labels.length,
              );
              setState(() => _selected = index == _selected ? null : index);
            },
            child: CustomPaint(
              size: Size(constraints.maxWidth, widget.height),
              painter: _ChartPainter(
                labels: widget.labels,
                series: widget.series,
                fixedMax: widget.fixedMax,
                unit: widget.unit,
                selected: selected,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (selected != null && selected < widget.labels.length)
          Text(
            '${widget.labels[selected]} · ${[for (final s in widget.series)
              if (selected < s.values.length) '${s.label} : ${s.values[selected] == null ? '—' : _fmt(s.values[selected]!)}'].join(' · ')}',
            style: const TextStyle(
              color: inkGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          )
        else
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (widget.series.length > 1)
                for (final s in widget.series)
                  _LegendItem(label: s.label, color: s.color, bar: s.asBars),
              const Text(
                'Touchez un jour pour voir les valeurs',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    required this.bar,
  });

  final String label;
  final Color color;
  final bool bar;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: bar ? 10 : 14,
        height: bar ? 10 : 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          color: inkGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.labels,
    required this.series,
    required this.fixedMax,
    required this.unit,
    required this.selected,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final double? fixedMax;
  final String unit;
  final int? selected;

  static const _left = 44.0;
  static const _bottom = 22.0;
  static const _top = 8.0;

  static int? indexAt(double dx, double width, int count) {
    if (count == 0 || dx < _left) return null;
    final slot = (width - _left) / count;
    return ((dx - _left) / slot).floor().clamp(0, count - 1);
  }

  /// 1, 2, 2.5 or 5 × 10ⁿ above [value].
  static double _niceMax(double value) {
    if (value <= 0) return 1;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor());
    for (final step in [1, 2, 2.5, 5, 10]) {
      if (step * magnitude >= value) return step * magnitude.toDouble();
    }
    return 10 * magnitude.toDouble();
  }

  static String _axisLabel(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    TextAlign align = TextAlign.center,
    Color color = mutedGreen,
    FontWeight weight = FontWeight.w500,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - painter.width,
      TextAlign.left => at.dx,
      _ => at.dx - painter.width / 2,
    };
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = labels.length;
    if (count == 0) return;
    final plot = Rect.fromLTRB(_left, _top, size.width, size.height - _bottom);
    final values = [
      for (final s in series)
        for (final v in s.values) ?v,
    ];
    final maxValue =
        fixedMax ?? _niceMax(values.isEmpty ? 1 : values.reduce(math.max));
    double y(double v) => plot.bottom - (v / maxValue) * plot.height;
    final slot = plot.width / count;
    double cx(int i) => plot.left + slot * (i + .5);

    // Recessive grid: 4 lines, labels in muted ink.
    final grid = Paint()
      ..color = borderGreen
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = maxValue * i / 4;
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), grid);
      _text(
        canvas,
        i == 4 ? '${_axisLabel(v)} $unit' : _axisLabel(v),
        Offset(plot.left - 6, y(v)),
        align: TextAlign.right,
      );
    }

    if (selected != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            plot.left + slot * selected!,
            plot.top,
            slot,
            plot.height,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0x1416351B),
      );
    }

    for (var i = 0; i < count; i++) {
      _text(
        canvas,
        labels[i],
        Offset(cx(i), size.height - _bottom / 2),
        color: i == selected ? inkGreen : mutedGreen,
        weight: i == selected ? FontWeight.w800 : FontWeight.w500,
      );
    }

    // Bars of several series sit side by side in the day's slot.
    final barSeries = series.where((s) => s.asBars).toList();
    final barWidth = math.min(18.0, (slot - 8) / math.max(1, barSeries.length));
    for (var b = 0; b < barSeries.length; b++) {
      final s = barSeries[b];
      for (var i = 0; i < count && i < s.values.length; i++) {
        final v = s.values[i];
        if (v == null) continue;
        final left = cx(i) - barWidth * barSeries.length / 2 + barWidth * b + 1;
        final rect = Rect.fromLTRB(
          left,
          math.min(y(v), plot.bottom - 2), // a zero still shows a sliver
          left + barWidth - 2, // 2px gap between adjacent bars
          plot.bottom,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = s.barColors?[i] ?? s.color,
        );
      }
    }

    for (final s in series.where((s) => !s.asBars)) {
      final points = [
        for (var i = 0; i < count && i < s.values.length; i++)
          if (s.values[i] != null) Offset(cx(i), y(s.values[i]!)),
      ];
      if (points.isEmpty) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
      for (final p in points) {
        canvas.drawCircle(p, 5, Paint()..color = Colors.white); // surface ring
        canvas.drawCircle(p, 3.5, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.selected != selected ||
      old.labels != labels ||
      old.series != series ||
      old.fixedMax != fixedMax;
}
