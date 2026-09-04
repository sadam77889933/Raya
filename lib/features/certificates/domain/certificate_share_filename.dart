import 'entities/certificate_render_data.dart';

/// يزيل من النص كل حرف غير مسموح به في اسم ملف على أي نظام تشغيل
/// (ويندوز/أندرويد/iOS)، بنفس القائمة المُعتمَدة فعلياً في مولّد ملفات
/// PDF الأخرى بالمشروع (`statistical_report_pdf_generator.dart`) لضمان
/// اتساق الأسلوب في كل أنحاء التطبيق.
String _sanitizeForFileName(String value) {
  return value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

/// يبني اسم ملف PDF ذا دلالة عند مشاركة/إعادة مشاركة دفعة شهادات، بدل
/// اسم عام واحد ثابت لكل الدفعات ("شهادات.pdf") لا يميّز بينها عند
/// الحفظ على الجهاز أو إرسالها عبر تطبيقات أخرى (فتتراكم كلها بنفس
/// الاسم، ويُستبدَل أحدها بالآخر أو يُرقَّم تلقائياً بأرقام لا معنى لها).
///
/// - **شهادة واحدة**: يحمل اسم المستفيدة نفسها — "شهادة_أساور_طلال.pdf".
/// - **عدة شهادات لنفس الحلقة**: اسم الحلقة + العدد —
///   "شهادات_حلقة_النور_12.pdf".
/// - **عدة شهادات من أكثر من حلقة**: اسم المسجد + العدد (أو عدد فقط إن
///   تعذّر توفر اسم مسجد) — "شهادات_جامع_السنة_20.pdf".
String buildCertificateShareFileName({
  required List<CertificateRenderData> recipients,
  String? circleNameSnapshot,
  String? mosqueNameSnapshot,
}) {
  if (recipients.length == 1) {
    final name = _sanitizeForFileName(recipients.first.recipientName);
    return name.isEmpty ? 'شهادة.pdf' : 'شهادة_$name.pdf';
  }

  final rawGroupLabel = (circleNameSnapshot != null &&
          circleNameSnapshot.trim().isNotEmpty)
      ? circleNameSnapshot.trim()
      : ((mosqueNameSnapshot != null && mosqueNameSnapshot.trim().isNotEmpty)
          ? mosqueNameSnapshot.trim()
          : null);

  final safeGroupLabel =
      rawGroupLabel != null ? _sanitizeForFileName(rawGroupLabel) : null;

  return (safeGroupLabel != null && safeGroupLabel.isNotEmpty)
      ? 'شهادات_${safeGroupLabel}_${recipients.length}.pdf'
      : 'شهادات_${recipients.length}.pdf';
}
