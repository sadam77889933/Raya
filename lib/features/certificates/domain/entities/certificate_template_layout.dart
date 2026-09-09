import 'package:equatable/equatable.dart';

import 'certificate_font_family.dart';
import 'certificate_template.dart';

/// قراءة رقم عشري بأمان من JSON محتمل التلف — قيمة مفقودة أو من نوع غير
/// متوقَّع (بدل الانهيار بـ`TypeError` عند `as num` المباشر) تُعيد
/// [fallback] بدل رمي استثناء يُسقِط التخطيط المخصَّص بأكمله. هذا تحديداً
/// ما تسبَّب سابقاً بشاشة معاينة تدور بلا توقف لمسجد له مستند تخطيط
/// تالف/قديم (حقل `dx`/`dy` مفقود)، بينما تعمل المعاينة بلا مشكلة لمسجد
/// آخر بمستند سليم لنفس القالب تماماً.
double _numOr(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return fallback;
}

/// تخطيط مخصَّص لحقل واحد داخل قالب أساسي — يطغى على الموضع الثابت
/// (`CertificateFieldPosition.dx/dy`) لمسجد بعينه فقط، بلا المساس بالقالب
/// الأساسي نفسه أو بأي مسجد آخر. يغطي الآن أيضاً تخصيص الخط (النوع
/// واللون والحجم النسبي) — الدفعة الثانية من القسم ١٣ من تصميم الميزة؛
/// النص الحر (`textOverride`) يبقى مؤجَّلاً لدفعة لاحقة.
class CertificateFieldLayout extends Equatable {
  final CertificateField field;
  final bool visible;

  /// نسبة أفقية/رأسية 0.0-1.0 من أبعاد الشهادة — نفس فكرة
  /// [CertificateFieldPosition.dx]/[CertificateFieldPosition.dy] تماماً.
  final double dx;
  final double dy;

  /// نوع الخط — من القائمة المُجمَّعة فقط (ستة خطوط)، افتراضياً
  /// `Amiri` ليطابق شكل الحقل قبل أي تخصيص.
  final CertificateFontFamily fontFamily;

  /// لون الخط كقيمة ARGB (`Color.value`)، أو `null` لإبقاء لون القالب
  /// الأساسي كما هو بلا أي تخصيص.
  final int? fontColorValue;

  /// نسبة تكبير/تصغير من حجم الخط الافتراضي للحقل في القالب الأساسي —
  /// وليس حجماً مطلقاً بالبكسل، فيحافظ على نفس النسبة عند التصدير.
  final double fontScale;

  /// تخصيص صريح لوزن الخط (عريض/عادي) لهذا الحقل تحديدا - null يعني اتباع
  /// وزن القالب الاساسي كما هو (CertificateFieldPosition.bold) بلا اي
  /// تخصيص، بنفس فكرة fontColorValue تماما. خط بلا نسخة عريضة مجمَّعة
  /// (انظر CertificateFontCatalog.hasBoldAsset) يرتد تلقائيا لنسخته
  /// العادية حتى لو كانت هذه القيمة true.
  final bool? boldOverride;

  const CertificateFieldLayout({
    required this.field,
    this.visible = true,
    required this.dx,
    required this.dy,
    this.fontFamily = CertificateFontFamily.amiri,
    this.fontColorValue,
    this.fontScale = 1.0,
    this.boldOverride,
  });

  CertificateFieldLayout copyWith({
    bool? visible,
    double? dx,
    double? dy,
    CertificateFontFamily? fontFamily,
    int? fontColorValue,
    bool clearFontColor = false,
    double? fontScale,
    bool? boldOverride,
  }) {
    return CertificateFieldLayout(
      field: field,
      visible: visible ?? this.visible,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      fontFamily: fontFamily ?? this.fontFamily,
      fontColorValue:
          clearFontColor ? null : (fontColorValue ?? this.fontColorValue),
      fontScale: fontScale ?? this.fontScale,
      boldOverride: boldOverride ?? this.boldOverride,
    );
  }

  Map<String, dynamic> toJson() => {
        'field': field.name,
        'visible': visible,
        'dx': dx,
        'dy': dy,
        'fontFamily': fontFamily.name,
        if (fontColorValue != null) 'fontColorValue': fontColorValue,
        'fontScale': fontScale,
        if (boldOverride != null) 'boldOverride': boldOverride,
      };

  factory CertificateFieldLayout.fromJson(Map<String, dynamic> json) {
    return CertificateFieldLayout(
      field: CertificateField.values.firstWhere(
        (f) => f.name == json['field'],
        orElse: () => CertificateField.recipientName,
      ),
      visible: json['visible'] as bool? ?? true,
      dx: _numOr(json['dx'], 0.5),
      dy: _numOr(json['dy'], 0.5),
      fontFamily: CertificateFontFamily.values.firstWhere(
        (f) => f.name == json['fontFamily'],
        orElse: () => CertificateFontFamily.amiri,
      ),
      fontColorValue: (json['fontColorValue'] as num?)?.toInt(),
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      boldOverride: json['boldOverride'] as bool?,
    );
  }

