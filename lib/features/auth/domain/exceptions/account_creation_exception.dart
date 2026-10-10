/// سبب فشل إنشاء حساب معلمة/مشرفة، مستقلّ عن Firebase حتى لا تعرف طبقة
/// العرض شيئاً عن `FirebaseAuthException`.
enum AccountCreationFailure {
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  network,
  operationNotAllowed,

  /// فشل حفظ بيانات الحساب في Firestore وتم التراجع عن حساب الدخول بنجاح.
  profileSaveFailed,

  /// فشل حفظ البيانات وفشل التراجع أيضاً — بقي حساب دخول بلا ملف بيانات.
  orphanedAuthAccount,
  unknown,
}

class AccountCreationException implements Exception {
  const AccountCreationException(this.reason, this.message);

  final AccountCreationFailure reason;

  /// رسالة عربية جاهزة للعرض على المشرفة كما هي.
  final String message;

  @override
  String toString() => 'AccountCreationException($reason): $message';
}
