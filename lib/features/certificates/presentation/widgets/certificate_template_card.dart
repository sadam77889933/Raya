
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/certificate_template.dart';
import '../../data/template_image_store.dart';

/// بطاقة عرض قالب شهادة واحد — تُستخدم في خطوة اختيار القالب بالمعالج
/// وفي شاشة إدارة القوالب معاً. مبنية أصلاً لتتّسع لأي عدد من القوالب
/// بلا أي تعديل عند إضافة قوالب أساسية جديدة مستقبلاً.
class CertificateTemplateCard extends StatelessWidget {
  final CertificateTemplateDefinition template;
  final bool selected;
  final VoidCallback? onTap;

  const CertificateTemplateCard({
    super.key,
    required this.template,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? AppTheme.lightGreen : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppTheme.primaryGreen : Colors.grey.shade200,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1.414, // A4 landscape تقريباً
                  // قالب مستورَد: صورة محلية على القرص (`Image.file`)؛ قالب
                  // أساسي مُجمَّع كـAsset: كما كان دائماً (`Image.asset`).
                  child: template.localBackgroundImagePath != null
                      ? TemplateImageStore.buildImage(
                          template.localBackgroundImagePath!,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          template.thumbnailAsset,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.displayName,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.primaryGreen, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
