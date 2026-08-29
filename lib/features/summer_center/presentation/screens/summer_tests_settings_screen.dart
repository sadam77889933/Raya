import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/summer_center.dart';
import '../providers/summer_center_provider.dart';

/// تفعيل/تعطيل شاشة الاختبارات للمعلمات في مركز صيفي واحد.
///
/// هذا مجرد مفتاح واجهة يعكس حقل [SummerCenter.testsEnabledForTeachers] —
/// الحماية الفعلية عند التعطيل مطبَّقة في قواعد أمان Firestore على مجموعات
/// summer_tests وsummer_test_questions (تتحقق من هذا الحقل عبر get() قبل
/// السماح لأي معلمة بالقراءة أو الكتابة)، وليست مجرد إخفاء هذا الزر.
/// وصول المشرفة والمشرفات يبقى دائماً بلا أي تأثير من هذا المفتاح.
class SummerTestsSettingsScreen extends ConsumerWidget {
  final SummerCenter center;
  const SummerTestsSettingsScreen({super.key, required this.center});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centerAsync = ref.watch(summerCenterProvider(center.id));
    final current = centerAsync.value ?? center;

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الاختبارات')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
              ),
              child: Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, size: 17, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'المركز: ${current.name}',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFF616161)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.quiz_outlined, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('شاشة الاختبارات للمعلمات',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ),
                      Switch(
                        value: current.testsEnabledForTeachers,
                        onChanged: (value) => ref
                            .read(summerCenterRepositoryProvider)
                            .setTestsEnabled(current.id, value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'عند التفعيل، تظهر شاشة "اختباراتي" للمعلمات ويمكنهن إنشاء اختبارات جديدة والوصول إلى اختباراتهن السابقة.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade600, height: 1.8),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                      color: current.testsEnabledForTeachers ? AppTheme.lightGreen : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          current.testsEnabledForTeachers ? Icons.check_circle : Icons.pause_circle_outline,
                          size: 13,
                          color: current.testsEnabledForTeachers ? AppTheme.primaryGreen : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          current.testsEnabledForTeachers ? 'مُفعَّلة حالياً' : 'مُعطَّلة حالياً',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: current.testsEnabledForTeachers ? AppTheme.primaryGreen : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF3E2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0DFB0), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _explainRow(
                    Icons.info_outline,
                    'عند التعطيل تختفي شاشة الاختبارات من واجهة المعلمة بالكامل، ولا يمكنها إنشاء أو فتح أي اختبار سابق — الحماية مطبَّقة في قاعدة البيانات نفسها وليست مجرد إخفاء زر.',
                  ),
                  const SizedBox(height: 9),
                  _explainRow(
                    Icons.verified_user_outlined,
                    'وصولك كمشرفة يستمر دائماً لعرض وإدارة الاختبارات، حتى بعد التعطيل — ولا يُحذف أي اختبار من قاعدة البيانات.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _explainRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.goldAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFF6B5416), height: 1.7),
          ),
        ),
      ],
    );
  }
}
