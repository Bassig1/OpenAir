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
    final app = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Data source',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep the official Fitbit app syncing your device. OpenAir reads the cloud copy through Google Health.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OpenAirColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use demo data'),
            subtitle: const Text('Preview the Whoop-style UI without OAuth'),
            value: app.useDemoData,
            activeThumbColor: OpenAirColors.recovery,
            onChanged: (v) => app.setUseDemoData(v),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              app.googleConnected ? 'Google Health connected' : 'Connect Google Health',
            ),
            subtitle: Text(
              app.accountEmail ??
                  'Sign in with the Google account linked to Fitbit',
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
          const Divider(height: 36),
          Text(
            'Gemini Coach',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a free API key at aistudio.google.com and paste it here. Stored only on this device.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OpenAirColors.textSecondary,
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
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'OpenAir is a personal Fitbit companion with a Whoop-inspired recovery UI. '
            'Scores are OpenAir heuristics. Not affiliated with Whoop or Fitbit/Google.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OpenAirColors.textSecondary,
                  height: 1.4,
                ),
          ),
          if (app.errorMessage != null) ...[
            const SizedBox(height: 20),
            Text(
              app.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OpenAirColors.heart,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
