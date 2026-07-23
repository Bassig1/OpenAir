import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../domain/models/day_summary.dart';

class GeminiCoach {
  Future<String> ask({
    required String apiKey,
    required String question,
    required List<DaySummary> recentDays,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Add a Gemini API key in Settings first.');
    }

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey.trim(),
      systemInstruction: Content.text(
        'You are OpenAir Coach, a concise personal fitness and recovery assistant. '
        'Use only the provided metrics JSON. Be practical and specific. '
        'You are not a doctor; include a brief non-diagnostic disclaimer when giving health advice. '
        'Keep answers under 180 words unless asked for detail.',
      ),
    );

    final context = recentDays.map((d) => d.toCoachJson()).toList();
    final prompt = StringBuffer()
      ..writeln('User metrics (most recent last):')
      ..writeln(jsonEncode(context))
      ..writeln()
      ..writeln('User question: $question');

    final response = await model.generateContent([Content.text(prompt.toString())]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }
    return text;
  }
}
