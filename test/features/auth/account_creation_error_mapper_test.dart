import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/features/auth/data/account_creation_error_mapper.dart';
import 'package:quran_circle_report/features/auth/domain/exceptions/account_creation_exception.dart';

void main() {
  group('mapCreateAccountError', () {
    test('البريد المستخدم مسبقاً يعطي رسالة عربية واضحة', () {
      final result = mapCreateAccountError(
        FirebaseAuthException(code: 'email-already-in-use'),
      );

      expect(result.reason, AccountCreationFailure.emailAlreadyInUse);
      expect(
        result.message,
        'هذا البريد الإلكتروني مستخدم مسبقًا، يرجى استخدام بريد آخر',
      );
    });

    test('البريد غير الصالح', () {
      final result = mapCreateAccountError(
        FirebaseAuthException(code: 'invalid-email'),
      );

      expect(result.reason, AccountCreationFailure.invalidEmail);
    });

    test('كلمة المرور الضعيفة', () {
      final result = mapCreateAccountError(
        FirebaseAuthException(code: 'weak-password'),
      );

      expect(result.reason, AccountCreationFailure.weakPassword);
    });

    test('انقطاع الشبكة', () {
      final result = mapCreateAccountError(
        FirebaseAuthException(code: 'network-request-failed'),
      );

      expect(result.reason, AccountCreationFailure.network);
    });

    test('كود غير معروف يُضمَّن في الرسالة للتشخيص', () {
      final result = mapCreateAccountError(
        FirebaseAuthException(code: 'something-new'),
      );

      expect(result.reason, AccountCreationFailure.unknown);
      expect(result.message, contains('something-new'));
    });
  });
}
