import 'package:equatable/equatable.dart';

/// مادة تُدرَّس داخل مركز صيفي واحد (مثال: "العقيدة"، "القرآن الكريم").
/// تابعة لـ[centerId] فقط — منفصلة تماماً عن أي منهج مصاحب في نظام
/// التقارير الشهرية المعتاد.
///
/// [mosqueId] مُخزَّن هنا كتكرار مقصود (denormalized) من مركزها الأب فقط
/// ليسمح لقواعد أمان Firestore بالتحقق من نطاق مسجد المادة دون قراءة
/// إضافية (get) لوثيقة المركز عند كل عملية — لا يُستخدَم في أي استعلام
/// من طرف التطبيق نفسه (الاستعلام دائماً بـcenterId فقط).
class SummerSubject extends Equatable {
  final String id;
  final String centerId;
  final String mosqueId;
  final String name;
  final int order;
  final bool isActive;
  final DateTime createdAt;

  const SummerSubject({
    required this.id,
    required this.centerId,
    required this.mosqueId,
    required this.name,
    required this.order,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'centerId': centerId,
        'mosqueId': mosqueId,
        'name': name,
        'order': order,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SummerSubject.fromJson(String id, Map<String, dynamic> json) {
    return SummerSubject(
      id: id,
      centerId: json['centerId'] as String,
      mosqueId: json['mosqueId'] as String? ?? '',
      name: json['name'] as String,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  SummerSubject copyWith({String? name, int? order, bool? isActive}) {
    return SummerSubject(
      id: id,
      centerId: centerId,
      mosqueId: mosqueId,
      name: name ?? this.name,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, centerId, mosqueId, name, order, isActive, createdAt];
}
