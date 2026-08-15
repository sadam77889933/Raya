import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/entities/student_record.dart';
import '../providers/firestore_report_provider.dart';
import '../widgets/student_form_card.dart';

/// شاشة تعديل تقرير سابق محفوظ في Firestore.
///
/// تسمح للمعلمة بتعديل بيانات أي طالبة موجودة في التقرير (الحفظ،
/// المراجعة، السلوك، الحضور والغياب، الملاحظات) أو إضافة طالبة جديدة
/// لم تكن موجودة وقت إنشاء التقرير. الحفظ يُحدّث التقرير في مكانه
/// داخل Firestore مباشرة دون تغيير تاريخ إنشائه الأصلي، ودون إعادة
/// رفع ملف PDF تلقائياً (المشاركة تبقى يدوية من شاشة التفاصيل).
class EditReportScreen extends ConsumerStatefulWidget {
  final ReportSummary report;

  const EditReportScreen({super.key, required this.report});

  @override
  ConsumerState<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends ConsumerState<EditReportScreen> {
  late List<StudentRecord> _students;
  int _expandedIndex = -1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _students = widget.report.students
        .map((json) => StudentRecord.fromJson(json))
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  void _addStudent() {
    final nextIndex =
        _students.isEmpty ? 1 : (_students.map((s) => s.index).reduce((a, b) => a > b ? a : b) + 1);
    setState(() {
      _students.add(StudentRecord.empty(nextIndex));
      _expandedIndex = _students.length - 1;
    });
  }

  /// يضيف تلقائياً أي طالبة جديدة تمت إضافتها لهذا التقرير إلى سجل
  /// الحلقة الدائم، إن لم تكن موجودة فيه أصلاً (بمطابقة الاسم).
  ///
  /// مهم: نستخدم هنا rosterProvider.notifier.addStudent() بالضبط كما
  /// تفعل شاشة "سجل الحلقة" نفسها، وليس الكتابة المباشرة على المستودع
  /// (Repository). السبب: الكتابة المباشرة تُحدّث التخزين لكنها لا
  /// تُخطر نسخة RosterNotifier الحيّة في الذاكرة (إن كانت محمّلة من
  /// فتحة سابقة لسجل الحلقة في نفس الجلسة)، فتبقى الشاشة تعرض بيانات
  /// قديمة حتى تُغلَق وتُفتَح من جديد بالكامل. استدعاء addStudent()
  /// يمرّ عبر نفس الـ Notifier ويُحدّث حالته فوراً أينما كان معروضاً.
  Future<void> _syncNewStudentsToRoster(List<StudentRecord> students) async {
    final circleId = widget.report.circleId;
    // تقرير قديم من قبل الترحيل لسجل الحلقة (لا يحمل معرّف حلقة):
    // نتجاهل المزامنة بدل تخمين حلقة قد تكون خاطئة.
    if (circleId.isEmpty) return;

    final repo = ref.read(rosterRepositoryProvider);
    final notifier = ref.read(rosterProvider(circleId).notifier);

    // نقرأ من المستودع مباشرة (وليس من state) لضمان قائمة حديثة
    // حتى لو لم تُفتَح شاشة سجل الحلقة بعد في هذه الجلسة.
    final existingNames = (await repo.watchByCircle(circleId).first)
        .map((s) => s.name.trim())
        .toSet();

    for (final student in students) {
      final name = student.name.trim();
      if (name.isEmpty || existingNames.contains(name)) continue;

      await notifier.addStudent(name);
      existingNames.add(name);
    }
  }

  Future<void> _save() async {
    final completeStudents = _students.where((s) => s.isComplete).toList();

    if (completeStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات مكتملة لحفظها'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final studentsJson =
          completeStudents.map((s) => s.toJson()).toList();

      await ref
          .read(firestoreReportServiceProvider)
          .updateReportStudents(widget.report.id, studentsJson);

      await _syncNewStudentsToRoster(completeStudents);

      if (!mounted) return;

      final updatedReport = ReportSummary(
        id: widget.report.id,
        teacherName: widget.report.teacherName,
        mosqueId: widget.report.mosqueId,
        circleId: widget.report.circleId,
        circleName: widget.report.circleName,
        schoolName: widget.report.schoolName,
        month: widget.report.month,
        year: widget.report.year,
        studentsCount: completeStudents.length,
        createdAt: widget.report.createdAt,
        students: studentsJson,
      );

      Navigator.of(context).pop(updatedReport);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر حفظ التعديلات: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('تعديل تقرير — ${report.month} ${report.year}'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.goldAccent.withOpacity(0.08),
              border: Border.all(color: AppTheme.goldAccent.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.goldAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'التعديلات تُحفظ مباشرة على هذا التقرير في النظام، دون التأثير على تاريخ إنشائه الأصلي.',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _students.length + 1,
              itemBuilder: (context, index) {
                if (index == _students.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      onPressed: _addStudent,
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          size: 18),
                      label: const Text('إضافة طالبة جديدة لهذا التقرير'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(
                          color: AppTheme.primaryGreen.withOpacity(0.5),
                        ),
                        backgroundColor: AppTheme.lightGreen,
                      ),
                    ),
                  );
                }

                final student = _students[index];
                return StudentFormCard(
                  studentIndex: student.index,
                  student: student,
                  isExpanded: _expandedIndex == index,
                  onToggle: () {
                    setState(() {
                      _expandedIndex = _expandedIndex == index ? -1 : index;
                    });
                  },
                  onSaved: (updatedStudent) {
                    setState(() {
                      _students[index] = updatedStudent;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 32,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ التعديلات'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }
}
