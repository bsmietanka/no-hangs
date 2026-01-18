import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/session.dart';
import '../models/rep.dart';

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

    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
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
    await db.execute(
      'CREATE INDEX idx_session_start_time ON session_reps(session_start_time DESC)',
    );
  }

  Future<double?> getBestRepForExercise(
    String exerciseId, {
    String? side,
  }) async {
    final db = await database;
    final String query = side != null
        ? 'SELECT MAX(peak_weight) as max_weight FROM session_reps WHERE exercise_id = ? AND side = ?'
        : 'SELECT MAX(peak_weight) as max_weight FROM session_reps WHERE exercise_id = ?';
    final List<Object> params = side != null
        ? [exerciseId, side]
        : [exerciseId];

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
    final query =
        '''
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

  /// Get all sessions with summary info
  Future<List<Session>> getAllSessions({String? exerciseId}) async {
    try {
      final db = await database;
      final String exerciseFilter = exerciseId != null
          ? 'WHERE exercise_id = ?'
          : '';
      final List<Object?> params = exerciseId != null ? [exerciseId] : [];

      final query =
          '''
        SELECT 
          session_id,
          session_start_time,
          session_duration_seconds,
          exercise_id,
          exercise_name,
          COUNT(*) as rep_count,
          MAX(peak_weight) as max_weight,
          SUM(peak_weight * rep_duration_ms / 1000.0) as total_volume,
          AVG(average_weight) as avg_weight
        FROM session_reps
        $exerciseFilter
        GROUP BY session_id
        ORDER BY session_start_time DESC
      ''';

      final result = await db.rawQuery(query, params);
      return result.map((map) => Session.fromMap(map)).toList();
    } catch (e, st) {
      _logDbError('getAllSessions', e, st);
      return [];
    }
  }

  /// Get reps for a specific session
  Future<List<Rep>> getRepsForSession(String sessionId) async {
    try {
      final db = await database;
      final result = await db.query(
        'session_reps',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'rep_start_time ASC',
      );

      return result.map((map) {
        final timeSeries =
            (json.decode(map['time_series_json'] as String) as List)
                .map((e) => (e as num).toDouble())
                .toList();

        return Rep(
          DateTime.fromMillisecondsSinceEpoch(map['rep_start_time'] as int),
          DateTime.fromMillisecondsSinceEpoch(map['rep_end_time'] as int),
          map['peak_weight'] as double,
          map['average_weight'] as double,
          map['median_weight'] as double,
          map['side'] as String,
          timeSeries,
        );
      }).toList();
    } catch (e, st) {
      _logDbError('getRepsForSession', e, st);
      return [];
    }
  }

  /// Delete a session and all its reps
  Future<void> deleteSession(String sessionId) async {
    try {
      final db = await database;
      await db.delete(
        'session_reps',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    } catch (e, st) {
      _logDbError('deleteSession', e, st);
    }
  }

  /// Delete a specific rep by its ID
  Future<void> deleteRep(int repId) async {
    try {
      final db = await database;
      await db.delete('session_reps', where: 'id = ?', whereArgs: [repId]);
    } catch (e, st) {
      _logDbError('deleteRep', e, st);
    }
  }

  /// Update the side of a rep
  Future<void> updateRepSide(int repId, String newSide) async {
    try {
      final db = await database;
      await db.update(
        'session_reps',
        {'side': newSide},
        where: 'id = ?',
        whereArgs: [repId],
      );
    } catch (e, st) {
      _logDbError('updateRepSide', e, st);
    }
  }

  /// Add a manual rep to a session
  Future<void> addManualRep({
    required String sessionId,
    required double weight,
    required String side,
    required int durationSeconds,
    required DateTime timestamp,
  }) async {
    try {
      final db = await database;

      // Get session info from existing reps
      final sessionInfo = await db.query(
        'session_reps',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );

      if (sessionInfo.isEmpty) {
        debugPrint('Cannot add manual rep: session not found');
        return;
      }

      final sessionData = sessionInfo.first;
      final durationMs = durationSeconds * 1000;
      final endTime = timestamp.add(Duration(seconds: durationSeconds));

      // Create uniform time series (flat signal at specified weight)
      final timeSeries = List.filled(
        durationSeconds * 10,
        weight,
      ); // 10 samples per second

      await db.insert('session_reps', {
        'session_id': sessionId,
        'session_start_time': sessionData['session_start_time'],
        'session_duration_seconds': sessionData['session_duration_seconds'],
        'exercise_id': sessionData['exercise_id'],
        'exercise_name': sessionData['exercise_name'],
        'side': side,
        'rep_start_time': timestamp.millisecondsSinceEpoch,
        'rep_end_time': endTime.millisecondsSinceEpoch,
        'rep_duration_ms': durationMs,
        'peak_weight': weight,
        'average_weight': weight,
        'median_weight': weight,
        'time_series_json': json.encode(timeSeries),
      });
    } catch (e, st) {
      _logDbError('addManualRep', e, st);
    }
  }

  /// Clone a rep multiple times
  Future<void> cloneRep(int repId, int times) async {
    try {
      final db = await database;

      // Get the rep to clone
      final result = await db.query(
        'session_reps',
        where: 'id = ?',
        whereArgs: [repId],
      );

      if (result.isEmpty) {
        debugPrint('Cannot clone rep: rep not found');
        return;
      }

      final repData = result.first;

      // Clone the rep 'times' times
      await db.transaction((txn) async {
        for (int i = 0; i < times; i++) {
          // Create new rep with same data but no ID (will auto-increment)
          final newRep = Map<String, dynamic>.from(repData);
          newRep.remove('id'); // Remove ID so it auto-increments
          await txn.insert('session_reps', newRep);
        }
      });
    } catch (e, st) {
      _logDbError('cloneRep', e, st);
    }
  }

  /// Get rep by ID (for editing/displaying)
  Future<Map<String, dynamic>?> getRepById(int repId) async {
    try {
      final db = await database;
      final result = await db.query(
        'session_reps',
        where: 'id = ?',
        whereArgs: [repId],
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e, st) {
      _logDbError('getRepById', e, st);
      return null;
    }
  }

  void _logDbError(String operation, Object error, StackTrace stackTrace) {
    debugPrint('Database error during $operation: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
