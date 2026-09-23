import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/certificate_template_import_service.dart';
import '../../data/templates/certificate_template_registry.dart';
import '../../domain/entities/certificate_batch.dart';
import '../../domain/entities/certificate_template.dart';
import '../../domain/entities/imported_certificate_template.dart';
import '../providers/imported_certificate_templates_provider.dart';
import '../widgets/certificate_template_card.dart';
import 'certificate_template_editor_screen.dart';
import '../../data/template_image_store.dart';

/// عنصر واحد في شبكة القوالب — قالب أساسي مُجمَّع (`imported == null`) أو
/// قالب مستورَد (`imported` يحمل سجله الكامل، لازم فقط لزر الحذف).
typedef _TemplateGridItem = ({
  CertificateTemplateDefinition definition,
  ImportedCertificateTemplate? imported,
});

/// شاشة "إدارة القوالب" — تعرض كل القوالب الأساسية المتاحة (شبكة تتّسع
/// تلقائياً لأي قوالب جديدة تُضاف مستقبلاً — القسم ٣-أ من تصميم الميزة)
/// بالإضافة إلى **القوالب المستورَدة** لمسجد المشرفة (القسم ٦ — استيراد
/// قوالب: صورة أو PDF، مخزَّنة محلياً على جهازها فقط بلا Firestore)، مع
/// زر "تحرير" على كل بطاقة يفتح محرر مواضع الحقول ("المرحلة الثانية" —
/// القسم ١٣): سحب حرّ + إظهار/إخفاء + تخصيص خط + إضافة حقول/نصوص حرة.
///
/// التحرير والاستيراد والحذف خاصة **بمشرفة المسجد فقط** لقوالب مسجدها هي
/// (كل مسجد يدير قوالبه بنفسه)؛ المشرف العام يرى القوالب الأساسية فقط
/// بلا زر تحرير — قراءة فقط، بنفس صلاحيات القسم ٧ من تصميم الميزة (ولا
/// يرى أي قوالب مستورَدة، بما أنها محلية على جهاز مشرفة بعينها أصلاً).
class ManageCertificateTemplatesScreen extends ConsumerWidget {
  const ManageCertificateTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final editableMosqueId =
        (user != null && user.isMosqueSupervisor) ? user.mosqueId : null;

    final importedList = editableMosqueId != null
        ? ref
            .watch(importedCertificateTemplatesProvider(editableMosqueId))
            .maybeWhen(
              data: (list) => list,
              orElse: () => const <ImportedCertificateTemplate>[],
            )
        : const <ImportedCertificateTemplate>[];

