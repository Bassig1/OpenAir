import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    context.watch<AppController>();

    final items = [
      _MoreItem('Weekly Report', 'Performance like Premium wellness reports', Icons.insights, '/weekly', colors.green),
      _MoreItem('Stress & Readiness', 'Stress load + daily readiness', Icons.spa_outlined, '/stress', colors.sleep),
      _MoreItem('Journal', 'Whoop-style behaviors & habits', Icons.menu_book_outlined, '/journal', colors.strain),
      _MoreItem('Insights', 'Live coaching cues from your metrics', Icons.lightbulb_outline, '/insights', colors.green),
      _MoreItem('Programs', 'Guided plans (sleep, strain, stress)', Icons.flag_outlined, '/programs', colors.spo2),
      _MoreItem('Coach', 'Ask Gemini about your data', Icons.auto_awesome, '/coach', colors.green),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'Premium-style features inspired by Whoop + Google Health Premium. Scores are OpenAir heuristics on your Fitbit cloud data.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colors.border),
                ),
                tileColor: colors.surface,
                leading: CircleAvatar(
                  backgroundColor: item.color.withValues(alpha: 0.15),
                  child: Icon(item.icon, color: item.color),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(item.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(item.route),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.title, this.subtitle, this.icon, this.route, this.color);
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
}
