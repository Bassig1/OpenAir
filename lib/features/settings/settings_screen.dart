import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/oauth_config.dart';
import '../../data/health/google_health_client.dart';
import '../../domain/units.dart';
import '../../features/profile/profile_screen.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _geminiController;
  late final TextEditingController _webClientController;
  bool _obscure = true;
  bool _obscureClient = true;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    _geminiController = TextEditingController(text: app.geminiApiKey ?? '');
    _webClientController = TextEditingController(
      text: app.googleWebClientId?.isNotEmpty == true
          ? app.googleWebClientId!
          : OAuthConfig.defaultWebClientId,
    );
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _webClientController.dispose();
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
          const Divider(height: 36),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Body profile',
              style: TextStyle(color: colors.textPrimary),
            ),
            subtitle: Text(
              app.profile.isComplete
                  ? 'Age ${app.profile.ageYears} · ${Units.weight(app.effectiveBody.weightKg, metric: app.profile.useMetric)} · ${Units.height(app.effectiveBody.heightCm, metric: app.profile.useMetric)}'
                  : 'Add age, weight, height for personalized scores',
              style: TextStyle(color: colors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const Divider(height: 36),
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
            'Fitbit syncs only through the official Fitbit app. OpenAir reads the Google Health cloud feed on open / resume / pull-to-refresh and builds your coaching summary.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data status: ${app.syncHealth.status.name.toUpperCase()}',
                  style: TextStyle(
                    color: colors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  app.syncHealth.message,
                  style: TextStyle(color: colors.textSecondary),
                ),
                if (app.syncHealth.missingDayCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Gaps in last 7 days: ${app.syncHealth.missingDayCount}',
                    style: TextStyle(color: colors.heart),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Push notifications',
              style: TextStyle(color: colors.textPrimary),
            ),
            subtitle: Text(
              'Separate channels: Sleep · Heart & vitals · Workouts · Recovery.',
              style: TextStyle(color: colors.textSecondary),
            ),
            value: app.alertsEnabled,
            activeThumbColor: colors.green,
            onChanged: (v) => app.setAlertsEnabled(v),
          ),
          if (app.alertsEnabled) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Sleep — overnight performance & debt\n'
                'Heart & vitals — unusual resting rate\n'
                'Workouts — session complete + strain\n'
                'Recovery — daily readiness brief',
                style: TextStyle(
                  color: colors.textMuted,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ),
          ],
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
          if (app.errorMessage != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              app.errorMessage!,
              style: TextStyle(color: colors.heart, height: 1.35),
            ),
          ],
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
            'Gemini analysis',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            app.geminiReady
                ? 'On automatically after Google Health connect. Deeper Whoop-style analysis refreshes after each sync — no API key setup needed for this personal build.'
                : 'Gemini is unavailable in this build.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
          ),
          const Divider(height: 36),
          Text(
            'Share data with Cursor',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exports your synced days, body metrics, recovery-style analysis, '
            'and a short raw Google Health sample into one JSON. Paste it in '
            'Cursor chat so the agent can verify accuracy for you — no manual UI checking.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: app.diagnosticExporting
                ? null
                : () async {
                    try {
                      final json =
                          await app.exportDiagnosticsForCursor(includeRaw: true);
                      await Clipboard.setData(ClipboardData(text: json));
                      if (!context.mounted) return;
                      final chars = json.length;
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Diagnostic export ready'),
                          content: Text(
                            'Copied ~${(chars / 1024).toStringAsFixed(0)} KB to the clipboard.\n\n'
                            'In Cursor: paste into chat and say “review this OpenAir dump and fix anything wrong.”\n\n'
                            'Or save it as diagnostics/latest.json in the OpenAir project folder.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e')),
                      );
                    }
                  },
            icon: app.diagnosticExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: Text(
              app.diagnosticExporting
                  ? 'Building export…'
                  : 'Export data for Cursor',
            ),
          ),
          const Divider(height: 36),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                'Advanced',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
              ),
              subtitle: Text(
                'OAuth debug values and optional Gemini override',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              children: [
                TextField(
                  controller: _webClientController,
                  obscureText: _obscureClient,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Google Web OAuth Client ID',
                    hintText: '….apps.googleusercontent.com',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureClient = !_obscureClient),
                      icon: Icon(
                        _obscureClient
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await app
                          .saveGoogleWebClientId(_webClientController.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Web Client ID saved')),
                        );
                      }
                    },
                    child: const Text('Save Client ID'),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'Package: ${GoogleHealthClient.androidPackageName}\n'
                  'SHA-1: ${GoogleHealthClient.debugSha1}',
                  style: TextStyle(color: colors.textSecondary, height: 1.4),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${GoogleHealthClient.androidPackageName}\n${GoogleHealthClient.debugSha1}',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Package + SHA-1 copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy package + SHA-1'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _geminiController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Optional personal Gemini API key',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () async {
                        await app.saveGeminiKey(_geminiController.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Personal Gemini key saved'),
                            ),
                          );
                        }
                      },
                      child: const Text('Save personal key'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        _geminiController.clear();
                        await app.saveGeminiKey(null);
                      },
                      child: const Text('Use project key'),
                    ),
                  ],
                ),
              ],
            ),
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
            'OpenAir is a personal Fitbit companion with a recovery-focused recovery UI. '
            'Scores are OpenAir heuristics. Not affiliated with Fitbit or Google.',
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
