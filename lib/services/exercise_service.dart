import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/exercise.dart';

class ExerciseService {
  static const String _exercisesKey = 'exercises';
  static const String _selectedExerciseKey = 'selected_exercise';

  // Get all exercises
  Future<List<Exercise>> getExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final String? exercisesJson = prefs.getString(_exercisesKey);
    
    if (exercisesJson == null) {
      // Return default exercises
      return _getDefaultExercises();
    }
    
    final List<dynamic> decoded = json.decode(exercisesJson);
    return decoded.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Save exercises
  Future<void> saveExercises(List<Exercise> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(exercises.map((e) => e.toJson()).toList());
    await prefs.setString(_exercisesKey, encoded);
  }

  // Add exercise
  Future<void> addExercise(Exercise exercise) async {
    final exercises = await getExercises();
    exercises.add(exercise);
    await saveExercises(exercises);
  }

  // Delete exercise
  Future<void> deleteExercise(String id) async {
    final exercises = await getExercises();
    exercises.removeWhere((e) => e.id == id);
    await saveExercises(exercises);
  }

  // Get selected exercise
  Future<Exercise?> getSelectedExercise() async {
    final prefs = await SharedPreferences.getInstance();
    final String? selectedId = prefs.getString(_selectedExerciseKey);
    
    if (selectedId == null) {
      return null;
    }
    
    final exercises = await getExercises();
    try {
      return exercises.firstWhere((e) => e.id == selectedId);
    } catch (_) {
      return null;
    }
  }

  // Set selected exercise
  Future<void> setSelectedExercise(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedExerciseKey, id);
  }

  List<Exercise> _getDefaultExercises() {
    return [
      Exercise(id: '1', name: 'Half Crimp', isTwoSided: true),
      Exercise(id: '2', name: 'Open Hand', isTwoSided: true),
      Exercise(id: '3', name: 'Pinch', isTwoSided: true),
    ];
  }
}
