import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/circle_info.dart';
import '../../domain/entities/circle_report.dart';
import '../../domain/entities/student_record.dart';

class ReportFormState {
  final CircleInfo? circleInfo;
  final List<StudentRecord> students;
  final bool isGeneratingPdf;
  final String? pdfPath;
  final String? errorMessage;

  const ReportFormState({
    this.circleInfo,
    this.students = const [],
    this.isGeneratingPdf = false,
    this.pdfPath,
    this.errorMessage,
  });

  bool get hasCircleInfo => circleInfo != null;

  bool get allStudentsComplete {
    if (students.isEmpty) return false;
    final completed = students.where((s) => s.isComplete).length;
    return completed == students.length;
  }

  ReportFormState copyWith({
    CircleInfo? circleInfo,
    List<StudentRecord>? students,
    bool? isGeneratingPdf,
    String? pdfPath,
    String? errorMessage,
    bool clearError = false,
    bool clearPdfPath = false,
  }) {
    return ReportFormState(
      circleInfo: circleInfo ?? this.circleInfo,
      students: students ?? this.students,
      isGeneratingPdf: isGeneratingPdf ?? this.isGeneratingPdf,
      pdfPath: clearPdfPath ? null : (pdfPath ?? this.pdfPath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ReportFormNotifier extends StateNotifier<ReportFormState> {
  ReportFormNotifier() : super(const ReportFormState());

  final _uuid = const Uuid();

  void saveCircleInfo(CircleInfo info) {
    final needsReset = state.circleInfo?.studentsCount != info.studentsCount;
    state = state.copyWith(
      circleInfo: info,
      students: needsReset ? _initStudents(info.studentsCount) : state.students,
      clearError: true,
    );
  }

  List<StudentRecord> _initStudents(int count) {
    return List.generate(count, (i) => StudentRecord.empty(i + 1));
  }
/// تعيين قائمة الطالبات مباشرة من سجل الحلقة
  /// (بدلاً من التهيئة الفارغة بعدد يدوي)
  void setStudentsFromRoster(List<StudentRecord> students) {
    final updatedInfo = state.circleInfo?.copyWith(studentsCount: students.length);
    state = state.copyWith(students: students, circleInfo: updatedInfo);
  }
  void updateStudent(int index, StudentRecord student) {
    final updated = [...state.students];
    final listIndex = updated.indexWhere((s) => s.index == index);
    if (listIndex != -1) {
      updated[listIndex] = student;
    }
    state = state.copyWith(students: updated);
  }

  /// تحديث المناهج المصاحبة المُختارة لهذه الحلقة (اختيار واحد يخص
  /// الحلقة كاملة، يُطبَّق تلقائياً على كل الطالبات عند التصدير).
  void setCompanionCurriculums(List<String> items) {
    final info = state.circleInfo;
    if (info == null) return;
    state = state.copyWith(
      circleInfo: info.copyWith(companionCurriculums: items),
    );
  }

  CircleReport buildReport() {
    return CircleReport(
      id: _uuid.v4(),
      circleInfo: state.circleInfo!,
      students: state.students.where((s) => s.isComplete).toList(),
      createdAt: DateTime.now(),
    );
  }

  void setPdfPath(String path) {
    state = state.copyWith(pdfPath: path, isGeneratingPdf: false);
  }

  void setGeneratingPdf(bool value) {
    state = state.copyWith(isGeneratingPdf: value);
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message, isGeneratingPdf: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    state = const ReportFormState();
  }
}

final reportFormProvider =
    StateNotifierProvider<ReportFormNotifier, ReportFormState>(
  (ref) => ReportFormNotifier(),
);