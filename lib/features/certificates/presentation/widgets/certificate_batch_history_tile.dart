import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/hijri_date_formatter.dart';
import '../../domain/entities/certificate_batch.dart';

/// عنصر واحد في سجل "آخر الشهادات" بالشاشة الرئيسية.
class CertificateBatchHistoryTile extends StatelessWidget {
  final CertificateBatch batch;
  final VoidCallback? onTap;

  const CertificateBatchHistoryTile({
    super.key,
    required this.batch,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatHijriDateLabel(batch.createdAt);
    final typeLabel = batch.recipientType == CertificateRecipientType.teacher
        ? 'معلمات'
        : 'طالبات';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${batch.recipientCount} شهادة — $typeLabel'
                      '${batch.circleNameSnapshot != null ? ' (${batch.circleNameSnapshot})' : ''}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${batch.mosqueNameSnapshot ?? ''} — $dateLabel'
                      ' — بواسطة ${batch.createdByName}',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.share_rounded, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