  @override
  List<Object?> get props => [
        field,
        visible,
        dx,
        dy,
        fontFamily,
        fontColorValue,
        fontScale,
        boldOverride
      ];
}

/// تخطيط مخصَّص لموضع الختم — منفصل عن [CertificateFieldLayout] لأن
/// الختم صورة لا نص (بلا `CertificateField` مقابل له)، بنفس منطق
/// `CertificateStampPosition` في القالب الأساسي.
class CertificateStampLayout extends Equatable {
  final bool visible;
  final double dx;
  final double dy;
  final double widthScale;

  const CertificateStampLayout({
    this.visible = true,
    required this.dx,
    required this.dy,
    this.widthScale = 1.0,
  });

  CertificateStampLayout copyWith({
    bool? visible,
    double? dx,
    double? dy,
    double? widthScale,
  }) {
    return CertificateStampLayout(
      visible: visible ?? this.visible,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      widthScale: widthScale ?? this.widthScale,
    );
  }

  Map<String, dynamic> toJson() =>
      {'visible': visible, 'dx': dx, 'dy': dy, 'widthScale': widthScale};

  factory CertificateStampLayout.fromJson(Map<String, dynamic> json) {
    return CertificateStampLayout(
      visible: json['visible'] as bool? ?? true,
      dx: _numOr(json['dx'], 0.5),
      dy: _numOr(json['dy'], 0.5),
      widthScale: _numOr(json['widthScale'], 1.0),
    );
  }

  @override
  List<Object?> get props => [visible, dx, dy, widthScale];
}

/// عنصر نص حرّ واحد يضيفه المستخدم يدوياً فوق الشهادة — بلا أي حقل بيانات
/// مرتبط (ليس اسم مستفيدة أو مسجد أو غيره)، بل نص مكتوب مباشرة وموضع حرّ
/// بالكامل (القسم ١٣ من تصميم الميزة، دفعة النصوص الحرة). لا يوجد "قالب
/// أساسي" مقابل له، لذا حجم خطه مطلق بالنقاط لا نسبياً كحقول
/// [CertificateFieldLayout] (لا حجم أساسي يُقاس نسبة إليه).
class CertificateCustomTextElement extends Equatable {
  final String id;
  final String text;

  /// نسبة أفقية/رأسية 0.0-1.0 من أبعاد الشهادة — نفس فكرة
  /// [CertificateFieldLayout.dx]/[CertificateFieldLayout.dy] تماماً.
  final double dx;
  final double dy;

  final CertificateFontFamily fontFamily;

  /// لون الخط كقيمة ARGB (`Color.value`)، أو `null` للون الأسود الافتراضي.
  final int? fontColorValue;

  /// حجم الخط بالنقاط مباشرة.
  final double fontSize;

  const CertificateCustomTextElement({
    required this.id,
    required this.text,
    required this.dx,
    required this.dy,
    this.fontFamily = CertificateFontFamily.amiri,
    this.fontColorValue,
    this.fontSize = 24,
  });

  CertificateCustomTextElement copyWith({
    String? text,
    double? dx,
    double? dy,
    CertificateFontFamily? fontFamily,
    int? fontColorValue,
    bool clearFontColor = false,
    double? fontSize,
  }) {
    return CertificateCustomTextElement(
      id: id,
      text: text ?? this.text,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      fontFamily: fontFamily ?? this.fontFamily,
      fontColorValue:
          clearFontColor ? null : (fontColorValue ?? this.fontColorValue),
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'dx': dx,
        'dy': dy,
        'fontFamily': fontFamily.name,
        if (fontColorValue != null) 'fontColorValue': fontColorValue,
        'fontSize': fontSize,
      };

  factory CertificateCustomTextElement.fromJson(Map<String, dynamic> json) {
    return CertificateCustomTextElement(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      dx: _numOr(json['dx'], 0.5),
      dy: _numOr(json['dy'], 0.5),
      fontFamily: CertificateFontFamily.values.firstWhere(
        (f) => f.name == json['fontFamily'],
        orElse: () => CertificateFontFamily.amiri,
      ),
      fontColorValue: (json['fontColorValue'] as num?)?.toInt(),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24,
    );
  }

  @override
  List<Object?> get props =>
      [id, text, dx, dy, fontFamily, fontColorValue, fontSize];
}

/// منطقة تغطية مستطيلة فوق صورة خلفية القالب — أداة "مسح نص من القالب"
/// العامة: تُخفي أي نص مطبوع ضمن صورة الخلفية نفسها (لا حقل بيانات ولا
/// نص حرّ، بل جزء من الصورة) عبر رسم مستطيل مصمت بلون يطابق الخلفية
/// المحيطة فوقه وقت العرض/التصدير فقط — بلا أي تعديل فعلي على ملف صورة
/// القالب الأساسي نفسه، الذي يبقى مشتركاً وسليماً لكل المساجد الأخرى.
/// كل مسجد يملك قائمته الخاصة من مناطق التغطية ضمن مستنده هو فقط.
class CertificateEraseRegion extends Equatable {
  final String id;

