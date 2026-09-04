import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/certificate_template.dart';
import '../../domain/entities/certificate_template_layout.dart';
import '../providers/certificate_template_layout_provider.dart';

/// تسميات عربية مختصرة لكل حقل — تُستخدَم في شرائح السحب وقائمة
/// الإظهار/الإخفاء أسفل الشاشة فقط، بلا أي علاقة بنص الشهادة نفسها.
String _fieldLabel(CertificateField field) {
  switch (field) {
    case CertificateField.recipientName:
      return 'اسم المستفيدة';
    case CertificateField.mosqueName:
      return 'اسم المسجد';
    case CertificateField.schoolName:
      return 'اسم الدار';
    case CertificateField.circleName:
      return 'اسم الحلقة';
    case CertificateField.teacherName:
      return 'اسم المعلمة';
    case CertificateField.supervisorName:
      return 'اسم المشرفة';
    case CertificateField.date:
      return 'التاريخ';
    case CertificateField.academicYear:
      return 'العام الدراسي';
    case CertificateField.certificateType:
      return 'نوع الشهادة';
  }
}

/// محرر مواضع حقول قالب أساسي واحد — دفعة أولى من "المرحلة الثانية"
/// (القسم ١٣ من تصميم الميزة): **سحب حرّ + إظهار/إخفاء فقط**، بلا تخصيص
/// خط/لون/حجم وبلا استيراد قوالب خارجية (تُضاف لاحقاً تدريجياً).
///
/// التعديل هنا خاص **بمسجد واحد فقط** (`mosqueId`) — يُنشئ أو يحدِّث
/// `CertificateTemplateLayout` مستقلاً في Firestore، بلا أي مساس بالقالب
/// الأساسي نفسه (يبقى كما هو دائماً لكل المساجد الأخرى).
class CertificateTemplateEditorScreen extends ConsumerStatefulWidget {
  final CertificateTemplateDefinition template;
  final String mosqueId;

  const CertificateTemplateEditorScreen({
    super.key,
    required this.template,
    required this.mosqueId,
  });

  @override
  ConsumerState<CertificateTemplateEditorScreen> createState() =>
      _CertificateTemplateEditorScreenState();
}

