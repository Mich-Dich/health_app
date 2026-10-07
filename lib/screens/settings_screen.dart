import 'package:flutter/material.dart';

import '../models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _goalController;
  late final TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _goalController =
        TextEditingController(text: widget.settings.goalWeight?.toString() ?? '');
    _heightController =
        TextEditingController(text: widget.settings.heightCm?.toString() ?? '');
  }

  @override
  void dispose() {
    _goalController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String? _validatePositive(String? value,
      {double min = 1, double max = 500}) {
    final text = (value ?? '').replaceAll(',', '.').trim();
    if (text.isEmpty) return null; // empty = unset, allowed
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < min || parsed > max) return 'Must be between $min and $max';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final goalText = _goalController.text.replaceAll(',', '.').trim();
    final heightText = _heightController.text.replaceAll(',', '.').trim();

    Navigator.of(context).pop(
      AppSettings(
        goalWeight: goalText.isEmpty ? null : double.parse(goalText),
        heightCm: heightText.isEmpty ? null : double.parse(heightText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Body', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _heightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Height',
                suffixText: 'cm',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten),
                helperText: 'Used to compute BMI',
              ),
              validator: (v) => _validatePositive(v, min: 50, max: 250),
            ),
            const SizedBox(height: 24),
            Text('Goals', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _goalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Goal weight',
                suffixText: 'kg',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag_outlined),
                helperText: 'Shown as a dashed line on the chart',
              ),
              validator: _validatePositive,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}