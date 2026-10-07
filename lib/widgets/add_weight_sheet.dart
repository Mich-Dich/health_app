import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/weight_entry.dart';

enum _DateMode { now, manual }

class AddWeightSheet extends StatefulWidget {
  /// When provided, the sheet edits this entry instead of creating one.
  final WeightEntry? initial;

  const AddWeightSheet({super.key, this.initial});

  @override
  State<AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends State<AddWeightSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;

  late _DateMode _mode;
  late DateTime _pickedDate;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _weightController = TextEditingController(
      text: initial == null ? '' : initial.weight.toString(),
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');

    if (initial == null) {
      _mode = _DateMode.now;
      _pickedDate = DateTime.now();
    } else {
      _mode = _DateMode.manual;
      _pickedDate = initial.date;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _pickedDate =
          DateTime(picked.year, picked.month, picked.day, now.hour, now.minute);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final weight =
        double.parse(_weightController.text.replaceAll(',', '.').trim());
    final date = _mode == _DateMode.now ? DateTime.now() : _pickedDate;
    final notes = _notesController.text.trim();

    Navigator.of(context).pop(
      WeightEntry(
        id: widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        weight: weight,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit weight' : 'Add weight',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              SegmentedButton<_DateMode>(
                segments: const [
                  ButtonSegment(
                    value: _DateMode.now,
                    label: Text('Now'),
                    icon: Icon(Icons.schedule),
                  ),
                  ButtonSegment(
                    value: _DateMode.manual,
                    label: Text('Pick date'),
                    icon: Icon(Icons.event_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _weightController,
                autofocus: !_isEditing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
                validator: (value) {
                  final text = (value ?? '').replaceAll(',', '.').trim();
                  if (text.isEmpty) return 'Please enter a weight';
                  final parsed = double.tryParse(text);
                  if (parsed == null) return 'Please enter a valid number';
                  if (parsed <= 0 || parsed > 500) {
                    return 'Enter a value between 0 and 500 kg';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              if (_mode == _DateMode.manual) ...[
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      DateFormat('EEEE, d MMMM yyyy').format(_pickedDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. after workout, morning',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                onFieldSubmitted: (_) => _submit(),
              ),

              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: Text(_isEditing ? 'Save changes' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}