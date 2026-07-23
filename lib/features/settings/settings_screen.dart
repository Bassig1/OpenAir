import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _geminiController;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final key = context.read<AppController>().geminiApiKey ?? '';
    _geminiController = TextEditingController(text: key);
  }

  @override
  void dispose() {
    _geminiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final app = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Theme',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {app.themeMode},
            onSelectionChanged: (modes) => app.setThemeMode(modes.first),
          ),
          const Divider(height: 36),
          Text(
            'Data source',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep the official Fitbit app syncing your device. OpenAir reads the cloud copy through Google Health.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Use demo data',
              style: TextStyle(color: colors.textPrimary),
            ),
            subtitle: Text(
              'Preview the Whoop-style UI without OAuth',
              style: TextStyle(color: colors.textSecondary),
            ),
            value: app.useDemoData,
            activeThumbColor: colors.green,
            onChanged: (v) => app.setUseDemoData(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Live sync',
              style: TextStyle(color: colors.textPrimary),
            ),
            subtitle: Text(
              'Poll every 2 minutes and refresh when the app resumes, when Google Health is connected.',
              style: TextStyle(color: colors.textSecondary),
            ),
            value: app.liveSyncEnabled,
            activeThumbColor: colors.green,
            onChanged: (v) => app.setLiveSyncEnabled(v),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              app.googleConnected ? 'Google Health connected' : 'Connect Google Health',
              style: TextStyle(color: colors.textPrimary),
            ),
            subtitle: Text(
              app.accountEmail ??
                  'Sign in with the Google account linked to Fitbit',
              style: TextStyle(color: colors.textSecondary),
            ),
            trailing: app.googleConnected
                ? TextButton(
                    onPressed: app.disconnectGoogle,
                    child: const Text('Disconnect'),
                  )
                : FilledButton(
                    onPressed: app.connectGoogle,
                    child: const Text('Connect'),
                  ),
          ),
          if (app.devices.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Paired devices',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
            ),
            ...app.devices.map(
              (d) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.watch),
                title: Text(
                  d.name,
                  style: TextStyle(color: colors.textPrimary),
                ),
                subtitle: Text(
                  d.model ?? 'Fitbit / Google wearable',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            ),
          ],
          if (app.lastSyncedAt != null)
            Text(
              'Last sync: ${app.lastSyncedAt}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
          const Divider(height: 36),
          Text(
            'Gemini Coach',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a free API key at aistudio.google.com and paste it here. Stored only on this device.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _geminiController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Gemini API key',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await app.saveGeminiKey(_geminiController.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gemini key saved')),
                );
              }
            },
            child: const Text('Save key'),
          ),
          TextButton(
            onPressed: () async {
              _geminiController.clear();
              await app.saveGeminiKey(null);
            },
            child: const Text('Clear key'),
          ),
          const Divider(height: 36),
          Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'OpenAir is a personal Fitbit companion with a Whoop-inspired recovery UI. '
            'Scores are OpenAir heuristics. Not affiliated with Whoop or Fitbit/Google.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
          ),
          if (app.errorMessage != null) ...[
            const SizedBox(height: 20),
            Text(
              app.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.heart,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
