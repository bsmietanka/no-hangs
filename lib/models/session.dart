/// Session summary data
class Session {
  final String id;
  final DateTime startTime;
  final String exerciseId;
  final String exerciseName;
  final int durationSeconds;
  final int repCount;
  final double maxWeight;
  final double totalVolume;
  final double avgWeight;

  Session({
    required this.id,
    required this.startTime,
    required this.exerciseId,
    required this.exerciseName,
    required this.durationSeconds,
    required this.repCount,
    required this.maxWeight,
    required this.totalVolume,
    required this.avgWeight,
  });

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['session_id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        map['session_start_time'] as int,
      ),
      exerciseId: map['exercise_id'] as String,
      exerciseName: map['exercise_name'] as String,
      durationSeconds: map['session_duration_seconds'] as int,
      repCount: map['rep_count'] as int,
      maxWeight: map['max_weight'] as double,
      totalVolume: map['total_volume'] as double,
      avgWeight: map['avg_weight'] as double,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': id,
      'session_start_time': startTime.millisecondsSinceEpoch,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'session_duration_seconds': durationSeconds,
      'rep_count': repCount,
      'max_weight': maxWeight,
      'total_volume': totalVolume,
      'avg_weight': avgWeight,
    };
  }

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }

  String get formattedDateTime {
    return '${formattedDate} ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }
}
