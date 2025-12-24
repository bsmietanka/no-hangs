import '../models/rep.dart';
import '../models/exercise.dart';
import 'database_service.dart';

/// Manages session state and persistence
class SessionService {
  final DatabaseService _databaseService = DatabaseService();
  
  DateTime? _sessionStartTime;
  double _sessionMax = 0.0;
  final List<Rep> _reps = [];
  
  // Getters
  DateTime? get sessionStartTime => _sessionStartTime;
  double get sessionMax => _sessionMax;
  List<Rep> get reps => List.unmodifiable(_reps);
  bool get hasReps => _reps.isNotEmpty;
  bool get hasUnsavedData => _reps.isNotEmpty;
  int get repCount => _reps.length;
  Rep? get lastRep => _reps.isEmpty ? null : _reps.last;
  
  /// Start a new session
  void startSession() {
    _sessionStartTime = DateTime.now();
    _sessionMax = 0.0;
    _reps.clear();
  }
  
  /// Reset session state
  void reset() {
    _sessionStartTime = DateTime.now();
    _sessionMax = 0.0;
    _reps.clear();
  }
  
  /// Clear session (disconnect)
  void clear() {
    _sessionStartTime = null;
    _sessionMax = 0.0;
    _reps.clear();
  }
  
  /// Add a rep to the session
  void addRep(Rep rep) {
    _reps.add(rep);
    
    // Update session max if this rep's peak is higher
    if (rep.peakWeight > _sessionMax) {
      _sessionMax = rep.peakWeight;
    }
  }
  
  /// Update session max weight
  void updateSessionMax(double weight) {
    if (weight > _sessionMax) {
      _sessionMax = weight;
    }
  }
  
  /// Get session duration
  Duration getSessionDuration() {
    if (_sessionStartTime == null) return Duration.zero;
    return DateTime.now().difference(_sessionStartTime!);
  }
  
  /// Format session time as MM:SS
  String formatSessionTime() {
    if (_sessionStartTime == null) return '--:--';
    final duration = getSessionDuration();
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Get reps for a specific side
  List<Rep> getRepsForSide(String side) {
    return _reps.where((r) => r.side == side).toList();
  }
  
  /// Get last rep
  Rep? getLastRep() {
    return _reps.isEmpty ? null : _reps.last;
  }
  
  /// Save session to database
  Future<bool> saveSession(Exercise exercise) async {
    if (_reps.isEmpty || _sessionStartTime == null) {
      return false;
    }
    
    try {
      final sessionDuration = getSessionDuration();
      final repsData = _reps.map((rep) => {
        'side': rep.side,
        'start_time': rep.startTime.millisecondsSinceEpoch,
        'end_time': rep.endTime.millisecondsSinceEpoch,
        'duration_ms': rep.duration.inMilliseconds,
        'peak_weight': rep.peakWeight,
        'average_weight': rep.avgWeight,
        'median_weight': rep.medianWeight,
        'time_series': rep.timeSeries,
      }).toList();

      await _databaseService.saveSession(
        startTime: _sessionStartTime!,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        durationSeconds: sessionDuration.inSeconds,
        reps: repsData,
      );
      
      // Reset session after successful save
      reset();
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
