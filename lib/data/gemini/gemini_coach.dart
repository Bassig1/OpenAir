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

    final model = GenerativeModel(
      model: GeminiConfig.modelName,
      apiKey: key,
      systemInstruction: Content.text(_systemCoach),
    );

    final context = recentDays.map((d) => d.toCoachJson()).toList();
    final prompt = StringBuffer()
      ..writeln('User profile: ${jsonEncode(profile.toJson())}')
      ..writeln('User metrics (most recent last):')
      ..writeln(jsonEncode(context))
      ..writeln()
      ..writeln('User question: $question');

    final response =
        await model.generateContent([Content.text(prompt.toString())]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }
    return text;
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

    final model = GenerativeModel(
      model: GeminiConfig.modelName,
      apiKey: key,
      systemInstruction: Content.text(_systemAnalyst),
    );

    final day = recentDays.last;
    final prompt = StringBuffer()
      ..writeln('Write an in-depth daily health analysis for this athlete.')
      ..writeln('Use ONLY the JSON metrics. Be specific with numbers.')
      ..writeln('Structure with short markdown-style headings:')
      ..writeln('## Overnight recovery')
      ..writeln('## Sleep architecture')
      ..writeln('## Heart & autonomic')
      ..writeln('## Activity & strain')
      ..writeln('## Today\'s plan')
      ..writeln('Keep total length under 350 words. No medical diagnosis.')
      ..writeln()
      ..writeln('Profile: ${jsonEncode(profile.toJson())}')
      ..writeln('OpenAir local brief: ${localBrief ?? 'n/a'}')
      ..writeln('Today metrics: ${jsonEncode(day.toCoachJson())}')
      ..writeln(
        'Recent history (oldest→newest): ${jsonEncode(recentDays.map((d) => d.toCoachJson()).toList())}',
      );

    final response =
        await model.generateContent([Content.text(prompt.toString())]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Gemini returned an empty analysis.');
    }
    return text;
  }

  static const _systemCoach =
      'You are OpenAir Coach, a personal fitness and recovery assistant. '
      'Use only the provided metrics JSON. Be practical and specific. '
      'You are not a doctor; include a brief non-diagnostic disclaimer when giving health advice. '
      'Keep answers under 180 words unless asked for detail.';

  static const _systemAnalyst =
      'You are OpenAir Health Analyst. Produce clear, athlete-friendly '
      'interpretations of wearable cloud metrics similar in depth to a premium '
      'health dashboard (sleep stages, HRV/RHR vs baseline, strain capacity, '
      'readiness). Never claim to diagnose disease. Prefer actionable coaching.';
}
