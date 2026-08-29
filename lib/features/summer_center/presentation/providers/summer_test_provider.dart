import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/summer_test.dart';
import '../../domain/entities/summer_test_question.dart';
import 'summer_center_provider.dart';

/// مفتاح (معلمة + مستوى + مادة) لاستعلام "قائمة اختباراتي" عند المعلمة.
class TeacherTestsKey extends Equatable {
  final String teacherId;
  final String levelId;
  final String subjectId;

  const TeacherTestsKey({
    required this.teacherId,
    required this.levelId,
    required this.subjectId,
  });

  @override
  List<Object?> get props => [teacherId, levelId, subjectId];
}

final summerTeacherTestsProvider = StreamProvider.family
    .autoDispose<List<SummerTest>, TeacherTestsKey>((ref, key) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchTeacherTests(
        teacherId: key.teacherId,
        levelId: key.levelId,
        subjectId: key.subjectId,
      );
});

/// فلاتر شاشة "اختبارات المعلمات" عند المشرفة — [centerId] مُلزَم دائماً
/// (لا استعلام بلا نطاق مركز محدَّد)، وبقية الحقول اختيارية.
class SummerTestFilter extends Equatable {
  final String centerId;
  final String? levelId;
  final String? subjectId;
  final String? teacherId;

  const SummerTestFilter({
    required this.centerId,
    this.levelId,
    this.subjectId,
    this.teacherId,
  });

  @override
  List<Object?> get props => [centerId, levelId, subjectId, teacherId];
}

final summerTestsFilteredProvider = StreamProvider.family
    .autoDispose<List<SummerTest>, SummerTestFilter>((ref, filter) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchTestsFiltered(
        centerId: filter.centerId,
        levelId: filter.levelId,
        subjectId: filter.subjectId,
        teacherId: filter.teacherId,
      );
});

/// اختبار واحد بمعرّفه (لشاشتي إنشاء/تعديل الاختبار والمعاينة والتفاصيل).
final summerTestProvider =
    StreamProvider.family.autoDispose<SummerTest?, String>((ref, testId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchTest(testId);
});

/// أسئلة اختبار واحد — لا تُحمَّل إطلاقاً إلا عند فتح هذا الاختبار تحديداً.
final summerQuestionsProvider = StreamProvider.family
    .autoDispose<List<SummerTestQuestion>, String>((ref, testId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchQuestions(testId);
});