    final items = <_TemplateGridItem>[
      for (final t in certificateTemplateRegistry) (definition: t, imported: null),
      for (final t in importedList) (definition: t.toDefinition(), imported: t),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('قوالب الشهادات'),
        actions: [
          if (editableMosqueId != null)
            IconButton(
              tooltip: 'استيراد قالب',
              icon: const Icon(Icons.upload_file_rounded),
              onPressed: () => showDialog(
                context: context,
                builder: (_) =>
                    _ImportTemplateDialog(mosqueId: editableMosqueId),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Text('لا توجد قوالب متاحة حالياً',
                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final template = item.definition;
                return Stack(
                  children: [
                    CertificateTemplateCard(template: template),
                    if (editableMosqueId != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 1.5,
                          child: IconButton(
                            tooltip: 'تحرير مواضع الحقول',
                            iconSize: 18,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.edit_rounded,
                                color: AppTheme.primaryGreen),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CertificateTemplateEditorScreen(
                                  template: template,
                                  mosqueId: editableMosqueId,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // زر الحذف يظهر فقط لقالب مستورَد — القوالب الأساسية
                    // المُجمَّعة لا يمكن حذفها إطلاقاً من داخل التطبيق.
                    if (item.imported != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 1.5,
                          child: IconButton(
                            tooltip: 'حذف القالب',
                            iconSize: 18,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.shade400),
                            onPressed: () => _confirmDeleteImported(
                                context, ref, editableMosqueId!, item.imported!),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _confirmDeleteImported(
    BuildContext context,
    WidgetRef ref,
    String mosqueId,
    ImportedCertificateTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف القالب', style: TextStyle(fontFamily: 'Tajawal')),
        content: Text(
          'هل تريدين حذف "${template.displayName}"؟ لا يمكن التراجع عن هذا.',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(importedCertificateTemplateRepositoryProvider)
        .delete(mosqueId, template.id);
    ref.invalidate(importedCertificateTemplatesProvider(mosqueId));
  }
}

/// حوار استيراد قالب جديد (القسم ٦ من تصميم الميزة) — اسم القالب + نوع
/// المستفيد + اختيار ملف (صورة أو PDF). عند التأكيد: يُحفَظ ملف الخلفية
/// محلياً عبر [CertificateTemplateImportService] (PDF يُحوَّل لصورة أول
/// صفحة منه فقط، وصورة تُنسَخ كما هي)، يُضاف سجل [ImportedCertificateTemplate]
/// جديد عبر المستودع المحلي، ثم يُغلَق هذا الحوار وتُفتَح مباشرة شاشة محرر
/// مواضع الحقول على القالب الجديد — فارغ تماماً بلا أي حقل بعد، فتبنيه
/// المشرفة حقلاً حقلاً عبر زر "إضافة حقل" هناك.
class _ImportTemplateDialog extends ConsumerStatefulWidget {
  final String mosqueId;

  const _ImportTemplateDialog({required this.mosqueId});

  @override
  ConsumerState<_ImportTemplateDialog> createState() =>
      _ImportTemplateDialogState();
}

class _ImportTemplateDialogState extends ConsumerState<_ImportTemplateDialog> {
  final _nameController = TextEditingController();
  CertificateRecipientType _recipientType = CertificateRecipientType.student;
  PlatformFile? _pickedFile;
  bool _isImporting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// حد أقصى معقول لحجم ملف القالب المستورَد (صورة أو PDF) - ملف أكبر من هذا قد يستهلك ذاكرة كافية
  /// لإسقاط التطبيق بالكامل عند قراءته دفعة واحدة في الذاكرة على أجهزة محدودة الرام -
  /// هذا ما حدث فعلياً مع ملف تصدير Canva ضخم: قراءته كاملاً في الذاكرة أسقطت التطبيق بالكامل بلا أي خطأً يُمكن عرضه للمستخدمة.
  static const int _maxImportFileSizeBytes = 8 * 1024 * 1024; // 8 ميجابايت

  Future<void> _pickFile() async {
    // نسخة file_picker 12.x (إعادة الكتابة الموحدة): pickFile() (المفردة) هي البديل غير الُهمل لـ pickFiles(allowMultiple: false)،
    // تعيد PlatformFile؟ مباشرة (null عند الإلغاء)، بلا FilePickerResult وبلا withData نهائياً.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null) return;

    // file_picker 12.x: لا يوجد getter مزامن اسمه size على PlatformFile
    // إطلاقاً (خطأ تصريف فعلي رصدتيه) — البديل الصحيح `Future<int?>
    // length()` غير متزامن (يعمل على كل المنصات بما فيها الويب، بلا أي
    // حاجة لـdart:io). null يعني حجماً غير معروف بلا قراءة كاملة للملف؛
    // في هذه الحالة النادرة نسمح بالمتابعة بدل حظرها بلا داعٍ.
    final sizeBytes = await picked.length();
    if (sizeBytes != null && sizeBytes > _maxImportFileSizeBytes) {
      setState(() {
        _error =
            'حجم الملف كبير جداً (${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت) - الحد الأقصى ${_maxImportFileSizeBytes ~/ (1024 * 1024)} ميجابايت. جرّبي صورة بحجم أصغر.';
      });
      return;
    }

    setState(() {
      _pickedFile = picked;
      _error = null;
    });
  }

  Future<void> _confirm() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتبي اسماً للقالب');
      return;
    }
    final picked = _pickedFile;
    if (picked == null) {
      setState(() => _error = 'اختاري ملف صورة أو PDF أولاً');
      return;
    }

    setState(() {
      _isImporting = true;
      _error = null;
    });
    try {
      // file_picker 12.x: لا يوجد getter مزامن اسمه bytes بعد الآن على PlatformFile إطلاقاً،
      // فالبايتس تُقرّأ عند الحاجة عبر هذه الدالة غير المتزامنة، مع احتياط بالقراءة من مسار الملف مباشرة إن فشلت.
      Uint8List bytes;
      try {
        bytes = await picked.readAsBytes();
      } catch (_) {
        if (picked.path == null) {
          throw Exception('تعذّرت قراءة الملف المختار');
        }
        bytes = await TemplateImageStore.readPickedFileBytes(picked.path!);
      }
      final extension = (picked.extension ?? '').toLowerCase();
      final isPdf = extension == 'pdf';

      final imagePath = await CertificateTemplateImportService.importFile(
        mosqueId: widget.mosqueId,
        bytes: bytes,
        isPdf: isPdf,
        imageExtension: extension.isEmpty ? 'png' : extension,
      );

      final template = ImportedCertificateTemplate(
        id: const Uuid().v4(),
        mosqueId: widget.mosqueId,
        displayName: name,
        recipientType: _recipientType,
        backgroundImagePath: imagePath,
        createdAt: DateTime.now(),
      );
      await ref
          .read(importedCertificateTemplateRepositoryProvider)
          .add(template);
      ref.invalidate(importedCertificateTemplatesProvider(widget.mosqueId));

      if (!mounted) return;
      // نلتقط Navigator الجذر قبل إغلاق هذا الحوار — بعد الإغلاق يصبح
      // `context` الخاص بهذا الحوار غير صالح، لكن مرجع NavigatorState نفسه
      // يبقى صالحاً للاستخدام مباشرة بعده.
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      Navigator.of(context).pop();
      rootNavigator.push(
        MaterialPageRoute(
          builder: (_) => CertificateTemplateEditorScreen(
            template: template.toDefinition(),
            mosqueId: widget.mosqueId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _error = 'تعذّر الاستيراد: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('استيراد قالب', style: TextStyle(fontFamily: 'Tajawal')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: const InputDecoration(
                labelText: 'اسم القالب',
                labelStyle: TextStyle(fontFamily: 'Tajawal'),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<CertificateRecipientType>(
              value: _recipientType,
              decoration: const InputDecoration(
                labelText: 'نوع المستفيد',
                labelStyle: TextStyle(fontFamily: 'Tajawal'),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: CertificateRecipientType.student,
                  child: Text('طالبات', style: TextStyle(fontFamily: 'Tajawal')),
                ),
                DropdownMenuItem(
                  value: CertificateRecipientType.teacher,
                  child: Text('معلمات', style: TextStyle(fontFamily: 'Tajawal')),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _recipientType = value);
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _pickFile,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(
                _pickedFile?.name ?? 'اختيار ملف (صورة أو PDF)',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                    fontFamily: 'Tajawal', color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
        ),
        ElevatedButton(
          onPressed: _isImporting ? null : _confirm,
          child: _isImporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('استيراد'),
        ),
      ],
    );
  }
}
