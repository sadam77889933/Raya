import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/teachers_provider.dart';
import '../../../mosques/domain/entities/mosque.dart';
import '../../../mosques/domain/entities/school.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../roster_report/domain/entities/roster_report_group.dart';
import '../../data/certificate_pdf_generator.dart';
import '../../data/templates/certificate_template_registry.dart';
import '../../domain/certificate_share_filename.dart';
import '../../domain/entities/certificate_batch.dart';
import '../../domain/entities/certificate_render_data.dart';
import '../../domain/entities/certificate_template.dart';
import '../providers/certificate_history_provider.dart';
import '../providers/certificate_recipients_provider.dart';
import '../providers/certificate_template_layout_provider.dart';
import '../providers/certificate_wizard_provider.dart';
import '../widgets/certificate_template_card.dart';

const List<String> _stepTitles = [
  'نوع المستفيد',
  'القالب',
  'المستفيدون',
  'معاينة',
  'الإنشاء والمشاركة',
];

/// معالج إنشاء شهادة — شاشة واحدة بخمس خطوات داخلية (القسم ٢ من تصميم
/// الميزة)، بدل خمس شاشات منفصلة.
class CertificateWizardScreen extends ConsumerStatefulWidget {
  const CertificateWizardScreen({super.key});

  @override
  ConsumerState<CertificateWizardScreen> createState() =>
      _CertificateWizardScreenState();
}

