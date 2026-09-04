import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/templates/certificate_template_registry.dart';
import '../widgets/certificate_template_card.dart';
import 'certificate_template_editor_screen.dart';

/// شاشة "إدارة القوالب" — تعرض كل القوالب الأساسية المتاحة (شبكة تتّسع
/// تلقائياً لأي قوالب جديدة تُضاف مستقبلاً — القسم ٣-أ من تصميم الميزة)،
/// بالإضافة إلى زر "تحرير" على كل بطاقة يفتح محرر مواضع الحقول
/// ("المرحلة الثانية" — القسم ١٣): سحب حرّ + إظهار/إخفاء فقط في هذه
/// الدفعة الأولى.
///
/// التحرير خاص **بمشرفة المسجد فقط** لقوالب مسجدها هي (كل مسجد يدير
/// قوالبه بنفسه)؛ المشرف العام يرى القوالب بلا زر تحرير — قراءة فقط،
/// بنفس صلاحيات القسم ٧ من تصميم الميزة.
class ManageCertificateTemplatesScreen extends ConsumerWidget {
  const ManageCertificateTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final editableMosqueId =
        (user != null && user.isMosqueSupervisor) ? user.mosqueId : null;

    return Scaffold(
      appBar: AppBar(title: const Text('قوالب الشهادات')),
      body: certificateTemplateRegistry.isEmpty
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
              itemCount: certificateTemplateRegistry.length,
              itemBuilder: (context, index) {
                final template = certificateTemplateRegistry[index];
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
                  ],
                );
              },
            ),
    );
  }
}
