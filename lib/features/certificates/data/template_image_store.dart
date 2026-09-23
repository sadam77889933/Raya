import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'template_image_store_web.dart'
    if (dart.library.io) 'template_image_store_io.dart' as impl;

/// يخزّن ويقرأ ويحذف صور خلفيات القوالب المستورَدة (القسم ٦ من تصميم
/// الميزة)، بمعزل تام عن اختلاف طبقة التخزين الفعلية بين المنصات: ملف
/// حقيقي داخل مجلد وثائق التطبيق (أندرويد/iOS/ويندوز/macOS/لينكس، عبر
/// `path_provider`) مقابل `IndexedDB` (الويب — لا نظام ملفات هناك
/// إطلاقاً). نفس أسلوب الاستيراد الشرطي المستخدَم أصلاً في
/// `core/services/pdf_share_service.dart`.
///
/// القيمة المُعادة من [save] "مرجع" مُبهَم (Opaque) يُحفَظ كما هو في
/// `ImportedCertificateTemplate.backgroundImagePath` — بنيته تختلف فعلياً
/// بين المنصتين (مسار كامل مقابل مفتاح IndexedDB)، فلا يجب تحليله أو
/// افتراض أي بنية له خارج هذا الملف، فقط تمريره لاحقاً كما هو لبقية
/// الدوال هنا.
abstract class TemplateImageStore {
  /// يحفظ [bytes] كصورة خلفية جديدة لمسجد [mosqueId]، ويُعيد مرجعاً
  /// فريداً يُستخدَم لاحقاً للقراءة أو الحذف.
  static Future<String> save({
    required String mosqueId,
    required Uint8List bytes,
    required String extension,
  }) =>
      impl.saveImpl(mosqueId: mosqueId, bytes: bytes, extension: extension);

  /// يقرأ بايتات صورة خلفية محفوظة سابقاً عبر مرجعها — تُستخدَم في توليد
  /// الـPDF وفي القطّارة (Eyedropper) بمحرر مواضع الحقول.
  static Future<Uint8List> loadBytes(String reference) =>
      impl.loadBytesImpl(reference);

  /// يحذف صورة خلفية محفوظة سابقاً؛ فشل الحذف لا يرمي استثناء (الأولوية
  /// لحذف سجل الفهرس بنجاح حتى لو تعذَّر حذف ملف/مُدخَل الصورة نفسه).
  static Future<void> delete(String reference) => impl.deleteImpl(reference);

  /// يبني ويدجت الصورة مباشرة من المرجع — بديل موحَّد لـ`Image.file` الذي
  /// لا يُصرَّف إطلاقاً على الويب (`dart:io` غير متاح هناك حتى لو لم
  /// يُستدعَ فعلياً وقت التشغيل). التنفيذ الفعلي (مباشر أم غير متزامن
  /// عبر `FutureBuilder`) يختلف حسب المنصة تماماً.
  static Widget buildImage(String reference, {required BoxFit fit}) =>
      impl.buildImageImpl(reference, fit: fit);

  /// احتياط: يقرأ بايتات ملف عبر مساره المحلي مباشرة — يُستخدَم فقط عند
  /// فشل `PlatformFile.readAsBytes()` بعد اختيار ملف عبر `file_picker`
  /// (مسارات الملفات غير موجودة على الويب إطلاقاً، فهذا الاحتياط لا
  /// يُستدعى هناك أصلاً).
  static Future<Uint8List> readPickedFileBytes(String path) =>
      impl.readPickedFileBytesImpl(path);
}
