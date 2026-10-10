import 'package:firebase_auth/firebase_auth.dart';
import '../domain/exceptions/account_creation_exception.dart';

/// يحوّل أخطاء Firebase Auth عند إنشاء حساب إلى [AccountCreationException]
/// برسالة عربية واضحة للمشرفة، بدل عرض النص الإنجليزي الخام.
///
/// بريد Firebase Auth فريد على مستوى المشروع كله (كل المساجد والأدوار)،
/// لذلك `email-already-in-use` تعني أن البريد مستخدم في أي مسجد أو دور.
AccountCreationException mapCreateAccountError(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return const AccountCreationException(
        AccountCreationFailure.emailAlreadyInUse,
        'هذا البريد الإلكتروني مستخدم مسبقًا، يرجى استخدام بريد آخر',
      );
    case 'invalid-email':
      return const AccountCreationException(
        AccountCreationFailure.invalidEmail,
        'صيغة البريد الإلكتروني غير صحيحة، تأكدي من كتابته',
      );
    case 'weak-password':
      return const AccountCreationException(
        AccountCreationFailure.weakPassword,
        'كلمة المرور ضعيفة، استخدمي 6 أحرف على الأقل',
      );
    case 'network-request-failed':
      return const AccountCreationException(
        AccountCreationFailure.network,
        'تعذّر الاتصال بالإنترنت، تحققي من الاتصال وحاولي مرة أخرى',
      );
    case 'operation-not-allowed':
      return const AccountCreationException(
        AccountCreationFailure.operationNotAllowed,
        'إنشاء الحسابات بالبريد غير مفعّل في إعدادات Firebase، تواصلي مع المسؤول',
      );
    default:
      return AccountCreationException(
        AccountCreationFailure.unknown,
        'تعذّر إنشاء الحساب (${e.code})، حاولي مرة أخرى',
      );
  }
}
