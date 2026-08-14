import 'package:equatable/equatable.dart';

class CircleInfo extends Equatable {
  final String teacherName;
  final String circleName;
  final String mosqueName;
  final String schoolName; // مدرسة/ دار
  final String month;
  final String year;
  final int studentsCount;

  const CircleInfo({
    required this.teacherName,
    required this.circleName,
    required this.mosqueName,
    required this.schoolName,
    required this.month,
    required this.year,
    required this.studentsCount,
  });

  CircleInfo copyWith({
    String? teacherName,
    String? circleName,
    String? mosqueName,
    String? schoolName,
    String? month,
    String? year,
    int? studentsCount,
  }) {
    return CircleInfo(
      teacherName: teacherName ?? this.teacherName,
      circleName: circleName ?? this.circleName,
      mosqueName: mosqueName ?? this.mosqueName,
      schoolName: schoolName ?? this.schoolName,
      month: month ?? this.month,
      year: year ?? this.year,
      studentsCount: studentsCount ?? this.studentsCount,
    );
  }

  @override
  List<Object?> get props => [
        teacherName, circleName, mosqueName, schoolName,
        month, year, studentsCount,
      ];
}