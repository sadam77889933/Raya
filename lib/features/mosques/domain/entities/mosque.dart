import 'package:equatable/equatable.dart';

/// مسجد مسجَّل في النظام
class Mosque extends Equatable {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const Mosque({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Mosque.fromJson(String id, Map<String, dynamic> json) {
    return Mosque(
      id: id,
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Mosque copyWith({String? name, bool? isActive}) {
    return Mosque(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, isActive, createdAt];
}