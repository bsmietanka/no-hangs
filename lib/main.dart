import 'package:flutter/material.dart';
import 'widgets/ble_connect_widget.dart';
import 'widgets/measurement_widget.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'models/exercise.dart';
import 'services/exercise_service.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Minimal home page: show BLE connection widget
  BluetoothDevice? _connectedDevice;
  final ValueNotifier<bool> _lastCmdAck = ValueNotifier(false);
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
  }
  
  Future<void> _loadExercises() async {
    final exercises = await _exerciseService.getExercises();
    final selected = await _exerciseService.getSelectedExercise();
    setState(() {
      _exercises = exercises;
      _selectedExercise = selected ?? (exercises.isNotEmpty ? exercises.first : null);
    });
    if (_selectedExercise != null) {
      await _exerciseService.setSelectedExercise(_selectedExercise!.id);
    }
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
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
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
                  MaterialPageRoute(
                    builder: (ctx) => const HistoryPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => SettingsPage(
                      graphWindowSeconds: _graphWindowSeconds,
                      onGraphWindowChanged: (value) {
                        setState(() {
                          _graphWindowSeconds = value;
                        });
                      },
                      repThreshold: _repThreshold,
                      onRepThresholdChanged: (value) {
                        setState(() {
                          _repThreshold = value;
                        });
                        _measurementKey.currentState?.updateRepThreshold(value);
                      },
                    ),
                  ),
                ).then((_) => _loadExercises()); // Reload exercises when returning
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
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  'Exercise:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _exercises.isEmpty
                      ? const Text('No exercises available')
                      : DropdownButton<Exercise>(
                          value: _selectedExercise,
                          isExpanded: true,
                          items: _exercises
                              .map((ex) => DropdownMenuItem(
                                    value: ex,
                                    child: Text(ex.name),
                                  ))
                              .toList(),
                          onChanged: (ex) async {
                            if (ex != null && ex.id != _selectedExercise?.id) {
                              // Check if there are unsaved reps
                              final hasUnsavedReps = _measurementKey.currentState?.hasUnsavedReps() ?? false;
                              
                              if (hasUnsavedReps) {
                                final shouldSave = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Save session?'),
                                    content: const Text('You have unsaved reps. Would you like to save this session before switching exercises?'),
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
                                _selectedExercise = ex;
                                _currentSide = 'L'; // Reset to left when changing exercise
                              });
                              await _exerciseService.setSelectedExercise(ex.id);
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
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
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
            ),
          ),
        ],
      ),

    );
  }
}
