import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/rep.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class SessionDetailPage extends StatefulWidget {
  final Session session;

  const SessionDetailPage({super.key, required this.session});

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Rep> _reps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReps();
  }

  Future<void> _loadReps() async {
    setState(() => _isLoading = true);

    final reps = await _dbService.getRepsForSession(widget.session.id);
    setState(() {
      _reps = reps;
      _isLoading = false;
    });
  }

  Future<void> _deleteRep(int index) async {
    if (_reps.isEmpty || index >= _reps.length) return;

    // Get rep ID from database by querying with the session_id and using index
    final db = await _dbService.database;
    final result = await db.query(
      'session_reps',
      where: 'session_id = ?',
      whereArgs: [widget.session.id],
      orderBy: 'rep_start_time ASC',
    );

    if (index < result.length) {
      final repId = result[index]['id'] as int;
      await _dbService.deleteRep(repId);
      await _loadReps();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rep deleted')));
      }
    }
  }

  Future<void> _changeSide(int index) async {
    if (_reps.isEmpty || index >= _reps.length) return;

    final rep = _reps[index];
    final newSide = rep.side == 'L' ? 'R' : 'L';

    // Get rep ID from database
    final db = await _dbService.database;
    final result = await db.query(
      'session_reps',
      where: 'session_id = ?',
      whereArgs: [widget.session.id],
      orderBy: 'rep_start_time ASC',
    );

    if (index < result.length) {
      final repId = result[index]['id'] as int;
      await _dbService.updateRepSide(repId, newSide);
      await _loadReps();
    }
  }

  Future<void> _cloneRep(int index) async {
    if (_reps.isEmpty || index >= _reps.length) return;

    final count = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: '1');
        return AlertDialog(
          title: const Text('Clone Rep'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How many copies do you want to create?'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Number of copies',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final count = int.tryParse(controller.text);
                if (count != null && count > 0) {
                  Navigator.of(ctx).pop(count);
                }
              },
              child: const Text('Clone'),
            ),
          ],
        );
      },
    );

    if (count != null && count > 0) {
      // Get rep ID from database
      final db = await _dbService.database;
      final result = await db.query(
        'session_reps',
        where: 'session_id = ?',
        whereArgs: [widget.session.id],
        orderBy: 'rep_start_time ASC',
      );

      if (index < result.length) {
        final repId = result[index]['id'] as int;
        await _dbService.cloneRep(repId, count);
        await _loadReps();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created $count ${count == 1 ? "copy" : "copies"}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _addManualRep() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddManualRepDialog(),
    );

    if (result != null) {
      await _dbService.addManualRep(
        sessionId: widget.session.id,
        weight: result['weight'] as double,
        side: result['side'] as String,
        durationSeconds: result['duration'] as int,
        timestamp: result['timestamp'] as DateTime,
      );

      await _loadReps();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Manual rep added')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Session header
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.session.exerciseName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.session.formattedDateTime,
                  style: TextStyle(fontSize: 14, color: appColors.statLabel),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHeaderStat(
                      'Reps',
                      widget.session.repCount.toString(),
                    ),
                    _buildHeaderStat(
                      'Duration',
                      widget.session.formattedDuration,
                    ),
                    _buildHeaderStat(
                      'Max',
                      '${widget.session.maxWeight.toStringAsFixed(1)} kg',
                    ),
                    _buildHeaderStat(
                      'Avg',
                      '${widget.session.avgWeight.toStringAsFixed(1)} kg',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Reps list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reps.isEmpty
                ? const Center(child: Text('No reps in this session'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _reps.length,
                    itemBuilder: (context, index) {
                      final rep = _reps[index];
                      return _RepCard(
                        rep: rep,
                        index: index,
                        onDelete: () => _deleteRep(index),
                        onChangeSide: () => _changeSide(index),
                        onClone: () => _cloneRep(index),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualRep,
        icon: const Icon(Icons.add),
        label: const Text('Add Manual Rep'),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: appColors.statLabel)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _RepCard extends StatelessWidget {
  final Rep rep;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onChangeSide;
  final VoidCallback onClone;

  const _RepCard({
    required this.rep,
    required this.index,
    required this.onDelete,
    required this.onChangeSide,
    required this.onClone,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Rep ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // Side toggle button
                InkWell(
                  onTap: onChangeSide,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: appColors.statPersonalBest.withAlpha(
                        (0.2 * 255).round(),
                      ),
                      border: Border.all(
                        color: appColors.statPersonalBest.withAlpha(
                          (0.5 * 255).round(),
                        ),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rep.side,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: appColors.statPersonalBest,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: appColors.statPersonalBest,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Compact action buttons
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 18),
                  onPressed: onClone,
                  tooltip: 'Clone',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: appColors.dangerZoneText,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  'Duration',
                  '${(rep.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                ),
                _buildStat('Max', '${rep.peakWeight.toStringAsFixed(1)} kg'),
                _buildStat('Avg', '${rep.avgWeight.toStringAsFixed(1)} kg'),
                _buildStat(
                  'Median',
                  '${rep.medianWeight.toStringAsFixed(1)} kg',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _AddManualRepDialog extends StatefulWidget {
  @override
  State<_AddManualRepDialog> createState() => _AddManualRepDialogState();
}

class _AddManualRepDialogState extends State<_AddManualRepDialog> {
  final TextEditingController _weightController = TextEditingController(
    text: '10.0',
  );
  final TextEditingController _durationController = TextEditingController(
    text: '7',
  );
  String _side = 'L';
  DateTime _timestamp = DateTime.now();

  @override
  void dispose() {
    _weightController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Manual Rep'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                hintText: '10.0',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (seconds)',
                hintText: '7',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Side:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'L', label: Text('Left')),
                ButtonSegment(value: 'R', label: Text('Right')),
              ],
              selected: {_side},
              onSelectionChanged: (Set<String> selected) {
                setState(() => _side = selected.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Time: ${_timestamp.hour.toString().padLeft(2, '0')}:${_timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
            TextButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_timestamp),
                );
                if (time != null) {
                  setState(() {
                    _timestamp = DateTime(
                      _timestamp.year,
                      _timestamp.month,
                      _timestamp.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              },
              child: const Text('Change Time'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final weight = double.tryParse(_weightController.text);
            final duration = int.tryParse(_durationController.text);

            if (weight == null || weight <= 0) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Invalid weight')));
              return;
            }

            if (duration == null || duration <= 0) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Invalid duration')));
              return;
            }

            Navigator.of(context).pop({
              'weight': weight,
              'duration': duration,
              'side': _side,
              'timestamp': _timestamp,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
