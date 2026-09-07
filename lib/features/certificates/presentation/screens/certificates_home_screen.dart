import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/teachers_provider.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../data/certificate_pdf_generator.dart';
import '../../data/templates/certificate_template_registry.dart';
import '../../domain/certificate_share_filename.dart';
import '../../domain/entities/certificate_batch.dart';
import '../../domain/entities/certificate_render_data.dart';
import '../providers/certificate_history_provider.dart';
import '../providers/certificate_recipients_provider.dart';
import '../providers/certificate_template_layout_provider.dart';
import '../providers/imported_certificate_templates_provider.dart';
import '../widgets/certificate_batch_history_tile.dart';
import 'certificate_wizard_screen.dart';
import 'manage_certificate_templates_screen.dart';

/// الشاشة الرئيسية لميزة "الشهادات" — زرّا الإنشاء والإدارة + سجل آخر
/// الدُفعات (القسم ٨ من تصميم الميزة).
class CertificatesHomeScreen extends ConsumerStatefulWidget {
  const CertificatesHomeScreen({super.key});

  @override
  ConsumerState<CertificatesHomeScreen> createState() =>
      _CertificatesHomeScreenState();
}

class _CertificatesHomeScreenState extends ConsumerState<CertificatesHomeScreen> {
  bool _isResharing = false;

