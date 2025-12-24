import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../models/exercise.dart';
import '../services/database_service.dart';
import '../services/rep_detection_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// Simple measurement container (weight in kg, timestamp in microseconds)
class MeasurementSample {
  final double weight;
  final int useconds;
  final DateTime receivedAt; // local arrival timestamp
  MeasurementSample(this.weight, this.useconds) : receivedAt = DateTime.now();
}

/// Minimal measurement widget: subscribes to the Progressor "Data" characteristic
/// and maintains a small in-memory buffer of recent weight readings. Shows the
/// last measurement on screen.
class MeasurementWidget extends StatefulWidget {
  final BluetoothDevice? device;
  final int bufferSize;
  final ValueNotifier<bool>? ackNotifier;
  final int graphWindowSeconds;
  final Exercise? selectedExercise;
  final String currentSide;
  final List<Exercise> exercises;
  final Function(Exercise)? onExerciseSwitch;

  const MeasurementWidget({
    super.key,
    required this.device,
    this.bufferSize = 100,
    this.ackNotifier,
    this.graphWindowSeconds = 10,
    this.selectedExercise,
    this.currentSide = 'L',
    this.exercises = const [],
    this.onExerciseSwitch,
  });

  @override
  State<MeasurementWidget> createState() => MeasurementWidgetState();
}

class MeasurementWidgetState extends State<MeasurementWidget> {
  // Data characteristic UUID (from the Python example)
  static final Guid _dataCharUuid = Guid('7e4e1702-1ea6-40c9-9dcc-13d34ffead57');
  static const int _resWeightMeas = 1;

  final List<MeasurementSample> _buffer = [];
  BluetoothCharacteristic? _dataChar;
  StreamSubscription<List<int>>? _charSub;
  Timer? _ackTimer;
  // Graph window duration in seconds (default will be passed from parent)
  int _graphWindowSeconds = 10;
  // Adaptive Y-axis max (kg). Start at 40kg and grow if higher values are seen.
  
  // Public methods for parent widget
  bool hasUnsavedReps() {
    return _sessionService.hasUnsavedData;
  }
  
  Future<void> saveSession() async {
    await _saveSession();
  }
  static const double _initialMaxWeight = 5.0;
  double _maxWeight = _initialMaxWeight;
  
  // Repetition tracking
  late RepDetectionService _repDetector;
  final SessionService _sessionService = SessionService();
  DateTime? _lastRepTime; // Track when last rep was completed
  Timer? _timeSinceRepTimer; // Timer to update UI every second
  double? _personalBest; // Historical best for this exercise
  double? _personalBestL; // PB for left side
  double? _personalBestR; // PB for right side
  double? _targetWeight; // Target weight in kg
  bool _targetIsPercentage = true; // Toggle between % and kg
  double _targetPercentage = 100.0; // Target as % of PB (0-100%)
  final TextEditingController _targetInputController = TextEditingController();
  final FocusNode _targetInputFocus = FocusNode();
  final DatabaseService _databaseService = DatabaseService();
  
  // Public method to update rep threshold from settings
  void updateRepThreshold(double threshold) {
    setState(() {
      _repDetector.threshold = threshold;
    });
  }
  
