import 'package:equatable/equatable.dart';
import 'circle_info.dart';
import 'student_record.dart';

class CircleReport extends Equatable {
  final String id;
  final CircleInfo circleInfo;
  final List<StudentRecord> students;
  final DateTime createdAt;

  const CircleReport({
    required this.id,
    required this.circleInfo,
    required this.students,
    required this.createdAt,
  });

  int get completedStudentsCount =>
      students.where((s) => s.isComplete).length;

  bool get isReady =>
      completedStudentsCount == circleInfo.studentsCount;

  String get suggestedFileName =>
      'تقرير_${circleInfo.circleName}_${circleInfo.month}_${circleInfo.year}.pdf';

  CircleReport copyWith({
    String? id,
    CircleInfo? circleInfo,
    List<StudentRecord>? students,
    DateTime? createdAt,
  }) {
    return CircleReport(
      id: id ?? this.id,
      circleInfo: circleInfo ?? this.circleInfo,
      students: students ?? this.students,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, circleInfo, students, createdAt];
  Map<String, dynamic> toFirestoreJson({
    required String teacherId,
    required String mosqueId,
  }) {
    return {
      'teacherId': teacherId,
      'teacherName': circleInfo.teacherName,
      'mosqueId': mosqueId,
      'circleId': circleInfo.circleId,
      'circleName': circleInfo.circleName,
      'schoolName': circleInfo.schoolName,
      'month': circleInfo.month,
      'year': circleInfo.year,
      'studentsCount': circleInfo.studentsCount,
      'companionCurriculums': circleInfo.companionCurriculums,
      'students': students.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}