class _CertificateTemplateEditorScreenState
    extends ConsumerState<CertificateTemplateEditorScreen> {
  bool _initialized = false;
  bool _isSaving = false;
  late Map<CertificateField, CertificateFieldLayout> _fieldLayouts;
  CertificateStampLayout? _stampLayout;

  /// يبني حالة البداية من التخطيط المخصَّص المحفوظ (إن وُجد)، وإلا من
  /// المواضع الثابتة في القالب الأساسي نفسها — بحيث تبدأ المشرفة دائماً
  /// من الشكل الحالي الفعلي للشهادة، لا من نقطة صفر.
  void _seedFrom(CertificateTemplateLayout? saved) {
    _fieldLayouts = {
      for (final f in widget.template.fixedFields)
        f.field: saved?.layoutFor(f.field) ??
            CertificateFieldLayout(field: f.field, dx: f.dx, dy: f.dy),
    };
    final basePosition = widget.template.stampPosition;
    _stampLayout = basePosition == null
        ? null
        : (saved?.stamp ??
            CertificateStampLayout(dx: basePosition.dx, dy: basePosition.dy));
  }

  void _resetField(CertificateField field) {
    final base = widget.template.fixedFields
        .firstWhere((f) => f.field == field);
    setState(() {
      _fieldLayouts[field] =
          CertificateFieldLayout(field: field, dx: base.dx, dy: base.dy);
    });
  }

  void _resetStamp() {
    final base = widget.template.stampPosition;
    if (base == null) return;
    setState(() {
      _stampLayout = CertificateStampLayout(dx: base.dx, dy: base.dy);
    });
  }

  void _resetAll() {
    setState(() => _seedFrom(null));
  }

  Future<void> _save() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      final layout = CertificateTemplateLayout(
        mosqueId: widget.mosqueId,
        baseTemplateId: widget.template.id,
        fields: _fieldLayouts.values.toList(),
        stamp: _stampLayout,
        updatedAt: DateTime.now(),
        updatedByUid: user.uid,
      );
      await ref
          .read(certificateTemplateLayoutRepositoryProvider)
          .save(layout);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تخطيط القالب')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الحفظ: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildDragChip({
    required double dx,
    required double dy,
    required double width,
    required double height,
    required String label,
    required void Function(Offset delta) onDrag,
    IconData? icon,
  }) {
    const chipWidth = 96.0;
    const chipHeight = 34.0;
    return Positioned(
      left: (dx * width) - (chipWidth / 2),
      top: (dy * height) - (chipHeight / 2),
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: chipWidth,
          height: chipHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.88),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 18)
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layoutAsync = ref.watch(certificateTemplateLayoutProvider(
        (mosqueId: widget.mosqueId, templateId: widget.template.id)));

    if (!_initialized) {
      final saved = layoutAsync.maybeWhen(
        data: (value) => value,
        orElse: () => null,
      );
      if (layoutAsync.isLoading && !layoutAsync.hasValue) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.template.displayName)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      _seedFrom(saved);
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.displayName),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط الكل',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _isSaving ? null : _resetAll,
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'اسحبي أي عنصر لتغيير موضعه، ثم احفظي التعديل',
                style: TextStyle(
                    fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: 1.414,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            widget.template.backgroundImageAsset,
                            fit: BoxFit.fill,
                          ),
                        ),
                        for (final layout in _fieldLayouts.values)
                          if (layout.visible)
                            _buildDragChip(
                              dx: layout.dx,
                              dy: layout.dy,
                              width: width,
                              height: height,
                              label: _fieldLabel(layout.field),
                              onDrag: (delta) => setState(() {
                                final dx =
                                    (layout.dx + delta.dx / width).clamp(0.0, 1.0);
                                final dy =
                                    (layout.dy + delta.dy / height).clamp(0.0, 1.0);
                                _fieldLayouts[layout.field] =
                                    layout.copyWith(dx: dx, dy: dy);
                              }),
                            ),
                        if (_stampLayout != null && _stampLayout!.visible)
                          _buildDragChip(
                            dx: _stampLayout!.dx,
                            dy: _stampLayout!.dy,
                            width: width,
                            height: height,
                            label: 'الختم',
                            icon: Icons.approval_rounded,
                            onDrag: (delta) => setState(() {
                              final dx = (_stampLayout!.dx + delta.dx / width)
                                  .clamp(0.0, 1.0);
                              final dy = (_stampLayout!.dy + delta.dy / height)
                                  .clamp(0.0, 1.0);
                              _stampLayout =
                                  _stampLayout!.copyWith(dx: dx, dy: dy);
                            }),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final layout in _fieldLayouts.values)
                  _buildFieldRow(
                    label: _fieldLabel(layout.field),
                    visible: layout.visible,
                    onVisibleChanged: (value) => setState(() {
                      _fieldLayouts[layout.field] =
                          layout.copyWith(visible: value);
                    }),
                    onReset: () => _resetField(layout.field),
                  ),
                if (_stampLayout != null)
                  _buildFieldRow(
                    label: 'الختم',
                    visible: _stampLayout!.visible,
                    onVisibleChanged: (value) => setState(() {
                      _stampLayout = _stampLayout!.copyWith(visible: value);
                    }),
                    onReset: _resetStamp,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow({
    required String label,
    required bool visible,
    required ValueChanged<bool> onVisibleChanged,
    required VoidCallback onReset,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'إعادة ضبط',
            icon: const Icon(Icons.replay_rounded, size: 18),
            color: Colors.grey.shade400,
            onPressed: onReset,
          ),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
          ),
          Switch(value: visible, onChanged: onVisibleChanged),
        ],
      ),
    );
  }
}
