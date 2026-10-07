import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/weight_entry.dart';
import '../services/settings_storage.dart';
import '../services/weight_storage.dart';
import '../widgets/add_weight_sheet.dart';
import '../widgets/weight_chart.dart';
import 'settings_screen.dart';

enum ChartRange { week, month, threeMonths, year, all }

extension ChartRangeX on ChartRange {
  String get label => switch (this) {
        ChartRange.week => '1W',
        ChartRange.month => '1M',
        ChartRange.threeMonths => '3M',
        ChartRange.year => '1Y',
        ChartRange.all => 'All',
      };

  int? get days => switch (this) {
        ChartRange.week => 7,
        ChartRange.month => 30,
        ChartRange.threeMonths => 90,
        ChartRange.year => 365,
        ChartRange.all => null,
      };
}

class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen> {
  final _storage = WeightStorage();
  final _settingsStorage = SettingsStorage();

  List<WeightEntry> _entries = const [];
  AppSettings _settings = const AppSettings();
  ChartRange _range = ChartRange.month;
  bool _showMovingAverage = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _storage.loadEntries();
    final settings = await _settingsStorage.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _settings = settings;
      _loading = false;
    });
  }

  List<WeightEntry> get _filteredEntries {
    final days = _range.days;
    if (days == null) return _entries;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _entries.where((e) => !e.date.isBefore(cutoff)).toList();
  }

  Future<void> _addEntry() async {
    final entry = await showModalBottomSheet<WeightEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddWeightSheet(),
    );
    if (entry == null) return;

    final updated = [..._entries, entry]
      ..sort((a, b) => a.date.compareTo(b.date));
    await _storage.saveEntries(updated);
    if (!mounted) return;
    setState(() => _entries = updated);
  }

  Future<void> _editEntry(WeightEntry entry) async {
    final result = await showModalBottomSheet<WeightEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddWeightSheet(initial: entry),
    );
    if (result == null) return;

    final updated = _entries
        .map((e) => e.id == result.id ? result : e)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    await _storage.saveEntries(updated);
    if (!mounted) return;
    setState(() => _entries = updated);
  }

  Future<void> _deleteEntry(WeightEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          '${entry.weight.toStringAsFixed(1)} kg — '
          '${DateFormat('d MMM yyyy').format(entry.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = _entries.where((e) => e.id != entry.id).toList();
    await _storage.saveEntries(updated);
    if (!mounted) return;
    setState(() => _entries = updated);
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(builder: (_) => SettingsScreen(settings: _settings)),
    );
    if (result == null) return;
    await _settingsStorage.save(result);
    if (!mounted) return;
    setState(() => _settings = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        tooltip: 'Add weight',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const _EmptyState()
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [..._entries]..sort((a, b) => a.date.compareTo(b.date));
    final filtered = _filteredEntries;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _SummaryCard(
          latest: sorted.last,
          rangeEntries: filtered,
          range: _range,
          goalWeight: _settings.goalWeight,
        ),
        const SizedBox(height: 12),
        _InsightsCard(
          entries: filtered,
          heightCm: _settings.heightCm,
          latestWeight: sorted.last.weight,
        ),
        const SizedBox(height: 20),

        _RangeSelector(
          range: _range,
          onChanged: (r) => setState(() => _range = r),
        ),
        const SizedBox(height: 12),

        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    children: [
                      Text('Trend', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      if (_settings.goalWeight != null) ...[
                        Container(width: 16, height: 2, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text('Goal', style: theme.textTheme.bodySmall),
                        const SizedBox(width: 12),
                      ],
                      Container(
                        width: 16,
                        height: 2,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text('Avg', style: theme.textTheme.bodySmall),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _showMovingAverage
                              ? Icons.show_chart
                              : Icons.timeline,
                          size: 20,
                        ),
                        tooltip: _showMovingAverage
                            ? 'Hide moving average'
                            : 'Show moving average',
                        onPressed: () => setState(
                            () => _showMovingAverage = !_showMovingAverage),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 240,
                  child: filtered.length < 2
                      ? const _NotEnoughData()
                      : WeightChart(
                          entries: filtered,
                          goalWeight: _settings.goalWeight,
                          showMovingAverage: _showMovingAverage,
                        ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text('History', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...sorted.reversed.map(
          (entry) => _EntryTile(
            entry: entry,
            onTap: () => _editEntry(entry),
            onDelete: () => _deleteEntry(entry),
          ),
        ),
      ],
    );
  }
}

// ---------- Range selector ----------

class _RangeSelector extends StatelessWidget {
  final ChartRange range;
  final ValueChanged<ChartRange> onChanged;

  const _RangeSelector({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ChartRange>(
        segments: ChartRange.values
            .map((r) => ButtonSegment(value: r, label: Text(r.label)))
            .toList(),
        selected: {range},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

// ---------- Summary ----------

class _SummaryCard extends StatelessWidget {
  final WeightEntry latest;
  final List<WeightEntry> rangeEntries;
  final ChartRange range;
  final double? goalWeight;

  const _SummaryCard({
    required this.latest,
    required this.rangeEntries,
    required this.range,
    required this.goalWeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double? change;
    if (rangeEntries.length >= 2) {
      change = rangeEntries.last.weight - rangeEntries.first.weight;
    }
    final hasChange = change != null && change.abs() >= 0.05;
    final up = (change ?? 0) > 0;
    final changeColor = up
        ? theme.colorScheme.error
        : (theme.brightness == Brightness.dark
            ? Colors.green.shade400
            : Colors.green.shade700);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current weight',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${latest.weight.toStringAsFixed(1)} kg',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d MMM yyyy').format(latest.date),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (hasChange)
                  Column(
                    children: [
                      Icon(
                        up ? Icons.trending_up : Icons.trending_down,
                        color: changeColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${up ? '+' : ''}${change!.toStringAsFixed(1)} kg',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: changeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(range.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            if (goalWeight != null) ...[
              const SizedBox(height: 16),
              _GoalProgress(current: latest.weight, goal: goalWeight!),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  final double current;
  final double goal;

  const _GoalProgress({required this.current, required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = current - goal;
    final reached = diff.abs() < 0.1;

    final String text;
    if (reached) {
      text = 'Goal reached!';
    } else if (diff > 0) {
      text = '${diff.toStringAsFixed(1)} kg to lose';
    } else {
      text = '${(-diff).toStringAsFixed(1)} kg to gain';
    }

    return Row(
      children: [
        Icon(Icons.flag_outlined, size: 16, color: Colors.orange.shade400),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          'Goal ${goal.toStringAsFixed(1)} kg',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------- Insights (BMI + stats) ----------

class _InsightsCard extends StatelessWidget {
  final List<WeightEntry> entries;
  final double? heightCm;
  final double latestWeight;

  const _InsightsCard({
    required this.entries,
    required this.heightCm,
    required this.latestWeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _Stats.from(entries);

    final bmi = (heightCm == null || heightCm! <= 0)
        ? null
        : latestWeight / math.pow(heightCm! / 100, 2);

    final items = <_InsightItem>[];

    if (bmi != null) {
      final (label, color) = _bmiCategory(bmi);
      items.add(_InsightItem(
        label: 'BMI',
        value: bmi.toStringAsFixed(1),
        subtitle: label,
        valueColor: color,
      ));
    }
    if (stats.avg7 != null) {
      items.add(_InsightItem(
        label: '7-day avg',
        value: '${stats.avg7!.toStringAsFixed(1)} kg',
      ));
    }
    if (stats.avg30 != null) {
      items.add(_InsightItem(
        label: '30-day avg',
        value: '${stats.avg30!.toStringAsFixed(1)} kg',
      ));
    }
    if (stats.average != null) {
      items.add(_InsightItem(
        label: 'Average',
        value: '${stats.average!.toStringAsFixed(1)} kg',
      ));
    }
    if (stats.min != null) {
      items.add(_InsightItem(
        label: 'Min',
        value: '${stats.min!.toStringAsFixed(1)} kg',
      ));
    }
    if (stats.max != null) {
      items.add(_InsightItem(
        label: 'Max',
        value: '${stats.max!.toStringAsFixed(1)} kg',
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Insights', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items
                      .map((i) => SizedBox(
                            width: tileWidth,
                            child: _InsightTile(item: i),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static (String, Color) _bmiCategory(double bmi) {
    if (bmi < 18.5) return ('Underweight', Colors.blue.shade400);
    if (bmi < 25) return ('Normal', Colors.green.shade500);
    if (bmi < 30) return ('Overweight', Colors.orange.shade500);
    return ('Obese', Colors.red.shade400);
  }
}

class _InsightItem {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  const _InsightItem({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });
}

class _InsightTile extends StatelessWidget {
  final _InsightItem item;

  const _InsightTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: item.valueColor,
            ),
          ),
          if (item.subtitle != null)
            Text(
              item.subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: item.valueColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats {
  final double? average;
  final double? min;
  final double? max;
  final double? avg7;
  final double? avg30;

  const _Stats({this.average, this.min, this.max, this.avg7, this.avg30});

  factory _Stats.from(List<WeightEntry> entries) {
    if (entries.isEmpty) return const _Stats();
    final weights = entries.map((e) => e.weight).toList();
    final now = DateTime.now();
    final last7 = entries
        .where((e) => now.difference(e.date).inDays <= 7)
        .toList();
    final last30 = entries
        .where((e) => now.difference(e.date).inDays <= 30)
        .toList();

    double avgOf(List<WeightEntry> l) =>
        l.map((e) => e.weight).reduce((a, b) => a + b) / l.length;

    return _Stats(
      average: avgOf(entries),
      min: weights.reduce(math.min),
      max: weights.reduce(math.max),
      avg7: last7.isEmpty ? null : avgOf(last7),
      avg30: last30.isEmpty ? null : avgOf(last30),
    );
  }
}

// ---------- History ----------

class _EntryTile extends StatelessWidget {
  final WeightEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNotes = entry.notes != null && entry.notes!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.monitor_weight_outlined,
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          '${entry.weight.toStringAsFixed(1)} kg',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE, d MMM yyyy').format(entry.date)),
            if (hasNotes)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  entry.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: onDelete,
        ),
      ),
    );
  }
}

// ---------- Empty / short states ----------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('No entries yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap + to log your first weight.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotEnoughData extends StatelessWidget {
  const _NotEnoughData();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Not enough data in this range.\n'
          'Add more entries or pick a wider range.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}