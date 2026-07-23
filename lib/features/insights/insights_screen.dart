import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/scores/health_insights_engine.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final colors = OpenAirColors.of(context);
    final day = app.selectedDay;
    final cards = app.healthInsightCards;
    final cues = app.todaysInsights;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          if (app.geminiReady)
            IconButton(
              tooltip: 'Refresh Gemini analysis',
              onPressed: app.aiAnalysisLoading
                  ? null
                  : () => app.refreshAiAnalysis(force: true),
              icon: app.aiAnalysisLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (day != null)
            DayStrip(days: app.days, selected: day, onSelected: app.selectDay),
          const SizedBox(height: 16),
          Text(
            'Deep read of your Google Health cloud day — sleep, heart, activity, recovery — plus Gemini narrative when signed in.',
            style: TextStyle(color: colors.textSecondary, height: 1.35),
          ),
          if (app.geminiReady) ...[
            const SizedBox(height: 20),
            const SectionHeader('Gemini daily analysis'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: app.aiAnalysisLoading && (app.aiAnalysis ?? '').isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Text(
                      app.aiAnalysis?.trim().isNotEmpty == true
                          ? app.aiAnalysis!
                          : 'Pull to refresh on Today, or tap the sparkle to generate your first Gemini analysis.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        height: 1.45,
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader('Health breakdown'),
          const SizedBox(height: 12),
          if (cards.isEmpty)
            Text(
              'Connect Google Health and sync to see insight cards.',
              style: TextStyle(color: colors.textMuted),
            )
          else
            ...cards.map((c) => _InsightCard(card: c, colors: colors)),
          if (cues.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader('Coaching cues'),
            const SizedBox(height: 12),
            ...cues.map(
              (i) => Container(
                width: double.infinity,
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
                    Text(
                      i.category.toUpperCase(),
                      style: TextStyle(
                        color: colors.green,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(i.body, style: TextStyle(color: colors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.card, required this.colors});

  final HealthInsightCard card;
  final OpenAirColors colors;

  @override
  Widget build(BuildContext context) {
    final accent = switch (card.accent) {
      'sleep' => colors.sleep,
      'heart' => colors.heart,
      'spo2' => colors.spo2,
      'strain' => colors.strain,
      _ => colors.green,
    };
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Text(
                card.category.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                card.score.toStringAsFixed(0),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(card.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            card.body,
            style: TextStyle(color: colors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (card.score / 100).clamp(0.05, 1.0),
              minHeight: 6,
              color: accent,
              backgroundColor: colors.border,
            ),
          ),
        ],
      ),
    );
  }
}
