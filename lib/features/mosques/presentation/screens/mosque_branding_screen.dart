import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mosque.dart';
import '../providers/mosque_provider.dart';

/// الحد الأقصى لحجم ملف الصورة (بالبايت) قبل ترميزه Base64 — يُطبَّق على
/// ختم مشرفة الحلقات وعلى شعار ترويسة التقرير كلاهما، لأن كليهما يُخزَّن
/// كحقل Base64 داخل مستند المسجد نفسه في Firestore (حده الأقصى 1 ميجابايت،
/// وBase64 يزيد الحجم ~33%، لذا نُبقي كل ملف أصلي صغيراً بما يكفي).
const int _maxStampFileBytes = 350 * 1024; // 350 كيلوبايت

/// شاشة إدارة "بيانات المسجد": ختم مشرفة الحلقات + اسمها.
/// تُفتح من "إدارة المساجد" (للمشرف العام) ومن لوحة مشرفة المسجد (لمسجدها فقط).
class MosqueBrandingScreen extends ConsumerStatefulWidget {
  final Mosque mosque;

  const MosqueBrandingScreen({super.key, required this.mosque});

  @override
  ConsumerState<MosqueBrandingScreen> createState() =>
      _MosqueBrandingScreenState();
}

class _MosqueBrandingScreenState extends ConsumerState<MosqueBrandingScreen> {
  late final TextEditingController _nameController;
  Uint8List? _pickedStampBytes; // ختم جديد اختارته المستخدمة، لم يُحفظ بعد
  bool _stampRemoved = false; // ضغطت "حذف الختم"
  bool _isSaving = false;

  // إعدادات ترويسة التقرير (جديد)
  late final TextEditingController _rightHeaderController;
  late final TextEditingController _leftHeaderController;
  Uint8List? _pickedHeaderLogoBytes; // شعار جديد اختارته المستخدمة، لم يُحفظ بعد
  bool _headerLogoRemoved = false; // ضغطت "حذف الشعار"

