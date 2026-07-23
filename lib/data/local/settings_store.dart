import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore({
    FlutterSecureStorage? secureStorage,
  }) : _secure = secureStorage ?? const FlutterSecureStorage();

  static const _geminiKey = 'gemini_api_key';
  static const _useDemoKey = 'use_demo_data';
  static const _connectedKey = 'google_connected';

  final FlutterSecureStorage _secure;

  Future<String?> getGeminiApiKey() => _secure.read(key: _geminiKey);

  Future<void> setGeminiApiKey(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _secure.delete(key: _geminiKey);
    } else {
      await _secure.write(key: _geminiKey, value: value.trim());
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
}
