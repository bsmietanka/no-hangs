import 'package:flutter/material.dart';
import 'widgets/ble_connect_widget.dart';
import 'widgets/measurement_widget.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'models/exercise.dart';
import 'services/exercise_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/history_page.dart';
import 'pages/sessions_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _themeService.getThemeMode();
    setState(() => _themeMode = mode);
  }

  void _updateThemeMode(ThemeMode mode) async {
    await _themeService.setThemeMode(mode);
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'No Hangs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      home: MyHomePage(
        title: 'No Hangs',
        onThemeModeChanged: _updateThemeMode,
        currentThemeMode: _themeMode,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.onThemeModeChanged,
    required this.currentThemeMode,
  });

  final String title;
  final Function(ThemeMode) onThemeModeChanged;
  final ThemeMode currentThemeMode;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Minimal home page: show BLE connection widget
  BluetoothDevice? _connectedDevice;
  final ValueNotifier<bool> _lastCmdAck = ValueNotifier(false);
  static const String _graphWindowKey = 'graph_window_seconds';
  static const String _repThresholdKey = 'rep_threshold';

  int _graphWindowSeconds = 10;
  double _repThreshold = 1.0;

  final ExerciseService _exerciseService = ExerciseService();
  List<Exercise> _exercises = [];
  Exercise? _selectedExercise;
  String _currentSide = 'L'; // 'L' or 'R' for two-sided exercises
  final GlobalKey<MeasurementWidgetState> _measurementKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final gw = prefs.getInt(_graphWindowKey) ?? _graphWindowSeconds;
    final rt = prefs.getDouble(_repThresholdKey) ?? _repThreshold;
    setState(() {
      _graphWindowSeconds = gw;
      _repThreshold = rt;
    });
    // propagate threshold to measurement widget
    _measurementKey.currentState?.updateRepThreshold(_repThreshold);
  }

  Future<void> _saveGraphWindow(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_graphWindowKey, seconds);
  }

  Future<void> _saveRepThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_repThresholdKey, threshold);
  }

  Future<void> _loadExercises() async {
    final exercises = await _exerciseService.getExercises();
    final selected = await _exerciseService.getSelectedExercise();
    setState(() {
      _exercises = exercises;
      _selectedExercise =
          selected ?? (exercises.isNotEmpty ? exercises.first : null);
    });
    if (_selectedExercise != null) {
      await _exerciseService.setSelectedExercise(_selectedExercise!.id);
    }
  }

  Future<void> _switchExercise(
    Exercise newExercise, {
    bool showSaveDialog = false,
  }) async {
    if (newExercise.id == _selectedExercise?.id) return;

    // Check for unsaved data
    final hasUnsavedReps =
        _measurementKey.currentState?.hasUnsavedReps() ?? false;

    if (hasUnsavedReps) {
      // Always show dialog when there are unsaved reps (both dropdown and swipe)
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save session?'),
          content: const Text(
            'You have unsaved reps. Would you like to save this session before switching exercises?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (shouldSave == true) {
        await _measurementKey.currentState?.saveSession();
      }
    }

    setState(() {
      _selectedExercise = newExercise;
      _currentSide = 'L'; // Reset to left when changing exercise
    });
    await _exerciseService.setSelectedExercise(newExercise.id);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('No Hangs'),
        actions: [
          BleConnectWidget(
            onConnectionChanged: (d) => setState(() => _connectedDevice = d),
            ackNotifier: _lastCmdAck,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.fitness_center, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'No Hangs',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: true,
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const HistoryPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Sessions'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const SessionsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (ctx) => SettingsPage(
                          graphWindowSeconds: _graphWindowSeconds,
                          onGraphWindowChanged: (value) {
                            setState(() {
                              _graphWindowSeconds = value;
                            });
                            _saveGraphWindow(value);
                          },
                          repThreshold: _repThreshold,
                          onRepThresholdChanged: (value) {
                            setState(() {
                              _repThreshold = value;
                            });
                            _measurementKey.currentState?.updateRepThreshold(
                              value,
                            );
                            _saveRepThreshold(value);
                          },
                          currentThemeMode: widget.currentThemeMode,
                          onThemeModeChanged: widget.onThemeModeChanged,
                        ),
                      ),
                    )
                    .then(
                      (_) => _loadExercises(),
                    ); // Reload exercises when returning
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Exercise selection
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.1 * 255).round()),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  'Exercise:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _exercises.isEmpty
                      ? const Text('No exercises available')
                      : DropdownButton<Exercise>(
                          value: _selectedExercise,
                          isExpanded: true,
                          items: _exercises
                              .map(
                                (ex) => DropdownMenuItem(
                                  value: ex,
                                  child: Text(ex.name),
                                ),
                              )
                              .toList(),
                          onChanged: (ex) async {
                            if (ex != null) {
                              await _switchExercise(ex, showSaveDialog: true);
                            }
                          },
                        ),
                ),
                if (_selectedExercise?.isTwoSided == true) ...[
                  const SizedBox(width: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'L', label: Text('L')),
                      ButtonSegment(value: 'R', label: Text('R')),
                    ],
                    selected: {_currentSide},
                    onSelectionChanged: (Set<String> selected) {
                      setState(() => _currentSide = selected.first);
                    },
                    style: ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: MeasurementWidget(
              key: _measurementKey,
              device: _connectedDevice,
              ackNotifier: _lastCmdAck,
              graphWindowSeconds: _graphWindowSeconds,
              selectedExercise: _selectedExercise,
              currentSide: _currentSide,
              exercises: _exercises,
              onExerciseSwitch: (exercise) => _switchExercise(exercise),
            ),
          ),
        ],
      ),
    );
  }
}
