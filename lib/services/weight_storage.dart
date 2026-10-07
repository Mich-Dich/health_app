import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weight_entry.dart';

/// Persists weight entries as a JSON list inside SharedPreferences.
class WeightStorage {
  static const String _key = 'weight_entries';

  Future<List<WeightEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final entries = <WeightEntry>[];
    for (final item in raw) {
      try {
        entries.add(
          WeightEntry.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip corrupt entries instead of crashing.
      }
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  Future<void> saveEntries(List<WeightEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    await prefs.setStringList(
      _key,
      sorted.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}