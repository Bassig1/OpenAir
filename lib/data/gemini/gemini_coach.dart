import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../config/gemini_config.dart';
import '../../domain/models/day_summary.dart';
import '../../domain/models/user_profile.dart';

class GeminiCoach {
  Future<String> ask({
    required String apiKey,
    required String question,
    required List<DaySummary> recentDays,
    UserProfile profile = UserProfile.empty,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw StateError('Gemini is unavailable right now.');
    }

    final context = recentDays.map((d) => d.toCoachJson()).toList();
    final prompt = StringBuffer()
      ..writeln('User profile: ${jsonEncode(profile.toJson())}')
      ..writeln('User metrics (most recent last):')
      ..writeln(jsonEncode(context))
      ..writeln()
      ..writeln('User question: $question');

    return _generate(
      apiKey: key,
      system: _systemCoach,
      prompt: prompt.toString(),
    );
  }

  /// Full daily health narrative — sleep, heart, activity, recovery, plan.
  Future<String> generateDailyAnalysis({
    required String apiKey,
    required List<DaySummary> recentDays,
    UserProfile profile = UserProfile.empty,
    String? localBrief,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw StateError('Gemini is unavailable right now.');
    }
    if (recentDays.isEmpty) {
      throw StateError('No health metrics to analyze yet.');
    }

    final day = recentDays.last;
    final prompt = StringBuffer()
      ..writeln('Write an in-depth daily health analysis for this athlete.')
      ..writeln('Use ONLY the JSON metrics. Be specific with numbers.')
      ..writeln('Match the clarity of a premium recovery coach (Whoop-style):')
      ..writeln('- Cite EXACT percentages and minutes from the JSON')
      ..writeln('- Include sleep stage shares (deep/REM/light %) and efficiency')
      ..writeln('- Explain WHAT the numbers mean in plain English')
      ..writeln('- Compare today vs recent baseline when history is present')
      ..writeln('- Call out HRV/RHR, SpO₂ range if present, strain capacity')
      ..writeln('- End with a concrete training / recovery plan for today')
      ..writeln('Structure with short markdown-style headings:')
      ..writeln('## Overnight recovery')
      ..writeln('## Sleep architecture')
      ..writeln('## Heart & autonomic')
      ..writeln('## Oxygen & vitals')
      ..writeln('## Activity & strain')
      ..writeln('## Today\'s plan')
      ..writeln('Keep total length under 450 words. No medical diagnosis.')
      ..writeln()
      ..writeln('Profile: ${jsonEncode(profile.toJson())}')
      ..writeln('OpenAir local brief: ${localBrief ?? 'n/a'}')
      ..writeln('Today metrics: ${jsonEncode(day.toCoachJson())}')
      ..writeln(
        'Recent history (oldest→newest): ${jsonEncode(recentDays.map((d) => d.toCoachJson()).toList())}',
      );

    return _generate(
      apiKey: key,
      system: _systemAnalyst,
      prompt: prompt.toString(),
    );
  }

  Future<String> _generate({
    required String apiKey,
    required String system,
    required String prompt,
  }) async {
    final models = <String>[
      GeminiConfig.modelName,
      ...GeminiConfig.modelFallbacks,
    ];
    final tried = <String>{};
    Object? lastError;

    for (final modelName in models) {
      if (!tried.add(modelName)) continue;
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          systemInstruction: Content.text(system),
        );
        final response =
            await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) return text;
        lastError = StateError('Gemini returned an empty response.');
      } catch (e) {
        lastError = e;
        final msg = e.toString().toLowerCase();
        final retryable = msg.contains('429') ||
            msg.contains('404') ||
            msg.contains('not found') ||
            msg.contains('quota') ||
            msg.contains('resource_exhausted') ||
            msg.contains('unavailable');
        if (!retryable) rethrow;
      }
    }

    throw StateError(
      'Gemini analysis failed after trying ${tried.length} models. '
      '${lastError ?? 'Unknown error'}',
    );
  }

  static const _systemCoach =
      'You are OpenAir Coach — a recovery coach in the style of premium '
      'wearable apps (clear, direct, athlete-first like WHOOP). '
      'Use only the provided metrics JSON. Always cite exact percentages '
      'and minutes from the JSON (e.g. deep 9.6%, efficiency 90.7%, '
      'recovery 72.0). Explain what they mean in plain English, then give '
      'one concrete plan. You are not a doctor; avoid diagnosis. '
      'Keep answers under 220 words unless asked for detail.';

  static const _systemAnalyst =
      'You are OpenAir Health Analyst. Write like a premium recovery coach '
      '(WHOOP-style): recovery zone first, then sleep architecture with '
      'exact percentages (performance, hours vs need, efficiency, deep/REM/'
      'light/awake %), then autonomic status (HRV and resting HR vs baseline '
      'with exact ms/bpm), SpO₂/vitals if present, then strain capacity and '
      'a specific training plan for today. Use only provided metrics. '
      'Never round away meaningful decimals when the JSON has them. '
      'Never diagnose disease. Prefer actionable coaching over jargon.';
}
