// Validates an OpenAir diagnostic dump (diagnostics/latest.json).
// Usage: dart run tool/validate_diagnostic.dart [path]
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final path = args.isEmpty ? 'diagnostics/latest.json' : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path — export from Settings first.');
    exit(1);
  }
  final dump = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final days = (dump['days'] as List?) ?? const [];
  final flags = (dump['sanityFlags'] as List?) ?? const [];
  final whoop = dump['whoopStyleAnalysis'] as Map?;
  final body = dump['bodyFromGoogleHealth'] as Map?;
  final conn = dump['connection'] as Map? ?? {};

  stdout.writeln('OpenAir diagnostic review');
  stdout.writeln('-------------------------');
  stdout.writeln('Days: ${conn['dayCount'] ?? days.length}');
  stdout.writeln('Google connected: ${conn['googleConnected']}');
  stdout.writeln('Body present: ${body != null}');
  stdout.writeln('Gemini analysis: ${conn['hasGeminiAnalysis']}');
  if (conn['geminiError'] != null) {
    stdout.writeln('Gemini error: ${conn['geminiError']}');
  }
  stdout.writeln('Sanity flags: ${flags.length}');
  for (final f in flags) {
    stdout.writeln('  • $f');
  }
  if (whoop != null) {
    stdout.writeln('\nWhoop-style (latest day ${whoop['focusDate']}):');
    stdout.writeln('  Recovery: ${whoop['recovery']}');
    stdout.writeln('  Strain: ${whoop['strain']}');
    stdout.writeln('  Sleep performance: ${whoop['sleepPerformance']}%');
    stdout.writeln('  SpO₂: ${whoop['spo2']} (${whoop['spo2Label']})');
    stdout.writeln('  HRV: ${whoop['hrvMs']}  RHR: ${whoop['rhr']}');
  }
  if (body != null) {
    stdout.writeln('\nBody: ${body['weightKg']} kg · ${body['heightCm']} cm');
  }
  if (days.isNotEmpty) {
    final last = days.last as Map;
    stdout.writeln('\nLatest day metrics:');
    stdout.writeln(
      '  sleep ${last['sleepMinutes']}m '
      '(D${last['deepSleepMinutes']}/R${last['remSleepMinutes']}/'
      'L${last['lightSleepMinutes']}/A${last['awakeMinutes']}) '
      'SpO₂ ${last['spo2Percent']} steps ${last['steps']}',
    );
  }
  final raw = dump['rawGoogleHealth'];
  stdout.writeln(
    '\nRaw Google Health samples included: ${raw != null && raw is! String}',
  );
}
