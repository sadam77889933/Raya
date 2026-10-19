import '../entities/report_summary.dart';

final _ignoredChars = RegExp(
  r'[\u064B-\u065F\u0670\u0640\u200B-\u200F\u202A-\u202E\uFEFF]',
);
final _alefVariants = RegExp(r'[\u0622\u0623\u0625\u0671]');
final _whitespace = RegExp(r'\s+');

/// يوحّد كتابة اسم الطالبة قبل مقارنته بغيره.
///
/// التقارير القديمة لا تحفظ رقماً تعريفياً للطالبة، فالاسم هو مفتاح التعرّف
/// عليها عبر الشهور. تُهمَل فروق الكتابة التي لا تغيّر الاسم فعلياً: التشكيل
/// والتطويل، وأشكال الألف (أ/إ/آ)، والتاء المربوطة/الهاء، والألف المقصورة/الياء،
/// والمسافات الزائدة والأحرف المخفيّة.
String normalizeStudentName(String name) {
  return name
      .replaceAll(_ignoredChars, '')
      .replaceAll(_alefVariants, '\u0627')
      .replaceAll('\u0629', '\u0647')
      .replaceAll('\u0649', '\u064A')
      .replaceAll(_whitespace, ' ')
      .trim()
      .toLowerCase();
}

extension UniqueStudentsCount on Iterable<ReportSummary> {
  /// عدد الطالبات المختلفات في هذه التقارير، فالطالبة تُحسب مرة واحدة مهما
  /// تكررت في تقارير شهور متعددة.
  ///
  /// التعرّف على الطالبة:
  /// - **برقمها في سجل الحلقة** (`studentId`) متى وُجد: فلا يتأثر العدّ بتغيير
  ///   اسمها ولا بانتقالها لحلقة أخرى، وتُحسب مرة واحدة عبر كل الحلقات.
  /// - **بالاسم الموحَّد داخل الحلقة** للتقارير القديمة بلا رقم. الصف القديم
  ///   يُربط برقم طالبة إن وُجد في نفس الحلقة صف مرتبط بالاسم ذاته، فلا تُحسب
  ///   الطالبة مرتين حين يختلط تقرير قديم بجديد. والتقارير القديمة بلا
  ///   `circleId` تُجمَّع باسم الحلقة.
  ///
  /// الصفوف بلا اسم ولا رقم تُهمَل لتعذّر تمييزها.
  int get uniqueStudentsCount {
    final idByScopedName = <String, String>{};
    for (final report in this) {
      final scope = _circleScopeOf(report);
      for (final student in report.students) {
        final id = _studentIdOf(student);
        final name = _normalizedNameOf(student);
        if (id.isEmpty || name.isEmpty) continue;
        idByScopedName.putIfAbsent('$scope|$name', () => id);
      }
    }

    final seen = <String>{};
    for (final report in this) {
      final scope = _circleScopeOf(report);
      for (final student in report.students) {
        final id = _studentIdOf(student);
        if (id.isNotEmpty) {
          seen.add('id:$id');
          continue;
        }
        final name = _normalizedNameOf(student);
        if (name.isEmpty) continue;
        final linkedId = idByScopedName['$scope|$name'];
        seen.add(linkedId != null ? 'id:$linkedId' : 'name:$scope|$name');
      }
    }
    return seen.length;
  }
}

String _circleScopeOf(ReportSummary report) =>
    report.circleId.isNotEmpty ? report.circleId : report.circleName.trim();

String _studentIdOf(Map<String, dynamic> student) =>
    student['studentId']?.toString().trim() ?? '';

String _normalizedNameOf(Map<String, dynamic> student) =>
    normalizeStudentName(student['name']?.toString() ?? '');
