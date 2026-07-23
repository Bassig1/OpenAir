import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(AppController app) async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    await app.askCoach(text);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final hasKey = (app.geminiApiKey ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach'),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: app.clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!hasKey)
            MaterialBanner(
              content: const Text(
                'Add a free Gemini API key in Settings to ask questions about your recovery, sleep, and strain.',
              ),
              actions: [
                TextButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('Settings'),
                ),
              ],
            ),
          Expanded(
            child: app.chat.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Ask OpenAir Coach',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Answers use your recent OpenAir metrics as context.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: OpenAirColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final q in const [
                            'Why is my recovery lower today?',
                            'How was my sleep quality this week?',
                            'Should I train hard tomorrow?',
                            'What do my SpO₂ and HRV suggest?',
                          ])
                            ActionChip(
                              label: Text(q),
                              onPressed: !hasKey
                                  ? null
                                  : () async {
                                      _controller.text = q;
                                      await _send(app);
                                    },
                            ),
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: app.chat.length,
                    itemBuilder: (context, index) {
                      final msg = app.chat[index];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? OpenAirColors.surfaceElevated
                                : OpenAirColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: OpenAirColors.border),
                          ),
                          child: Text(msg.text),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: hasKey && !_sending,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask about recovery, sleep, strain…',
                      ),
                      onSubmitted: (_) => _send(app),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: !hasKey || _sending ? null : () => _send(app),
                    style: IconButton.styleFrom(
                      backgroundColor: OpenAirColors.recovery,
                      foregroundColor: Colors.black,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
