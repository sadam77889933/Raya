import 'package:flutter/material.dart';

import '../../data/templates/certificate_template_registry.dart';
import '../widgets/certificate_template_card.dart';

/// شاشة "إدارة القوالب" — المرحلة الأولى: عرض فقط لكل القوالب الأساسية
/// المتاحة (تبدأ بقالب واحد)، بلا استيراد أو تحرير. الشاشة مبنية أصلاً
/// كشبكة قوالب، فتعرض تلقائياً أي قوالب أساسية جديدة تُضاف مستقبلاً
/// (القسم ٣-أ من تصميم الميزة) بلا أي تعديل عليها.
class ManageCertificateTemplatesScreen extends StatelessWidget {
  const ManageCertificateTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                childAspectRatio: 0.85,
              ),
              itemCount: certificateTemplateRegistry.length,
              itemBuilder: (context, index) {
                final template = certificateTemplateRegistry[index];
                return CertificateTemplateCard(template: template);
              },
            ),
    );
  }
}
