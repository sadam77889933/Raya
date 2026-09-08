import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart' show PdfColor, PdfPageFormat;
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/certificate_font_catalog.dart';
import '../../domain/entities/certificate_font_family.dart';
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

/// يحوّل لون [PdfColor] (نظام ألوان حزمة pdf، قيم عشرية 0.0-1.0 لكل قناة)
/// إلى [Color] فلاتر عادي — لازم لعرض لون الحبر الافتراضي لحقل ثابت
/// (`CertificateFieldPosition.color`) بدقة على قماشة المحرر، بنفس اللون
/// تماماً الذي سيُرسَم به في ملف الـPDF الناتج عند عدم تخصيص لون خاص.
Color _pdfColorToFlutter(PdfColor c) => Color.fromRGBO(
      (c.red * 255).round().clamp(0, 255),
      (c.green * 255).round().clamp(0, 255),
      (c.blue * 255).round().clamp(0, 255),
      c.alpha,
    );

/// حدود منطقية لنسبة تكبير/تصغير الخط — تمنع تصغيراً/تكبيراً متطرفاً قد
/// يُخرج النص عن مساحة الشهادة أو يجعله غير مقروء.
const double _minFontScale = 0.5;
const double _maxFontScale = 2.0;
const double _fontScaleStep = 0.1;

/// حدود حجم الخط المطلق (بالنقاط) لعناصر النص الحرّ — لا نسبة تكبير هنا
/// لأنه لا يوجد حجم أساسي يُقاس نسبة إليه (بخلاف الحقول الثابتة).
const double _minCustomFontSize = 10;
const double _maxCustomFontSize = 72;
const double _customFontSizeStep = 2;

/// حدود عرض/ارتفاع منطقة تغطية النص — نسبة من أبعاد الشهادة (وليست
/// بالبكسل المطلق)، بنفس منطق dx/dy لبقية العناصر.
const double _minEraseSize = 0.02;
const double _maxEraseSize = 0.95;
const double _eraseSizeStep = 0.01;

/// نفس `customTextMaxWidthRatio` بالضبط في
/// `certificate_generic_template_renderer.dart` — لازمة هنا لتُطابق
/// معاينة القماشة عرض صندوق النص الحقيقي في ملف الـPDF الناتج تماماً
/// (المعاينة المباشرة الحقيقية للنصوص الحرة).
const double _customTextMaxWidthRatio = 0.6;

