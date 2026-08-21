import 'package:equatable/equatable.dart';

/// مسجد مسجَّل في النظام
class Mosque extends Equatable {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  /// صورة ختم مشرفة الحلقات الخاصة بهذا المسجد، مخزّنة كنص Base64.
  /// null تعني أن هذا المسجد ليس له ختم بعد (يظهر مكانه فارغاً في التقرير).
  final String? stampBase64;

  /// اسم مشرفة الحلقات الخاصة بهذا المسجد (يظهر في تذييل التقرير).
  final String? supervisorName;

  /// النص الأيمن لترويسة تقرير PDF الشهري الخاص بهذا المسجد.
  /// null تعني أن هذا المسجد لم يُخصِّص ترويسته إطلاقاً بعد، فيُستخدم
  /// [defaultRightHeaderText] كما هو مرسوم حالياً في كل التقارير — بينما
  /// نص فارغ (لا null) يعني أن المسؤول حذفه عمداً، فلا يظهر شيء بدلاً عنه.
  final String? rightHeaderText;

  /// النص الأيسر لترويسة تقرير PDF (اختياري تماماً). null أو فارغ تعني
  /// عدم وجود نص أيسر — وهو الحال في كل التقارير حالياً قبل هذه الميزة.
  final String? leftHeaderText;

  /// شعار ترويسة التقرير الخاص بهذا المسجد، مخزَّن كنص Base64، بنفس أسلوب
  /// [stampBase64]. null تعني عدم وجود شعار (لا يظهر شيء في الترويسة).
  final String? headerLogoBase64;

  /// نص شريط عنوان التقرير الشهري (أسفل الترويسة مباشرة)، بدون عبارة
  /// "لشهر: ..." التي تُضاف دائماً تلقائياً في نهايته عند العرض — لأنها
  /// يجب أن تعكس الشهر الفعلي لكل تقرير، فلا يصح تخزينها ضمن نص ثابت.
  /// null تعني عدم التخصيص، فيُستخدم [defaultMonthlyBannerText].
  final String? monthlyBannerText;

  /// النص الافتراضي الحالي لترويسة التقرير اليمنى — مطابق تماماً للنص
  /// المرسوم بشكل ثابت في PdfGenerator._orgHeader قبل إضافة هذه الميزة.
  /// يُستخدم كتعبئة أولى في شاشة الإعدادات، وكقيمة احتياطية عند توليد PDF
  /// لأي مسجد لم يُخصِّص [rightHeaderText] إطلاقاً (لا يزال null).
  static const String defaultRightHeaderText =
      'مجمع آيات بينات لتعليم القرآن\nالكريم وعلومه\nشبوة- عتق';

  /// النص الافتراضي الحالي لشريط عنوان التقرير الشهري — مطابق تماماً
  /// للنص المرسوم بشكل ثابت في PdfGenerator._monthBanner قبل إضافة هذه
  /// الميزة (بدون عبارة "لشهر: ..." التي تُضاف دائماً تلقائياً بعده).
  static const String defaultMonthlyBannerText =
      'التقرير الشهري لحلقات مجمع آيات بينات لتعليم القرآن الكريم وعلومه';

  const Mosque({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.stampBase64,
    this.supervisorName,
    this.rightHeaderText,
    this.leftHeaderText,
    this.headerLogoBase64,
    this.monthlyBannerText,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        if (stampBase64 != null) 'stampBase64': stampBase64,
        if (supervisorName != null) 'supervisorName': supervisorName,
        if (rightHeaderText != null) 'rightHeaderText': rightHeaderText,
        if (leftHeaderText != null) 'leftHeaderText': leftHeaderText,
        if (headerLogoBase64 != null) 'headerLogoBase64': headerLogoBase64,
        if (monthlyBannerText != null) 'monthlyBannerText': monthlyBannerText,
      };

  factory Mosque.fromJson(String id, Map<String, dynamic> json) {
    return Mosque(
      id: id,
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      stampBase64: json['stampBase64'] as String?,
      supervisorName: json['supervisorName'] as String?,
      rightHeaderText: json['rightHeaderText'] as String?,
      leftHeaderText: json['leftHeaderText'] as String?,
      headerLogoBase64: json['headerLogoBase64'] as String?,
      monthlyBannerText: json['monthlyBannerText'] as String?,
    );
  }

  Mosque copyWith({
    String? name,
    bool? isActive,
    String? stampBase64,
    String? supervisorName,
    String? rightHeaderText,
    String? leftHeaderText,
    String? headerLogoBase64,
    String? monthlyBannerText,
  }) {
    return Mosque(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      stampBase64: stampBase64 ?? this.stampBase64,
      supervisorName: supervisorName ?? this.supervisorName,
      rightHeaderText: rightHeaderText ?? this.rightHeaderText,
      leftHeaderText: leftHeaderText ?? this.leftHeaderText,
      headerLogoBase64: headerLogoBase64 ?? this.headerLogoBase64,
      monthlyBannerText: monthlyBannerText ?? this.monthlyBannerText,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        isActive,
        createdAt,
        stampBase64,
        supervisorName,
        rightHeaderText,
        leftHeaderText,
        headerLogoBase64,
        monthlyBannerText,
      ];
}