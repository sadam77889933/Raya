import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mosque.dart';
import '../providers/mosque_provider.dart';

/// الحد الأقصى لحجم ملف صورة الختم (بالبايت) قبل ترميزه Base64.
/// (مستند Firestore حده الأقصى 1 ميجابايت، وBase64 يزيد الحجم ~33%،
/// لذا نُبقي الملف الأصلي صغيراً بما يكفي).
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

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.mosque.supervisorName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final newStampBase64 =
          _pickedStampBytes != null ? base64Encode(_pickedStampBytes!) : null;

      await ref.read(mosqueRepositoryProvider).updateBranding(
            widget.mosque.id,
            stampBase64: newStampBase64,
            removeStamp: _stampRemoved,
            supervisorName: _nameController.text.trim(),
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
