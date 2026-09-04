import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
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
    final hijri = _gregorianToHijri(batch.createdAt);
    final dateLabel = '${hijri.day}/${hijri.month}/${hijri.year}هـ';
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

/// تاريخ هجري تقريبي (يوم/شهر/سنة) لعرض تاريخ إنشاء الدُفعة فقط.
class _ApproxHijriDate {
  final int year;
  final int month;
  final int day;
  const _ApproxHijriDate(this.year, this.month, this.day);
}

/// تحويل ميلادي ← هجري بخوارزمية جدولية معروفة (الخوارزمية الكويتية) —
/// مستقل تماماً عن حزمة hijri الخارجية (المستخدَمة في بقية التطبيق فقط
/// لتاريخ اليوم الحالي عبر HijriCalendar.now())، لأن هذه الشاشة تحتاج
/// تحويل تاريخ إنشاء دُفعة قديم وليس تاريخ اليوم. دقّة تقريبية (يوم أو
/// يومان) كافية تماماً لعرض تاريخ سجل، وليست حساباً شرعياً رسمياً.
_ApproxHijriDate _gregorianToHijri(DateTime date) {
  final jdn = _gregorianToJulianDayNumber(date.year, date.month, date.day);
  final l1 = jdn - 1948440 + 10632;
  final n = ((l1 - 1) / 10631).floor();
  final l2 = l1 - 10631 * n + 354;
  final j = (((10985 - l2) / 5316).floor()) * (((50 * l2) / 17719).floor()) +
      ((l2 / 5670).floor()) * (((43 * l2) / 15238).floor());
  final l3 = l2 -
      (((30 - j) / 15).floor()) * (((17719 * j) / 50).floor()) -
      ((j / 16).floor()) * (((15238 * j) / 43).floor()) +
      29;
  final month = ((24 * l3) / 709).floor();
  final day = l3 - ((709 * month) / 24).floor();
  final year = 30 * n + j - 30;
  return _ApproxHijriDate(year, month, day);
}

int _gregorianToJulianDayNumber(int year, int month, int day) {
  final a = ((14 - month) / 12).floor();
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day +
      ((153 * m + 2) / 5).floor() +
      365 * y +
      (y / 4).floor() -
      (y / 100).floor() +
      (y / 400).floor() -
      32045;
}
