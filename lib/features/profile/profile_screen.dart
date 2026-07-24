import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/health_extras.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/units.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  BiologicalSex? _sex;
  bool _metric = true;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    final p = app.profile;
    final body = app.effectiveBody;
    _metric = p.useMetric;
    _sex = p.sex;
    _name = TextEditingController(text: p.displayName ?? '');
    _age = TextEditingController(text: p.ageYears?.toString() ?? '');
    final heightCm = p.heightCm ?? body.heightCm;
    final weightKg = p.weightKg ?? body.weightKg;
    _height = TextEditingController(
      text: heightCm == null
          ? ''
          : _metric
              ? heightCm.toStringAsFixed(0)
              : Units.cmToInValue(heightCm)!.toStringAsFixed(1),
    );
    _weight = TextEditingController(
      text: weightKg == null
          ? ''
          : _metric
              ? weightKg.toStringAsFixed(1)
              : Units.kgToLbValue(weightKg)!.toStringAsFixed(1),
    );

    // Auto-fill empty fields from Google Health body on open.
    if (app.googleConnected &&
        (p.heightCm == null || p.weightKg == null) &&
        (body.heightCm != null || body.weightKg != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final ok = await app.importBodyFromGoogleHealth();
        if (!mounted || !ok) return;
        final next = app.profile;
        setState(() {
          _height.text = next.heightCm == null
              ? _height.text
              : next.heightCm!.toStringAsFixed(0);
          _weight.text = next.weightKg == null
              ? _weight.text
              : next.weightKg!.toStringAsFixed(1);
          _metric = true;
        });
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _applyUnitToggle(bool metric) {
    final rawH = double.tryParse(_height.text.trim());
    final rawW = double.tryParse(_weight.text.trim());
    // Convert current field values between unit systems.
    double? heightCm;
    double? weightKg;
    if (rawH != null) {
      heightCm = _metric ? rawH : rawH * 2.54;
    }
    if (rawW != null) {
      weightKg = _metric ? rawW : rawW / Units.kgToLb;
    }
    setState(() {
      _metric = metric;
      if (heightCm != null) {
        _height.text = metric
            ? heightCm.toStringAsFixed(0)
            : Units.cmToInValue(heightCm)!.toStringAsFixed(1);
      }
      if (weightKg != null) {
        _weight.text = metric
            ? weightKg.toStringAsFixed(1)
            : Units.kgToLbValue(weightKg)!.toStringAsFixed(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final app = context.watch<AppController>();
    final body = app.body;

    return Scaffold(
      appBar: AppBar(title: const Text('Body profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Age, sex, height, and weight personalize sleep need and strain. '
            'OpenAir can pull weight/height from Google Health when available.',
            style: TextStyle(color: colors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Use metric (cm / kg)',
              style: TextStyle(color: colors.textPrimary),
            ),
            subtitle: Text(
              _metric
                  ? 'Default — matches Google Health body units'
                  : 'Switch on for centimeters & kilograms',
              style: TextStyle(color: colors.textMuted),
            ),
            value: _metric,
            activeThumbColor: colors.green,
            onChanged: _applyUnitToggle,
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age (years)'),
          ),
          const SizedBox(height: 8),
          Text('Sex', style: TextStyle(color: colors.textMuted)),
          Wrap(
            spacing: 8,
            children: [
              for (final s in BiologicalSex.values)
                ChoiceChip(
                  label: Text(s.name),
                  selected: _sex == s,
                  onSelected: (_) => setState(() => _sex = s),
                ),
            ],
          ),
          TextField(
            controller: _height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _metric ? 'Height (cm)' : 'Height (in)',
            ),
          ),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _metric ? 'Weight (kg)' : 'Weight (lb)',
            ),
          ),
          const SizedBox(height: 16),
          if (app.googleConnected) ...[
            Container(
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
                    'From Google Health',
                    style: TextStyle(
                      color: colors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body != null &&
                            (body.weightKg != null || body.heightCm != null)
                        ? 'Weight: ${Units.weight(body.weightKg, metric: _metric)}\n'
                            'Height: ${Units.height(body.heightCm, metric: _metric)}\n'
                            'BMI: ${body.bmi?.toStringAsFixed(1) ?? '—'}\n'
                            'Body fat: ${body.bodyFatPercent?.toStringAsFixed(1) ?? '—'}%\n'
                            'VO₂ max: ${body.vo2Max?.toStringAsFixed(1) ?? '—'}'
                        : 'No body metrics cached yet. Tap import to pull the latest weight/height from Google Health.',
                    style: TextStyle(color: colors.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await app.importBodyFromGoogleHealth();
                      if (!context.mounted) return;
                      if (ok) {
                        final p = app.profile;
                        setState(() {
                          _metric = true;
                          _height.text = p.heightCm == null
                              ? ''
                              : p.heightCm!.toStringAsFixed(0);
                          _weight.text = p.weightKg == null
                              ? ''
                              : p.weightKg!.toStringAsFixed(1);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Imported ${Units.weight(p.weightKg, metric: true)} · '
                              '${Units.height(p.heightCm, metric: true)}',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              app.errorMessage ??
                                  'No weight/height found in Google Health. '
                                  'Log them in the Fitbit app first, then try again.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Import height & weight (cm/kg)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          FilledButton(
            onPressed: () async {
              final age = int.tryParse(_age.text.trim());
              final rawH = double.tryParse(_height.text.trim());
              final rawW = double.tryParse(_weight.text.trim());
              final heightCm = rawH == null
                  ? null
                  : _metric
                      ? rawH
                      : rawH * 2.54;
              final weightKg = rawW == null
                  ? null
                  : _metric
                      ? rawW
                      : rawW / Units.kgToLb;
              await app.saveProfile(
                UserProfile(
                  displayName:
                      _name.text.trim().isEmpty ? null : _name.text.trim(),
                  ageYears: age,
                  sex: _sex,
                  heightCm: heightCm,
                  weightKg: weightKg,
                  useMetric: _metric,
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile saved')),
                );
              }
            },
            child: const Text('Save profile'),
          ),
        ],
      ),
    );
  }
}

extension on BodySnapshot {
  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final m = heightCm! / 100;
    return weightKg! / (m * m);
  }
}
