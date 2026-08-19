import 'package:flutter/material.dart';

import '../../domain/entities/student_period_summary.dart';

/// جدول ملخّص أداء الطالبات خلال الفترة. عمود الاسم مثبَّت (Sticky) على
/// الجانب الأيمن أثناء التمرير الأفقي للأعمدة الأخرى — بدون هذا التثبيت
/// يفقد المستخدم مرجعية "لمن هذا الصف" عند التمرير على شاشة صغيرة.
class StudentSummaryTable extends StatelessWidget {
  final List<StudentPeriodSummary> students;

  const StudentSummaryTable({super.key, required this.students});

  static const _headerStyle = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );
  static const _cellStyle = TextStyle(fontFamily: 'Tajawal', fontSize: 11.5);

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'لا توجد بيانات لهذه الفترة',
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade400),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العمود المثبَّت: اسم الطالبة
            Column(
              children: [
                _headerCell('الطالبة', alignRight: true, width: 110),
                for (final s in students)
                  _cell(s.studentName, alignRight: true, width: 110, bold: true),
              ],
            ),
            Container(width: 1, color: Colors.grey.shade200),
            // الأعمدة القابلة للتمرير أفقياً
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    Row(children: [
                      _headerCell('الحفظ', width: 76),
                      _headerCell('المراجعة', width: 76),
                      _headerCell('السلوك', width: 60),
                      _headerCell('الحضور', width: 60),
                      _headerCell('الغياب', width: 60),
                    ]),
                    for (final s in students)
                      Row(children: [
                        _cell(s.memorizationGrade.isEmpty ? '—' : s.memorizationGrade,
                            width: 76),
                        _cell(s.revisionGrade.isEmpty ? '—' : s.revisionGrade,
                            width: 76),
                        _cell(s.behaviorAvg > 0 ? s.behaviorAvg.toStringAsFixed(1) : '—',
                            width: 60),
                        _cell(
                            s.totalPossibleDays > 0
                                ? '${s.attendancePercent.round()}%'
                                : '—',
                            width: 60),
                        _cell(
                            s.totalPossibleDays > 0
                                ? '${s.absencePercent.round()}%'
                                : '—',
                            width: 60),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {double width = 70, bool alignRight = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      color: const Color(0xFFE8F5E9),
      alignment: alignRight ? Alignment.centerRight : Alignment.center,
      child: Text(text,
          textAlign: alignRight ? TextAlign.right : TextAlign.center,
          style: _headerStyle),
    );
  }

  Widget _cell(String text,
      {double width = 70, bool alignRight = false, bool bold = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      alignment: alignRight ? Alignment.centerRight : Alignment.center,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: _cellStyle.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
      ),
    );
  }
}