  /// يجمع مستفيدي الدفعة الأصليين — للطالبات من سلسلة مزوّدات (مسجد ←
  /// دور ← حلقات ← سجل الطالبات)، وللمعلمات من `teachersByMosqueProvider`
  /// مباشرة (لا يوجد "حلقة" للمعلمة، والدار محفوظة مسبقاً في
  /// `circleNameSnapshot` — انظر التعليق على هذا الحقل في
  /// `CertificateBatch`). كلاهما `autoDispose` يعتمد على دفق Firestore
  /// حيّ. إن لم يسبق لأي شاشة أخرى متابعة هذه السلسلة لهذا المسجد تحديداً
  /// (الحالة الشائعة هنا: الشاشة الرئيسية لا تفتح شاشة سجل أي حلقة)،
  /// فقراءتها بـ`ref.read()` مباشرة لحظة أول ضغطة تُنشئها للتوّ وهي
  /// لا تزال في طور التحميل (تُعيد قوائم فارغة فوراً)، والبيانات
  /// الحقيقية لا تصل إلا بعد جزء من الثانية (اتصال Firestore)، وقد
  /// يحتاج الأمر عدة مستويات متتالية (دور ثم حلقات ثم سجل) كل واحد
  /// يُنشأ فقط بعد اكتمال المستوى الذي قبله — من هنا الحاجة لعدة ضغطات
  /// يدوية سابقاً. هذه الدالة تُعيد المحاولة تلقائياً بفاصل قصير بدل
  /// الفشل الفوري، فتنجح غالباً من أول ضغطة وحيدة.
  Future<List<CertificateRenderData>?> _resolveRecipients(
      CertificateBatch batch) async {
    const maxAttempts = 8;
    const retryDelay = Duration(milliseconds: 300);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final recipients = <CertificateRenderData>[];
      if (batch.recipientType == CertificateRecipientType.teacher) {
        final teachers =
            ref.read(teachersByMosqueProvider(batch.mosqueId)).maybeWhen(
                  data: (list) => list,
                  orElse: () => const <UserModel>[],
                );
        for (final teacher in teachers) {
          if (!batch.recipientIds.contains(teacher.uid)) continue;
          recipients.add(CertificateRenderData(
            recipientId: teacher.uid,
            recipientName: teacher.name,
            mosqueName: batch.mosqueNameSnapshot ?? '',
            // اسم الدار المختارة يدوياً للدفعة محفوظ مسبقاً في
            // circleNameSnapshot (استخدام مزدوج للحقل خاص بدفعات
            // المعلمات — لا "حلقة" فعلية للمعلمة).
            schoolName: batch.circleNameSnapshot ?? '',
          ));
        }
      } else {
        final groups =
            ref.read(certificateRecipientGroupsProvider(batch.mosqueId));
        for (final group in groups) {
          for (final student in group.students) {
            if (!batch.recipientIds.contains(student.id)) continue;
            recipients.add(CertificateRenderData(
              recipientId: student.id,
              recipientName: student.name,
              mosqueName: group.mosqueName,
              schoolName: group.schoolName,
              circleName: group.circleName,
            ));
          }
        }
      }
      if (recipients.isNotEmpty) return recipients;
      if (attempt < maxAttempts - 1) {
        await Future.delayed(retryDelay);
      }
    }
    return null;
  }

  Future<void> _reshareBatch(CertificateBatch batch) async {
    // القالب قد يكون أساسياً مُجمَّعاً أو **مستورَداً** (القسم ٦ من تصميم
    // الميزة) — بدون هذا كانت إعادة مشاركة دفعة صادرة أصلاً عن قالب
    // مستورَد ستفشل بصمت هنا (`return` مبكر بلا أي رسالة) لأن القالب غير
    // موجود إطلاقاً في السجل الأساسي الثابت.
    final importedTemplates = await ref
        .read(importedCertificateTemplatesProvider(batch.mosqueId).future);
    final template = resolveTemplateById(batch.templateId, importedTemplates);
    if (template == null) return;

    setState(() => _isResharing = true);
    try {
      final recipients = await _resolveRecipients(batch);

      if (recipients == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تعذّر إيجاد المستفيدين الأصليين (رُبَّما نُقلوا أو حُذفوا)')),
        );
        return;
      }

      final mosque = ref
          .read(activeMosquesProvider)
          .where((m) => m.id == batch.mosqueId)
          .firstOrNull;

      // نفس التخطيط المخصَّص المستخدَم عند الإنشاء الأول (إن وُجد) — حتى
      // تُطابق إعادة المشاركة الشكل الحالي الفعلي للقالب لهذا المسجد.
      final customLayout = await ref.read(certificateTemplateLayoutProvider(
              (mosqueId: batch.mosqueId, templateId: template.id))
          .future);
      final bytes = await CertificatePdfGenerator.generate(
        template: template,
        recipients: recipients,
        mosqueStampBase64: mosque?.stampBase64,
        customLayout: customLayout,
      );

      if (!mounted) return;
      final fileName = buildCertificateShareFileName(
        recipients: recipients,
        circleNameSnapshot: batch.circleNameSnapshot,
        mosqueNameSnapshot: batch.mosqueNameSnapshot ?? mosque?.name,
      );
      // XFile.fromData(bytes, name: ...) لا يُظهِر الاسم المطلوب على كل
      // منصة (على ويندوز يظهر اسم عشوائي بدل الاسم المُمرَّر). الحل
      // الموثوق: كتابة الملف فعلياً بالاسم المطلوب في مجلد مؤقت أولاً،
      // ثم مشاركته كملف حقيقي بمساره — نفس أسلوب بقية مولّدات PDF
      // بالمشروع.
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'شهادات',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّرت إعادة المشاركة: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isResharing = false);
    }
  }

  /// يبني سجل "آخر الشهادات" مقسَّماً إلى قسمين ثابتين بعنوان — "معلمات"
  /// و"طالبات" — بدل قائمة واحدة مختلطة زمنياً، بحيث تبقى شهادات كل نوع
  /// مجتمعة مع بعضها (طلب المستخدمة). القائمتان الأصليتان مرتَّبتان أصلاً
  /// تنازلياً حسب تاريخ الإنشاء (`orderBy('createdAt', descending: true)`
  /// في `CertificateRepositoryImpl`)، فيكفي فرزهما إلى نوعين بلا أي إعادة
  /// ترتيب داخلي. أمّا ترتيب القسمين نفسيهما فديناميكي: يظهر أولاً القسم
  /// الذي يحوي أحدث شهادة على الإطلاق (وليس ترتيباً ثابتاً دائماً)، حتى لا
  /// يختفي آخر نشاط فعلي أسفل الشاشة خلف قسم أقدم.
  Widget _buildGroupedHistory(List<CertificateBatch> batches) {
    final teacherBatches = batches
        .where((b) => b.recipientType == CertificateRecipientType.teacher)
        .toList();
    final studentBatches = batches
        .where((b) => b.recipientType == CertificateRecipientType.student)
        .toList();

    final teacherIsNewer = teacherBatches.isNotEmpty &&
        (studentBatches.isEmpty ||
            teacherBatches.first.createdAt
                .isAfter(studentBatches.first.createdAt));

    final orderedGroups = teacherIsNewer
        ? [('معلمات', teacherBatches), ('طالبات', studentBatches)]
        : [('طالبات', studentBatches), ('معلمات', teacherBatches)];

    final children = <Widget>[];
    for (final (label, groupBatches) in orderedGroups) {
      if (groupBatches.isEmpty) continue;
      if (children.isNotEmpty) children.add(const SizedBox(height: 16));
      children.add(Align(
        alignment: Alignment.centerRight,
        child: Text(label,
            style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen)),
      ));
      children.add(const SizedBox(height: 8));
      for (final batch in groupBatches) {
        children.add(CertificateBatchHistoryTile(
          batch: batch,
          onTap: () => _reshareBatch(batch),
        ));
      }
    }
    return Column(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final batchesAsync = user.isSupervisor
        ? ref.watch(certificateBatchesAllProvider)
        : ref.watch(certificateBatchesByMosqueProvider(user.mosqueId ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('الشهادات')),
      body: AbsorbPointer(
        absorbing: _isResharing,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CertificateWizardScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إنشاء شهادة جديدة'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ManageCertificateTemplatesScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.dashboard_customize_rounded),
                          label: const Text('إدارة القوالب'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text('آخر الشهادات',
                      style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 10),
                  batchesAsync.when(
                    loading: () =>
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('حدث خطأ: $err',
                          style: const TextStyle(fontFamily: 'Tajawal')),
                    ),
                    data: (batches) {
                      if (batches.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text('لا توجد شهادات صادرة بعد',
                                style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: Colors.grey.shade400)),
                          ),
                        );
                      }
                      // إحماء دائم لسلسلة (دور ← حلقات ← سجل الطالبات)
                      // وسلسلة المعلمات (مسجد ← معلمات) معاً لكل مسجد
                      // ظاهر في السجل، طوال بقاء هذه الشاشة — بنفس سبب
                      // الإصلاح المطبَّق في معالج إنشاء الشهادات
                      // (autoDispose بلا أي مستمع سابق يعني بيانات فارغة
                      // عند أول قراءة). بهذا تكون البيانات جاهزة غالباً
                      // بالفعل لحظة الضغط على "مشاركة"، لا تحتاج انتظار
                      // _resolveRecipients لإعادة المحاولة — سواء كانت
                      // الدفعة لطالبات أو معلمات.
                      for (final mosqueId
                          in batches.map((b) => b.mosqueId).toSet()) {
                        ref.watch(certificateRecipientGroupsProvider(mosqueId));
                        ref.watch(teachersByMosqueProvider(mosqueId));
                      }
                      return _buildGroupedHistory(batches);
                    },
                  ),
                ],
              ),
            ),
            if (_isResharing)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
