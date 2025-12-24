import '../models/rep.dart';

/// Handles threshold-based rep detection from weight samples
class RepDetectionService {
  double threshold;
  bool _inRep = false;
  DateTime? _repStartTime;
  double _currentRepPeak = 0.0;
  final List<double> _currentRepWeights = [];
  
  final void Function(Rep rep)? onRepCompleted;
  
  RepDetectionService({
    this.threshold = 1.0,
    this.onRepCompleted,
  });
  
  /// Process a weight sample and detect rep start/end
  void processSample(double weight, DateTime timestamp, String side) {
    if (!_inRep && weight >= threshold) {
      // Start new rep
      _startRep(weight, timestamp);
    } else if (_inRep) {
      // Track weight during rep
      _trackRepWeight(weight);
      
      // End rep when dropping below threshold
      if (weight < threshold) {
        _endRep(timestamp, side);
      }
    }
  }
  
  /// Start a new rep
  void _startRep(double weight, DateTime timestamp) {
    _inRep = true;
    _repStartTime = timestamp;
    _currentRepPeak = weight;
    _currentRepWeights.clear();
    _currentRepWeights.add(weight);
  }
  
  /// Track weight sample during an active rep
  void _trackRepWeight(double weight) {
    _currentRepWeights.add(weight);
    // Update peak if this weight is higher
    if (weight > _currentRepPeak) {
      _currentRepPeak = weight;
    }
  }
  
  /// End the current rep and calculate statistics
  void _endRep(DateTime timestamp, String side) {
    _inRep = false;
    
    if (_repStartTime != null && _currentRepWeights.isNotEmpty) {
      final avgWeight = _currentRepWeights.reduce((a, b) => a + b) / _currentRepWeights.length;
      final medianWeight = Rep.calculateMedian(_currentRepWeights);
      final timeSeries = List<double>.from(_currentRepWeights);
      
      final rep = Rep(
        _repStartTime!,
        timestamp,
        _currentRepPeak,
        avgWeight,
        medianWeight,
        side,
        timeSeries,
      );
      
      onRepCompleted?.call(rep);
    }
    
    // Reset rep state
    _repStartTime = null;
    _currentRepPeak = 0.0;
    _currentRepWeights.clear();
  }
  
  /// Reset detection state (e.g., when starting new session)
  void reset() {
    _inRep = false;
    _repStartTime = null;
    _currentRepPeak = 0.0;
    _currentRepWeights.clear();
  }
  
  /// Check if currently in a rep
  bool get isInRep => _inRep;
  
  /// Get current rep peak (if in rep)
  double get currentRepPeak => _currentRepPeak;
  
  /// Force end current rep (e.g., on session end)
  void forceEndRep(String side) {
    if (_inRep && _repStartTime != null) {
      _endRep(DateTime.now(), side);
    }
  }
}
