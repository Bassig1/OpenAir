import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/health_extras.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final entry = context.read<AppController>().todayJournal;
    _notes = TextEditingController(text: entry?.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final colors = OpenAirColors.of(context);
    final day = app.selectedDay;
    final entry = app.todayJournal ??
        JournalEntry(dateKey: JournalEntry.keyFor(day?.date ?? DateTime.now()));

    if (_notes.text != entry.notes && !_notes.selection.isValid) {
      _notes.text = entry.notes;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (day != null)
            DayStrip(days: app.days, selected: day, onSelected: (i) {
              app.selectDay(i);
              final next = app.todayJournal;
              _notes.text = next?.notes ?? '';
            }),
          const SizedBox(height: 16),
          Text(
            'Log behaviors that affect recovery — same idea as daily behavior logging.',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          _toggle(app, entry, 'Alcohol', entry.alcohol, (v) => entry.copyWith(alcohol: v)),
          _toggle(app, entry, 'Caffeine late', entry.caffeineLate, (v) => entry.copyWith(caffeineLate: v)),
          _toggle(app, entry, 'Late meal', entry.lateMeal, (v) => entry.copyWith(lateMeal: v)),
          _toggle(app, entry, 'High stress day', entry.highStress, (v) => entry.copyWith(highStress: v)),
          _toggle(app, entry, 'Hydrated well', entry.hydrated, (v) => entry.copyWith(hydrated: v)),
          _toggle(app, entry, 'Meditated / breathwork', entry.meditated, (v) => entry.copyWith(meditated: v)),
          _toggle(app, entry, 'Feeling sick', entry.sick, (v) => entry.copyWith(sick: v)),
          _toggle(app, entry, 'Travel', entry.travel, (v) => entry.copyWith(travel: v)),
          _toggle(app, entry, 'Cycle / menstrual', entry.menstrual, (v) => entry.copyWith(menstrual: v)),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Anything else about recovery today…',
            ),
            onChanged: (text) => app.updateJournal(entry.copyWith(notes: text)),
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    AppController app,
    JournalEntry entry,
    String label,
    bool value,
    JournalEntry Function(bool) copy,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: (v) => app.updateJournal(copy(v)),
    );
  }
}
