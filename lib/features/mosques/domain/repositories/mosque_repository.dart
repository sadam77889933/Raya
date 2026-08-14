import '../entities/mosque.dart';

abstract class MosqueRepository {
  /// جلب جميع المساجد (كـ Stream حتى تتحدث القائمة تلقائياً عند أي تغيير)
  Stream<List<Mosque>> watchAll();

  /// إضافة مسجد جديد
  Future<void> add(String name);

  /// تعطيل/تفعيل مسجد
  Future<void> setActive(String mosqueId, bool isActive);

  /// تحديث ختم المسجد (Base64) و/أو اسم مشرفة الحلقات.
  /// تمرير null لأي من الحقلين يعني "بدون تغيير عليه".
  /// لحذف الختم نهائياً استخدمي [removeStamp]: true.
  Future<void> updateBranding(
    String mosqueId, {
    String? stampBase64,
    bool removeStamp = false,
    String? supervisorName,
  });
}