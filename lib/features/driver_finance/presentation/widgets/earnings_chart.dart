import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../driver/domain/driver_models.dart';

/// Daily earnings bar chart (custom painted). Tap a bar to see its value.
class EarningsBarChart extends StatefulWidget {
  const EarningsBarChart({super.key, required this.daily, required this.currency, required this.period});
  final List<DailyEarning> daily;
  final String currency;
  final String period;

  @override
  State<EarningsBarChart> createState() => _EarningsBarChartState();
}

class _EarningsBarChartState extends State<EarningsBarChart> {
  int? _selected;

  /// Fills missing days so the week view always shows 7 bars.
  List<DailyEarning> get _series {
    if (widget.period != 'week') return widget.daily;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return widget.daily.firstWhere(
        (e) => e.date.year == d.year && e.date.month == d.month && e.date.day == d.day,
        orElse: () => DailyEarning(date: d),
      );
    });
  }

  @override
  void didUpdateWidget(covariant EarningsBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final data = _series;
    if (data.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(child: Text('No completed trips in this period yet', style: AppText.bodySm)),
      );
    }
    final sel = _selected != null && _selected! < data.length ? data[_selected!] : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 22,
        child: sel == null
            ? Text('Tap a bar for details', style: AppText.caption)
            : Text(
                '${formatDate(sel.date)} · ${formatMoney(sel.earnings, currency: widget.currency)} · ${sel.trips} trip${sel.trips == 1 ? '' : 's'}',
                style: AppText.label.copyWith(color: AppColors.crimson),
              ),
      ),
      const SizedBox(height: AppSpace.xs),
      LayoutBuilder(builder: (context, c) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final slot = c.maxWidth / data.length;
            final i = (d.localPosition.dx / slot).floor().clamp(0, data.length - 1);
            setState(() => _selected = _selected == i ? null : i);
          },
          child: CustomPaint(
            size: Size(c.maxWidth, 170),
            painter: _BarsPainter(data: data, selected: _selected, labelEvery: data.length > 10 ? (data.length / 7).ceil() : 1),
          ),
        );
      }),
    ]);
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.data, required this.selected, required this.labelEvery});
  final List<DailyEarning> data;
  final int? selected;
  final int labelEvery;

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 20.0;
    final chartH = size.height - labelH;
    final maxV = data.map((e) => e.earnings).fold<double>(0, math.max);
    final slot = size.width / data.length;
    final barW = math.min(28.0, slot * 0.6);

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chartH * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var i = 0; i < data.length; i++) {
      final v = data[i].earnings;
      final h = maxV <= 0 ? 0.0 : (v / maxV) * (chartH - 8);
      final x = slot * i + (slot - barW) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, chartH - math.max(h, 3), barW, math.max(h, 3)),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      final isSel = selected == i;
      final paint = Paint()
        ..shader = (v <= 0
                ? const LinearGradient(colors: [AppColors.line, AppColors.line])
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isSel ? const [AppColors.deepRed, AppColors.deepRed] : const [AppColors.crimson, AppColors.deepRed],
                  ))
            .createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      if (i % labelEvery == 0 || isSel) {
        final label = data.length > 10 ? '${data[i].date.day}' : formatShortDay(data[i].date);
        final tp = TextPainter(
          text: TextSpan(text: label, style: AppText.caption.copyWith(fontSize: 11, color: isSel ? AppColors.crimson : AppColors.muted)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(slot * i + (slot - tp.width) / 2, chartH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.data != data || old.selected != selected;
}
