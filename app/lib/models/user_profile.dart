// UserProfile model - stores swimmer personal data used in SWOLF calculations.
// Persisted as JSON in shared_preferences.

import 'dart:convert';

/// Represents the swimmer's personal profile saved on first launch.
class UserProfile {
  /// Full name of the swimmer.
  final String name;

  /// Age in years.
  final int age;

  /// Height in centimetres.
  final int heightCm;

  /// Weight in kilograms.
  final int weightKg;

  /// Gender: 'male', 'female', or 'other'.
  final String gender;

  const UserProfile({
    required this.name,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.gender,
  });

  /// Creates a [UserProfile] from a JSON map.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name:     json['name']      as String,
      age:      json['age']       as int,
      heightCm: json['height_cm'] as int,
      weightKg: json['weight_kg'] as int,
      gender:   json['gender']    as String,
    );
  }

  /// Converts this profile to a JSON map for persistence.
  Map<String, dynamic> toJson() => {
    'name':      name,
    'age':       age,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'gender':    gender,
  };

  /// Serialises the profile to a JSON string for shared_preferences.
  String toJsonString() => jsonEncode(toJson());

  /// Returns the user's initials (up to 2 characters) for the avatar widget.
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Returns a display string like "28y · 180cm · 75kg".
  String get summaryLine => '${age}y · ${heightCm}cm · ${weightKg}kg';

  /// Creates a copy with optionally overridden fields.
  UserProfile copyWith({
    String? name,
    int?    age,
    int?    heightCm,
    int?    weightKg,
    String? gender,
  }) {
    return UserProfile(
      name:     name     ?? this.name,
      age:      age      ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      gender:   gender   ?? this.gender,
    );
  }

  @override
  String toString() =>
      'UserProfile(name: $name, age: $age, '
      'heightCm: $heightCm, weightKg: $weightKg, gender: $gender)';
}