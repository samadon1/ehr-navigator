import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// A reusable chart widget for displaying vital signs and lab trends over time
class TrendChart extends StatelessWidget {
  final String title;
  final String? unit;
  final List<Map<String, dynamic>> dataPoints;
  final Color? lineColor;
  final double? referenceLineValue;
  final String? referenceLabelLow;
  final String? referenceLabelHigh;
  final double? referenceLowValue;
  final double? referenceHighValue;
  final bool showDots;
  final double height;

  const TrendChart({
    super.key,
    required this.title,
    required this.dataPoints,
    this.unit,
    this.lineColor,
    this.referenceLineValue,
    this.referenceLabelLow,
    this.referenceLabelHigh,
    this.referenceLowValue,
    this.referenceHighValue,
    this.showDots = true,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return _buildEmptyState(context);
    }

    final theme = Theme.of(context);
    final chartColor = lineColor ?? theme.colorScheme.primary;

    // Parse data points
    final spots = <FlSpot>[];
    final dates = <DateTime>[];

    for (int i = 0; i < dataPoints.length; i++) {
      final dp = dataPoints[i];
      final value = dp['value'] as num?;
      final dateStr = dp['date'] as String?;

      if (value != null && dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          spots.add(FlSpot(i.toDouble(), value.toDouble()));
          dates.add(date);
        }
      }
    }

    if (spots.isEmpty) {
      return _buildEmptyState(context);
    }

    // Calculate min/max for Y axis
    final values = spots.map((s) => s.y).toList();
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);

    // Include reference lines in range calculation
    if (referenceLowValue != null) {
      minY = minY < referenceLowValue! ? minY : referenceLowValue!;
    }
    if (referenceHighValue != null) {
      maxY = maxY > referenceHighValue! ? maxY : referenceHighValue!;
    }

    // Add padding to Y range
    final yRange = maxY - minY;
    final padding = yRange == 0 ? 10 : yRange * 0.1;
    minY -= padding;
    maxY += padding;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit != null)
                  Text(
                    unit!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatsSummary(context, values),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yRange > 0 ? yRange / 4 : 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: spots.length > 6 ? (spots.length / 4).ceil().toDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= dates.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('M/d').format(dates[index]),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: chartColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: showDots,
                        getDotPainter: (spot, percent, barData, index) {
                          final isAbnormal = _isAbnormal(spot.y);
                          return FlDotCirclePainter(
                            radius: 4,
                            color: isAbnormal ? Colors.red : chartColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: chartColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: _buildReferenceLines(theme),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.surface,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final date = index < dates.length
                              ? DateFormat('MMM d, y').format(dates[index])
                              : '';
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)} ${unit ?? ''}\n$date',
                            TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Icon(
              Icons.show_chart,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'No data available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary(BuildContext context, List<double> values) {
    if (values.isEmpty) return const SizedBox.shrink();

    final latest = values.last;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;
    final trend = values.length > 1
        ? (values.last > values.first ? 'trending up' : values.last < values.first ? 'trending down' : 'stable')
        : '';

    final theme = Theme.of(context);
    final isLatestAbnormal = _isAbnormal(latest);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildStatChip(
          context,
          'Latest',
          latest.toStringAsFixed(1),
          isHighlighted: true,
          isWarning: isLatestAbnormal,
        ),
        _buildStatChip(context, 'Min', min.toStringAsFixed(1)),
        _buildStatChip(context, 'Max', max.toStringAsFixed(1)),
        _buildStatChip(context, 'Avg', avg.toStringAsFixed(1)),
        if (trend.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                trend == 'trending up'
                    ? Icons.trending_up
                    : trend == 'trending down'
                        ? Icons.trending_down
                        : Icons.trending_flat,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    String label,
    String value, {
    bool isHighlighted = false,
    bool isWarning = false,
  }) {
    final theme = Theme.of(context);
    final bgColor = isWarning
        ? Colors.red.withOpacity(0.1)
        : isHighlighted
            ? theme.colorScheme.primary.withOpacity(0.1)
            : theme.colorScheme.surface;
    final textColor = isWarning
        ? Colors.red
        : isHighlighted
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  List<HorizontalLine> _buildReferenceLines(ThemeData theme) {
    final lines = <HorizontalLine>[];

    if (referenceLowValue != null) {
      lines.add(HorizontalLine(
        y: referenceLowValue!,
        color: Colors.orange.withOpacity(0.5),
        strokeWidth: 1,
        dashArray: [5, 5],
        label: HorizontalLineLabel(
          show: true,
          labelResolver: (_) => referenceLabelLow ?? 'Low',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 10,
          ),
        ),
      ));
    }

    if (referenceHighValue != null) {
      lines.add(HorizontalLine(
        y: referenceHighValue!,
        color: Colors.orange.withOpacity(0.5),
        strokeWidth: 1,
        dashArray: [5, 5],
        label: HorizontalLineLabel(
          show: true,
          labelResolver: (_) => referenceLabelHigh ?? 'High',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 10,
          ),
        ),
      ));
    }

    return lines;
  }

  bool _isAbnormal(double value) {
    if (referenceLowValue != null && value < referenceLowValue!) return true;
    if (referenceHighValue != null && value > referenceHighValue!) return true;
    return false;
  }
}

/// Widget to display multiple trends side by side (e.g., Blood Pressure)
class MultiTrendChart extends StatelessWidget {
  final String title;
  final List<TrendSeries> series;
  final double height;

  const MultiTrendChart({
    super.key,
    required this.title,
    required this.series,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty || series.every((s) => s.dataPoints.isEmpty)) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Icon(Icons.show_chart, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 8),
              Text('No data available', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    // Parse all series data
    final allSpots = <LineChartBarData>[];
    final dates = <DateTime>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final s in series) {
      final spots = <FlSpot>[];
      for (int i = 0; i < s.dataPoints.length; i++) {
        final dp = s.dataPoints[i];
        final value = dp['value'] as num?;
        final dateStr = dp['date'] as String?;

        if (value != null && dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            spots.add(FlSpot(i.toDouble(), value.toDouble()));
            if (dates.length <= i) dates.add(date);
            if (value < minY) minY = value.toDouble();
            if (value > maxY) maxY = value.toDouble();
          }
        }
      }

      if (spots.isNotEmpty) {
        allSpots.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: s.color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: s.color,
                strokeWidth: 1,
                strokeColor: Colors.white,
              );
            },
          ),
        ));
      }
    }

    if (allSpots.isEmpty) {
      return const SizedBox.shrink();
    }

    // Add padding
    final yRange = maxY - minY;
    final padding = yRange == 0 ? 10 : yRange * 0.1;
    minY -= padding;
    maxY += padding;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Legend
            Wrap(
              spacing: 16,
              children: series.map((s) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(s.name, style: theme.textTheme.bodySmall),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yRange > 0 ? yRange / 4 : 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: dates.length > 6 ? (dates.length / 4).ceil().toDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= dates.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('M/d').format(dates[index]),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toStringAsFixed(0),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (dates.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: allSpots,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.surface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single series in a multi-trend chart
class TrendSeries {
  final String name;
  final Color color;
  final List<Map<String, dynamic>> dataPoints;

  const TrendSeries({
    required this.name,
    required this.color,
    required this.dataPoints,
  });
}
