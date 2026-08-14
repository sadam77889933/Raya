import '../entities/user_model.dart';

abstract class AuthRepository {
  /// تسجيل الدخول بالبريد وكلمة المرور
  Future<UserModel> signIn(String email, String password);

  /// تسجيل الخروج
  Future<void> signOut();

  /// المستخدم الحالي (null لو لا يوجد تسجيل دخول)
  Future<UserModel?> getCurrentUser();

  /// إنشاء حساب معلمة جديد (تستخدمها المشرفة فقط)
  /// إنشاء حساب معلمة أو مشرفة مسجد جديد (تستخدمها المشرفة العامة فقط)
  Future<void> createTeacherAccount({
    required String email,
    required String password,
    required String name,
    required String mosqueId,
    String role = 'teacher',
  });

  /// تغيير كلمة المرور للمستخدم الحالي
  Future<void> changePassword(String newPassword);
  /// إرسال رابط إعادة تعيين كلمة المرور للبريد المُدخل
  Future<void> sendPasswordResetEmail(String email);
  /// جلب جميع المعلمات (كـ Stream حيّة)
  Stream<List<UserModel>> watchAllTeachers();
  /// جلب معلمات مسجد معيّن فقط (للاستخدام مع مشرفة المسجد)
  Stream<List<UserModel>> watchTeachersByMosque(String mosqueId);
  /// تعديل اسم معلمة (تستخدمها المشرفة العامة أو مشرفة المسجد)
  Future<void> updateTeacherName(String uid, String newName);
  /// تعطيل/تفعيل حساب معلمة
  Future<void> setTeacherActive(String uid, bool isActive);
  /// تحديد الدور/المدارس والحلقات التي تُدرّس بها المعلمة
  Future<void> updateTeacherAssignments(
    String uid, {
    required List<String> schoolIds,
    required List<String> circleIds,
  });
}