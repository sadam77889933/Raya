import 'package:equatable/equatable.dart';

/// سجل تاريخي لعملية نقل طالبة من حلقة إلى حلقة أخرى (داخل نفس المسجد
/// أو بين مسجدين مختلفين).
///
/// هذا الكيان **لا يُستخدم إطلاقاً** لتحديد أين تظهر الطالبة في أي تقرير
/// شهري — التقارير مستقلة تماماً عنه (انظر توثيق [StudentTransferRepository]
/// في `student_transfer_repository.dart`). دوره الوحيد هو توثيق "من نقل
/// من، إلى أين، ومتى، ولماذا" بحيث يمكن الرجوع إليه مستقبلاً.
class StudentTransfer extends Equatable {
  final String id;
  final String studentId;
  final String studentName;

  final String fromMosqueId;
  final String fromMosqueName;
  final String fromSchoolId;
  final String fromSchoolName;
  final String fromCircleId;
  final String fromCircleName;

  final String toMosqueId;
  final String toMosqueName;
  final String toSchoolId;
  final String toSchoolName;
  final String toCircleId;
  final String toCircleName;

  /// الفترة الهجرية (شهر + سنة) التي اختارتها المشرفة كتاريخ نفاذ النقل —
  /// بنفس القائمة والصيغة المستخدمة في بقية التطبيق لكل التواريخ الهجرية.
  final String transferHijriMonth;
  final String transferHijriYear;

  /// مفتاح رقمي متسلسل لنفس الفترة أعلاه (`QuranConstants.hijriPeriodKey`)،
  /// لتفادي تكرار نفس منطق المقارنة بين الفترات الهجرية الموجود مسبقاً
  /// لأغراض التقارير.
  final int transferPeriodKey;

  /// توقيت تنفيذ العملية فعلياً على الجهاز (يختلف عن تاريخ النقل الهجري
  /// أعلاه، الذي هو تاريخ نفاذ إداري قد يُختار ليكون بداية الشهر مثلاً).
  final DateTime performedAt;
  final String performedByUid;
  final String performedByName;

  /// سبب النقل، اختياري بالكامل.
  final String reason;

  const StudentTransfer({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.fromMosqueId,
    required this.fromMosqueName,
    required this.fromSchoolId,
    required this.fromSchoolName,
    required this.fromCircleId,
    required this.fromCircleName,
    required this.toMosqueId,
    required this.toMosqueName,
    required this.toSchoolId,
    required this.toSchoolName,
    required this.toCircleId,
    required this.toCircleName,
    required this.transferHijriMonth,
    required this.transferHijriYear,
    required this.transferPeriodKey,
    required this.performedAt,
    required this.performedByUid,
    required this.performedByName,
    this.reason = '',
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'fromMosqueId': fromMosqueId,
        'fromMosqueName': fromMosqueName,
        'fromSchoolId': fromSchoolId,
        'fromSchoolName': fromSchoolName,
        'fromCircleId': fromCircleId,
        'fromCircleName': fromCircleName,
        'toMosqueId': toMosqueId,
        'toMosqueName': toMosqueName,
        'toSchoolId': toSchoolId,
        'toSchoolName': toSchoolName,
        'toCircleId': toCircleId,
        'toCircleName': toCircleName,
        'transferHijriMonth': transferHijriMonth,
        'transferHijriYear': transferHijriYear,
        'transferPeriodKey': transferPeriodKey,
        'performedAt': performedAt.toIso8601String(),
        'performedByUid': performedByUid,
        'performedByName': performedByName,
        'reason': reason,
      };

  factory StudentTransfer.fromJson(String id, Map<String, dynamic> json) {
    return StudentTransfer(
      id: id,
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      fromMosqueId: json['fromMosqueId'] as String? ?? '',
      fromMosqueName: json['fromMosqueName'] as String? ?? '',
      fromSchoolId: json['fromSchoolId'] as String? ?? '',
      fromSchoolName: json['fromSchoolName'] as String? ?? '',
      fromCircleId: json['fromCircleId'] as String? ?? '',
      fromCircleName: json['fromCircleName'] as String? ?? '',
      toMosqueId: json['toMosqueId'] as String? ?? '',
      toMosqueName: json['toMosqueName'] as String? ?? '',
      toSchoolId: json['toSchoolId'] as String? ?? '',
      toSchoolName: json['toSchoolName'] as String? ?? '',
      toCircleId: json['toCircleId'] as String? ?? '',
      toCircleName: json['toCircleName'] as String? ?? '',
      transferHijriMonth: json['transferHijriMonth'] as String? ?? '',
      transferHijriYear: json['transferHijriYear'] as String? ?? '',
      transferPeriodKey: json['transferPeriodKey'] as int? ?? 0,
      performedAt: DateTime.tryParse(json['performedAt'] as String? ?? '') ??
          DateTime.now(),
      performedByUid: json['performedByUid'] as String? ?? '',
      performedByName: json['performedByName'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        id,
        studentId,
        studentName,
        fromMosqueId,
        fromMosqueName,
        fromSchoolId,
        fromSchoolName,
        fromCircleId,
        fromCircleName,
        toMosqueId,
        toMosqueName,
        toSchoolId,
        toSchoolName,
        toCircleId,
        toCircleName,
        transferHijriMonth,
        transferHijriYear,
        transferPeriodKey,
        performedAt,
        performedByUid,
        performedByName,
        reason,
      ];
}
