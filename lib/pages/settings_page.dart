import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../services/database_service.dart';

class SettingsPage extends StatefulWidget {
  final int graphWindowSeconds;
  final Function(int) onGraphWindowChanged;
  final double repThreshold;
  final Function(double) onRepThresholdChanged;

  const SettingsPage({
    Key? key,
    required this.graphWindowSeconds,
    required this.onGraphWindowChanged,
    required this.repThreshold,
    required this.onRepThresholdChanged,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ExerciseService _exerciseService = ExerciseService();
  List<Exercise> _exercises = [];
  int _tempGraphWindow = 10;
  double _tempRepThreshold = 1.0;

  @override
  void initState() {
    super.initState();
    _tempGraphWindow = widget.graphWindowSeconds;
    _tempRepThreshold = widget.repThreshold;
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await _exerciseService.getExercises();
    setState(() {
      _exercises = exercises;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Graph Window Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Graph Window',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Window duration (seconds)'),
                  const SizedBox(height: 8),
                  DropdownButton<int>(
                    value: _tempGraphWindow,
                    isExpanded: true,
                    items: const [5, 10, 20, 30, 60]
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('$v seconds'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _tempGraphWindow = v);
                        widget.onGraphWindowChanged(v);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Rep Threshold Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rep Detection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Threshold weight (kg)'),
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '1.0',
                      suffixText: 'kg',
                      border: const OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: _tempRepThreshold.toStringAsFixed(1)),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed >= 0.1 && parsed <= 50.0) {
                        setState(() => _tempRepThreshold = parsed);
                        widget.onRepThresholdChanged(parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A rep is counted when weight exceeds this threshold.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Exercise Management
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Exercises',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final result = await _showAddExerciseDialog(context);
                          if (result != null && result['name']?.isNotEmpty == true) {
                            final newExercise = Exercise(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: result['name'],
                              isTwoSided: result['isTwoSided'] ?? false,
                            );
                            await _exerciseService.addExercise(newExercise);
                            await _loadExercises();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_exercises.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No exercises yet. Tap + to add one.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._exercises.map((exercise) => ListTile(
                          title: Text(exercise.name),
                          subtitle: exercise.isTwoSided
                              ? const Text('Two-sided')
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Exercise'),
                                  content: Text(
                                      'Are you sure you want to delete "${exercise.name}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await _exerciseService.deleteExercise(exercise.id);
                                await _loadExercises();
                              }
                            },
                          ),
                          contentPadding: EdgeInsets.zero,
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Danger Zone
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danger Zone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear All Data'),
                          content: const Text(
                              'This will delete all exercises and settings. Session history will be preserved. This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text(
                                'Clear All',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        await _loadExercises();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All data cleared'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.warning),
                    label: const Text('Clear All Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete All Session Data'),
                          content: const Text(
                              'This will permanently delete all training session history and reps. Personal bests will be reset. This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text(
                                'Delete All Sessions',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final dbService = DatabaseService();
                        await dbService.deleteAllSessions();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All session data deleted'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete All Sessions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showAddExerciseDialog(BuildContext context) async {
    final controller = TextEditingController();
    bool isTwoSided = false;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Exercise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  hintText: 'e.g., Half Crimp',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Two-sided exercise'),
                subtitle: const Text('Enable L/R toggle'),
                value: isTwoSided,
                onChanged: (value) => setState(() => isTwoSided = value ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop({
                'name': controller.text,
                'isTwoSided': isTwoSided,
              }),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
