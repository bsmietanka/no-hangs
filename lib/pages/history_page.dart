import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import '../services/exercise_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DatabaseService _dbService = DatabaseService();
  final ExerciseService _exerciseService = ExerciseService();
  
  List<Exercise> _allExercises = [];
  List<String> _selectedExerciseIds = [];
  String _groupBy = 'day'; // 'session', 'day', 'week', 'month'
  bool _separateSides = false;
  String _selectedMetric = 'volume'; // 'volume', 'max_weight', 'median_weight'
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _allExercises = await _exerciseService.getExercises();
    
    // Select first exercise by default if available
    if (_allExercises.isNotEmpty && _selectedExerciseIds.isEmpty) {
      _selectedExerciseIds = [_allExercises.first.id];
    }
    
    await _loadHistoryData();
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadHistoryData() async {
    if (_selectedExerciseIds.isEmpty) {
      setState(() => _historyData = []);
      return;
    }
    
    final data = await _dbService.getHistoricalData(
      exerciseIds: _selectedExerciseIds,
      groupBy: _groupBy,
      separateSides: _separateSides,
    );
    
    setState(() => _historyData = data);
  }

  Future<void> _showExerciseSelector() async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return _ExerciseSelectorDialog(
          allExercises: _allExercises,
          selectedIds: _selectedExerciseIds,
        );
      },
    );

    if (selected != null) {
      setState(() => _selectedExerciseIds = selected);
      _loadHistoryData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildControls(),
                Expanded(child: _buildCharts()),
              ],
            ),
    );
  }

  Widget _buildControls() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise selector
            const Text('Exercises:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: () => _showExerciseSelector(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedExerciseIds.isEmpty
                          ? 'Select exercises...'
                          : _selectedExerciseIds.length == 1
                              ? _allExercises.firstWhere((e) => e.id == _selectedExerciseIds.first).name
                              : '${_selectedExerciseIds.length} exercises selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Metric and Group by selectors in a row
            Row(
              children: [
                // Metric selector
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Metric:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: _selectedMetric,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'volume', child: Text('Volume (kg·s)')),
                          DropdownMenuItem(value: 'max_weight', child: Text('Max Weight (kg)')),
                          DropdownMenuItem(value: 'median_weight', child: Text('Median Weight (kg)')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedMetric = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Group by selector
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Group by:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: _groupBy,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'session', child: Text('Session')),
                          DropdownMenuItem(value: 'day', child: Text('Day')),
                          DropdownMenuItem(value: 'week', child: Text('Week')),
                          DropdownMenuItem(value: 'month', child: Text('Month')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _groupBy = value);
                            _loadHistoryData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Separate sides toggle
            SwitchListTile(
              title: const Text('Show sides separately'),
              value: _separateSides,
              onChanged: (value) {
                setState(() => _separateSides = value);
                _loadHistoryData();
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts() {
    if (_historyData.isEmpty) {
      return const Center(
        child: Text('No data available. Complete some training sessions first!'),
      );
    }

    // Determine chart title and color based on selected metric
    String title;
    Color color;
    switch (_selectedMetric) {
      case 'max_weight':
        title = 'Max Weight (kg)';
        color = Colors.red;
        break;
      case 'median_weight':
        title = 'Median Weight (kg)';
        color = Colors.green;
        break;
      case 'volume':
      default:
        title = 'Volume (kg·s)';
        color = Colors.blue;
    }

    return SingleChildScrollView(
      child: _buildChart(title, _selectedMetric, color),
    );
  }

  Widget _buildChart(String title, String metricKey, Color color) {
    // Group data by exercise and side
    final Map<String, List<FlSpot>> seriesData = {};
    final Map<String, Color> seriesColors = {};
    
    for (int i = 0; i < _historyData.length; i++) {
      final point = _historyData[i];
      final exerciseName = point['exercise_name'] as String;
      final side = point['side'] as String;
      final value = (point[metricKey] as num?)?.toDouble() ?? 0.0;
      final timestamp = (point['first_session_time'] as int).toDouble();
      
      final seriesKey = _separateSides && side.isNotEmpty 
          ? '$exerciseName ($side)' 
          : exerciseName;
      
      seriesData.putIfAbsent(seriesKey, () => []);
      seriesData[seriesKey]!.add(FlSpot(timestamp, value));
      
      // Assign colors
      if (!seriesColors.containsKey(seriesKey)) {
        final baseColor = color;
        final hue = (seriesColors.length * 30) % 360;
        seriesColors[seriesKey] = HSVColor.fromAHSV(
          1.0,
          hue.toDouble(),
          0.7,
          baseColor.computeLuminance() > 0.5 ? 0.6 : 0.8,
        ).toColor();
      }
    }

    final lines = seriesData.entries.map((entry) {
      return LineChartBarData(
        spots: entry.value,
        isCurved: true,
        preventCurveOverShooting: true,
        color: seriesColors[entry.key],
        barWidth: 3,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  lineBarsData: lines,
                  minX: _getChartMinX(),
                  maxX: _getChartMaxX(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 86400000, // One day in milliseconds
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _formatTimestamp(value.toInt()),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  gridData: const FlGridData(show: true),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: seriesData.keys.map((key) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: seriesColors[key],
                    ),
                    const SizedBox(width: 4),
                    Text(key, style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  double _getChartMinX() {
    if (_historyData.isEmpty) return 0;
    
    final timestamps = _historyData.map((d) => d['first_session_time'] as int).toList();
    final minTimestamp = timestamps.reduce((a, b) => a < b ? a : b);
    final date = DateTime.fromMillisecondsSinceEpoch(minTimestamp);
    
    // Start of that day (00:00:00)
    final startOfDay = DateTime(date.year, date.month, date.day);
    return startOfDay.millisecondsSinceEpoch.toDouble();
  }

  double _getChartMaxX() {
    if (_historyData.isEmpty) return 86400000;
    
    final timestamps = _historyData.map((d) => d['first_session_time'] as int).toList();
    final maxTimestamp = timestamps.reduce((a, b) => a > b ? a : b);
    final date = DateTime.fromMillisecondsSinceEpoch(maxTimestamp);
    
    // End of that day (start of next day)
    final endOfDay = DateTime(date.year, date.month, date.day + 1);
    return endOfDay.millisecondsSinceEpoch.toDouble();
  }

  double? _calculateXAxisInterval() {
    // One day in milliseconds
    return 86400000.0;
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    
    switch (_groupBy) {
      case 'month':
        return '${date.month}/${date.year % 100}';
      case 'week':
      case 'day':
      case 'session':
      default:
        return '${date.day}/${date.month}';
    }
  }

  String _formatXAxisLabel(int index) {
    if (index >= _historyData.length) return '';
    
    final point = _historyData[index];
    final timeGroup = point['time_group'] as String;
    
    switch (_groupBy) {
      case 'day':
        // Format: "12/20"
        final parts = timeGroup.split('-');
        if (parts.length >= 3) {
          return '${parts[1]}/${parts[2]}';
        }
        return timeGroup;
      case 'week':
        // Format: "W50"
        return timeGroup.split('-').last;
      case 'month':
        // Format: "12/25"
        final parts = timeGroup.split('-');
        if (parts.length >= 2) {
          return '${parts[1]}/${parts[0].substring(2)}';
        }
        return timeGroup;
      case 'session':
      default:
        // Just show index number
        return '${index + 1}';
    }
  }
}

class _ExerciseSelectorDialog extends StatefulWidget {
  final List<Exercise> allExercises;
  final List<String> selectedIds;

  const _ExerciseSelectorDialog({
    required this.allExercises,
    required this.selectedIds,
  });

  @override
  State<_ExerciseSelectorDialog> createState() => _ExerciseSelectorDialogState();
}

class _ExerciseSelectorDialogState extends State<_ExerciseSelectorDialog> {
  late List<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Exercises'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.allExercises.map((exercise) {
            final isSelected = _tempSelected.contains(exercise.id);
            return CheckboxListTile(
              title: Text(exercise.name),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _tempSelected.add(exercise.id);
                  } else {
                    _tempSelected.remove(exercise.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_tempSelected),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
