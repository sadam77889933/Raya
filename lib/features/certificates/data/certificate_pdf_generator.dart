import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/certificate_render_data.dart';
import '../domain/entities/certificate_template.dart';
import '../domain/entities/certificate_template_layout.dart';
import 'certificate_font_catalog.dart';
import 'templates/certificate_generic_template_renderer.dart';

/// يدمج تخطيط مسجد مخصَّص (إن وُجد — "المرحلة الثانية"، القسم ١٣ من
/// تصميم الميزة) فوق المواضع الثابتة للقالب الأساسي: يستبدل `dx/dy`،
/// ونوع/لون/حجم الخط عند تخصيصها (وإلا يبقى الخط/اللون/الحجم من القالب
/// الأساسي كما هو تماماً)، ويُسقِط أي حقل مُعطَّل الإظهار تماماً من
/// القائمة النهائية. القالب الأساسي نفسه لا يتغيّر أبداً؛ هذا الدمج
/// يحدث فقط لحظة التوليد، محلياً في هذه الدالة.
List<CertificateFieldPosition> _mergeFieldPositions(
  List<CertificateFieldPosition> baseFields,
  CertificateTemplateLayout? customLayout,
) {
  if (customLayout == null) return baseFields;
  final merged = <CertificateFieldPosition>[];
  final coveredFields = <CertificateField>{};

  for (final f in baseFields) {
    coveredFields.add(f.field);
    final override = customLayout.layoutFor(f.field);
    if (override == null) {
      merged.add(f);
      continue;
    }
    if (!override.visible) continue;
    merged.add(CertificateFieldPosition(
      field: f.field,
      dx: override.dx,
      dy: override.dy,
      fontSize: f.fontSize * override.fontScale,
      color: override.fontColorValue != null
          ? PdfColor.fromInt(override.fontColorValue!)
          : f.color,
      bold: override.boldOverride ?? f.bold,
      fontFamily: override.fontFamily,
      maxWidthRatio: f.maxWidthRatio,
    ));
  }

  // حقول أضافتها المشرفة يدوياً عبر زر "إضافة حقل" في المحرر — لا وجود
  // لها إطلاقاً ضمن baseFields (قوالب مستورَدة غالباً، `fixedFields`
  // فارغة تماماً لها). بدون هذه الحلقة كانت ستُسقَط بصمت من ملف الـPDF
  // النهائي رغم ظهورها بصرياً في معاينة المحرر — الموضع الافتراضي
  // [defaultFieldPosition] هو نفسه المستخدَم في المحرر لأي حقل كهذا،
  // فتبقى المعاينة مطابقة للناتج الفعلي دائماً.
  for (final override in customLayout.fields) {
    if (coveredFields.contains(override.field)) continue;
    if (!override.visible) continue;
    final base = defaultFieldPosition(override.field);
    merged.add(CertificateFieldPosition(
      field: override.field,
      dx: override.dx,
      dy: override.dy,
      fontSize: base.fontSize * override.fontScale,
      color: override.fontColorValue != null
          ? PdfColor.fromInt(override.fontColorValue!)
          : base.color,
      bold: override.boldOverride ?? base.bold,
      fontFamily: override.fontFamily,
      maxWidthRatio: base.maxWidthRatio,
    ));
  }

  return merged;
}

CertificateStampPosition? _mergeStampPosition(
  CertificateStampPosition? baseStamp,
  CertificateTemplateLayout? customLayout,
) {
  if (baseStamp == null) return null;
  final override = customLayout?.stamp;
  if (override == null) return baseStamp;
  if (!override.visible) return null;
  return CertificateStampPosition(
    dx: override.dx,
    dy: override.dy,
    widthRatio: baseStamp.widthRatio * override.widthScale,
  );
}

/// يولّد ملف PDF متعدد الصفحات (صفحة واحدة لكل مستفيد) من قالب شهادة
/// واحد — توليد Bytes مباشرة (بلا `dart:io File`) كبقية مولّدات الميزة
/// الجديدة في هذا المشروع، متوافق مع `printing`/`share_plus` مباشرة
/// ومهيّأ تلقائياً للويب مستقبلاً.
class CertificatePdfGenerator {
  static Future<Uint8List> generate({
    required CertificateTemplateDefinition template,
    required List<CertificateRenderData> recipients,
    String? mosqueStampBase64,
    CertificateTemplateLayout? customLayout,
  }) async {
    final regularFonts = await CertificateFontCatalog.loadRegular();
    final boldFonts = await CertificateFontCatalog.loadBold();

    // قالب مستورَد (`localBackgroundImagePath` غير فارغ): يُقرأ من القرص
    // مباشرة؛ قالب أساسي مُجمَّع كـAsset: يُقرأ كما كان دائماً عبر
    // rootBundle.
    final localPath = template.localBackgroundImagePath;
    final bgBytes = localPath != null
        ? await File(localPath).readAsBytes()
        : (await rootBundle.load(template.backgroundImageAsset))
            .buffer
            .asUint8List();
    final bgImage = pw.MemoryImage(bgBytes);

    pw.MemoryImage? stampImage;
    if (template.stampPosition != null &&
        mosqueStampBase64 != null &&
        mosqueStampBase64.isNotEmpty) {
      try {
        stampImage = pw.MemoryImage(base64Decode(mosqueStampBase64));
      } catch (_) {
        // ختم تالف أو غير صالح: نتجاهله ونترك مكانه فارغاً بدل تعطيل التوليد
        stampImage = null;
      }
    }

    // نفس نسبة أبعاد صورة الخلفية (عادة A4 landscape تقريباً) — نستخدم
    // أبعاد الصفحة الفعلية بالنقاط بدل أبعاد الصورة بالبكسل مباشرة.
    const pageFormat = PdfPageFormat.a4;
    final pageWidth = pageFormat.height; // landscape: العرض = ارتفاع A4
    final pageHeight = pageFormat.width; // landscape: الارتفاع = عرض A4

    final effectiveFields =
        _mergeFieldPositions(template.fixedFields, customLayout);
    final effectiveStamp =
        _mergeStampPosition(template.stampPosition, customLayout);

    final doc = pw.Document();

    for (final recipient in recipients) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat.landscape,
          margin: pw.EdgeInsets.zero,
          build: (context) => buildGenericCertificatePage(
            backgroundImage: bgImage,
            fields: effectiveFields,
            recipient: recipient,
            regularFonts: regularFonts,
            boldFonts: boldFonts,
            stampPosition: effectiveStamp,
            stampImage: stampImage,
            eraseRegions: customLayout?.eraseRegions ?? const [],
            customTexts: customLayout?.customTexts ?? const [],
            pageWidth: pageWidth,
            pageHeight: pageHeight,
          ),
        ),
      );
    }

    return doc.save();
  }
}
