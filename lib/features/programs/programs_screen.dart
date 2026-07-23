import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final colors = OpenAirColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Guided plans guided recovery and training themes.',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...app.programs.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.category.toUpperCase(),
                    style: TextStyle(
                      color: colors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(p.subtitle, style: TextStyle(color: colors.textSecondary)),
                  const SizedBox(height: 10),
                  Text(p.durationLabel, style: TextStyle(color: colors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
