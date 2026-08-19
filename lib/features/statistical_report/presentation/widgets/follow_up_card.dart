import 'package:flutter/material.dart';

import '../../domain/entities/follow_up_student.dart';

/// بطاقة طالبة واحدة بحاجة إلى متابعة — تُعرض بدل صف جدول على الجوال
/// لأن قائمة قصيرة من البطاقات أوضح من جدول أفقي مزدحم لعدد محدود
/// من الطالبات.
class FollowUpCard extends StatelessWidget {
  final FollowUpStudent followUp;

  const FollowUpCard({super.key, required this.followUp});

  @override
  Widget build(BuildContext context) {
    final s = followUp.summary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.studentName,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: followUp.reasons
                .map((r) => Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFEAD7A6)),
                      ),
                      child: Text(
                        r,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A6200),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat('الحضور',
                  s.totalPossibleDays > 0
                      ? '${s.attendancePercent.round()}%'
                      : '—'),
              const SizedBox(width: 14),
              _stat('الغياب',
                  s.totalPossibleDays > 0
                      ? '${s.absencePercent.round()}%'
                      : '—'),
              const SizedBox(width: 14),
              _stat('السلوك',
                  s.behaviorAvg > 0 ? s.behaviorAvg.toStringAsFixed(1) : '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
            fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade600),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