  // نص شريط عنوان التقرير الشهري (جديد)
  late final TextEditingController _monthlyBannerController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.mosque.supervisorName ?? '');
    // تعبئة أولى بالقيمة الحالية إن وُجدت، وإلا بالنص الافتراضي المرسوم
    // فعلياً في كل التقارير اليوم — بهذا لا تبدأ المستخدمة من فراغ، ولا
    // يظهر أي فرق إن حفظت الشاشة دون تعديل أي شيء.
    _rightHeaderController = TextEditingController(
        text: widget.mosque.rightHeaderText ?? Mosque.defaultRightHeaderText);
    _leftHeaderController =
        TextEditingController(text: widget.mosque.leftHeaderText ?? '');
    _monthlyBannerController = TextEditingController(
        text: widget.mosque.monthlyBannerText ??
            Mosque.defaultMonthlyBannerText);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rightHeaderController.dispose();
    _leftHeaderController.dispose();
    _monthlyBannerController.dispose();
    super.dispose();
  }

  Uint8List? get _existingStampBytes {
    final b64 = widget.mosque.stampBase64;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Uint8List? get _existingHeaderLogoBytes {
    final b64 = widget.mosque.headerLogoBase64;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _maxStampFileBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('حجم الصورة كبير، اختاري صورة أصغر (أقل من 350 كيلوبايت)'),
        ),
      );
      return;
    }

    setState(() {
      _pickedStampBytes = bytes;
      _stampRemoved = false;
    });
  }

  void _removeStamp() {
    setState(() {
      _pickedStampBytes = null;
      _stampRemoved = true;
    });
  }

  Future<void> _pickHeaderLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _maxStampFileBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('حجم الصورة كبير، اختاري صورة أصغر (أقل من 350 كيلوبايت)'),
        ),
      );
      return;
    }

    setState(() {
      _pickedHeaderLogoBytes = bytes;
      _headerLogoRemoved = false;
    });
  }

  void _removeHeaderLogo() {
    setState(() {
      _pickedHeaderLogoBytes = null;
      _headerLogoRemoved = true;
    });
  }

  void _resetRightHeaderTextToDefault() {
    setState(() {
      _rightHeaderController.text = Mosque.defaultRightHeaderText;
    });
  }

  void _resetMonthlyBannerTextToDefault() {
    setState(() {
      _monthlyBannerController.text = Mosque.defaultMonthlyBannerText;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final newStampBase64 =
          _pickedStampBytes != null ? base64Encode(_pickedStampBytes!) : null;
      final newHeaderLogoBase64 = _pickedHeaderLogoBytes != null
          ? base64Encode(_pickedHeaderLogoBytes!)
          : null;

      await ref.read(mosqueRepositoryProvider).updateBranding(
            widget.mosque.id,
            stampBase64: newStampBase64,
            removeStamp: _stampRemoved,
            supervisorName: _nameController.text.trim(),
          );

      await ref.read(mosqueRepositoryProvider).updateHeaderSettings(
            widget.mosque.id,
            rightHeaderText: _rightHeaderController.text.trim(),
            leftHeaderText: _leftHeaderController.text.trim(),
            headerLogoBase64: newHeaderLogoBase64,
            removeHeaderLogo: _headerLogoRemoved,
            monthlyBannerText: _monthlyBannerController.text.trim(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ بيانات المسجد بنجاح')),
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

  @override
  Widget build(BuildContext context) {
    final displayBytes =
        _stampRemoved ? null : (_pickedStampBytes ?? _existingStampBytes);
    final hasStamp = displayBytes != null;

    final displayHeaderLogoBytes = _headerLogoRemoved
        ? null
        : (_pickedHeaderLogoBytes ?? _existingHeaderLogoBytes);
    final hasHeaderLogo = displayHeaderLogoBytes != null;

    return Scaffold(
      appBar: AppBar(title: const Text('بيانات المسجد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mosque_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المسجد',
                          style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: Colors.grey.shade600)),
                      Text(
                        widget.mosque.name,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'ختم مشرفة الحلقات',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        hasStamp ? AppTheme.primaryGreen : Colors.grey.shade400,
                    width: hasStamp ? 2 : 1.5,
                  ),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: hasStamp
                    ? Image.memory(displayBytes, fit: BoxFit.contain)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 34, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'لا يوجد ختم لهذا المسجد بعد',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(hasStamp ? 'تغيير صورة الختم' : 'اختيار صورة الختم'),
            ),
            if (hasStamp) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _removeStamp,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.red),
                label: const Text(
                  'حذف الختم',
                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.red),
                ),
              ),
            ],

            const Divider(height: 40),

            Text(
              'اسم مشرفة الحلقات',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
              decoration: const InputDecoration(hintText: 'مثال: أم محمد'),
            ),
            const SizedBox(height: 6),
            Text(
              'يظهر هذا الاسم أسفل كل تقرير خاص بهذا المسجد',
              style:
                  TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade500),
            ),

            const Divider(height: 40),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFCFEFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.lightGreen, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'إعدادات ترويسة التقرير',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تظهر هذه القيم في أعلى كل تقرير PDF لهذا المسجد فقط. ما لم تُعدَّل، تبقى التقارير كما هي بالضبط.',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'النص الأيمن للترويسة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      GestureDetector(
                        onTap: _resetRightHeaderTextToDefault,
                        child: const Text(
                          'استعادة الافتراضي',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rightHeaderController,
                    textDirection: TextDirection.rtl,
                    maxLines: 3,
                    minLines: 3,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'النص الأيسر للترويسة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        'اختياري',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _leftHeaderController,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    minLines: 2,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'مثال: عنوان المسجد أو رقم التواصل',
                    ),
                  ),

                  const SizedBox(height: 18),
                  Text(
                    'شعار الترويسة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasHeaderLogo
                              ? AppTheme.primaryGreen
                              : Colors.grey.shade400,
                          width: hasHeaderLogo ? 2 : 1.5,
                        ),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasHeaderLogo
                          ? Image.memory(displayHeaderLogoBytes,
                              fit: BoxFit.contain)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined,
                                    size: 30, color: Colors.grey.shade400),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text(
                                    'لا يوجد شعار لهذا المسجد بعد',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickHeaderLogo,
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                    label:
                        Text(hasHeaderLogo ? 'تغيير الشعار' : 'اختيار شعار'),
                  ),
                  if (hasHeaderLogo) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        onPressed: _removeHeaderLogo,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.red),
                        label: const Text(
                          'حذف الشعار',
                          style: TextStyle(
                              fontFamily: 'Tajawal', color: Colors.red),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'نص عنوان التقرير الشهري',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      GestureDetector(
                        onTap: _resetMonthlyBannerTextToDefault,
                        child: const Text(
                          'استعادة الافتراضي',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _monthlyBannerController,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    minLines: 2,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: AppTheme.goldAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'عبارة "لشهر: [اسم الشهر]" تُضاف تلقائياً في نهاية هذا النص دائماً — لا تُكتب هنا، ولا يمكن تعديلها لأنها تتغيّر مع كل تقرير.',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10.5,
                              color: Colors.grey.shade700,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ التغييرات'),
            ),
          ],
        ),
      ),
    );
  }
}
