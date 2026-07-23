import 'dart:async';

import 'package:flutter/material.dart';

import '../data/gemini/gemini_coach.dart';
import '../data/health/demo_health_repository.dart';
import '../data/health/google_health_client.dart';
import '../data/local/journal_store.dart';
import '../data/local/settings_store.dart';
import '../domain/models/day_summary.dart';
import '../domain/models/health_extras.dart';
import '../domain/scores/advanced_analysis.dart';
import '../domain/scores/score_engine.dart';

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    SettingsStore? settings,
    DemoHealthRepository? demoRepo,
    GoogleHealthClient? healthClient,
    ScoreEngine? scoreEngine,
    GeminiCoach? coach,
    JournalStore? journalStore,
  })  : _settings = settings ?? SettingsStore(),
        _demoRepo = demoRepo ?? DemoHealthRepository(),
        _healthClient = healthClient ?? GoogleHealthClient(),
        _scoreEngine = scoreEngine ?? const ScoreEngine(),
        _coach = coach ?? GeminiCoach(),
        _journalStore = journalStore ?? JournalStore();

  final SettingsStore _settings;
  final DemoHealthRepository _demoRepo;
  final GoogleHealthClient _healthClient;
  final ScoreEngine _scoreEngine;
  final GeminiCoach _coach;
  final JournalStore _journalStore;
  final AdvancedAnalysis _analysis = const AdvancedAnalysis();

  static const livePollInterval = Duration(minutes: 1);

  List<DaySummary> days = const [];
  List<ChatMessage> chat = const [];
  List<PairedDeviceInfo> devices = const [];
  BodySnapshot? body;
  JournalEntry? todayJournal;
  int selectedIndex = 0;
  bool loading = true;
  bool syncing = false;
  bool useDemoData = true;
  bool googleConnected = false;
  bool liveSyncEnabled = true;
  ThemeMode themeMode = ThemeMode.system;
  String? geminiApiKey;
  String? googleWebClientId;
  String? errorMessage;
  String? accountEmail;
  DateTime? lastSyncedAt;

  Timer? _liveTimer;

  DaySummary? get selectedDay {
    if (days.isEmpty) return null;
    final i = selectedIndex.clamp(0, days.length - 1);
    return days[i];
  }

  DaySummary? get today => days.isEmpty ? null : days.last;

  bool get isLive => !useDemoData && googleConnected;

  WeeklyReport get weeklyReport => _scoreEngine.buildWeeklyReport(days);

  List<GuidedProgram> get programs => ScoreEngine.guidedPrograms;

  List<InsightItem> get todaysInsights => selectedDay?.insights ?? const [];

  SyncHealth get syncHealth => _analysis.assessSync(
        days: days,
        lastSyncedAt: lastSyncedAt,
        isLive: isLive,
      );

  SleepAnalysis? get sleepAnalysis {
    final day = selectedDay;
    if (day == null) return null;
    return _analysis.sleep(day);
  }

  HeartbeatAnalysis? get heartbeatAnalysis {
    final day = selectedDay;
    if (day == null) return null;
    return _analysis.heartbeat(day, days);
  }

  OxygenAnalysis? get oxygenAnalysis {
    final day = selectedDay;
    if (day == null) return null;
    return _analysis.oxygen(day);
  }

  List<ExerciseSession> get allRecentWorkouts {
    final list = <ExerciseSession>[];
    for (final d in days) {
      list.addAll(d.exercises);
    }
    list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  Future<void> bootstrap() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      useDemoData = await _settings.getUseDemoData();
      geminiApiKey = await _settings.getGeminiApiKey();
      googleWebClientId = await _settings.getGoogleWebClientId();
      googleConnected = await _settings.getGoogleConnectedFlag();
      liveSyncEnabled = await _settings.getLiveSyncEnabled();
      themeMode = await _settings.getThemeMode();
      await _healthClient.configure(serverClientId: googleWebClientId);
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
    } catch (_) {}

    await refresh();
    _restartLiveTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isLive && liveSyncEnabled) {
      unawaited(refresh(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTimer?.cancel();
    super.dispose();
  }

  void _restartLiveTimer() {
    _liveTimer?.cancel();
    if (!isLive || !liveSyncEnabled) return;
    _liveTimer = Timer.periodic(livePollInterval, (_) {
      unawaited(refresh(silent: true));
    });
  }

  void selectDay(int index) {
    if (days.isEmpty) return;
    selectedIndex = index.clamp(0, days.length - 1);
    notifyListeners();
    unawaited(_loadJournalForSelected().then((_) => notifyListeners()));
  }

  Future<void> _loadJournalForSelected() async {
    final day = selectedDay;
    if (day == null) {
      todayJournal = null;
      return;
    }
    todayJournal = await _journalStore.loadForDate(day.date);
  }

  Future<void> updateJournal(JournalEntry entry) async {
    await _journalStore.save(entry);
    todayJournal = entry;
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      syncing = true;
      errorMessage = null;
      notifyListeners();
    } else if (syncing) {
      return;
    } else {
      syncing = true;
      notifyListeners();
    }

    final previousSelected = selectedDay?.date;
    try {
      if (useDemoData || !googleConnected) {
        final bundle = await _demoRepo.loadBundle();
        days = _scoreEngine.scoreDays(bundle.days);
        body = bundle.body;
        devices = bundle.devices;
      } else {
        final bundle = await _healthClient.syncRecent();
        days = _scoreEngine.scoreDays(bundle.days);
        body = bundle.body;
        devices = bundle.devices;
      }
      if (previousSelected != null) {
        final i = days.indexWhere(
          (d) =>
              d.date.year == previousSelected.year &&
              d.date.month == previousSelected.month &&
              d.date.day == previousSelected.day,
        );
        selectedIndex = i >= 0 ? i : (days.isEmpty ? 0 : days.length - 1);
      } else {
        selectedIndex = days.isEmpty ? 0 : days.length - 1;
      }
      lastSyncedAt = DateTime.now();
      loading = false;
      errorMessage = null;
      await _loadJournalForSelected();
    } catch (e) {
      errorMessage = e.toString();
      if (days.isEmpty) {
        final bundle = await _demoRepo.loadBundle();
        days = _scoreEngine.scoreDays(bundle.days);
        body = bundle.body;
        devices = bundle.devices;
        selectedIndex = days.length - 1;
        useDemoData = true;
      }
      loading = false;
      await _loadJournalForSelected();
    } finally {
      syncing = false;
      notifyListeners();
      _restartLiveTimer();
    }
  }

  Future<void> setUseDemoData(bool value) async {
    useDemoData = value;
    await _settings.setUseDemoData(value);
    notifyListeners();
    await refresh();
    _restartLiveTimer();
  }

  Future<void> setLiveSyncEnabled(bool value) async {
    liveSyncEnabled = value;
    await _settings.setLiveSyncEnabled(value);
    notifyListeners();
    _restartLiveTimer();
    if (value && isLive) await refresh(silent: true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _settings.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> connectGoogle() async {
    errorMessage = null;
    notifyListeners();
    try {
      await _healthClient.configure(serverClientId: googleWebClientId);
      final account = await _healthClient.signIn();
      if (account == null) return;
      googleConnected = true;
      accountEmail = account.email;
      useDemoData = false;
      await _settings.setGoogleConnectedFlag(true);
      await _settings.setUseDemoData(false);
      await refresh();
      _restartLiveTimer();
    } catch (e) {
      final text = e.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
      errorMessage = text;
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
    _restartLiveTimer();
  }

  Future<void> saveGoogleWebClientId(String? clientId) async {
    await _settings.setGoogleWebClientId(clientId);
    googleWebClientId =
        (clientId == null || clientId.trim().isEmpty) ? null : clientId.trim();
    await _healthClient.configure(serverClientId: googleWebClientId);
    notifyListeners();
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
