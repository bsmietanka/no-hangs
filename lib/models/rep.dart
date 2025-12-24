/// Repetition data
class Rep {
  final DateTime startTime;
  final DateTime endTime;
  final double peakWeight;
  final double avgWeight;
  final double medianWeight;
  final String side; // 'L' or 'R' for two-sided exercises
  final List<double> timeSeries; // Weight samples during rep
  final Duration duration;
  
  Rep(
    this.startTime,
    this.endTime,
    this.peakWeight,
    this.avgWeight,
    this.medianWeight,
    this.side,
    this.timeSeries,
  ) : duration = endTime.difference(startTime);
  
  static double calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 1) {
      return sorted[middle];
    } else {
      return (sorted[middle - 1] + sorted[middle]) / 2.0;
    }
  }
  
  // For database serialization
  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'peakWeight': peakWeight,
      'avgWeight': avgWeight,
      'medianWeight': medianWeight,
      'side': side,
      'duration': duration.inMilliseconds,
    };
  }
}
