import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/health_extras.dart';
import '../../domain/models/user_profile.dart';
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
    final p = context.read<AppController>().profile;
    _metric = p.useMetric;
    _sex = p.sex;
    _name = TextEditingController(text: p.displayName ?? '');
    _age = TextEditingController(text: p.ageYears?.toString() ?? '');
    _height = TextEditingController(
      text: p.heightCm == null
          ? ''
          : _metric
              ? p.heightCm!.toStringAsFixed(0)
              : (p.heightCm! / 2.54).toStringAsFixed(1),
    );
    _weight = TextEditingController(
      text: p.weightKg == null
          ? ''
          : _metric
              ? p.weightKg!.toStringAsFixed(1)
              : (p.weightKg! * 2.20462).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final app = context.watch<AppController>();
    final body = app.effectiveBody;

    return Scaffold(
      appBar: AppBar(title: const Text('Body profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Age, sex, height, and weight personalize sleep need, strain zones, and BMI. Cloud weight/height from Google Health fill in when you leave a field blank.',
            style: TextStyle(color: colors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Metric units (cm / kg)'),
            subtitle: Text(
              _metric ? 'Centimeters & kilograms' : 'Inches & pounds',
              style: TextStyle(color: colors.textMuted),
            ),
            value: _metric,
            activeThumbColor: colors.green,
            onChanged: (v) => setState(() => _metric = v),
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
          if (body.weightKg != null || body.heightCm != null || body.bmi != null)
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
                    'Live snapshot',
                    style: TextStyle(
                      color: colors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Weight: ${body.weightKg?.toStringAsFixed(1) ?? '—'} kg\n'
                    'Height: ${body.heightCm?.toStringAsFixed(0) ?? '—'} cm\n'
                    'BMI: ${body.bmi?.toStringAsFixed(1) ?? '—'}\n'
                    'Body fat: ${body.bodyFatPercent?.toStringAsFixed(1) ?? '—'}%\n'
                    'VO₂ max: ${body.vo2Max?.toStringAsFixed(1) ?? '—'}',
                    style: TextStyle(color: colors.textSecondary, height: 1.45),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
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
                      : rawW / 2.20462;
              await app.saveProfile(
                UserProfile(
                  displayName: _name.text.trim().isEmpty
                      ? null
                      : _name.text.trim(),
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
