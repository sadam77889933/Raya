import 'package:equatable/equatable.dart';

class CircleInfo extends Equatable {
  final String teacherName;
  final String circleId;
  final String circleName;
  final String mosqueName;
  final String schoolId;
  final String schoolName; // مدرسة/ دار
  final String month;
  final String year;
  final int studentsCount;

  const CircleInfo({
    required this.teacherName,
    required this.circleId,
    required this.circleName,
    required this.mosqueName,
    required this.schoolId,
    required this.schoolName,
    required this.month,
    required this.year,
    required this.studentsCount,
  });

  CircleInfo copyWith({
    String? teacherName,
    String? circleId,
    String? circleName,
    String? mosqueName,
    String? schoolId,
    String? schoolName,
    String? month,
    String? year,
    int? studentsCount,
  }) {
    return CircleInfo(
      teacherName: teacherName ?? this.teacherName,
      circleId: circleId ?? this.circleId,
      circleName: circleName ?? this.circleName,
      mosqueName: mosqueName ?? this.mosqueName,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      month: month ?? this.month,
      year: year ?? this.year,
      studentsCount: studentsCount ?? this.studentsCount,
    );
  }

  @override
  List<Object?> get props => [
        teacherName, circleId, circleName, mosqueName, schoolId, schoolName,
        month, year, studentsCount,
      ];
}
