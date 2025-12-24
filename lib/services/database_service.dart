import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'no_hangs.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Single table with all session and rep data
    await db.execute('''
      CREATE TABLE session_reps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        session_start_time INTEGER NOT NULL,
        session_duration_seconds INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        side TEXT,
        rep_start_time INTEGER NOT NULL,
        rep_end_time INTEGER NOT NULL,
        rep_duration_ms INTEGER NOT NULL,
        peak_weight REAL NOT NULL,
        average_weight REAL NOT NULL,
        median_weight REAL NOT NULL,
        time_series_json TEXT NOT NULL
      )
    ''');

    // Indexes for faster queries
    await db.execute('CREATE INDEX idx_session_id ON session_reps(session_id)');
    await db.execute('CREATE INDEX idx_session_start_time ON session_reps(session_start_time DESC)');
  }

  Future<double?> getBestRepForExercise(String exerciseId, {String? side}) async {
    final db = await database;
    final String query = side != null
        ? 'SELECT MAX(peak_weight) as max_weight FROM session_reps WHERE exercise_id = ? AND side = ?'
        : 'SELECT MAX(peak_weight) as max_weight FROM session_reps WHERE exercise_id = ?';
    final List<Object> params = side != null ? [exerciseId, side] : [exerciseId];
    
    try {
      final result = await db.rawQuery(query, params);
      if (result.isEmpty || result.first['max_weight'] == null) {
        return null;
      }
      return result.first['max_weight'] as double;
    } catch (e, st) {
      _logDbError('getBestRepForExercise', e, st);
      return null;
    }
  }

  Future<String> saveSession({
    required DateTime startTime,
    required String exerciseId,
    required String exerciseName,
    required int durationSeconds,
    required List<Map<String, dynamic>> reps,
  }) async {
    try {
      final db = await database;
      final sessionId = '${DateTime.now().millisecondsSinceEpoch}_$exerciseId';
      await db.transaction((txn) async {
        for (final rep in reps) {
          await txn.insert('session_reps', {
            'session_id': sessionId,
            'session_start_time': startTime.millisecondsSinceEpoch,
            'session_duration_seconds': durationSeconds,
            'exercise_id': exerciseId,
            'exercise_name': exerciseName,
            'side': rep['side'],
            'rep_start_time': rep['start_time'],
            'rep_end_time': rep['end_time'],
            'rep_duration_ms': rep['duration_ms'],
            'peak_weight': rep['peak_weight'],
            'average_weight': rep['average_weight'],
            'median_weight': rep['median_weight'],
            'time_series_json': json.encode(rep['time_series']),
          });
        }
      });
      return sessionId;
    } catch (e, st) {
      _logDbError('saveSession', e, st);
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> getHistoricalData({
    required List<String> exerciseIds,
    String? groupBy, // 'session', 'day', 'week', 'month'
    bool separateSides = false,
  }) async {
    if (exerciseIds.isEmpty) return [];
    final exerciseFilter = exerciseIds.map((id) => "'$id'").join(',');
    final groupByField = _getGroupByField(groupBy ?? 'session');
    final sideGroup = separateSides ? ', side' : '';
    final sideSelect = separateSides ? ', side' : ", '' as side";
    final query = '''
      SELECT 
        $groupByField as time_group,
        exercise_id,
        exercise_name
        $sideSelect,
        MAX(peak_weight) as max_weight,
        AVG(average_weight) as avg_weight,
        AVG(median_weight) as median_weight,
        SUM(peak_weight * rep_duration_ms / 1000.0) as volume,
        COUNT(*) as rep_count,
        MIN(session_start_time) as first_session_time
      FROM session_reps
      WHERE exercise_id IN ($exerciseFilter)
      GROUP BY $groupByField, exercise_id $sideGroup
      ORDER BY time_group ASC
    ''';
    try {
      final db = await database;
      return await db.rawQuery(query);
    } catch (e, st) {
      _logDbError('getHistoricalData', e, st);
      return [];
    }
  }

  String _getGroupByField(String groupBy) {
    switch (groupBy) {
      case 'day':
        return 'date(session_start_time / 1000, "unixepoch")';
      case 'week':
        return 'strftime("%Y-W%W", session_start_time / 1000, "unixepoch")';
      case 'month':
        return 'strftime("%Y-%m", session_start_time / 1000, "unixepoch")';
      case 'session':
      default:
        return 'session_id';
    }
  }

  Future<void> close() async {
    try {
      final db = await database;
      await db.close();
    } catch (e, st) {
      _logDbError('close', e, st);
    }
  }

  Future<void> deleteAllSessions() async {
    try {
      final db = await database;
      await db.delete('session_reps');
    } catch (e, st) {
      _logDbError('deleteAllSessions', e, st);
    }
  }

  void _logDbError(String operation, Object error, StackTrace stackTrace) {
    debugPrint('Database error during $operation: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
