class WeightEntry {
  final String id;
  final DateTime date;
  final double weight;
  final String? notes;

  const WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
    this.notes,
  });

  WeightEntry copyWith({
    String? id,
    DateTime? date,
    double? weight,
    String? notes,
  }) =>
      WeightEntry(
        id: id ?? this.id,
        date: date ?? this.date,
        weight: weight ?? this.weight,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'weight': weight,
        'notes': notes,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);
    return WeightEntry(
      // Fallback id for legacy entries saved before this change.
      id: json['id'] as String? ??
          date.microsecondsSinceEpoch.toString(),
      date: date,
      weight: (json['weight'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }
}