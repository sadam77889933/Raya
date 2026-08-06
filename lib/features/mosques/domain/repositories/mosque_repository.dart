import '../entities/mosque.dart';

abstract class MosqueRepository {
  /// جلب جميع المساجد (كـ Stream حتى تتحدث القائمة تلقائياً عند أي تغيير)
  Stream<List<Mosque>> watchAll();

  /// إضافة مسجد جديد
  Future<void> add(String name);

  /// تعطيل/تفعيل مسجد
  Future<void> setActive(String mosqueId, bool isActive);
}