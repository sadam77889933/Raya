import 'package:equatable/equatable.dart';

import 'certificate_template.dart';

/// تخطيط مخصَّص لحقل واحد داخل قالب أساسي — يطغى على الموضع الثابت
/// (`CertificateFieldPosition.dx/dy`) لمسجد بعينه فقط، بلا المساس بالقالب
/// الأساسي نفسه أو بأي مسجد آخر. نسخة مبسَّطة عن بداية القسم ١٣ من تصميم
/// الميزة: **بلا** تخصيص خط/لون/حجم أو نص حر بعد — هذه دفعة أولى تقتصر
/// على السحب الحر والإخفاء/الإظهار فقط، وتُضاف بقية الخصائص لاحقاً بلا
/// أي تعديل بنيوي (حقول إضافية فقط).
class CertificateFieldLayout extends Equatable {
  final CertificateField field;
  final bool visible;

  /// نسبة أفقية/رأسية 0.0-1.0 من أبعاد الشهادة — نفس فكرة
  /// [CertificateFieldPosition.dx]/[CertificateFieldPosition.dy] تماماً.
  final double dx;
  final double dy;

  const CertificateFieldLayout({
    required this.field,
    this.visible = true,
    required this.dx,
    required this.dy,
  });

  CertificateFieldLayout copyWith({bool? visible, double? dx, double? dy}) {
    return CertificateFieldLayout(
      field: field,
      visible: visible ?? this.visible,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
    );
  }

  Map<String, dynamic> toJson() => {
        'field': field.name,
        'visible': visible,
        'dx': dx,
        'dy': dy,
      };

  factory CertificateFieldLayout.fromJson(Map<String, dynamic> json) {
    return CertificateFieldLayout(
      field: CertificateField.values.firstWhere(
        (f) => f.name == json['field'],
        orElse: () => CertificateField.recipientName,
      ),
      visible: json['visible'] as bool? ?? true,
      dx: (json['dx'] as num).toDouble(),
      dy: (json['dy'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [field, visible, dx, dy];
}

/// تخطيط مخصَّص لموضع الختم — منفصل عن [CertificateFieldLayout] لأن
/// الختم صورة لا نص (بلا `CertificateField` مقابل له)، بنفس منطق
/// `CertificateStampPosition` في القالب الأساسي.
class CertificateStampLayout extends Equatable {
  final bool visible;
  final double dx;
  final double dy;

  const CertificateStampLayout({
    this.visible = true,
    required this.dx,
    required this.dy,
  });

  CertificateStampLayout copyWith({bool? visible, double? dx, double? dy}) {
    return CertificateStampLayout(
      visible: visible ?? this.visible,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
    );
  }

  Map<String, dynamic> toJson() => {'visible': visible, 'dx': dx, 'dy': dy};

  factory CertificateStampLayout.fromJson(Map<String, dynamic> json) {
    return CertificateStampLayout(
      visible: json['visible'] as bool? ?? true,
      dx: (json['dx'] as num).toDouble(),
      dy: (json['dy'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [visible, dx, dy];
}

/// تخطيط مخصَّص كامل لقالب أساسي واحد، خاص بمسجد واحد — مستند Firestore
/// واحد في مجموعة `certificate_templates` (القسم ١٣ من تصميم الميزة)،
/// بمعرّف حتمي `<mosqueId>_<baseTemplateId>` (قراءة/كتابة مباشرة بلا
/// استعلام، بما أن كل مسجد له تخطيط واحد فقط لكل قالب أساسي).
///
/// القالب الأساسي نفسه (`CertificateTemplateDefinition`) يبقى كما هو
/// دائماً لكل المساجد؛ وجود هذا المستند لمسجد معيّن فقط هو ما يُخصِّص له
/// مواضعه/إخفاءه الخاص عند التوليد.
class CertificateTemplateLayout extends Equatable {
  final String mosqueId;
  final String baseTemplateId;
  final List<CertificateFieldLayout> fields;
  final CertificateStampLayout? stamp;
  final DateTime updatedAt;
  final String updatedByUid;

  const CertificateTemplateLayout({
    required this.mosqueId,
    required this.baseTemplateId,
    required this.fields,
    this.stamp,
    required this.updatedAt,
    required this.updatedByUid,
  });

  String get docId => '${mosqueId}_$baseTemplateId';

  CertificateFieldLayout? layoutFor(CertificateField field) {
    for (final f in fields) {
      if (f.field == field) return f;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'mosqueId': mosqueId,
        'baseTemplateId': baseTemplateId,
        'fields': fields.map((f) => f.toJson()).toList(),
        if (stamp != null) 'stamp': stamp!.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
        'updatedByUid': updatedByUid,
      };

  factory CertificateTemplateLayout.fromJson(Map<String, dynamic> json) {
    return CertificateTemplateLayout(
      mosqueId: json['mosqueId'] as String? ?? '',
      baseTemplateId: json['baseTemplateId'] as String? ?? '',
      fields: (json['fields'] as List<dynamic>? ?? const [])
          .map((e) => CertificateFieldLayout.fromJson(e as Map<String, dynamic>))
          .toList(),
      stamp: json['stamp'] != null
          ? CertificateStampLayout.fromJson(json['stamp'] as Map<String, dynamic>)
          : null,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      updatedByUid: json['updatedByUid'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props =>
      [mosqueId, baseTemplateId, fields, stamp, updatedAt, updatedByUid];
}
