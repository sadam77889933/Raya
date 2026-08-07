import '../entities/user_model.dart';

abstract class AuthRepository {
  /// تسجيل الدخول بالبريد وكلمة المرور
  Future<UserModel> signIn(String email, String password);

  /// تسجيل الخروج
  Future<void> signOut();

  /// المستخدم الحالي (null لو لا يوجد تسجيل دخول)
  Future<UserModel?> getCurrentUser();

  /// إنشاء حساب معلمة جديد (تستخدمها المشرفة فقط)
  Future<void> createTeacherAccount({
    required String email,
    required String password,
    required String name,
    required String mosqueId,
  });

  /// تغيير كلمة المرور للمستخدم الحالي
  Future<void> changePassword(String newPassword);
  /// إرسال رابط إعادة تعيين كلمة المرور للبريد المُدخل
  Future<void> sendPasswordResetEmail(String email);
  /// جلب جميع المعلمات (كـ Stream حيّة)
  Stream<List<UserModel>> watchAllTeachers();

  /// تعطيل/تفعيل حساب معلمة
  Future<void> setTeacherActive(String uid, bool isActive);
}