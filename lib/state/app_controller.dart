import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/gemini/gemini_coach.dart';
import '../data/health/demo_health_repository.dart';
import '../data/health/google_health_client.dart';
import '../data/local/journal_store.dart';
import '../data/local/notification_service.dart';
import '../data/local/settings_store.dart';
import '../data/local/workout_store.dart';
import '../domain/models/day_summary.dart';
import '../domain/models/health_extras.dart';
import '../domain/models/user_profile.dart';
import '../domain/scores/advanced_analysis.dart';
import '../domain/scores/period_analytics.dart';
import '../domain/scores/score_engine.dart';

class ActiveWorkout {
  const ActiveWorkout({
    required this.activityName,
    required this.startedAt,
  });

  final String activityName;
  final DateTime startedAt;

  Duration get elapsed => DateTime.now().difference(startedAt);
}

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    SettingsStore? settings,
    DemoHealthRepository? demoRepo,
    GoogleHealthClient? healthClient,
    ScoreEngine? scoreEngine,
    GeminiCoach? coach,
    JournalStore? journalStore,
    WorkoutStore? workoutStore,
    NotificationService? notifications,
  })  : _settings = settings ?? SettingsStore(),
        _demoRepo = demoRepo ?? DemoHealthRepository(),
        _healthClient = healthClient ?? GoogleHealthClient(),
        _scoreEngine = scoreEngine ?? const ScoreEngine(),
        _coach = coach ?? GeminiCoach(),
        _journalStore = journalStore ?? JournalStore(),
        _workoutStore = workoutStore ?? WorkoutStore(),
        _notifications = notifications ?? NotificationService();

  final SettingsStore _settings;
  final DemoHealthRepository _demoRepo;
  final GoogleHealthClient _healthClient;
  final ScoreEngine _scoreEngine;
  final GeminiCoach _coach;
  final JournalStore _journalStore;
  final WorkoutStore _workoutStore;
  final NotificationService _notifications;
  final AdvancedAnalysis _analysis = const AdvancedAnalysis();
  final PeriodAnalytics _periods = const PeriodAnalytics();

  static const livePollInterval = Duration(minutes: 1);
  static const syncDayWindow = 30;

  List<DaySummary> days = const [];
  List<ChatMessage> chat = const [];
  List<PairedDeviceInfo> devices = const [];
  List<ExerciseSession> manualWorkouts = const [];
  BodySnapshot? body;
  UserProfile profile = UserProfile.empty;
  JournalEntry? todayJournal;
  ActiveWorkout? activeWorkout;
  int selectedIndex = 0;
  bool loading = true;
  bool syncing = false;
  bool useDemoData = true;
  bool googleConnected = false;
  bool liveSyncEnabled = true;
  bool alertsEnabled = true;
  ThemeMode themeMode = ThemeMode.system;
  String? geminiApiKey;
  String? googleWebClientId;
  String? errorMessage;
  String? accountEmail;
  DateTime? lastSyncedAt;

  Timer? _liveTimer;
  Timer? _activeWorkoutTicker;

  DaySummary? get selectedDay {
    if (days.isEmpty) return null;
    final i = selectedIndex.clamp(0, days.length - 1);
    return days[i];
  }

  DaySummary? get today => days.isEmpty ? null : days.last;

  bool get isLive => !useDemoData && googleConnected;

  WeeklyReport get weeklyReport => _scoreEngine.buildWeeklyReport(days);

  PeriodSummary get dailySummary {
    final day = selectedDay;
    if (day == null) {
      final now = DateTime.now();
      return PeriodSummary(
        label: 'Daily',
        start: now,
        end: now,
        dayCount: 0,
        avgRecovery: 0,
        avgStrain: 0,
        avgSleepPerformance: 0,
        avgSleepMinutes: 0,
        avgHrv: null,
        avgRhr: null,
        avgReadiness: 0,
        avgStress: 0,
        totalSteps: 0,
        totalWorkouts: 0,
        hrvTrend: '—',
        recoveryTrend: '—',
        sleepTrend: '—',
        summary: 'No day selected',
      );
    }
    return _periods.daily(day, profile);
  }

  PeriodSummary get weekSummary => _periods.week(days, profile);

  PeriodSummary get monthSummary => _periods.month(days, profile);

  HrvTrendReport get hrvTrends => _periods.hrvReport(days);

  List<TrendPoint> hrvSeries({int take = 30}) =>
      _periods.hrvSeries(days, take: take);

  List<TrendPoint> sleepPerfSeries({int take = 30}) =>
      _periods.sleepPerformanceSeries(days, profile, take: take);

  List<TrendPoint> recoverySeries({int take = 30}) =>
      _periods.recoverySeries(days, take: take);

  BodySnapshot get effectiveBody {
    final cloud = body;
    return BodySnapshot(
      weightKg: profile.weightKg ?? cloud?.weightKg,
      heightCm: profile.heightCm ?? cloud?.heightCm,
      bodyFatPercent: cloud?.bodyFatPercent,
      vo2Max: cloud?.vo2Max,
      measuredAt: cloud?.measuredAt,
    );
  }

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
    return _analysis.sleep(day, profile: profile, history: days);
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
      alertsEnabled = await _settings.getAlertsEnabled();
      themeMode = await _settings.getThemeMode();
      final profileJson = await _settings.getUserProfileJson();
      if (profileJson != null && profileJson.trim().isNotEmpty) {
        profile = UserProfile.fromJson(
          jsonDecode(profileJson) as Map<String, dynamic>,
        );
      }
      manualWorkouts = await _workoutStore.loadAll();
      await _healthClient.configure(serverClientId: googleWebClientId);
      if (alertsEnabled) await _notifications.init();
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
    _activeWorkoutTicker?.cancel();
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

  List<DaySummary> _mergeManualWorkouts(List<DaySummary> scored) {
    if (manualWorkouts.isEmpty) return scored;
    return scored.map((day) {
      final extras = manualWorkouts.where((w) {
        return w.start.year == day.date.year &&
            w.start.month == day.date.month &&
            w.start.day == day.date.day;
      }).toList();
      if (extras.isEmpty) return day;
      final existingIds = day.exercises.map((e) => e.id).toSet();
      final merged = [
        ...day.exercises,
        ...extras.where((e) => !existingIds.contains(e.id)),
      ]..sort((a, b) => b.start.compareTo(a.start));
      return day.copyWith(exercises: merged);
    }).toList();
  }

  String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _maybeNotifyAlerts() async {
    if (!alertsEnabled || days.isEmpty) return;
    final day = days.last;
    final ymd = _ymd(day.date);

    final lastSleep = await _settings.getLastSleepNotifyYmd();
    if (day.sleepMinutes >= 180 && lastSleep != ymd) {
      final summary =
          _analysis.sleep(day, profile: profile, history: days).summary;
      await _notifications.sleepSummary(summary: summary);
      await _settings.setLastSleepNotifyYmd(ymd);
    }

    final lastHr = await _settings.getLastHrNotifyYmd();
    if (lastHr != ymd) {
      final event = _analysis.detectUnusualHeart(day: day, history: days);
      if (event != null) {
        await _notifications.unusualHeartbeat(
          bpm: event.bpm,
          baseline: event.baselineBpm,
        );
        await _settings.setLastHrNotifyYmd(ymd);
      }
    }
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
      manualWorkouts = await _workoutStore.loadAll();
      if (useDemoData || !googleConnected) {
        final bundle = await _demoRepo.loadBundle(days: syncDayWindow);
        days = _mergeManualWorkouts(
          _scoreEngine.scoreDays(bundle.days, profile: profile),
        );
        body = _mergeBody(bundle.body);
        devices = bundle.devices;
      } else {
        final bundle = await _healthClient.syncRecent(days: syncDayWindow);
        days = _mergeManualWorkouts(
          _scoreEngine.scoreDays(bundle.days, profile: profile),
        );
        body = _mergeBody(bundle.body);
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
      unawaited(_maybeNotifyAlerts());
    } catch (e) {
      errorMessage = e.toString();
      if (days.isEmpty) {
        final bundle = await _demoRepo.loadBundle(days: syncDayWindow);
        days = _mergeManualWorkouts(
          _scoreEngine.scoreDays(bundle.days, profile: profile),
        );
        body = _mergeBody(bundle.body);
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

  BodySnapshot? _mergeBody(BodySnapshot? cloud) {
    if (cloud == null &&
        profile.weightKg == null &&
        profile.heightCm == null) {
      return null;
    }
    return BodySnapshot(
      weightKg: profile.weightKg ?? cloud?.weightKg,
      heightCm: profile.heightCm ?? cloud?.heightCm,
      bodyFatPercent: cloud?.bodyFatPercent,
      vo2Max: cloud?.vo2Max,
      measuredAt: cloud?.measuredAt,
    );
  }

  Future<void> saveProfile(UserProfile next) async {
    profile = next;
    await _settings.setUserProfileJson(jsonEncode(next.toJson()));
    notifyListeners();
    await refresh(silent: true);
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

  Future<void> setAlertsEnabled(bool value) async {
    alertsEnabled = value;
    await _settings.setAlertsEnabled(value);
    if (value) await _notifications.init();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _settings.setThemeMode(mode);
    notifyListeners();
  }

  void startWorkout(String activityName) {
    if (activeWorkout != null) return;
    activeWorkout = ActiveWorkout(
      activityName: activityName,
      startedAt: DateTime.now(),
    );
    _activeWorkoutTicker?.cancel();
    _activeWorkoutTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  Future<ExerciseSession?> stopWorkout({
    double? calories,
    double? distanceMeters,
    int? perceivedExertion,
    String? notes,
  }) async {
    final active = activeWorkout;
    if (active == null) return null;
    _activeWorkoutTicker?.cancel();
    activeWorkout = null;

    final end = DateTime.now();
    final session = ExerciseSession(
      id: 'manual-${active.startedAt.millisecondsSinceEpoch}',
      name: active.activityName,
      start: active.startedAt,
      end: end,
      calories: calories,
      distanceMeters: distanceMeters,
      perceivedExertion: perceivedExertion,
      notes: notes,
      isManual: true,
    );
    manualWorkouts = await _workoutStore.upsert(session);
    await refresh(silent: true);

    final analysis = _analysis.workout(
      session,
      dayStrain: today?.strainScore,
    );
    if (alertsEnabled) {
      await _notifications.workoutComplete(
        name: session.name,
        minutes: session.durationMinutes,
        calories: session.calories ?? analysis.calorieEstimate,
        strainDelta: analysis.strainContribution,
      );
    }
    notifyListeners();
    return session;
  }

  Future<void> logManualWorkout(ExerciseSession session) async {
    manualWorkouts = await _workoutStore.upsert(session);
    await refresh(silent: true);
    final analysis = _analysis.workout(
      session,
      dayStrain: today?.strainScore,
    );
    if (alertsEnabled) {
      await _notifications.workoutComplete(
        name: session.name,
        minutes: session.durationMinutes,
        calories: session.calories ?? analysis.calorieEstimate,
        strainDelta: analysis.strainContribution,
      );
    }
  }

  Future<void> deleteManualWorkout(String id) async {
    manualWorkouts = await _workoutStore.remove(id);
    await refresh(silent: true);
  }

  WorkoutAnalysis analyzeWorkout(ExerciseSession session) {
    return _analysis.workout(session, dayStrain: today?.strainScore);
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
      final text = e
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
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
