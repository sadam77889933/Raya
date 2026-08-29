import 'package:equatable/equatable.dart';

/// مركز صيفي: كيان مستقل تماماً عن نظام الحلقات المعتادة والتقارير الشهرية.
/// يُنشأ عند الحاجة (عادة موسم صيفي واحد لمسجد واحد) ويمكن أرشفته
/// (isActive: false) بعد انتهاء الحاجة إليه دون حذفه.
///
/// قرار معماري مهم: هذا الكيان لا يرتبط بأي حقل من حقول [Mosque] أو
/// [TeachingCircle] — العلاقة الوحيدة هي [mosqueId] كمعرّف مرجعي بحت،
/// تماماً كما ترتبط School بالمسجد. لا تُستخدم بيانات الحلقات الحالية
/// إطلاقاً لبناء مستويات أو مواد المركز الصيفي.
class SummerCenter extends Equatable {
  final String id;
  final String name;
  final String mosqueId;
  final String hijriYear;

  /// نص حر اختياري لوصف الفترة (مثال: "محرَّم – صفر")، بلا أي حساب أو
  /// تحقق تلقائي — المشرفة تكتبه كما يناسبها.
  final String? periodLabel;

  final bool isActive;

  /// تتحكم في ظهور شاشة "اختباراتي" للمعلمات ووصولهن الفعلي للبيانات
  /// (تُطبَّق أيضاً في Security Rules، وليست مجرد إخفاء واجهة).
  /// افتراضياً true عند الإنشاء.
  final bool testsEnabledForTeachers;

  final DateTime createdAt;

  const SummerCenter({
    required this.id,
    required this.name,
    required this.mosqueId,
    required this.hijriYear,
    this.periodLabel,
    required this.isActive,
    this.testsEnabledForTeachers = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'mosqueId': mosqueId,
        'hijriYear': hijriYear,
        if (periodLabel != null) 'periodLabel': periodLabel,
        'isActive': isActive,
        'testsEnabledForTeachers': testsEnabledForTeachers,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SummerCenter.fromJson(String id, Map<String, dynamic> json) {
    return SummerCenter(
      id: id,
      name: json['name'] as String,
      mosqueId: json['mosqueId'] as String,
      hijriYear: json['hijriYear'] as String? ?? '',
      periodLabel: json['periodLabel'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      testsEnabledForTeachers:
          json['testsEnabledForTeachers'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  SummerCenter copyWith({
    String? name,
    String? hijriYear,
    String? periodLabel,
    bool? isActive,
    bool? testsEnabledForTeachers,
  }) {
    return SummerCenter(
      id: id,
      name: name ?? this.name,
      mosqueId: mosqueId,
      hijriYear: hijriYear ?? this.hijriYear,
      periodLabel: periodLabel ?? this.periodLabel,
      isActive: isActive ?? this.isActive,
      testsEnabledForTeachers:
          testsEnabledForTeachers ?? this.testsEnabledForTeachers,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        mosqueId,
        hijriYear,
        periodLabel,
        isActive,
        testsEnabledForTeachers,
        createdAt,
      ];
}
