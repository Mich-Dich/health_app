class AppSettings {
  final double? goalWeight; // kg
  final double? heightCm;

  const AppSettings({this.goalWeight, this.heightCm});

  Map<String, dynamic> toJson() => {
        'goalWeight': goalWeight,
        'heightCm': heightCm,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        goalWeight: (json['goalWeight'] as num?)?.toDouble(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
      );
}