  /// مركز المنطقة أفقياً/رأسياً — نسبة 0.0-1.0 من أبعاد الشهادة، بنفس
  /// فكرة dx/dy في كل العناصر الأخرى.
  final double dx;
  final double dy;

  /// عرض/ارتفاع المنطقة كنسبة 0.0-1.0 من أبعاد الشهادة (لا بالبكسل
  /// المطلق)، فتحافظ على نفس الحجم النسبي عند التصدير لأي حجم صفحة.
  final double width;
  final double height;

  /// لون التغطية كقيمة ARGB (`Color.value`) — أبيض افتراضياً (أكثر لون
  /// شائع لخلفيات الشهادات)، يُعدَّل عادة عبر القطّارة لمطابقة الخلفية
  /// الفعلية المحيطة بالنص المراد إخفاؤه.
  final int colorValue;

  const CertificateEraseRegion({
    required this.id,
    required this.dx,
    required this.dy,
    this.width = 0.2,
    this.height = 0.06,
    this.colorValue = 0xFFFFFFFF,
  });

  CertificateEraseRegion copyWith({
    double? dx,
    double? dy,
    double? width,
    double? height,
    int? colorValue,
  }) {
    return CertificateEraseRegion(
      id: id,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      width: width ?? this.width,
      height: height ?? this.height,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dx': dx,
        'dy': dy,
        'width': width,
        'height': height,
        'colorValue': colorValue,
      };

  factory CertificateEraseRegion.fromJson(Map<String, dynamic> json) {
    return CertificateEraseRegion(
      id: json['id'] as String? ?? '',
      dx: _numOr(json['dx'], 0.5),
      dy: _numOr(json['dy'], 0.5),
      width: _numOr(json['width'], 0.2),
      height: _numOr(json['height'], 0.06),
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
    );
  }

  @override
  List<Object?> get props => [id, dx, dy, width, height, colorValue];
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

  /// مناطق تغطية النص المطبوع ضمن صورة الخلفية نفسها — قائمة مفتوحة،
  /// افتراضياً فارغة، تُرسَم فوق الخلفية مباشرة وقبل كل الحقول/النصوص
  /// الأخرى (أداة "مسح نص من القالب" العامة).
  final List<CertificateEraseRegion> eraseRegions;

  /// عناصر النص الحرّ المضافة يدوياً فوق هذا القالب لهذا المسجد — قائمة
  /// مفتوحة، افتراضياً فارغة (لا وجود لها في القالب الأساسي إطلاقاً).
  final List<CertificateCustomTextElement> customTexts;
  final DateTime updatedAt;
  final String updatedByUid;

  const CertificateTemplateLayout({
    required this.mosqueId,
    required this.baseTemplateId,
    required this.fields,
    this.stamp,
    this.eraseRegions = const [],
    this.customTexts = const [],
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
        'eraseRegions': eraseRegions.map((r) => r.toJson()).toList(),
        'customTexts': customTexts.map((t) => t.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
        'updatedByUid': updatedByUid,
      };

  factory CertificateTemplateLayout.fromJson(Map<String, dynamic> json) {
    return CertificateTemplateLayout(
      mosqueId: json['mosqueId'] as String? ?? '',
      baseTemplateId: json['baseTemplateId'] as String? ?? '',
      fields: _parseList(
          json['fields'], (e) => CertificateFieldLayout.fromJson(e)),
      stamp: _parseStamp(json['stamp']),
      eraseRegions: _parseList(
          json['eraseRegions'], (e) => CertificateEraseRegion.fromJson(e)),
      customTexts: _parseList(json['customTexts'],
          (e) => CertificateCustomTextElement.fromJson(e)),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      updatedByUid: json['updatedByUid'] as String? ?? '',
    );
  }

  /// يحوِّل قائمة JSON خام إلى كائنات مُحلَّلة، متجاهلاً أي عنصر واحد
  /// تالف بدل أن يُسقِط الاستثناء القائمة كاملة — مستند تخطيط بحقل واحد
  /// فاسد (بيانات قديمة/تحرير يدوي خاطئ) لا يجب أن يُعطِّل بقية الحقول
  /// السليمة، ولا يجب أن يترك شاشة المعاينة عالقة على استثناء صامت.
  static List<T> _parseList<T>(
      dynamic raw, T Function(Map<String, dynamic>) parseOne) {
    if (raw is! List) return const [];
    final result = <T>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) continue;
      try {
        result.add(parseOne(e));
      } catch (_) {
        // عنصر تالف واحد — يُتجاهَل بدل إسقاط بقية القائمة السليمة.
      }
    }
    return result;
  }

  static CertificateStampLayout? _parseStamp(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return CertificateStampLayout.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        mosqueId,
        baseTemplateId,
        fields,
        stamp,
        eraseRegions,
        customTexts,
        updatedAt,
        updatedByUid
      ];
}
