import '../entities/certificate_batch.dart';

/// عقد مجرّد لتخزين واسترجاع دُفعات الشهادات — مستند Firestore واحد لكل
/// دفعة (`certificate_batches`)، مقيَّد بـ mosqueId لعزل كل مسجد عن الآخر.
abstract class CertificateRepository {
  /// آخر الدُفعات ضمن مسجد واحد، للعرض في سجل الشاشة الرئيسية.
  Stream<List<CertificateBatch>> watchByMosque(String mosqueId, {int limit});

  /// كل الدُفعات (للمشرف العام بلا قيود)، بنفس حدّ العرض.
  Stream<List<CertificateBatch>> watchAll({int limit});

  Future<void> create(CertificateBatch batch);
}
