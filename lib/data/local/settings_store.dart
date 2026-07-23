import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore({
    FlutterSecureStorage? secureStorage,
  }) : _secure = secureStorage ?? const FlutterSecureStorage();

  static const _geminiKey = 'gemini_api_key';
  static const _webClientIdKey = 'google_web_client_id';
  static const _useDemoKey = 'use_demo_data';
  static const _connectedKey = 'google_connected';
  static const _liveSyncKey = 'live_sync_enabled';
  static const _themeModeKey = 'theme_mode';

  final FlutterSecureStorage _secure;

  Future<String?> getGeminiApiKey() => _secure.read(key: _geminiKey);

  Future<void> setGeminiApiKey(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _secure.delete(key: _geminiKey);
    } else {
      await _secure.write(key: _geminiKey, value: value.trim());
    }
  }

  Future<String?> getGoogleWebClientId() => _secure.read(key: _webClientIdKey);

  Future<void> setGoogleWebClientId(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _secure.delete(key: _webClientIdKey);
    } else {
      await _secure.write(key: _webClientIdKey, value: value.trim());
    }
  }

  Future<bool> getUseDemoData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useDemoKey) ?? true;
  }

  Future<void> setUseDemoData(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDemoKey, value);
  }

  Future<bool> getGoogleConnectedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_connectedKey) ?? false;
  }

  Future<void> setGoogleConnectedFlag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, value);
  }

  Future<bool> getLiveSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_liveSyncKey) ?? true;
  }

  Future<void> setLiveSyncEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_liveSyncKey, value);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, value);
  }
}
