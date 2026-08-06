import 'package:equatable/equatable.dart';

class StudentRecord extends Equatable {
  final int index;
  final String name;
  final String startSurah;
  final String endSurah;
  final String grade;
  final int behaviorScore; // السلوك والانضباط من 10
  final String reviewStartSurah;
  final String reviewEndSurah;
  final String reviewGrade;
  final int attendanceDays;
  final int absenceDays;
  final String absenceReason;
  final String companionCurriculum;
  final String notes;

  const StudentRecord({
    required this.index,
    required this.name,
    required this.startSurah,
    required this.endSurah,
    required this.grade,
    this.behaviorScore = 10,
    this.reviewStartSurah = '',
    this.reviewEndSurah = '',
    this.reviewGrade = '',
    this.attendanceDays = 0,
    this.absenceDays = 0,
    this.absenceReason = '',
    this.companionCurriculum = '',
    this.notes = '',
  });

  bool get isComplete =>
      name.trim().isNotEmpty &&
      startSurah.isNotEmpty &&
      endSurah.isNotEmpty &&
      grade.isNotEmpty;

  bool get wasAbsent => absenceDays > 0;

  static StudentRecord empty(int index) => StudentRecord(
        index: index,
        name: '',
        startSurah: '',
        endSurah: '',
        grade: '',
      );

  StudentRecord copyWith({
    int? index,
    String? name,
    String? startSurah,
    String? endSurah,
    String? grade,
    int? behaviorScore,
    String? reviewStartSurah,
    String? reviewEndSurah,
    String? reviewGrade,
    int? attendanceDays,
    int? absenceDays,
    String? absenceReason,
    String? companionCurriculum,
    String? notes,
  }) {
    return StudentRecord(
      index: index ?? this.index,
      name: name ?? this.name,
      startSurah: startSurah ?? this.startSurah,
      endSurah: endSurah ?? this.endSurah,
      grade: grade ?? this.grade,
      reviewStartSurah: reviewStartSurah ?? this.reviewStartSurah,
      reviewEndSurah: reviewEndSurah ?? this.reviewEndSurah,
      reviewGrade: reviewGrade ?? this.reviewGrade,
      attendanceDays: attendanceDays ?? this.attendanceDays,
      absenceDays: absenceDays ?? this.absenceDays,
      absenceReason: absenceReason ?? this.absenceReason,
      companionCurriculum: companionCurriculum ?? this.companionCurriculum,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        index, name, startSurah, endSurah, grade,behaviorScore,
        reviewStartSurah, reviewEndSurah, reviewGrade,
        attendanceDays, absenceDays, absenceReason,
        companionCurriculum, notes,
      ];
}