class _CertificateWizardScreenState
    extends ConsumerState<CertificateWizardScreen> {
  String? _globalSupervisorMosqueId; // اختيار المسجد للمشرف العام فقط
  Uint8List? _previewBytes;
  bool _isLoadingPreview = false;

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(certificateWizardProvider);
    final notifier = ref.read(certificateWizardProvider.notifier);
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final effectiveMosqueId =
        user.isSupervisor ? _globalSupervisorMosqueId : user.mosqueId;

    // مراقبة مستمرة طوال بقاء شاشة المعالج كاملة (وليس فقط أثناء خطوة
    // اختيار المستفيدين) — تمنع تخلّص Riverpod التلقائي (autoDispose) من
    // مزوّد المجموعات ومزوّدات الحلقات/الدور التابعة له أثناء انتقال
    // المستخدمة عبر خطوتي المعاينة والإنشاء، واللتين تقرآن القائمة عبر
    // ref.read() فقط (لا تُبقيان أي مستمع). بدون هذا، تجاوز 60 ثانية بين
    // فتح خطوة الاختيار وضغط "إنشاء" قد يُفرغ القائمة فجأة قبل التوليد.
    if (effectiveMosqueId != null) {
      ref.watch(certificateRecipientGroupsProvider(effectiveMosqueId));
      // نفس الإحماء أعلاه، لكن لسلسلة المعلمات (تُستخدَم فقط عند اختيار
      // "معلمات" في الخطوة ١) — بلا هذا سيتكرر نفس تأخير autoDispose عند
      // أول استخدام لهذه السلسلة تحديداً في خطوة اختيار المستفيدين.
      ref.watch(teachersByMosqueProvider(effectiveMosqueId));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء شهادة')),
      body: Column(
        children: [
          _buildStepper(wizard.step),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(wizard, notifier, user, effectiveMosqueId),
            ),
          ),
          _buildNavBar(wizard, notifier, effectiveMosqueId),
        ],
      ),
    );
  }

  Widget _buildStepper(int step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < _stepTitles.length; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step
                      ? AppTheme.primaryGreen
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i != _stepTitles.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildStepContent(
    CertificateWizardState wizard,
    CertificateWizardNotifier notifier,
    UserModel user,
    String? mosqueId,
  ) {
    switch (wizard.step) {
      case 0:
        return _buildRecipientTypeStep(wizard, notifier);
      case 1:
        return _buildTemplateStep(wizard, notifier);
      case 2:
        return _buildRecipientsStep(wizard, notifier, user, mosqueId);
      case 3:
        return _buildPreviewStep(wizard, notifier, mosqueId);
      case 4:
        return _buildGenerateStep(wizard, notifier, user, mosqueId);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── خطوة ١: نوع المستفيد ──
  Widget _buildRecipientTypeStep(
      CertificateWizardState wizard, CertificateWizardNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('لمن تُصدَر الشهادات؟',
            style: TextStyle(
                fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _RecipientTypeOption(
          icon: Icons.school_rounded,
          label: 'طالبات',
          selected: wizard.recipientType == CertificateRecipientType.student,
          enabled: true,
          onTap: () =>
              notifier.setRecipientType(CertificateRecipientType.student),
        ),
        const SizedBox(height: 10),
        _RecipientTypeOption(
          icon: Icons.co_present_rounded,
          label: 'معلمات',
          selected: wizard.recipientType == CertificateRecipientType.teacher,
          enabled: true,
          onTap: () =>
              notifier.setRecipientType(CertificateRecipientType.teacher),
        ),
      ],
    );
  }

  // ── خطوة ٢: القالب ──
  Widget _buildTemplateStep(
      CertificateWizardState wizard, CertificateWizardNotifier notifier) {
    final type = wizard.recipientType;
    if (type == null) {
      return const Center(
        child: Text('اختاري نوع المستفيد أولاً',
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
      );
    }
    final templates = certificateTemplatesFor(type);
    if (templates.isEmpty) {
      return const Center(
        child: Text('لا يوجد قالب متاح لهذا النوع بعد',
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final t = templates[index];
        return CertificateTemplateCard(
          template: t,
          selected: wizard.templateId == t.id,
          onTap: () => notifier.setTemplate(t.id),
        );
      },
    );
  }

  // ── خطوة ٣: المستفيدون ──
  Widget _buildRecipientsStep(
    CertificateWizardState wizard,
    CertificateWizardNotifier notifier,
    UserModel user,
    String? mosqueId,
  ) {
    if (user.isSupervisor) {
      final mosques = ref.watch(activeMosquesProvider);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _globalSupervisorMosqueId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.mosque_rounded, size: 18),
              hintText: 'اختاري المسجد',
              isDense: true,
            ),
            items: mosques
                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                .toList(),
            onChanged: (val) => setState(() => _globalSupervisorMosqueId = val),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: mosqueId == null
                ? const Center(
                    child: Text('اختاري المسجد أولاً',
                        style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                  )
                : _buildRecipientGroups(wizard, notifier, mosqueId),
          ),
        ],
      );
    }
    if (mosqueId == null) {
      return const Center(
        child: Text('تعذّر تحديد مسجدك',
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
      );
    }
    return _buildRecipientGroups(wizard, notifier, mosqueId);
  }

  Widget _buildRecipientGroups(CertificateWizardState wizard,
      CertificateWizardNotifier notifier, String mosqueId) {
    if (wizard.recipientType == CertificateRecipientType.teacher) {
      return _buildTeacherRecipients(wizard, notifier, mosqueId);
    }
    final groups = ref.watch(certificateRecipientGroupsProvider(mosqueId));
    if (groups.isEmpty) {
      return const Center(
        child: Text('لا توجد طالبات نشطات في هذا المسجد',
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('العدد المختار: ${wizard.selectedRecipientIds.length}',
            style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final group in groups) ...[
                _GroupHeader(
                  group: group,
                  allSelected: group.students
                      .every((s) => wizard.selectedRecipientIds.contains(s.id)),
                  onToggleAll: (val) => notifier.setGroupSelected(
                      group.students.map((s) => s.id).toList(), val),
                ),
                for (final student in group.students)
                  CheckboxListTile(
                    dense: true,
                    value: wizard.selectedRecipientIds.contains(student.id),
                    onChanged: (_) => notifier.toggleRecipient(student.id),
                    title: Text(student.name,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5)),
                    activeColor: AppTheme.primaryGreen,
                  ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// اختيار مستفيدي شهادات المعلمات: خطوة إضافية أولى (اختيار الدار
  /// يدوياً من المشرفة، لأن المعلمة قد تُدرّس في أكثر من دار فلا يوجد
  /// "دار افتراضية" صحيحة تلقائياً)، ثم قائمة المعلمات المسندات لتلك
  /// الدار تحديداً للاختيار منها — بنفس أسلوب قوائم الطالبات أعلاه.
  Widget _buildTeacherRecipients(CertificateWizardState wizard,
      CertificateWizardNotifier notifier, String mosqueId) {
    final schools = ref.watch(activeSchoolsByMosqueProvider(mosqueId));
    if (schools.isEmpty) {
      return const Center(
        child: Text('لا توجد دور نشطة في هذا المسجد',
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
      );
    }

    final schoolDropdown = DropdownButtonFormField<String>(
      value: wizard.selectedSchoolId,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.home_work_rounded, size: 18),
        hintText: 'اختاري الدار',
        isDense: true,
      ),
      items: schools
          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
          .toList(),
      onChanged: (val) => notifier.setSelectedSchool(val),
    );

    if (wizard.selectedSchoolId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          schoolDropdown,
          const SizedBox(height: 20),
          const Expanded(
            child: Center(
              child: Text('اختاري الدار أولاً لعرض معلماتها',
                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
            ),
          ),
        ],
      );
    }

    final teachersAsync = ref.watch(teachersByMosqueProvider(mosqueId));
    final selectedSchoolId = wizard.selectedSchoolId!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        schoolDropdown,
        const SizedBox(height: 12),
        Text('العدد المختار: ${wizard.selectedRecipientIds.length}',
            style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Expanded(
          child: teachersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('حدث خطأ: $err',
                  style: const TextStyle(fontFamily: 'Tajawal')),
            ),
            data: (allTeachers) {
              final teachers = allTeachers
                  .where((t) =>
                      t.isActive && t.assignedSchoolIds.contains(selectedSchoolId))
                  .toList();
              if (teachers.isEmpty) {
                return const Center(
                  child: Text('لا توجد معلمات مسندات لهذه الدار',
                      style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                );
              }
              return ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('المعلمات (${teachers.length})',
                            style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () => notifier.setGroupSelected(
                          teachers.map((t) => t.uid).toList(),
                          !teachers.every((t) =>
                              wizard.selectedRecipientIds.contains(t.uid)),
                        ),
                        child: Text(
                          teachers.every((t) =>
                                  wizard.selectedRecipientIds.contains(t.uid))
                              ? 'إلغاء الكل'
                              : 'تحديد الكل',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  for (final teacher in teachers)
                    CheckboxListTile(
                      dense: true,
                      value: wizard.selectedRecipientIds.contains(teacher.uid),
                      onChanged: (_) => notifier.toggleRecipient(teacher.uid),
                      title: Text(teacher.name,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5)),
                      activeColor: AppTheme.primaryGreen,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── خطوة ٤: معاينة ──
  Widget _buildPreviewStep(CertificateWizardState wizard,
      CertificateWizardNotifier notifier, String? mosqueId) {
    final selectedIds = wizard.selectedRecipientIds.toList();
    if (selectedIds.isEmpty || wizard.templateId == null || mosqueId == null) {
      return const Center(
        child: Text('أكملي الخطوات السابقة أولاً',
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
      );
    }
    final template = certificateTemplateById(wizard.templateId!);
    if (template == null) return const SizedBox.shrink();

    final recipients = _buildRenderDataList(wizard, mosqueId, selectedIds);
    if (recipients.isEmpty) return const SizedBox.shrink();

    final index = wizard.previewIndex.clamp(0, recipients.length - 1).toInt();
    final mosque = ref
        .watch(activeMosquesProvider)
        .where((m) => m.id == mosqueId)
        .firstOrNull;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreview(template, recipients[index], mosque, mosqueId);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('معاينة ${index + 1} / ${recipients.length} — ${recipients[index].recipientName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Expanded(
          child: _isLoadingPreview || _previewBytes == null
              ? const Center(child: CircularProgressIndicator())
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: PdfPreview(
                    build: (_) async => _previewBytes!,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: false,
                    useActions: false,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: index > 0
                  ? () {
                      notifier.setPreviewIndex(index - 1);
                      setState(() => _previewBytes = null);
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ),
            Text('${index + 1} / ${recipients.length}',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
            IconButton(
              onPressed: index < recipients.length - 1
                  ? () {
                      notifier.setPreviewIndex(index + 1);
                      setState(() => _previewBytes = null);
                    }
                  : null,
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadPreview(CertificateTemplateDefinition template,
      CertificateRenderData recipient, Mosque? mosque, String mosqueId) async {
    if (_previewBytes != null || _isLoadingPreview) return;
    setState(() => _isLoadingPreview = true);
    try {
      // معاينة WYSIWYG حقيقية: نجلب تخطيط المسجد المخصَّص لهذا القالب
      // (إن وُجد — "المرحلة الثانية" من محرر مواضع الحقول) فتُظهر
      // المعاينة بالضبط ما سيصدر فعلاً، لا المواضع الافتراضية دوماً.
      final customLayout = await ref.read(certificateTemplateLayoutProvider(
              (mosqueId: mosqueId, templateId: template.id))
          .future);
      final bytes = await CertificatePdfGenerator.generate(
        template: template,
        recipients: [recipient],
        mosqueStampBase64: mosque?.stampBase64,
        customLayout: customLayout,
      );
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _isLoadingPreview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPreview = false);
    }
  }

  // ── خطوة ٥: الإنشاء والمشاركة ──
  Widget _buildGenerateStep(CertificateWizardState wizard,
      CertificateWizardNotifier notifier, UserModel user, String? mosqueId) {
    final selectedIds = wizard.selectedRecipientIds.toList();
    final template = wizard.templateId != null
        ? certificateTemplateById(wizard.templateId!)
        : null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: 64, color: AppTheme.primaryGreen.withOpacity(0.7)),
          const SizedBox(height: 14),
          Text('جاهزة لإنشاء ${selectedIds.length} شهادة',
              style: const TextStyle(
                  fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(template?.displayName ?? '',
              style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade600)),
          const SizedBox(height: 26),
          if (wizard.error != null) ...[
            Text(wizard.error!,
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontSize: 12)),
            const SizedBox(height: 14),
          ],
          if (wizard.isGenerating)
            const CircularProgressIndicator()
          else
            ElevatedButton.icon(
              onPressed: () => _generateAndShare(wizard, notifier, user, mosqueId),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('إنشاء الشهادات ومشاركتها'),
            ),
        ],
      ),
    );
  }

  /// يبني بيانات العرض للمعاينة (خطوة ٤) — من سجل الحلقات للطالبات، أو
  /// من قائمة المعلمات المسندات للدار المختارة يدوياً للمعلمات (انظر
  /// `_buildTeacherRecipients` أعلاه لسبب عدم وجود "دار افتراضية" آلية).
  List<CertificateRenderData> _buildRenderDataList(
      CertificateWizardState wizard, String mosqueId, List<String> selectedIds) {
    if (wizard.recipientType == CertificateRecipientType.teacher) {
      final schoolId = wizard.selectedSchoolId;
      if (schoolId == null) return const [];
      final mosque = ref
          .read(activeMosquesProvider)
          .where((m) => m.id == mosqueId)
          .firstOrNull;
      final school = ref
          .read(activeSchoolsByMosqueProvider(mosqueId))
          .where((s) => s.id == schoolId)
          .firstOrNull;
      final teachers = ref.read(teachersByMosqueProvider(mosqueId)).maybeWhen(
            data: (list) => list,
            orElse: () => const <UserModel>[],
          );
      final data = <CertificateRenderData>[];
      for (final teacher in teachers) {
        if (!selectedIds.contains(teacher.uid)) continue;
        data.add(CertificateRenderData(
          recipientId: teacher.uid,
          recipientName: teacher.name,
          mosqueName: mosque?.name ?? '',
          schoolName: school?.name ?? '',
        ));
      }
      return data;
    }

    final groups = ref.read(certificateRecipientGroupsProvider(mosqueId));
    final data = <CertificateRenderData>[];
    for (final group in groups) {
      for (final student in group.students) {
        if (!selectedIds.contains(student.id)) continue;
        data.add(CertificateRenderData(
          recipientId: student.id,
          recipientName: student.name,
          mosqueName: group.mosqueName,
          schoolName: group.schoolName,
          circleName: group.circleName,
        ));
      }
    }
    return data;
  }

  Future<void> _generateAndShare(
    CertificateWizardState wizard,
    CertificateWizardNotifier notifier,
    UserModel user,
    String? mosqueId,
  ) async {
    if (mosqueId == null || wizard.templateId == null) return;
    final template = certificateTemplateById(wizard.templateId!);
    if (template == null) return;

    notifier.setGenerating(true);
    try {
      final selectedIds = wizard.selectedRecipientIds.toList();
      final recipients = _buildRenderDataList(wizard, mosqueId, selectedIds);
      if (recipients.isEmpty) {
        notifier.setError('لم يتبقَّ أي مستفيد ضمن الاختيار');
        return;
      }

      final mosque = ref
          .read(activeMosquesProvider)
          .where((m) => m.id == mosqueId)
          .firstOrNull;

      // تسمية سياقية للدُفعة تُعرض في سجل "آخر الشهادات": اسم الحلقة
      // للطالبات (إن كانت كل الشهادات المختارة لنفس الحلقة)، أو اسم
      // الدار المختارة يدوياً للمعلمات (معروف دائماً بما أن اختياره
      // إلزامي في خطوة الاختيار لهذا النوع — انظر _buildTeacherRecipients).
      String? contextLabel;
      if (wizard.recipientType == CertificateRecipientType.teacher) {
        final schoolId = wizard.selectedSchoolId;
        contextLabel = schoolId == null
            ? null
            : ref
                .read(activeSchoolsByMosqueProvider(mosqueId))
                .where((s) => s.id == schoolId)
                .firstOrNull
                ?.name;
      } else {
        final circleNames = recipients.map((r) => r.circleName).toSet();
        contextLabel = circleNames.length == 1 ? circleNames.first : null;
      }

      // نفس التخطيط المخصَّص المستخدَم في المعاينة (إن وُجد) — حتى تُطابق
      // الشهادة الفعلية المُصدَرة ما ظهر للمشرفة في خطوة المعاينة تماماً.
      final customLayout = await ref.read(certificateTemplateLayoutProvider(
              (mosqueId: mosqueId, templateId: template.id))
          .future);
      final bytes = await CertificatePdfGenerator.generate(
        template: template,
        recipients: recipients,
        mosqueStampBase64: mosque?.stampBase64,
        customLayout: customLayout,
      );

      await ref.read(certificateRepositoryProvider).create(
            CertificateBatch(
              id: '',
              createdAt: DateTime.now(),
              createdByUid: user.uid,
              createdByName: user.name,
              mosqueId: mosqueId,
              mosqueNameSnapshot: mosque?.name,
              recipientType: wizard.recipientType!,
              templateId: template.id,
              recipientIds: recipients.map((r) => r.recipientId).toList(),
              recipientCount: recipients.length,
              circleNameSnapshot: contextLabel,
            ),
          );

      if (!mounted) return;
      final fileName = buildCertificateShareFileName(
        recipients: recipients,
        circleNameSnapshot: contextLabel,
        mosqueNameSnapshot: mosque?.name,
      );
      // XFile.fromData(bytes, name: ...) لا يُظهِر الاسم المطلوب على كل
      // منصة (على ويندوز تحديداً يظهر اسم عشوائي بدل الاسم المُمرَّر —
      // المنصة تكتب البايتات إلى ملف مؤقت باسمها الداخلي الخاص، متجاهلة
      // معامل name). الحل الموثوق: كتابة الملف فعلياً بالاسم المطلوب في
      // مجلد مؤقت أولاً، ثم مشاركته كملف حقيقي بمساره — نفس الأسلوب
      // المعتمَد فعلاً في بقية مولّدات PDF بالمشروع (كالتقرير الإحصائي).
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'شهادات',
      );

      if (!mounted) return;
      notifier.setGenerating(false);
      Navigator.of(context).pop();
    } catch (e) {
      notifier.setError('تعذّر إنشاء الشهادات: ${e.toString()}');
    }
  }

  Widget _buildNavBar(CertificateWizardState wizard,
      CertificateWizardNotifier notifier, String? mosqueId) {
    final canGoNext = _canProceed(wizard, mosqueId);
    final isLastStep = wizard.step == _stepTitles.length - 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (wizard.step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: notifier.back,
                child: const Text('السابق'),
              ),
            ),
          if (wizard.step > 0) const SizedBox(width: 10),
          if (!isLastStep)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: canGoNext ? notifier.next : null,
                child: const Text('التالي'),
              ),
            ),
        ],
      ),
    );
  }

  bool _canProceed(CertificateWizardState wizard, String? mosqueId) {
    switch (wizard.step) {
      case 0:
        return wizard.recipientType != null;
      case 1:
        return wizard.templateId != null;
      case 2:
        if (mosqueId == null || wizard.selectedRecipientIds.isEmpty) {
          return false;
        }
        if (wizard.recipientType == CertificateRecipientType.teacher) {
          return wizard.selectedSchoolId != null;
        }
        return true;
      case 3:
        return true;
      default:
        return false;
    }
  }
}

class _RecipientTypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final String? subtitleWhenDisabled;
  final VoidCallback onTap;

  const _RecipientTypeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.subtitleWhenDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? AppTheme.lightGreen : null,
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: Icon(icon,
            color: enabled ? AppTheme.primaryGreen : Colors.grey.shade400),
        title: Text(label,
            style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
                color: enabled ? Colors.black87 : Colors.grey.shade400)),
        subtitle: !enabled && subtitleWhenDisabled != null
            ? Text(subtitleWhenDisabled!,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11))
            : null,
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen)
            : null,
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final RosterReportGroup group;
  final bool allSelected;
  final ValueChanged<bool> onToggleAll;

  const _GroupHeader({
    required this.group,
    required this.allSelected,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('${group.circleName} — ${group.schoolName}',
                style: const TextStyle(
                    fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => onToggleAll(!allSelected),
            child: Text(allSelected ? 'إلغاء الكل' : 'تحديد الكل',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
