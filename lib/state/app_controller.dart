import 'package:flutter/foundation.dart';

import '../data/gemini/gemini_coach.dart';
import '../data/health/demo_health_repository.dart';
import '../data/health/google_health_client.dart';
import '../data/local/settings_store.dart';
import '../domain/models/day_summary.dart';
import '../domain/scores/score_engine.dart';

class AppController extends ChangeNotifier {
  AppController({
    SettingsStore? settings,
    DemoHealthRepository? demoRepo,
    GoogleHealthClient? healthClient,
    ScoreEngine? scoreEngine,
    GeminiCoach? coach,
  })  : _settings = settings ?? SettingsStore(),
        _demoRepo = demoRepo ?? DemoHealthRepository(),
        _healthClient = healthClient ?? GoogleHealthClient(),
        _scoreEngine = scoreEngine ?? const ScoreEngine(),
        _coach = coach ?? GeminiCoach();

  final SettingsStore _settings;
  final DemoHealthRepository _demoRepo;
  final GoogleHealthClient _healthClient;
  final ScoreEngine _scoreEngine;
  final GeminiCoach _coach;

  List<DaySummary> days = const [];
  List<ChatMessage> chat = const [];
  bool loading = true;
  bool syncing = false;
  bool useDemoData = true;
  bool googleConnected = false;
  String? geminiApiKey;
  String? errorMessage;
  String? accountEmail;

  DaySummary? get today => days.isEmpty ? null : days.last;

  Future<void> bootstrap() async {
    try {
      useDemoData = await _settings.getUseDemoData();
      geminiApiKey = await _settings.getGeminiApiKey();
      googleConnected = await _settings.getGoogleConnectedFlag();
    } catch (_) {
      useDemoData = true;
    }

    try {
      final silent = await _healthClient.signInSilently();
      if (silent != null) {
        googleConnected = true;
        accountEmail = silent.email;
        await _settings.setGoogleConnectedFlag(true);
      }
    } catch (_) {
      // Silent sign-in is best-effort until Cloud OAuth is configured.
    }

    await refresh();
  }

  Future<void> refresh() async {
    syncing = true;
    errorMessage = null;
    notifyListeners();
    try {
      final raw = useDemoData || !googleConnected
          ? await _demoRepo.loadRecentDays()
          : await _healthClient.fetchRecentDays();
      days = _scoreEngine.scoreDays(raw);
      loading = false;
    } catch (e) {
      errorMessage = e.toString();
      if (days.isEmpty) {
        final raw = await _demoRepo.loadRecentDays();
        days = _scoreEngine.scoreDays(raw);
        useDemoData = true;
      }
      loading = false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> setUseDemoData(bool value) async {
    useDemoData = value;
    await _settings.setUseDemoData(value);
    notifyListeners();
    await refresh();
  }

  Future<void> connectGoogle() async {
    errorMessage = null;
    notifyListeners();
    try {
      final account = await _healthClient.signIn();
      if (account == null) return;
      googleConnected = true;
      accountEmail = account.email;
      useDemoData = false;
      await _settings.setGoogleConnectedFlag(true);
      await _settings.setUseDemoData(false);
      await refresh();
    } catch (e) {
      errorMessage =
          'Google Health sign-in failed. Check Cloud OAuth setup in README.\n$e';
      notifyListeners();
    }
  }

  Future<void> disconnectGoogle() async {
    await _healthClient.signOut();
    googleConnected = false;
    accountEmail = null;
    await _settings.setGoogleConnectedFlag(false);
    useDemoData = true;
    await _settings.setUseDemoData(true);
    notifyListeners();
    await refresh();
  }

  Future<void> saveGeminiKey(String? key) async {
    await _settings.setGeminiApiKey(key);
    geminiApiKey = (key == null || key.trim().isEmpty) ? null : key.trim();
    notifyListeners();
  }

  Future<void> askCoach(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;
    chat = [...chat, ChatMessage(role: 'user', text: trimmed)];
    notifyListeners();
    try {
      final answer = await _coach.ask(
        apiKey: geminiApiKey ?? '',
        question: trimmed,
        recentDays: days.length > 14 ? days.sublist(days.length - 14) : days,
      );
      chat = [...chat, ChatMessage(role: 'assistant', text: answer)];
    } catch (e) {
      chat = [
        ...chat,
        ChatMessage(role: 'assistant', text: 'Could not reach Gemini: $e'),
      ];
    }
    notifyListeners();
  }

  void clearChat() {
    chat = const [];
    notifyListeners();
  }
}