  @override
  void initState() {
    super.initState();
    
    // Initialize rep detection service
    _repDetector = RepDetectionService(
      threshold: 1.0,
      onRepCompleted: (rep) {
        setState(() {
          _sessionService.addRep(rep);
          _lastRepTime = rep.endTime;
        });
        debugPrint('Rep completed: peak=${rep.peakWeight.toStringAsFixed(2)} kg, avg=${rep.avgWeight.toStringAsFixed(2)} kg, median=${rep.medianWeight.toStringAsFixed(2)} kg, side=${rep.side}, duration=${rep.endTime.difference(rep.startTime).inMilliseconds}ms');
      },
    );
    
    if (widget.device != null) {
      _sessionService.startSession();
      _loadPersonalBest();
      _discoverAndSubscribe();
    }
    // Start timer to update time since last rep every second
    _timeSinceRepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastRepTime != null && mounted) {
        setState(() {}); // Trigger rebuild to update elapsed time
      }
    });
  }

  @override
  void didUpdateWidget(covariant MeasurementWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle exercise changes - reset measurements without recreating widget
    if (oldWidget.selectedExercise?.id != widget.selectedExercise?.id) {
      setState(() {
        _buffer.clear();
        _maxWeight = _initialMaxWeight;
        _sessionService.reset();
        _repDetector.reset();
      });
      _loadPersonalBest();
    }
    
    if (oldWidget.device?.remoteId.str != widget.device?.remoteId.str) {
      _stopSubscription();
      if (widget.device != null) {
        // Start session time immediately when device connects
        setState(() {
          _sessionService.startSession();
        });
        _discoverAndSubscribe();
      } else {
        setState(() {
          _buffer.clear();
          _dataChar = null;
          _maxWeight = _initialMaxWeight; // reset adaptive max on disconnect
          _sessionService.clear();
          _repDetector.reset();
        });
      }
    }

    if (oldWidget.graphWindowSeconds != widget.graphWindowSeconds) {
      _graphWindowSeconds = widget.graphWindowSeconds;
    }
  }

  @override
  void dispose() {
    _ackTimer?.cancel();
    _timeSinceRepTimer?.cancel();
    _targetInputController.dispose();
    _targetInputFocus.dispose();
    _stopSubscription();
    super.dispose();
  }

  Future<void> _discoverAndSubscribe() async {
    final device = widget.device;
    if (device == null) return;

    try {
      final services = await device.discoverServices();
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.uuid == _dataCharUuid) {
            _dataChar = c;
            break;
          }
        }
        if (_dataChar != null) break;
      }

      if (_dataChar == null) {
        // characteristic not found
        return;
      }

      // enable notifications
      await _dataChar!.setNotifyValue(true);

      _charSub = _dataChar!.onValueReceived.listen(_handleNotification);
    } catch (e, st) {
      debugPrint('Failed to subscribe to data characteristic: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Update graph window (in seconds)
  void updateGraphWindow(int seconds) {
    setState(() {
      _graphWindowSeconds = seconds;
    });
  }

  Future<void> _loadPersonalBest() async {
    if (widget.selectedExercise == null) {
      setState(() {
        _personalBest = null;
        _personalBestL = null;
        _personalBestR = null;
        _targetWeight = null;
      });
      return;
    }

    final pb = await _databaseService.getBestRepForExercise(widget.selectedExercise!.id);
    final pbL = widget.selectedExercise!.isTwoSided
        ? await _databaseService.getBestRepForExercise(widget.selectedExercise!.id, side: 'L')
        : null;
    final pbR = widget.selectedExercise!.isTwoSided
        ? await _databaseService.getBestRepForExercise(widget.selectedExercise!.id, side: 'R')
        : null;
    
    setState(() {
      _personalBest = pb;
      _personalBestL = pbL;
      _personalBestR = pbR;
      _updateTargetWeight();
      // Initialize the input controller with the current value
      if (_targetIsPercentage) {
        _targetInputController.text = _targetPercentage.toStringAsFixed(0);
      } else {
        _targetInputController.text = _targetWeight?.toStringAsFixed(1) ?? '0.0';
      }
    });
  }

  void _updateTargetWeight() {
    if (_targetIsPercentage && _personalBest != null) {
      _targetWeight = _personalBest! * (_targetPercentage / 100.0);
    }
    // If absolute kg mode, _targetWeight stays as is
  }

  void _handleNotification(List<int> raw) {
    try {
      if (raw.isEmpty) return;
      final b = Uint8List.fromList(raw);
      final bd = ByteData.sublistView(b);
      final type = bd.getUint8(0);

      // Log raw packet (hex) for debugging (always)
      // try {
      //   final hex = raw.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      //   debugPrint('Tindeq raw packet: $hex');
      // } catch (_) {}

      // If this packet was a command response (type F0), trigger ack notifier
      if (type == 0) {
        if (widget.ackNotifier != null) {
          widget.ackNotifier!.value = true;
          // reset after 2 seconds
          _ackTimer?.cancel();
          _ackTimer = Timer(const Duration(seconds: 2), () {
            widget.ackNotifier!.value = false;
          });
        }
        // nothing else to parse for ACK packets
        return;
      }

      // For weight measurement packets (type 1): parse samples
      if (type != _resWeightMeas) return;

      // payload begins at byte index 2. Each sample: 4 bytes float (weight), 4 bytes uint32 (useconds)
      final int payloadLen = b.length;
      final int samples = (payloadLen - 2) ~/ 8;
      if (samples <= 0) return;

      final List<MeasurementSample> newSamples = [];
      for (int k = 0; k < samples; k++) {
        final int wo = 2 + k * 8; // weight offset
        final int to = 6 + k * 8; // timestamp offset
        if (wo + 4 <= payloadLen && to + 4 <= payloadLen) {
          final double weight = bd.getFloat32(wo, Endian.little);
          final int useconds = bd.getUint32(to, Endian.little);
          newSamples.add(MeasurementSample(weight, useconds));
        }
      }

      if (newSamples.isEmpty) return;

      setState(() {
        _buffer.addAll(newSamples);
        // Buffer size: 100 measurements per second × graph window seconds
        final effectiveBufferSize = _graphWindowSeconds * 100;
        while (_buffer.length > effectiveBufferSize) {
          _buffer.removeAt(0);
        }
        // Update adaptive max weight if any new sample exceeds current max
        final double observedMax = newSamples.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
        if (observedMax > _maxWeight) {
          _maxWeight = observedMax;
        }
        // Track session maximum
        if (observedMax > _sessionService.sessionMax) {
          _sessionService.updateSessionMax(observedMax);
        }
        
        // Rep detection: process each new sample
        for (final sample in newSamples) {
          _repDetector.processSample(sample.weight, sample.receivedAt, widget.currentSide);
        }
      });
    } catch (e, st) {
      debugPrint('Failed to process measurement notification: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _stopSubscription() {
    _charSub?.cancel();
    _charSub = null;
    if (_dataChar != null && widget.device != null) {
      try {
        _dataChar!.setNotifyValue(false);
      } catch (e, st) {
        debugPrint('Unable to disable notifications: $e');
        debugPrintStack(stackTrace: st);
      }
    }
    _dataChar = null;
  }

  Future<void> _saveSession() async {
    if (widget.selectedExercise == null) {
      return;
    }

    final success = await _sessionService.saveSession(widget.selectedExercise!);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session saved: ${_sessionService.repCount} reps')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving session')),
        );
      }
    }
  }

  String _formatSessionTime() {
    return _sessionService.formatSessionTime();
  }
  String _formatTimeSinceLastRep() {
    if (_lastRepTime == null) return '-';
    final elapsed = DateTime.now().difference(_lastRepTime!);
    final seconds = elapsed.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = elapsed.inMinutes;
      final secs = seconds % 60;
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildStatDisplay(String label, String value, Color color) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: appColors.statLabel,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _handleSwipe(DragEndDetails details) async {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 500) return; // Require minimum swipe speed
    if (widget.exercises.isEmpty || widget.selectedExercise == null) return;
    
    final currentIndex = widget.exercises.indexWhere((e) => e.id == widget.selectedExercise!.id);
    if (currentIndex == -1) return;
    
    final newIndex = velocity > 0 
        ? (currentIndex - 1 + widget.exercises.length) % widget.exercises.length
        : (currentIndex + 1) % widget.exercises.length;
    
    final newExercise = widget.exercises[newIndex];
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Notify parent to switch exercise
    widget.onExerciseSwitch?.call(newExercise);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    // Render chart without fixed aspect ratio
    return GestureDetector(
      onHorizontalDragEnd: _handleSwipe,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.all(16.0),
            child: _buildChart(),
          ),
        ),
        // Controls and displays area below the graph
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.1 * 255).round()),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Last rep details (if available)
              if (_sessionService.hasUnsavedData) ...[
                Text(
                  'Last Rep',
                  style: TextStyle(
                    fontSize: 12,
                    color: appColors.statLabel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatDisplay('Duration', '${(_sessionService.lastRep!.duration.inMilliseconds / 1000).toStringAsFixed(1)}s', appColors.statLastRepDuration),
                    _buildStatDisplay('Max', '${_sessionService.lastRep!.peakWeight.toStringAsFixed(1)} kg', appColors.statLastRepMax),
                    _buildStatDisplay('Average', '${_sessionService.lastRep!.avgWeight.toStringAsFixed(1)} kg', appColors.statLastRepAverage),
                    _buildStatDisplay('Median', '${_sessionService.lastRep!.medianWeight.toStringAsFixed(1)} kg', appColors.statLastRepMedian),
                  ],
                ),
                const Divider(height: 16),
              ],
              // Session stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatDisplay('Session Max', '${_sessionService.sessionMax.toStringAsFixed(1)} kg', appColors.statSessionMax),
                  if (widget.selectedExercise?.isTwoSided == true) ...[
                    _buildStatDisplay('PB L', '${_personalBestL?.toStringAsFixed(1) ?? '-'} kg', appColors.statPersonalBest),
                    _buildStatDisplay('PB R', '${_personalBestR?.toStringAsFixed(1) ?? '-'} kg', appColors.statPersonalBest),
                  ] else
                    _buildStatDisplay('PB', '${_personalBest?.toStringAsFixed(1) ?? '-'} kg', appColors.statPersonalBest),
                  _buildStatDisplay('Session Time', _formatSessionTime(), appColors.statSessionTime),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (widget.selectedExercise?.isTwoSided == true) ...[
                    _buildStatDisplay('L Reps', '${_sessionService.getRepsForSide('L').length}', appColors.statRepCount),
                    _buildStatDisplay('R Reps', '${_sessionService.getRepsForSide('R').length}', appColors.statRepCount),
                  ] else
                    _buildStatDisplay('Reps', '${_sessionService.repCount}', appColors.statRepCount),
                  if (_lastRepTime != null)
                    _buildStatDisplay('Since Last', _formatTimeSinceLastRep(), appColors.statRepCount),
                ],
              ),
              const Divider(height: 16),
              // Target settings
              Row(
                children: [
                  const Text('Target:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                      // Compact toggle between % and kg mode
                      ToggleButtons(
                        isSelected: [_targetIsPercentage, !_targetIsPercentage],
                        onPressed: _personalBest == null ? null : (index) {
                          setState(() {
                            _targetIsPercentage = index == 0;
                            if (_targetIsPercentage) {
                              // Switching to % mode - calculate percentage from current kg value
                              if (_targetWeight != null && _personalBest != null && _personalBest! > 0) {
                                _targetPercentage = (_targetWeight! / _personalBest! * 100).clamp(0, 100);
                              }
                              _updateTargetWeight();
                              // Update controller to show percentage
                              _targetInputController.text = _targetPercentage.toStringAsFixed(0);
                            } else {
                              // Switching to kg mode - update controller to show kg value
                              _targetInputController.text = _targetWeight?.toStringAsFixed(1) ?? '0.0';
                            }
                          });
                        },
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 30),
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                        color: appColors.targetButtonText,
                        selectedColor: appColors.targetButtonTextSelected,
                        fillColor: appColors.targetButtonFill,
                        borderColor: appColors.targetButtonBorder,
                        selectedBorderColor: appColors.targetButtonBorderSelected,
                        borderWidth: 1,
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text('%'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text('kg'),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      // Stepper controls
                      if (_targetIsPercentage) ...[
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: _personalBest == null || _targetPercentage <= 0 ? null : () {
                            setState(() {
                              _targetPercentage = math.max(0, _targetPercentage - 5);
                              _updateTargetWeight();
                              _targetInputController.text = _targetPercentage.toStringAsFixed(0);
                            });
                          },
                        ),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: _targetInputController,
                            focusNode: _targetInputFocus,
                            enabled: _personalBest != null,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: appColors.targetInputBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: appColors.targetInputBorder, width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: appColors.targetInputBorder, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: appColors.targetInputBorderFocused, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              suffix: Text(
                                '%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: appColors.targetInputText,
                                ),
                              ),
                            ),
                            onTap: () {
                              // Select all text on tap for easy replacement
                              _targetInputController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _targetInputController.text.length,
                              );
                            },
                            onSubmitted: (value) {
                              final input = double.tryParse(value);
                              setState(() {
                                if (input != null) {
                                  _targetPercentage = input.clamp(0, 100);
                                  _updateTargetWeight();
                                }
                                _targetInputController.text = _targetPercentage.toStringAsFixed(0);
                              });
                              _targetInputFocus.unfocus();
                            },
                            onEditingComplete: () {
                              final input = double.tryParse(_targetInputController.text);
                              setState(() {
                                if (input != null) {
                                  _targetPercentage = input.clamp(0, 100);
                                  _updateTargetWeight();
                                }
                                _targetInputController.text = _targetPercentage.toStringAsFixed(0);
                              });
                              _targetInputFocus.unfocus();
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: _personalBest == null || _targetPercentage >= 100 ? null : () {
                            setState(() {
                              _targetPercentage = (_targetPercentage + 5).clamp(50, 100);
                              _updateTargetWeight();
                              _targetInputController.text = _targetPercentage.toStringAsFixed(0);
                            });
                          },
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: _personalBest == null || (_targetWeight ?? 0) <= 0 ? null : () {
                            setState(() {
                              _targetWeight = math.max(0, (_targetWeight ?? 0) - 1.0);
                              _targetInputController.text = _targetWeight?.toStringAsFixed(1) ?? '0.0';
                            });
                          },
                        ),
                        SizedBox(
                          width: 85,
                          child: TextField(
                            controller: _targetInputController,
                            focusNode: _targetInputFocus,
                            enabled: _personalBest != null,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: appColors.targetInputBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: appColors.targetInputBorder, width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: appColors.targetInputBorder, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: appColors.targetInputBorderFocused, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              suffix: Text(
                                'kg',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: appColors.targetInputText,
                                ),
                              ),
                            ),
                            onTap: () {
                              // Select all text on tap for easy replacement
                              _targetInputController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _targetInputController.text.length,
                              );
                            },
                            onSubmitted: (value) {
                              final input = double.tryParse(value);
                              setState(() {
                                if (input != null && _personalBest != null) {
                                  _targetWeight = input.clamp(0, _personalBest!);
                                }
                                _targetInputController.text = _targetWeight?.toStringAsFixed(1) ?? '0.0';
                              });
                              _targetInputFocus.unfocus();
                            },
                            onEditingComplete: () {
                              final input = double.tryParse(_targetInputController.text);
                              setState(() {
                                if (input != null && _personalBest != null) {
                                  _targetWeight = input.clamp(0, _personalBest!);
                                }
                                _targetInputController.text = _targetWeight?.toStringAsFixed(1) ?? '0.0';
                              });
                              _targetInputFocus.unfocus();
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: _personalBest == null || (_targetWeight ?? 0) >= (_personalBest ?? 0) ? null : () {
                            setState(() {
                              _targetWeight = math.min(_personalBest ?? double.infinity, (_targetWeight ?? 0) + 1.0);
                              _targetInputController.text = _targetWeight?.toStringAsFixed(1) ?? '0.0';
                            });
                          },
                        ),
                      ],
                ],
              ),
              const Divider(height: 16),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _sessionService.reset();
                        _repDetector.reset();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: !_sessionService.hasUnsavedData ? null : _saveSession,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Session'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildChart() {
    final appColors = Theme.of(context).extension<AppColors>()!;
    if (_buffer.isEmpty) return const SizedBox.shrink(); 

    final now = DateTime.now();
    final windowStart = now.subtract(Duration(seconds: _graphWindowSeconds));
    final samples = _buffer.where((s) => s.receivedAt.isAfter(windowStart)).toList();
    if (samples.isEmpty) return const SizedBox.shrink();

    // X axis: seconds since windowStart
    final xs = samples.map((s) => s.receivedAt.difference(windowStart).inMilliseconds / 1000.0).toList();
    final ys = samples.map((s) => s.weight).toList();

    final spots = List<FlSpot>.generate(samples.length, (i) => FlSpot(xs[i], ys[i]));

    final minX = 0.0;
    final maxX = _graphWindowSeconds.toDouble();
    final minY = 0.0;
    // Use PB if available, otherwise adaptive max (start 40kg)
    final dataMax = math.max(_maxWeight, _initialMaxWeight);
    final effectiveMax = _personalBest != null 
        ? math.max(_personalBest!, dataMax)
        : dataMax;
    final maxY = (effectiveMax <= minY) ? (minY + 1.0) : effectiveMax;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            dotData: FlDotData(show: false),
            color: appColors.chartLine,
            barWidth: 2,
            curveSmoothness: 0.1,
          ),
          // Target line
          if (_targetWeight != null && _targetWeight! > 0)
            LineChartBarData(
              spots: [
                FlSpot(minX, _targetWeight!),
                FlSpot(maxX, _targetWeight!),
              ],
              isCurved: false,
              dotData: FlDotData(show: false),
              color: appColors.chartThreshold,
              barWidth: 2,
              dashArray: [5, 5],
            ),
        ],
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: appColors.chartAxisText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _graphWindowSeconds >= 30 ? 10.0 : 5.0,
              getTitlesWidget: (value, meta) {
                final seconds = value.toInt();
                if (seconds >= 60) {
                  final mins = seconds ~/ 60;
                  final secs = seconds % 60;
                  return Text(
                    '$mins:${secs.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: appColors.chartAxisText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return Text(
                  '${seconds}s',
                  style: TextStyle(
                    color: appColors.chartAxisText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }
}
