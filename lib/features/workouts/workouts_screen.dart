import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/models/health_extras.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import 'workout_catalog.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final colors = OpenAirColors.of(context);
    final logged = app.allRecentWorkouts;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Track'),
              Tab(text: 'Logged'),
              Tab(text: 'Types'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Log manually',
              onPressed: () => _showManualLogSheet(context),
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _TrackTab(colors: colors, app: app),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Cloud sessions plus anything you start or log in OpenAir.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (logged.isEmpty)
                  Text(
                    'No workouts yet. Start one on Track, or log manually.',
                    style: TextStyle(color: colors.textMuted),
                  )
                else
                  ...logged.map((e) => _LoggedTile(session: e)),
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Pick a type to start tracking, or browse what you can log.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 12),
                for (final category in WorkoutCatalog.categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: colors.green,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ...WorkoutCatalog.activities
                      .where((a) => a.category == category)
                      .map(
                        (a) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                colors.green.withValues(alpha: 0.15),
                            child: Icon(a.icon, color: colors.green),
                          ),
                          title: Text(a.name),
                          trailing: TextButton(
                            onPressed: app.activeWorkout == null
                                ? () {
                                    app.startWorkout(a.name);
                                    DefaultTabController.of(context)
                                        .animateTo(0);
                                  }
                                : null,
                            child: const Text('Start'),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showManualLogSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('Log workout'),
        ),
      ),
    );
  }
}

class _TrackTab extends StatelessWidget {
  const _TrackTab({required this.colors, required this.app});

  final OpenAirColors colors;
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final active = app.activeWorkout;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        if (active == null) ...[
          Text(
            'Start & stop like a fitness tracker — OpenAir stores the session on this device and folds it into Strain.',
            style: TextStyle(color: colors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in const [
                'Run',
                'Walk',
                'Ride',
                'Weight Training',
                'HIIT',
                'Yoga',
                'Swim',
              ])
                ActionChip(
                  label: Text(name),
                  onPressed: () => app.startWorkout(name),
                ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showManualLogSheet(context),
            icon: const Icon(Icons.edit_note),
            label: const Text('Log a past workout'),
          ),
        ] else ...[
          Text(
            'IN PROGRESS',
            style: TextStyle(
              color: colors.green,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            active.activityName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatElapsed(active.elapsed),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: colors.strain,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Started ${DateFormat.jm().format(active.startedAt)}',
            style: TextStyle(color: colors.textMuted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _confirmStop(context, app),
            icon: const Icon(Icons.stop),
            label: const Text('Finish workout'),
          ),
        ],
      ],
    );
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

Future<void> _confirmStop(BuildContext context, AppController app) async {
  final caloriesCtrl = TextEditingController();
  final distanceCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  var rpe = 5;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Finish ${app.activeWorkout?.activityName ?? 'workout'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: caloriesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories (optional)'),
                ),
                TextField(
                  controller: distanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Distance km (optional)'),
                ),
                const SizedBox(height: 8),
                Text('Effort (RPE): $rpe'),
                Slider(
                  value: rpe.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$rpe',
                  onChanged: (v) => setModal(() => rpe = v.round()),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save session'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  if (ok != true) return;
  final km = double.tryParse(distanceCtrl.text.trim());
  await app.stopWorkout(
    calories: double.tryParse(caloriesCtrl.text.trim()),
    distanceMeters: km == null ? null : km * 1000,
    perceivedExertion: rpe,
    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
  );
}

Future<void> _showManualLogSheet(BuildContext context) async {
  final app = context.read<AppController>();
  final nameCtrl = TextEditingController(text: 'Run');
  final minutesCtrl = TextEditingController(text: '30');
  final caloriesCtrl = TextEditingController();
  final distanceCtrl = TextEditingController();
  var when = DateTime.now().subtract(const Duration(hours: 1));
  var rpe = 5;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Log workout',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Activity'),
                  ),
                  TextField(
                    controller: minutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (min)'),
                  ),
                  TextField(
                    controller: caloriesCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Calories (optional)'),
                  ),
                  TextField(
                    controller: distanceCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Distance km (optional)'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start time'),
                    subtitle: Text(DateFormat.yMMMd().add_jm().format(when)),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: when,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now(),
                      );
                      if (date == null || !ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(when),
                      );
                      if (time == null || !ctx.mounted) return;
                      setModal(() {
                        when = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                  Text('Effort (RPE): $rpe'),
                  Slider(
                    value: rpe.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) => setModal(() => rpe = v.round()),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (ok != true) return;
  final minutes = int.tryParse(minutesCtrl.text.trim()) ?? 30;
  final km = double.tryParse(distanceCtrl.text.trim());
  final start = when;
  final end = start.add(Duration(minutes: minutes.clamp(1, 600)));
  await app.logManualWorkout(
    ExerciseSession(
      id: 'manual-${start.millisecondsSinceEpoch}',
      name: nameCtrl.text.trim().isEmpty ? 'Workout' : nameCtrl.text.trim(),
      start: start,
      end: end,
      calories: double.tryParse(caloriesCtrl.text.trim()),
      distanceMeters: km == null ? null : km * 1000,
      perceivedExertion: rpe,
      isManual: true,
    ),
  );
}

class _LoggedTile extends StatelessWidget {
  const _LoggedTile({required this.session});

  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final app = context.watch<AppController>();
    final analysis = app.analyzeWorkout(session);
    final pace = session.paceMinPerKm;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (session.isManual)
                TextButton(
                  onPressed: () => app.deleteManualWorkout(session.id),
                  child: const Text('Delete'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat.MMMd().add_jm().format(session.start)} · '
            '${session.durationMinutes} min'
            '${session.isManual ? ' · manual' : ' · synced'}',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _chip(colors, 'Strain +${analysis.strainContribution}'),
              _chip(colors, analysis.intensityLabel),
              _chip(
                colors,
                '${(session.calories ?? analysis.calorieEstimate).round()} kcal',
              ),
              if (analysis.distanceKm != null)
                _chip(colors, '${analysis.distanceKm!.toStringAsFixed(2)} km'),
              if (pace != null)
                _chip(
                  colors,
                  '${pace.floor()}:${((pace % 1) * 60).round().toString().padLeft(2, '0')}/km',
                ),
              if (session.avgHeartRate != null)
                _chip(colors, 'avg ${session.avgHeartRate!.round()} bpm'),
              if (session.maxHeartRate != null)
                _chip(colors, 'max ${session.maxHeartRate!.round()} bpm'),
              if (session.perceivedExertion != null)
                _chip(colors, 'RPE ${session.perceivedExertion}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            analysis.recoveryTip,
            style: TextStyle(color: colors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _chip(OpenAirColors colors, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
