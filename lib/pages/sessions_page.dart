import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import '../services/exercise_service.dart';
import '../theme/app_theme.dart';
import 'session_detail_page.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final DatabaseService _dbService = DatabaseService();
  final ExerciseService _exerciseService = ExerciseService();

  List<Session> _sessions = [];
  List<Exercise> _exercises = [];
  String? _selectedExerciseId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _exercises = await _exerciseService.getExercises();
    await _loadSessions();

    setState(() => _isLoading = false);
  }

  Future<void> _loadSessions() async {
    final sessions = await _dbService.getAllSessions(
      exerciseId: _selectedExerciseId,
    );
    setState(() => _sessions = sessions);
  }

  Future<void> _deleteSession(Session session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Are you sure you want to delete this session?\n\n'
          '${session.exerciseName}\n'
          '${session.formattedDateTime}\n'
          '${session.repCount} reps',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: Theme.of(context).extension<AppColors>()!.dangerZoneText,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.deleteSession(session.id);
      await _loadSessions();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Exercise filter
          if (_exercises.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                    'Filter:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<String?>(
                      value: _selectedExerciseId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Exercises'),
                        ),
                        ..._exercises.map(
                          (ex) => DropdownMenuItem(
                            value: ex.id,
                            child: Text(ex.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedExerciseId = value);
                        _loadSessions();
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Sessions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sessions yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start training to see your sessions here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return _SessionCard(
                        session: session,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  SessionDetailPage(session: session),
                            ),
                          );
                          // Reload in case session was modified
                          _loadSessions();
                        },
                        onDelete: () => _deleteSession(session),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: appColors.statPersonalBest.withAlpha(
                    (0.2 * 255).round(),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: appColors.statPersonalBest,
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.exerciseName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.formattedDateTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: appColors.statLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStat(
                          Icons.repeat,
                          '${session.repCount} reps',
                          appColors.statLabel,
                        ),
                        const SizedBox(width: 16),
                        _buildStat(
                          Icons.timer,
                          session.formattedDuration,
                          appColors.statLabel,
                        ),
                        const SizedBox(width: 16),
                        _buildStat(
                          Icons.trending_up,
                          '${session.maxWeight.toStringAsFixed(1)} kg',
                          appColors.statPersonalBest,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: appColors.dangerZoneText,
                ),
                onPressed: onDelete,
                tooltip: 'Delete session',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
