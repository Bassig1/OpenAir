import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/oauth_config.dart';
import '../config/gemini_config.dart';
import '../data/diagnostics/health_diagnostic_export.dart';
import '../data/gemini/gemini_coach.dart';
import '../data/gemini/local_coach.dart';
import '../data/health/demo_health_repository.dart';
import '../data/health/google_health_client.dart';
import '../data/local/health_cache_store.dart';
import '../data/local/journal_store.dart';
import '../data/local/notification_service.dart';
import '../data/local/settings_store.dart';
import '../data/local/workout_store.dart';
import '../domain/models/day_summary.dart';
import '../domain/models/health_extras.dart';
import '../domain/models/user_profile.dart';
import '../domain/scores/advanced_analysis.dart';
import '../domain/scores/health_insights_engine.dart';
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
    HealthCacheStore? healthCache,
    GoogleHealthClient? healthClient,
    ScoreEngine? scoreEngine,
    GeminiCoach? coach,
    JournalStore? journalStore,
    WorkoutStore? workoutStore,
    NotificationService? notifications,
  })  : _settings = settings ?? SettingsStore(),
        _healthCache = healthCache ?? HealthCacheStore(),
        _healthClient = healthClient ??
            GoogleHealthClient(serverClientId: OAuthConfig.defaultWebClientId),
        _scoreEngine = scoreEngine ?? const ScoreEngine(),
        _coach = coach ?? GeminiCoach(),
        _localCoach = const LocalCoach(),
        _journalStore = journalStore ?? JournalStore(),
        _workoutStore = workoutStore ?? WorkoutStore(),
        _notifications = notifications ?? NotificationService();

  final SettingsStore _settings;
  final HealthCacheStore _healthCache;
  final GoogleHealthClient _healthClient;
  final ScoreEngine _scoreEngine;
  final GeminiCoach _coach;
  final LocalCoach _localCoach;
  final JournalStore _journalStore;
  final WorkoutStore _workoutStore;
  final NotificationService _notifications;
  final AdvancedAnalysis _analysis = const AdvancedAnalysis();
  final PeriodAnalytics _periods = const PeriodAnalytics();
  final HealthInsightsEngine _insightsEngine = const HealthInsightsEngine();

  static const syncDayWindow = 30;
  static const syncTimeout = Duration(seconds: 90);

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
  bool googleConnected = false;
  bool alertsEnabled = true;
  bool aiAnalysisLoading = false;
  ThemeMode themeMode = ThemeMode.system;
  String? geminiApiKey;
  String? googleWebClientId;
  String? errorMessage;
  String? accountEmail;
  String? aiAnalysis;
  String? aiAnalysisDayKey;
  String? aiAnalysisError;
  DateTime? lastSyncedAt;

  Timer? _activeWorkoutTicker;

  DaySummary? get selectedDay {
    if (days.isEmpty) return null;
    final i = selectedIndex.clamp(0, days.length - 1);
    return days[i];
  }

  DaySummary? get today => days.isEmpty ? null : days.last;

  bool get isConnected => googleConnected;

  /// Personal build: use Settings key or `--dart-define=GEMINI_API_KEY=...`.
  /// Public repo ships with no baked-in key.
  String get effectiveGeminiKey {
    final override = geminiApiKey?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return GeminiConfig.defaultApiKey;
  }

  bool get geminiReady => effectiveGeminiKey.isNotEmpty;

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

  List<InsightItem> get todaysInsights => selectedDay?.insights ?? const [];

  List<HealthInsightCard> get healthInsightCards {
    final day = selectedDay;
    if (day == null) return const [];
    return _insightsEngine.build(
      day: day,
      history: days,
      profile: profile,
    );
  }

  SyncHealth get syncHealth => _analysis.assessSync(
        days: days,
        lastSyncedAt: lastSyncedAt,
        connected: googleConnected,
      );

  DayBriefing? get dayBriefing {
    final day = selectedDay;
    if (day == null) return null;
    return _analysis.briefing(day: day, history: days, profile: profile);
  }

  MetricSample? get latestHeartSample {
    MetricSample? latest;
    for (final day in days) {
      for (final sample in day.heartSamples) {
        if (latest == null || sample.time.isAfter(latest.time)) {
          latest = sample;
        }
      }
    }
    return latest;
  }

  SleepAnalysis? get sleepAnalysis {
    final day = selectedDay;
    if (day == null) return null;
    return _analysis.sleep(day, profile: profile, history: days);
  }

  StrainDayAnalysis? get strainAnalysis {
    final day = selectedDay;
    if (day == null) return null;
    return _analysis.strain(day, profile: profile);
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

    // Portfolio / screenshot builds only: flutter run --dart-define=SHOWCASE=true
    const showcase = bool.fromEnvironment('SHOWCASE');
    if (showcase) {
      await _bootstrapShowcase();
      return;
    }

    try {
      geminiApiKey = await _settings.getGeminiApiKey();
      googleWebClientId = await _settings.getGoogleWebClientId();
      if (googleWebClientId == null || googleWebClientId!.trim().isEmpty) {
        googleWebClientId = OAuthConfig.defaultWebClientId;
        await _settings.setGoogleWebClientId(googleWebClientId);
      }
      googleConnected = await _settings.getGoogleConnectedFlag();
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
      final cachedAi = await _settings.getAiAnalysis();
      aiAnalysis = cachedAi.text;
      aiAnalysisDayKey = cachedAi.dayKey;
    } catch (_) {
      googleWebClientId ??= OAuthConfig.defaultWebClientId;
      try {
        await _healthClient.configure(serverClientId: googleWebClientId);
      } catch (_) {}
    }

    // Show last successful snapshot immediately (no demo filler).
    final cached = await _healthCache.load();
    if (cached != null && cached.days.isNotEmpty) {
      days = _mergeManualWorkouts(
        _scoreEngine.scoreDays(cached.days, profile: profile),
      );
      body = cached.body;
      devices = cached.devices;
      lastSyncedAt = cached.syncedAt;
      selectedIndex = days.isEmpty ? 0 : days.length - 1;
      loading = false;
      notifyListeners();
      await _loadJournalForSelected();
    }

    // Show UI immediately — never block cold start on network sync.
    loading = false;
    notifyListeners();
    unawaited(_finishBootstrapInBackground());
  }

  Future<void> _finishBootstrapInBackground() async {
    try {
      if (alertsEnabled) await _notifications.init();
    } catch (_) {}

    try {
      final silent = await _healthClient.signInSilently();
      if (silent != null) {
        googleConnected = true;
        accountEmail = silent.email;
        await _settings.setGoogleConnectedFlag(true);
        notifyListeners();
      } else if (googleConnected) {
        accountEmail = null;
        notifyListeners();
      }
    } catch (_) {}

    await refresh(silent: days.isNotEmpty);
  }

  Future<void> _bootstrapShowcase() async {
    themeMode = ThemeMode.dark;
    googleConnected = true;
    accountEmail = 'portfolio@openair.app';
    lastSyncedAt = DateTime.now();
    profile = const UserProfile(
      ageYears: 28,
      sex: BiologicalSex.male,
      weightKg: 78.4,
      heightCm: 178,
    );
    final bundle = await DemoHealthRepository().loadBundle(days: syncDayWindow);
    days = _mergeManualWorkouts(
      _scoreEngine.scoreDays(bundle.days, profile: profile),
    );
    body = bundle.body;
    devices = bundle.devices;
    selectedIndex = days.isEmpty ? 0 : days.length - 1;
    aiAnalysis =
        'Overnight recovery\n'
        'Recovery landed in the green zone after a solid night. HRV held near '
        'your recent baseline and resting heart rate stayed calm.\n\n'
        'Sleep architecture\n'
        'Sleep performance was strong relative to need, with a healthy mix of '
        'deep and REM. A little less late-night wake time would push efficiency higher.\n\n'
        'Today\'s plan\n'
        'You still have strain capacity left. One focused workout is fine — '
        'keep bedtime consistent tonight so tomorrow stays green.';
    aiAnalysisDayKey = _ymd(days.last.date);
    errorMessage = null;
    loading = false;
    notifyListeners();
    try {
      await _loadJournalForSelected();
    } catch (_) {
      todayJournal = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (const bool.fromEnvironment('SHOWCASE')) return;
    if (state == AppLifecycleState.resumed && googleConnected) {
      unawaited(refresh(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeWorkoutTicker?.cancel();
    super.dispose();
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
    try {
      todayJournal = await _journalStore.loadForDate(day.date);
    } catch (_) {
      todayJournal = null;
    }
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

    final lastRecovery = await _settings.getLastRecoveryNotifyYmd();
    if (lastRecovery != ymd && day.sleepMinutes >= 180) {
      final brief =
          _analysis.briefing(day: day, history: days, profile: profile);
      final recovery = day.recoveryScore?.toStringAsFixed(0) ?? '—';
      await _notifications.recoveryBrief(
        headline: 'Recovery ${brief.recoveryZone} · $recovery',
        body:
            '${brief.headline} Sleep ${brief.sleepPerformance.toStringAsFixed(0)}% · '
            '${brief.strainTarget}.',
      );
      await _settings.setLastRecoveryNotifyYmd(ymd);
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

      if (!googleConnected) {
        loading = false;
        errorMessage = null;
        return;
      }

      if (const bool.fromEnvironment('SHOWCASE')) {
        loading = false;
        errorMessage = null;
        return;
      }

      final bundle = await _healthClient
          .syncRecent(days: syncDayWindow)
          .timeout(
            syncTimeout,
            onTimeout: () => throw TimeoutException(
              'Google Health sync timed out. Pull to refresh after Fitbit syncs.',
            ),
          );
      days = _mergeManualWorkouts(
        _scoreEngine.scoreDays(bundle.days, profile: profile),
      );
      body = bundle.body;
      devices = bundle.devices;
      lastSyncedAt = DateTime.now();
      await _maybeImportCloudBody(bundle.body);
      await _healthCache.save(
        days: days,
        body: body,
        devices: devices,
        syncedAt: lastSyncedAt,
      );

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
      loading = false;
      errorMessage = null;
      await _loadJournalForSelected();
      unawaited(_maybeNotifyAlerts());
      unawaited(refreshAiAnalysis(force: true));
    } catch (e) {
      errorMessage = e
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '')
          .replaceFirst('TimeoutException: ', '');
      // Keep cached days — never wipe to demo on sync failure.
      loading = false;
      await _loadJournalForSelected();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> saveProfile(UserProfile next) async {
    profile = next;
    await _settings.setUserProfileJson(jsonEncode(next.toJson()));
    notifyListeners();
    if (googleConnected) await refresh(silent: true);
  }

  /// Fill blank profile fields from Google Health body metrics.
  Future<void> _maybeImportCloudBody(BodySnapshot? cloud) async {
    if (cloud == null) return;
    var next = profile;
    var changed = false;
    if (next.weightKg == null && cloud.weightKg != null) {
      next = next.copyWith(weightKg: cloud.weightKg);
      changed = true;
    }
    if (next.heightCm == null && cloud.heightCm != null) {
      next = next.copyWith(heightCm: cloud.heightCm);
      changed = true;
    }
    if (!changed) return;
    profile = next;
    await _settings.setUserProfileJson(jsonEncode(next.toJson()));
  }

  /// Overwrite profile weight/height from the latest Google Health snapshot.
  /// Fetches body metrics live so Import works even if the last full sync missed them.
  Future<bool> importBodyFromGoogleHealth() async {
    if (!googleConnected) return false;
    BodySnapshot? cloud = body;
    try {
      cloud = await _healthClient.fetchLatestBody() ?? cloud;
      if (cloud != null) {
        body = cloud;
        await _healthCache.save(
          days: days,
          body: body,
          devices: devices,
          syncedAt: lastSyncedAt ?? DateTime.now(),
        );
      }
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
    if (cloud == null ||
        (cloud.weightKg == null && cloud.heightCm == null)) {
      return false;
    }
    profile = profile.copyWith(
      weightKg: cloud.weightKg ?? profile.weightKg,
      heightCm: cloud.heightCm ?? profile.heightCm,
      useMetric: true,
    );
    await _settings.setUserProfileJson(jsonEncode(profile.toJson()));
    notifyListeners();
    return true;
  }

  bool diagnosticExporting = false;

  /// One-tap dump for Cursor: parsed days, Whoop-style analysis, sanity flags,
  /// and truncated raw Google Health JSON so we can verify accuracy for you.
  Future<String> exportDiagnosticsForCursor({bool includeRaw = true}) async {
    diagnosticExporting = true;
    notifyListeners();
    try {
      Map<String, dynamic>? raw;
      if (includeRaw && googleConnected) {
        try {
          raw = await _healthClient.fetchDiagnosticRaw();
        } catch (e) {
          raw = {'error': e.toString()};
        }
      }
      final dump = const HealthDiagnosticExport().build(
        days: days,
        profile: profile,
        body: body,
        devices: devices,
        aiAnalysis: aiAnalysis,
        aiAnalysisError: aiAnalysisError,
        lastSyncedAt: lastSyncedAt,
        rawGoogleHealth: raw,
        googleConnected: googleConnected,
      );
      return const HealthDiagnosticExport().encodePretty(dump);
    } finally {
      diagnosticExporting = false;
      notifyListeners();
    }
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
      final clientId =
          (googleWebClientId == null || googleWebClientId!.trim().isEmpty)
              ? OAuthConfig.defaultWebClientId
              : googleWebClientId!;
      googleWebClientId = clientId;
      await _settings.setGoogleWebClientId(clientId);
      await _healthClient.configure(serverClientId: clientId);
      final account = await _healthClient.signIn();
      if (account == null) return;
      googleConnected = true;
      accountEmail = account.email;
      await _settings.setGoogleConnectedFlag(true);
      await refresh();
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
    await _healthCache.clear();
    await _settings.clearAiAnalysis();
    days = const [];
    body = null;
    devices = const [];
    lastSyncedAt = null;
    aiAnalysis = null;
    aiAnalysisDayKey = null;
    loading = false;
    notifyListeners();
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
    if (geminiReady) unawaited(refreshAiAnalysis(force: true));
  }

  Future<void> refreshAiAnalysis({bool force = false}) async {
    if (!googleConnected || !geminiReady || days.isEmpty) return;
    final day = selectedDay ?? days.last;
    final dayKey = _ymd(day.date);
    if (!force &&
        aiAnalysis != null &&
        aiAnalysisDayKey == dayKey &&
        aiAnalysis!.trim().isNotEmpty) {
      return;
    }
    if (aiAnalysisLoading) return;
    aiAnalysisLoading = true;
    aiAnalysisError = null;
    notifyListeners();
    try {
      final recent =
          days.length > 14 ? days.sublist(days.length - 14) : days;
      final local = dayBriefing?.coaching;
      final text = await _coach.generateDailyAnalysis(
        apiKey: effectiveGeminiKey,
        recentDays: recent,
        profile: profile,
        localBrief: local,
      );
      aiAnalysis = text;
      aiAnalysisDayKey = dayKey;
      aiAnalysisError = null;
      await _settings.setAiAnalysis(dayKey, text);
    } catch (e) {
      aiAnalysisError = e.toString().replaceFirst('Exception: ', '');
      // Keep prior analysis; local insight cards still cover the day.
    } finally {
      aiAnalysisLoading = false;
      notifyListeners();
    }
  }

  Future<void> askCoach(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;
    chat = [...chat, ChatMessage(role: 'user', text: trimmed)];
    notifyListeners();
    final recent = days.length > 14 ? days.sublist(days.length - 14) : days;
    try {
      final key = effectiveGeminiKey;
      final String answer;
      if (key.isEmpty) {
        answer = _localCoach.answer(
          question: trimmed,
          recentDays: recent,
          profile: profile,
        );
      } else {
        answer = await _coach.ask(
          apiKey: key,
          question: trimmed,
          recentDays: recent,
          profile: profile,
        );
      }
      chat = [...chat, ChatMessage(role: 'assistant', text: answer)];
    } catch (e) {
      chat = [
        ...chat,
        ChatMessage(
          role: 'assistant',
          text: _localCoach.answer(
            question: trimmed,
            recentDays: recent,
            profile: profile,
          ),
        ),
      ];
    }
    notifyListeners();
  }

  void clearChat() {
    chat = const [];
    notifyListeners();
  }
}
