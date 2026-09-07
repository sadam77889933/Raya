import 'package:equatable/equatable.dart';

import 'certificate_batch.dart';
import 'certificate_template.dart';

/// سجل قالب شهادة **مستورَد** من ملف (صورة أو PDF) بمعرفة المشرفة نفسها —
/// القسم ٦ من تصميم الميزة (استيراد قوالب). مخزَّن محلياً بحتاً على جهاز
/// المشرفة فقط (لا Firestore ولا Firebase Storage إطلاقاً؛ قرار مقصود:
/// صفر تكلفة تخزين سحابي، مقابل فقدان القوالب المستورَدة عند حذف التطبيق
/// أو تغيير الجهاز)، عبر `ImportedCertificateTemplateRepository`.
///
/// بخلاف `CertificateTemplateDefinition` (قالب أساسي مُجمَّع كـAsset)، لا
/// يوجد لهذا القالب أي `fixedFields` معروفة مسبقاً — تبدأ فارغة تماماً،
/// وتُضاف حقولها لاحقاً يدوياً واحداً تلو الآخر عبر زر "إضافة حقل" في
/// محرر مواضع الحقول (`CertificateTemplateEditorScreen`).
class ImportedCertificateTemplate extends Equatable {
  final String id;
  final String mosqueId;
  final String displayName;
  final CertificateRecipientType recipientType;

  /// المسار المحلي الكامل لصورة الخلفية المحفوظة على القرص (PNG دائماً
  /// لملف PDF مصدر — أول صفحة منه مُحوَّلة بدقة طباعة عبر `Printing.
  /// raster`؛ نفس امتداد الملف الأصلي لملف صورة مصدر).
  final String backgroundImagePath;
  final DateTime createdAt;

  const ImportedCertificateTemplate({
    required this.id,
    required this.mosqueId,
    required this.displayName,
    required this.recipientType,
    required this.backgroundImagePath,
    required this.createdAt,
  });

  /// تحوِّل سجل الاستيراد إلى `CertificateTemplateDefinition` قابل
  /// للاستخدام مباشرة في كل شاشات الميزة (البطاقة، المعالج، المحرر) بلا
  /// أي تفريع خاص بها — فقط عبر `localBackgroundImagePath` غير الفارغ.
  /// `fixedFields` تبدأ فارغة عمداً (تُبنى يدوياً في المحرر)، وموضع الختم
  /// الافتراضي معقول (أسفل منتصف الشهادة تقريباً) حتى تعمل أداة إظهار/
  /// إخفاء الختم الموجودة أصلاً بلا أي حاجة لإضافة خاصة بها هنا.
  CertificateTemplateDefinition toDefinition() {
    return CertificateTemplateDefinition(
      id: id,
      displayName: displayName,
      backgroundImageAsset: '',
      thumbnailAsset: '',
      recipientType: recipientType,
      fixedFields: const [],
      localBackgroundImagePath: backgroundImagePath,
      stampPosition: const CertificateStampPosition(
        dx: 0.5,
        dy: 0.9,
        widthRatio: 0.09,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mosqueId': mosqueId,
        'displayName': displayName,
        'recipientType': recipientType.name,
        'backgroundImagePath': backgroundImagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ImportedCertificateTemplate.fromJson(Map<String, dynamic> json) {
    return ImportedCertificateTemplate(
      id: json['id'] as String? ?? '',
      mosqueId: json['mosqueId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      recipientType: CertificateRecipientType.values.firstWhere(
        (t) => t.name == json['recipientType'],
        orElse: () => CertificateRecipientType.student,
      ),
      backgroundImagePath: json['backgroundImagePath'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, mosqueId, displayName, recipientType, backgroundImagePath, createdAt];
}