/// محرر مواضع حقول قالب أساسي واحد — الدفعة الثانية من "المرحلة الثانية"
/// (القسم ١٣ من تصميم الميزة): **سحب حرّ + إظهار/إخفاء + تخصيص الخط**
/// (النوع من ستة خطوط مُجمَّعة، اللون بحرية كاملة — يدوياً عبر لوحة
/// الألوان أو بقطّارة تلتقط لوناً مباشرة من صورة الشهادة نفسها — والحجم
/// النسبي)، بالإضافة إلى **عناصر نص حرّ** يضيفها المستخدم يدوياً (نص
/// مكتوب مباشرة + موضع حرّ بالسحب + نفس خيارات تخصيص الخط)، بلا استيراد
/// قوالب خارجية بعد (تُضاف لاحقاً).
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

  /// الحقل النصي المفتوح حالياً في لوحة تخصيص الخط — لا علاقة له بالختم
  /// (صورة، بلا خط ليُخصَّص).
  CertificateField? _selectedField;

  /// بكسلات صورة خلفية القالب (RGBA خام) — تُحمَّل مرة واحدة فقط عند أول
  /// استخدام لأداة "قطّارة اللون" (Format Painter المطلوبة)، وتُعاد
  /// استخدام النسخة المحمَّلة لكل التقاط لاحق طوال حياة هذه الشاشة.
  Uint8List? _bgPixels;
  int? _bgPixelWidth;
  int? _bgPixelHeight;
  bool _loadingEyedropper = false;

  /// الحقل الذي يُطلَب التقاط لون له حالياً من خلفية الشهادة — null يعني
  /// أن القطّارة غير نشطة والسحب/الضغط العادي على العناصر يعمل كما هو.
  CertificateField? _eyedropperTarget;

  /// عناصر النص الحرّ المضافة يدوياً فوق هذا القالب لهذا المسجد — كل
  /// عنصر مستقل تماماً (نص + موضع + خط/لون/حجم خاص به)، بلا أي علاقة
  /// بحقول الشهادة الثابتة (القسم ١٣، دفعة النصوص الحرة).
  late List<CertificateCustomTextElement> _customTexts;

  /// متحكّم نص Flutter واحد لكل عنصر نص حرّ (بمعرّفه) — يبقى حياً طوال
  /// عمر العنصر ليحافظ على موضع المؤشر أثناء الكتابة، ويُتخلّص منه فور
  /// حذف العنصر أو إغلاق الشاشة.
  final Map<String, TextEditingController> _customTextControllers = {};

  /// عنصر النص الحرّ المفتوح حالياً في لوحة تخصيصه — يُلغي أي حقل ثابت
  /// مفتوح، والعكس صحيح (لوحة واحدة مفتوحة كحد أقصى في كل لحظة).
  String? _selectedCustomTextId;

  /// عنصر النص الحرّ الذي تُطلَب قطّارة لون له حالياً — منفصل عن
  /// [_eyedropperTarget] (الحقول الثابتة) لأن النصوص الحرة لا تملك قيمة
  /// [CertificateField] مقابلة.
  String? _eyedropperCustomTextId;

  /// مناطق تغطية النص المطبوع ضمن صورة الخلفية نفسها — أداة "مسح نص من
  /// القالب" العامة (القسم ١٣). كل منطقة مستطيل مصمت مستقل تماماً (موضع
  /// + حجم + لون خاص به)، بلا أي علاقة بحقول الشهادة أو النصوص الحرة.
  late List<CertificateEraseRegion> _eraseRegions;

  /// منطقة التغطية المفتوحة حالياً في لوحة تخصيصها — بنفس منطق
  /// [_selectedField]/[_selectedCustomTextId] (لوحة واحدة كحد أقصى).
  String? _selectedEraseRegionId;

  /// منطقة التغطية التي تُطلَب قطّارة لون لها حالياً.
  String? _eyedropperEraseRegionId;

  /// يبني حالة البداية من التخطيط المخصَّص المحفوظ (إن وُجد)، وإلا من
  /// المواضع الثابتة في القالب الأساسي نفسها — بحيث تبدأ المشرفة دائماً
  /// من الشكل الحالي الفعلي للشهادة، لا من نقطة صفر.
  void _seedFrom(CertificateTemplateLayout? saved) {
    // الحقول التي أضافتها المشرفة يدوياً عبر "إضافة حقل" (زر متاح لكل قالب، أساسي أو مستورَد) تُحفَظ فقط داخل التخطيط المخصّص (`saved.fields`) ولا وجود لها إطلاقاً في `widget.template.fixedFields`
    // (ثابتة للقالب الأساسي، وفارغة دائماً للقالب المستورَد) - الاكتفاء بالتكرار على `fixedFields` وحدها كان يسقطها بصمت عند
    // إعادة فتح المحرر رغم بقائها محفوظة فعلياً وظهورها الصحيح عند توليد الشهادات.
    final allFields = <CertificateField>{
      for (final f in widget.template.fixedFields) f.field,
      for (final f in saved?.fields ?? const <CertificateFieldLayout>[])
        f.field,
    };
    _fieldLayouts = {
      for (final field in allFields)
        field: saved?.layoutFor(field) ?? _defaultLayoutFor(field),
    };
    final basePosition = widget.template.stampPosition;
    _stampLayout = basePosition == null
        ? null
        : (saved?.stamp ??
            CertificateStampLayout(dx: basePosition.dx, dy: basePosition.dy));

    _eraseRegions = List.of(saved?.eraseRegions ?? const []);

    _customTexts = List.of(saved?.customTexts ?? const []);
    for (final controller in _customTextControllers.values) {
      controller.dispose();
    }
    _customTextControllers.clear();
    for (final t in _customTexts) {
      _customTextControllers[t.id] = TextEditingController(text: t.text);
    }
  }

  /// الموضع الافتراضي لحقل لا يوجد له تخطيط محفوظ بعد - موضعه الثابت في القالب الأساسي إن وجداً، وموضع افتراضي معقول لحقل مضاف يدوياً بحت لا وجود له في القالب (حقول القالب المستورَد جميعها تدخل هنا).
  CertificateFieldLayout _defaultLayoutFor(CertificateField field) {
    final base = widget.template.fixedFields.firstWhere(
      (f) => f.field == field,
      orElse: () => defaultFieldPosition(field),
    );
    return CertificateFieldLayout(field: base.field, dx: base.dx, dy: base.dy);
  }

  @override
  void dispose() {
    for (final controller in _customTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addCustomText() {
    final id = const Uuid().v4();
    final element =
        CertificateCustomTextElement(id: id, text: 'نص جديد', dx: 0.5, dy: 0.5);
    setState(() {
      _customTexts = [..._customTexts, element];
      _customTextControllers[id] = TextEditingController(text: element.text);
      _selectedCustomTextId = id;
      _selectedField = null;
      _selectedEraseRegionId = null;
      _eyedropperTarget = null;
      _eyedropperCustomTextId = null;
      _eyedropperEraseRegionId = null;
    });
  }

  void _updateCustomText(
    String id,
    CertificateCustomTextElement Function(CertificateCustomTextElement current)
        update,
  ) {
    setState(() {
      _customTexts = [
        for (final t in _customTexts) t.id == id ? update(t) : t,
      ];
    });
  }

  void _removeCustomText(String id) {
    setState(() {
      _customTexts = _customTexts.where((t) => t.id != id).toList();
      _customTextControllers.remove(id)?.dispose();
      if (_selectedCustomTextId == id) _selectedCustomTextId = null;
      if (_eyedropperCustomTextId == id) _eyedropperCustomTextId = null;
    });
  }

  void _addEraseRegion() {
    final id = const Uuid().v4();
    final region = CertificateEraseRegion(id: id, dx: 0.5, dy: 0.5);
    setState(() {
      _eraseRegions = [..._eraseRegions, region];
      _selectedEraseRegionId = id;
      _selectedField = null;
      _selectedCustomTextId = null;
      _eyedropperTarget = null;
      _eyedropperCustomTextId = null;
      _eyedropperEraseRegionId = null;
    });
  }

  void _updateEraseRegion(
    String id,
    CertificateEraseRegion Function(CertificateEraseRegion current) update,
  ) {
    setState(() {
      _eraseRegions = [
        for (final r in _eraseRegions) r.id == id ? update(r) : r,
      ];
    });
  }

  void _removeEraseRegion(String id) {
    setState(() {
      _eraseRegions = _eraseRegions.where((r) => r.id != id).toList();
      if (_selectedEraseRegionId == id) _selectedEraseRegionId = null;
      if (_eyedropperEraseRegionId == id) _eyedropperEraseRegionId = null;
    });
  }

  void _resetField(CertificateField field) {
    final base = widget.template.fixedFields.firstWhere(
      (f) => f.field == field,
      orElse: () => defaultFieldPosition(field),
    );
    setState(() {
      _fieldLayouts[field] =
          CertificateFieldLayout(field: field, dx: base.dx, dy: base.dy);
    });
  }

  /// تفتح قائمة (Bottom Sheet) بكل الحقول غير المُضافة بعد لهذا القالب —
  /// القسم ٦ من تصميم الميزة (استيراد قوالب): قالب مستورَد يبدأ بلا أي
  /// حقل إطلاقاً (`fixedFields` فارغة)، وهذه هي الطريقة الوحيدة لبناء
  /// حقوله واحداً تلو الآخر. متاحة أيضاً لأي قالب أساسي عادي (لإضافة حقل
  /// إضافي غير معرَّف له مسبقاً)، بلا أي قيد.
  void _openAddFieldSheet() {
    final available = CertificateField.values
        .where((f) => !_fieldLayouts.containsKey(f))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كل الحقول مُضافة بالفعل')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          // قائمة الحقول الممكنة (حتى تسعة) قد تتجاوز ارتفاع الشاشة على الشيت الرأسية،
          // فيستلزم تقييد ارتفاع الشيت + تمرير داخلي بدل امتداد المحتوى خارج الشاشة.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('اختاري حقلاً لإضافته',
                      style: TextStyle(
                          fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final field in available)
                      ListTile(
                        title: Text(_fieldLabel(field),
                            style: const TextStyle(fontFamily: 'Tajawal')),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _addFixedField(field);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// تضيف حقلاً جديداً بموضع افتراضي معقول (منتصف الشهادة تقريباً — نفس
  /// [defaultFieldPosition] المستخدَمة أيضاً في مولّد الـPDF لهذا الحقل
  /// تحديداً إن لم يكن معرَّفاً في `fixedFields`)، ثم تفتح لوحة تخصيصه
  /// مباشرة (نفس سلوك [_addCustomText]/[_addEraseRegion] عند الإضافة).
  void _addFixedField(CertificateField field) {
    final base = defaultFieldPosition(field);
    setState(() {
      _fieldLayouts[field] =
          CertificateFieldLayout(field: field, dx: base.dx, dy: base.dy);
      _selectedField = field;
      _selectedCustomTextId = null;
      _selectedEraseRegionId = null;
      _eyedropperTarget = null;
      _eyedropperCustomTextId = null;
      _eyedropperEraseRegionId = null;
    });
  }

  /// تحذف حقلاً أضافته المشرفة يدوياً عبر [_addFixedField] — لا تُستخدَم
  /// إطلاقاً لحقل أساسي معرَّف في `fixedFields` (زر الحذف لا يظهر أصلاً
  /// لهذه الحالة في [_buildTextFieldRow]، فلا حاجة لأي حماية إضافية هنا).
  void _removeFixedField(CertificateField field) {
    setState(() {
      _fieldLayouts.remove(field);
      if (_selectedField == field) _selectedField = null;
      if (_eyedropperTarget == field) _eyedropperTarget = null;
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
    setState(() {
      _seedFrom(null);
      _selectedField = null;
      _selectedCustomTextId = null;
      _selectedEraseRegionId = null;
      _eyedropperTarget = null;
      _eyedropperCustomTextId = null;
      _eyedropperEraseRegionId = null;
    });
  }

  void _updateField(
    CertificateField field,
    CertificateFieldLayout Function(CertificateFieldLayout current) update,
  ) {
    setState(() {
      _fieldLayouts[field] = update(_fieldLayouts[field]!);
    });
  }

  /// حوار اختيار لون حرّ واحد مشترك بين لوحتي تخصيص الخط (الحقول الثابتة
  /// والنصوص الحرة على حدّ سواء) — بلا أي تكرار لبنية الحوار نفسها.
  Future<Color?> _pickColorDialog(Color initial) {
    Color picked = initial;
    return showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اختاري لوناً للنص',
            style: TextStyle(fontFamily: 'Tajawal')),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [ColorLabelType.hex],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(picked),
            child: const Text('اختيار', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  /// تحمِّل صورة خلفية الشهادة مرة واحدة فقط (إن لم تكن محمَّلة أصلاً) —
  /// خطوة مشتركة بين قطّارة الحقول الثابتة وقطّارة النصوص الحرة على حدّ
  /// سواء. تُرجِع `true` عند النجاح فقط.
  Future<bool> _ensureBgPixelsLoaded() async {
    if (_bgPixels != null) return true;
    setState(() => _loadingEyedropper = true);
    try {
      // قالب مستورَد: يُقرأ من مساره المحلي على القرص؛ قالب أساسي مُجمَّع
      // كـAsset: كما كان دائماً عبر rootBundle.
      final localPath = widget.template.localBackgroundImagePath;
      final bgBytes = localPath != null
          ? await File(localPath).readAsBytes()
          : (await rootBundle.load(widget.template.backgroundImageAsset))
              .buffer
              .asUint8List();
      final codec = await ui.instantiateImageCodec(bgBytes);
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw Exception('تعذّرت قراءة بيانات صورة الشهادة');
      }
      _bgPixels = byteData.buffer.asUint8List();
      _bgPixelWidth = frame.image.width;
      _bgPixelHeight = frame.image.height;
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _loadingEyedropper = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('تعذّر تحميل صورة الشهادة لالتقاط اللون: ${e.toString()}')),
      );
      return false;
    }
  }

  /// تفعيل "قطّارة اللون" (Format Painter) لحقل ثابت: تنتظر ضغطة المشرفة
  /// على أي نقطة من الشهادة نفسها لالتقاط لونها الفعلي وتطبيقه مباشرة على
  /// [field] — بلا حاجة لمعرفة قيمة اللون يدوياً أو مطابقتها بالعين.
  Future<void> _startEyedropper(CertificateField field) async {
    final loaded = await _ensureBgPixelsLoaded();
    if (!loaded || !mounted) return;
    setState(() {
      _loadingEyedropper = false;
      _eyedropperTarget = field;
      _eyedropperCustomTextId = null;
      _eyedropperEraseRegionId = null;
    });
  }

  /// نفس فكرة [_startEyedropper] تماماً، لكن لعنصر نص حرّ بمعرّفه بدل حقل
  /// ثابت.
  Future<void> _startEyedropperForCustomText(String id) async {
    final loaded = await _ensureBgPixelsLoaded();
    if (!loaded || !mounted) return;
    setState(() {
      _loadingEyedropper = false;
      _eyedropperCustomTextId = id;
      _eyedropperTarget = null;
      _eyedropperEraseRegionId = null;
    });
  }

  /// نفس فكرة [_startEyedropper] تماماً، لكن لمنطقة تغطية بمعرّفها — تُستخدَم
  /// عادة لالتقاط لون الخلفية النظيفة المجاورة للنص المراد إخفاؤه.
  Future<void> _startEyedropperForEraseRegion(String id) async {
    final loaded = await _ensureBgPixelsLoaded();
    if (!loaded || !mounted) return;
    setState(() {
      _loadingEyedropper = false;
      _eyedropperEraseRegionId = id;
      _eyedropperTarget = null;
      _eyedropperCustomTextId = null;
    });
  }

  void _cancelEyedropper() => setState(() {
        _eyedropperTarget = null;
        _eyedropperCustomTextId = null;
        _eyedropperEraseRegionId = null;
      });

  /// تحوِّل نقطة الضغط على مساحة عرض الشهادة (بأبعاد [boxWidth]×[boxHeight])
  /// إلى بكسل مقابل في صورة الخلفية الفعلية (BoxFit.fill يجعل التحويل
  /// نسبياً بسيطاً بلا حساب حواف/تمدد)، وتقرأ لونه مباشرة من [_bgPixels]،
  /// وتُطبِّقه على أي كان الهدف النشط حالياً — حقل ثابت أو نص حرّ.
  void _pickColorAt(Offset localPosition, double boxWidth, double boxHeight) {
    final field = _eyedropperTarget;
    final customTextId = _eyedropperCustomTextId;
    final eraseRegionId = _eyedropperEraseRegionId;
    if ((field == null && customTextId == null && eraseRegionId == null) ||
        _bgPixels == null) {
      return;
    }
    final px = ((localPosition.dx / boxWidth) * _bgPixelWidth!)
        .round()
        .clamp(0, _bgPixelWidth! - 1);
    final py = ((localPosition.dy / boxHeight) * _bgPixelHeight!)
        .round()
        .clamp(0, _bgPixelHeight! - 1);
    final index = (py * _bgPixelWidth! + px) * 4;
    final color = Color.fromARGB(
      255,
      _bgPixels![index],
      _bgPixels![index + 1],
      _bgPixels![index + 2],
    );
    if (field != null) {
      _updateField(field, (c) => c.copyWith(fontColorValue: color.value));
    } else if (customTextId != null) {
      _updateCustomText(
          customTextId, (c) => c.copyWith(fontColorValue: color.value));
    } else if (eraseRegionId != null) {
      _updateEraseRegion(
          eraseRegionId, (c) => c.copyWith(colorValue: color.value));
    }
    setState(() {
      _eyedropperTarget = null;
      _eyedropperCustomTextId = null;
      _eyedropperEraseRegionId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            const Text('تم التقاط اللون وتطبيقه',
                style: TextStyle(fontFamily: 'Tajawal')),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
        eraseRegions: _eraseRegions,
        customTexts: _customTexts,
        updatedAt: DateTime.now(),
        updatedByUid: user.uid,
      );
      await ref.read(certificateTemplateLayoutRepositoryProvider).save(layout);
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

  /// شريحة سحب رمزية بسيطة (نفس الشكل والحجم دائماً) — تُستخدَم الآن
  /// للختم فقط (صورة، بلا خط ليُخصَّص أو معاينة WYSIWYG له)؛ الحقول
  /// الثابتة (اسم الدار/المسجد/المستفيدة...) تستخدم
  /// [_buildFixedFieldPreviewBox] بدلاً منها، وعناصر النص الحرّ تستخدم
  /// [_buildCustomTextPreviewBox].
  Widget _buildDragChip({
    required double dx,
    required double dy,
    required double width,
    required double height,
    required String label,
    required void Function(Offset delta) onDrag,
    VoidCallback? onTap,
    bool selected = false,
    IconData? icon,
  }) {
    const chipWidth = 96.0;
    const chipHeight = 34.0;
    return Positioned(
      left: (dx * width) - (chipWidth / 2),
      top: (dy * height) - (chipHeight / 2),
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: chipWidth,
          height: chipHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.88),
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: AppTheme.goldAccent, width: 2)
                : null,
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

  /// مستطيل منطقة تغطية واحدة على القماشة — يُرسَم بحجمه ولونه الحقيقيين
  /// (لا شريحة رمزية كـ[_buildDragChip]) حتى تُطابق المعاينة هنا الناتج
  /// النهائي في PDF تماماً، قابل للسحب لأي موضع وللتحديد بالضغط لفتح لوحة
  /// تعديل العرض/الارتفاع/اللون أسفل الشاشة.
  Widget _buildEraseRegionBox({
    required CertificateEraseRegion region,
    required double width,
    required double height,
  }) {
    final boxWidth = region.width * width;
    final boxHeight = region.height * height;
    final isSelected = _selectedEraseRegionId == region.id;
    return Positioned(
      left: (region.dx * width) - (boxWidth / 2),
      top: (region.dy * height) - (boxHeight / 2),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedEraseRegionId = isSelected ? null : region.id;
          _selectedField = null;
          _selectedCustomTextId = null;
          _eyedropperTarget = null;
          _eyedropperCustomTextId = null;
          _eyedropperEraseRegionId = null;
        }),
        onPanUpdate: (details) => setState(() {
          final dx =
              (region.dx + details.delta.dx / width).clamp(0.0, 1.0);
          final dy =
              (region.dy + details.delta.dy / height).clamp(0.0, 1.0);
          _eraseRegions = [
            for (final r in _eraseRegions)
              r.id == region.id ? r.copyWith(dx: dx, dy: dy) : r,
          ];
        }),
        child: Container(
          width: boxWidth,
          height: boxHeight,
          decoration: BoxDecoration(
            color: Color(region.colorValue),
            border: Border.all(
              color: isSelected ? AppTheme.goldAccent : Colors.black26,
              width: isSelected ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
  }

  /// معاينة مباشرة حقيقية (WYSIWYG) لحقل ثابت واحد (اسم الدار/المسجد/
  /// المستفيدة...) — بنفس فكرة [_buildCustomTextPreviewBox] تماماً، لكن
  /// بمصدرين للبيانات معاً: [basePosition] (حجم الخط الأساسي، نسبة أقصى
  /// عرض، لون ووزن افتراضيان — من القالب الأساسي الثابت في الكود) و
  /// [layout] (تخصيص هذا المسجد تحديداً: الموضع الفعلي، نسبة التكبير/
  /// التصغير، الخط، اللون).
  ///
  /// النص المعروض هو تسمية الحقل نفسها (`_fieldLabel`) كنص عيّنة فقط —
  /// هذه الشاشة عامة لكل مستفيدة مستقبلية، فلا تعرف اسماً حقيقياً بعد؛
  /// هذا النص للمعاينة البصرية حصراً، لا يُحفظ ولا يظهر في أي شهادة فعلية.
  ///
  /// بخلاف النص الحرّ (يلتفّ على عدة أسطر عمداً بعد إصلاح خلل الحجم)،
  /// الحقول الثابتة سطر واحد دائماً في المولّد الفعلي
  /// (`certificate_generic_template_renderer.dart`: `maxLines: 1` +
  /// `FittedBox(scaleDown)` كشبكة أمان تصغير فقط) — نفس القيد هنا حرفياً،
  /// فارتفاع الصندوق معروف مسبقاً (لا حاجة لحيلة `Align` بارتفاع كامل
  /// المستخدَمة في معاينة النص الحرّ لحساب ارتفاع متغيّر).
  ///
  /// محاذاة اليمين خاصة بـ"اسم الدار"/"اسم المسجد" (يقعان بجانب تسميتَي
  /// "مدرسة"/"بجامع" المطبوعتين في صورة الخلفية نفسها) تُطابق تماماً
  /// `needsRightAlign` في المولّد؛ ووزن الخط العريض يُطلَب فقط إن كان هذا
  /// الخط المختار يملك فعلاً نسخة عريضة مُجمَّعة (`CertificateFontCatalog.
  /// hasBoldAsset`) تماماً كسلوك الارتداد في المولّد، فلا يظهر هنا وزن
  /// عريض مزيَّف (Faux Bold من فلاتر) لخط لا يملكه فعلياً في الـPDF.
  Widget _buildFixedFieldPreviewBox({
    required CertificateFieldLayout layout,
    required CertificateFieldPosition basePosition,
    required double width,
    required double height,
    required double fontScaleFactor,
  }) {
    final boxWidth = basePosition.maxWidthRatio * width;
    final canvasFontSize =
        basePosition.fontSize * layout.fontScale * fontScaleFactor;
    final boxHeight = canvasFontSize * 1.8;
    final isSelected = _selectedField == layout.field;
    final needsRightAlign = layout.field == CertificateField.schoolName ||
        layout.field == CertificateField.mosqueName;
    final effectiveBold = basePosition.bold &&
        CertificateFontCatalog.hasBoldAsset(layout.fontFamily);
    final color = layout.fontColorValue != null
        ? Color(layout.fontColorValue!)
        : _pdfColorToFlutter(basePosition.color);

    return Positioned(
      left: (layout.dx * width) - (boxWidth / 2),
      top: (layout.dy * height) - (boxHeight / 2),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedField = isSelected ? null : layout.field;
          _selectedCustomTextId = null;
          _selectedEraseRegionId = null;
          _eyedropperTarget = null;
          _eyedropperCustomTextId = null;
          _eyedropperEraseRegionId = null;
        }),
        onPanUpdate: (details) => setState(() {
          final dx = (layout.dx + details.delta.dx / width).clamp(0.0, 1.0);
          final dy = (layout.dy + details.delta.dy / height).clamp(0.0, 1.0);
          _fieldLayouts[layout.field] = layout.copyWith(dx: dx, dy: dy);
        }),
        child: Container(
          width: boxWidth,
          height: boxHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppTheme.goldAccent : Colors.black26,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment:
              needsRightAlign ? Alignment.centerRight : Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _fieldLabel(layout.field),
              textDirection: TextDirection.rtl,
              maxLines: 1,
              style: TextStyle(
                fontFamily: layout.fontFamily.flutterFamilyName,
                fontSize: canvasFontSize,
                fontWeight:
                    effectiveBold ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// معاينة مباشرة حقيقية (WYSIWYG) لعنصر نص حرّ واحد على القماشة — بخلاف
  /// [_buildDragChip] المستخدَم للختم فقط الآن (شريحة رمزية ثابتة
  /// الحجم بخط Tajawal 11 دائماً، بلا أي علاقة بالخط/الحجم/اللون الفعلي)،
  /// هذا العنصر يرسم النص الحقيقي: نفس نوع الخط ولونه المختاران فعلاً،
  /// وحجم خط محوَّل من نقاط الـPDF المطلقة إلى بكسلات القماشة بنفس نسبة
  /// تحويل الموضع (dx/dy) — عرض القماشة ÷ عرض صفحة الـPDF الفعلي — حتى
  /// تبقى النسبة بين حجم الخط وعرض الشهادة مطابقة لما سيصدر فعلاً.
  ///
  /// الالتفاف على عدة أسطر هنا حقيقي بالكامل (تخطيط Flutter الفعلي للنص
  /// ضمن عرض صندوق ثابت عبر `Align` داخل `Positioned` بارتفاع كامل)، لا
  /// تقدير تقريبي كما في مولّد الـPDF (`_estimateCustomTextBoxHeight`) —
  /// فلا حاجة له هنا أصلاً بما أن Flutter يحسب الارتفاع الحقيقي بنفسه.
  Widget _buildCustomTextPreviewBox({
    required CertificateCustomTextElement t,
    required double width,
    required double height,
    required double fontScaleFactor,
  }) {
    final boxWidth = _customTextMaxWidthRatio * width;
    final isSelected = _selectedCustomTextId == t.id;
    final canvasFontSize = t.fontSize * fontScaleFactor;
    return Positioned(
      left: (t.dx * width) - (boxWidth / 2),
      top: 0,
      bottom: 0,
      width: boxWidth,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedCustomTextId = isSelected ? null : t.id;
          _selectedField = null;
          _selectedEraseRegionId = null;
          _eyedropperTarget = null;
          _eyedropperCustomTextId = null;
          _eyedropperEraseRegionId = null;
        }),
        onPanUpdate: (details) => setState(() {
          final dx = (t.dx + details.delta.dx / width).clamp(0.0, 1.0);
          final dy = (t.dy + details.delta.dy / height).clamp(0.0, 1.0);
          _customTexts = [
            for (final e in _customTexts)
              e.id == t.id ? e.copyWith(dx: dx, dy: dy) : e,
          ];
        }),
        child: Align(
          alignment: Alignment(0, (t.dy * 2) - 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppTheme.goldAccent : Colors.black26,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              t.text.isEmpty ? 'نص فارغ' : t.text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: t.fontFamily.flutterFamilyName,
                fontSize: canvasFontSize,
                color: t.fontColorValue != null
                    ? Color(t.fontColorValue!)
                    : Colors.black,
              ),
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
            tooltip: 'إضافة حقل',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: _isSaving ? null : _openAddFieldSheet,
          ),
          IconButton(
            tooltip: 'إضافة منطقة تغطية (مسح نص من القالب)',
            icon: const Icon(Icons.format_color_fill_rounded),
            onPressed: _isSaving ? null : _addEraseRegion,
          ),
          IconButton(
            tooltip: 'إضافة نص',
            icon: const Icon(Icons.add_box_rounded),
            onPressed: _isSaving ? null : _addCustomText,
          ),
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
                'اسحبي أي عنصر لتغيير موضعه، واضغطي على حقل من القائمة لتخصيص خطه',
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
                    // نفس أبعاد صفحة الـPDF الفعلية تماماً
                    // (`certificate_pdf_generator.dart`: أفقي = A4 landscape،
                    // فعرضها هو ارتفاع A4 القياسي) — تحويل حجم الخط المطلق
                    // بالنقاط إلى بكسلات القماشة بنفس نسبة تحويل الموضع
                    // (dx * width تماماً كـdx * pageWidth في المولّد)، فتبقى
                    // نسبة حجم الخط إلى عرض الشهادة مطابقة لما سيصدر فعلاً.
                    final fontScaleFactor = width / PdfPageFormat.a4.height;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: widget.template.localBackgroundImagePath !=
                                  null
                              ? Image.file(
                                  File(widget
                                      .template.localBackgroundImagePath!),
                                  fit: BoxFit.fill,
                                )
                              : Image.asset(
                                  widget.template.backgroundImageAsset,
                                  fit: BoxFit.fill,
                                ),
                        ),
                        for (final region in _eraseRegions)
                          _buildEraseRegionBox(
                            region: region,
                            width: width,
                            height: height,
                          ),
                        for (final layout in _fieldLayouts.values)
                          if (layout.visible)
                            _buildFixedFieldPreviewBox(
                              layout: layout,
                              basePosition: widget.template.fixedFields
                                  .firstWhere(
                                (f) => f.field == layout.field,
                                orElse: () =>
                                    defaultFieldPosition(layout.field),
                              ),
                              width: width,
                              height: height,
                              fontScaleFactor: fontScaleFactor,
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
                        for (final t in _customTexts)
                          _buildCustomTextPreviewBox(
                            t: t,
                            width: width,
                            height: height,
                            fontScaleFactor: fontScaleFactor,
                          ),
                        if (_eyedropperTarget != null ||
                            _eyedropperCustomTextId != null ||
                            _eyedropperEraseRegionId != null) ...[
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) => _pickColorAt(
                                  details.localPosition, width, height),
                              child: Container(
                                color: Colors.black.withOpacity(0.06),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4),
                                      ],
                                    ),
                                    child: const Text(
                                      'اضغطي على أي نقطة من الشهادة لالتقاط لونها',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontFamily: 'Tajawal', fontSize: 11),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: _cancelEyedropper,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4),
                                      ],
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        size: 18, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                  _buildTextFieldRow(layout),
                if (_stampLayout != null)
                  _buildSimpleRow(
                    label: 'الختم',
                    visible: _stampLayout!.visible,
                    onVisibleChanged: (value) => setState(() {
                      _stampLayout = _stampLayout!.copyWith(visible: value);
                    }),
                    onReset: _resetStamp,
                  ),
                if (_eraseRegions.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'مناطق تغطية نص القالب',
                        style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                  for (final r in _eraseRegions) _buildEraseRegionRow(r),
                ],
                if (_customTexts.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'نصوص حرة مضافة',
                        style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                  for (final t in _customTexts) _buildCustomTextRow(t),
                ],
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

  /// صف حقل نصي واحد: عنوان + تبديل الإظهار كما هو، بالإضافة إلى لوحة
  /// تخصيص خط قابلة للطي (تظهر بالضغط على الصف) — الخط، اللون، والحجم.
  ///
  /// حقل أساسي معرَّف في `fixedFields` نفسها: زر "إعادة ضبط" (يرتدّ لموضعه
  /// الأصلي في القالب). حقل أضافته المشرفة يدوياً عبر [_addFixedField] —
  /// لا "أصل" له ليُعاد إليه أصلاً — فيظهر زر "حذف" بدلاً منه (نفس منطق
  /// الحذف في عناصر النص الحرّ ومناطق التغطية).
  Widget _buildTextFieldRow(CertificateFieldLayout layout) {
    final isSelected = _selectedField == layout.field;
    final isBaseField =
        widget.template.fixedFields.any((f) => f.field == layout.field);
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            _selectedField = isSelected ? null : layout.field;
            _selectedCustomTextId = null;
            _selectedEraseRegionId = null;
            _eyedropperTarget = null;
            _eyedropperCustomTextId = null;
            _eyedropperEraseRegionId = null;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                if (isBaseField)
                  IconButton(
                    tooltip: 'إعادة ضبط',
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    color: Colors.grey.shade400,
                    onPressed: () => _resetField(layout.field),
                  )
                else
                  IconButton(
                    tooltip: 'حذف الحقل',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: Colors.red.shade300,
                    onPressed: () => _removeFixedField(layout.field),
                  ),
                Expanded(
                  child: Text(
                    _fieldLabel(layout.field),
                    style: TextStyle(
                      fontFamily: layout.fontFamily.flutterFamilyName,
                      fontSize: 14,
                      color: layout.fontColorValue != null
                          ? Color(layout.fontColorValue!)
                          : null,
                    ),
                  ),
                ),
                Switch(
                  value: layout.visible,
                  onChanged: (value) =>
                      _updateField(layout.field, (c) => c.copyWith(visible: value)),
                ),
              ],
            ),
          ),
        ),
        if (isSelected) _buildFontPanel(layout),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildFontPanel(CertificateFieldLayout layout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fontFamilyDropdownRow(
            value: layout.fontFamily,
            onChanged: (value) =>
                _updateField(layout.field, (c) => c.copyWith(fontFamily: value)),
          ),
          const SizedBox(height: 8),
          _fontSizeStepperRow(
            valueLabel: '${(layout.fontScale * 100).round()}%',
            onDecrement: () => _updateField(
              layout.field,
              (c) => c.copyWith(
                  fontScale: (c.fontScale - _fontScaleStep)
                      .clamp(_minFontScale, _maxFontScale)),
            ),
            onIncrement: () => _updateField(
              layout.field,
              (c) => c.copyWith(
                  fontScale: (c.fontScale + _fontScaleStep)
                      .clamp(_minFontScale, _maxFontScale)),
            ),
          ),
          const SizedBox(height: 8),
          _colorRow(
            currentColorValue: layout.fontColorValue,
            onColorSelected: (value) =>
                _updateField(layout.field, (c) => c.copyWith(fontColorValue: value)),
            onClear: () =>
                _updateField(layout.field, (c) => c.copyWith(clearFontColor: true)),
            onEyedropperTap: () => _startEyedropper(layout.field),
          ),
        ],
      ),
    );
  }

  /// نفس لوحة [_buildFontPanel] بالضبط (نفس خيارات الخط/اللون)، لكن لعنصر
  /// نص حرّ: الفرق الوحيد أن الحجم مطلق بالنقاط لا نسبة تكبير/تصغير، إذ
  /// لا يوجد حجم أساسي يُقاس نسبة إليه.
  Widget _buildCustomTextFontPanel(CertificateCustomTextElement t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fontFamilyDropdownRow(
            value: t.fontFamily,
            onChanged: (value) =>
                _updateCustomText(t.id, (c) => c.copyWith(fontFamily: value)),
          ),
          const SizedBox(height: 8),
          _fontSizeStepperRow(
            valueLabel: '${t.fontSize.round()}',
            onDecrement: () => _updateCustomText(
              t.id,
              (c) => c.copyWith(
                  fontSize: (c.fontSize - _customFontSizeStep)
                      .clamp(_minCustomFontSize, _maxCustomFontSize)),
            ),
            onIncrement: () => _updateCustomText(
              t.id,
              (c) => c.copyWith(
                  fontSize: (c.fontSize + _customFontSizeStep)
                      .clamp(_minCustomFontSize, _maxCustomFontSize)),
            ),
          ),
          const SizedBox(height: 8),
          _colorRow(
            currentColorValue: t.fontColorValue,
            onColorSelected: (value) =>
                _updateCustomText(t.id, (c) => c.copyWith(fontColorValue: value)),
            onClear: () => _updateCustomText(
                t.id, (c) => c.copyWith(clearFontColor: true)),
            onEyedropperTap: () => _startEyedropperForCustomText(t.id),
          ),
        ],
      ),
    );
  }

  /// صف اختيار نوع الخط — مشترك بين لوحتي الحقول الثابتة والنصوص الحرة.
  Widget _fontFamilyDropdownRow({
    required CertificateFontFamily value,
    required ValueChanged<CertificateFontFamily> onChanged,
  }) {
    return Row(
      children: [
        const SizedBox(
          width: 52,
          child: Text('الخط',
              style:
                  TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: DropdownButton<CertificateFontFamily>(
            isExpanded: true,
            value: value,
            underline: const SizedBox(),
            items: CertificateFontFamily.values
                .map((family) => DropdownMenuItem(
                      value: family,
                      child: Text(
                        family.displayName,
                        style: TextStyle(
                            fontFamily: family.flutterFamilyName, fontSize: 14),
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              onChanged(value);
            },
          ),
        ),
      ],
    );
  }

  /// صف تكبير/تصغير الحجم — [valueLabel] هو النص المعروض فقط (نسبة مئوية
  /// للحقول الثابتة، أو رقم نقاط مطلق للنصوص الحرة)؛ منطق التغيير نفسه
  /// يبقى عند المستدعي (حدود مختلفة لكل حالة).
  Widget _fontSizeStepperRow({
    required String valueLabel,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    String label = 'الحجم',
  }) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
        ),
        IconButton(
          tooltip: 'تصغير',
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
          color: AppTheme.primaryGreen,
          onPressed: onDecrement,
        ),
        SizedBox(
          width: 48,
          child: Text(
            valueLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'تكبير',
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          color: AppTheme.primaryGreen,
          onPressed: onIncrement,
        ),
      ],
    );
  }

  /// صف اختيار اللون الكامل (ثلاثة ألوان جاهزة + لوحة ألوان حرة + قطّارة)
  /// — مشترك بين لوحتي الحقول الثابتة والنصوص الحرة، بمعزل تام عن نوع
  /// النموذج المستدعي عبر ردود الأفعال (callbacks) فقط.
  Widget _colorRow({
    required int? currentColorValue,
    required ValueChanged<int> onColorSelected,
    required VoidCallback onClear,
    required VoidCallback onEyedropperTap,
  }) {
    return Row(
      children: [
        const SizedBox(
          width: 52,
          child: Text('اللون',
              style:
                  TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
        ),
        _colorSwatch(
          color: AppTheme.goldAccent,
          selected: currentColorValue == AppTheme.goldAccent.value,
          onTap: () => onColorSelected(AppTheme.goldAccent.value),
        ),
        const SizedBox(width: 8),
        _colorSwatch(
          color: AppTheme.primaryGreen,
          selected: currentColorValue == AppTheme.primaryGreen.value,
          onTap: () => onColorSelected(AppTheme.primaryGreen.value),
        ),
        const SizedBox(width: 8),
        _colorSwatch(
          color: Colors.black,
          selected: currentColorValue == Colors.black.value,
          onTap: () => onColorSelected(Colors.black.value),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final picked = await _pickColorDialog(
                currentColorValue != null ? Color(currentColorValue) : Colors.black);
            if (picked != null) onColorSelected(picked.value);
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [
                Colors.red,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ]),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'التقطي لوناً من الشهادة نفسها',
          child: GestureDetector(
            onTap: _loadingEyedropper ? null : onEyedropperTap,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
              ),
              child: _loadingEyedropper
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.colorize, size: 15, color: AppTheme.primaryGreen),
            ),
          ),
        ),
        const Spacer(),
        if (currentColorValue != null)
          TextButton(
            onPressed: onClear,
            child: const Text('افتراضي',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
          ),
      ],
    );
  }

  Widget _colorSwatch({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.goldAccent : Colors.white,
            width: selected ? 2.5 : 2,
          ),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
        ),
      ),
    );
  }

  /// صف عنصر نص حرّ واحد في القائمة: حذف + حقل نص قابل للتحرير مباشرة
  /// (تُحدَّث القيمة المعروضة على شريحة القماشة فوراً) + طيّ لوحة تخصيص
  /// الخط. لا يوجد زرّ "إعادة ضبط" هنا (بخلاف الحقول الثابتة) لأن عنصر
  /// النص الحرّ ليس له أي موضع/شكل أساسي يُرتدّ إليه.
  Widget _buildCustomTextRow(CertificateCustomTextElement t) {
    final isSelected = _selectedCustomTextId == t.id;
    final controller = _customTextControllers[t.id]!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: Colors.red.shade300,
                onPressed: () => _removeCustomText(t.id),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textDirection: TextDirection.rtl,
                  // متعدد الأسطر: تسمح بالضغط على Enter لإنزال سطر جديد
                  // يدوياً بدل إغلاق لوحة المفاتيح — بالضبط كما سيُرسَم في
                  // الشهادة النهائية (بلا فرض سطر واحد كما كان سابقاً).
                  maxLines: null,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    fontFamily: t.fontFamily.flutterFamilyName,
                    fontSize: 14,
                    color: t.fontColorValue != null
                        ? Color(t.fontColorValue!)
                        : null,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'اكتبي النص هنا (Enter لسطر جديد)',
                  ),
                  onChanged: (value) =>
                      _updateCustomText(t.id, (c) => c.copyWith(text: value)),
                ),
              ),
              IconButton(
                icon: Icon(
                  isSelected
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                onPressed: () => setState(() {
                  _selectedCustomTextId = isSelected ? null : t.id;
                  _selectedField = null;
                  _selectedEraseRegionId = null;
                  _eyedropperTarget = null;
                  _eyedropperCustomTextId = null;
                  _eyedropperEraseRegionId = null;
                }),
              ),
            ],
          ),
        ),
        if (isSelected) _buildCustomTextFontPanel(t),
        const Divider(height: 1),
      ],
    );
  }

  /// صف منطقة تغطية واحدة في القائمة: حذف + تسمية مرقّمة + طيّ لوحة تعديل
  /// العرض/الارتفاع/اللون. لا يوجد حقل نص ولا مفتاح إظهار/إخفاء هنا — منطقة
  /// التغطية مجرد مستطيل مصمت، وحذفها هو ما يُعيد إظهار النص الأصلي خلفها.
  Widget _buildEraseRegionRow(CertificateEraseRegion region) {
    final isSelected = _selectedEraseRegionId == region.id;
    final index = _eraseRegions.indexOf(region) + 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: Colors.red.shade300,
                onPressed: () => _removeEraseRegion(region.id),
              ),
              Expanded(
                child: Text('منطقة تغطية $index',
                    style:
                        const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
              ),
              IconButton(
                icon: Icon(
                  isSelected
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                onPressed: () => setState(() {
                  _selectedEraseRegionId = isSelected ? null : region.id;
                  _selectedField = null;
                  _selectedCustomTextId = null;
                  _eyedropperTarget = null;
                  _eyedropperCustomTextId = null;
                  _eyedropperEraseRegionId = null;
                }),
              ),
            ],
          ),
        ),
        if (isSelected) _buildEraseRegionPanel(region),
        const Divider(height: 1),
      ],
    );
  }

  /// لوحة تعديل منطقة تغطية واحدة: عرض/ارتفاع (بأزرار −/+ نسبة من أبعاد
  /// الشهادة) + نفس صف اللون المشترك المستخدَم للخط في اللوحات الأخرى —
  /// عادة عبر القطّارة لالتقاط لون الخلفية النظيفة المجاورة للنص بدقة.
  Widget _buildEraseRegionPanel(CertificateEraseRegion region) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fontSizeStepperRow(
            label: 'العرض',
            valueLabel: '${(region.width * 100).round()}%',
            onDecrement: () => _updateEraseRegion(
              region.id,
              (c) => c.copyWith(
                  width: (c.width - _eraseSizeStep)
                      .clamp(_minEraseSize, _maxEraseSize)),
            ),
            onIncrement: () => _updateEraseRegion(
              region.id,
              (c) => c.copyWith(
                  width: (c.width + _eraseSizeStep)
                      .clamp(_minEraseSize, _maxEraseSize)),
            ),
          ),
          const SizedBox(height: 8),
          _fontSizeStepperRow(
            label: 'الارتفاع',
            valueLabel: '${(region.height * 100).round()}%',
            onDecrement: () => _updateEraseRegion(
              region.id,
              (c) => c.copyWith(
                  height: (c.height - _eraseSizeStep)
                      .clamp(_minEraseSize, _maxEraseSize)),
            ),
            onIncrement: () => _updateEraseRegion(
              region.id,
              (c) => c.copyWith(
                  height: (c.height + _eraseSizeStep)
                      .clamp(_minEraseSize, _maxEraseSize)),
            ),
          ),
          const SizedBox(height: 8),
          _colorRow(
            currentColorValue: region.colorValue,
            onColorSelected: (value) => _updateEraseRegion(
                region.id, (c) => c.copyWith(colorValue: value)),
            onClear: () => _updateEraseRegion(
                region.id, (c) => c.copyWith(colorValue: 0xFFFFFFFF)),
            onEyedropperTap: () => _startEyedropperForEraseRegion(region.id),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleRow({
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
