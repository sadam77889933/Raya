import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/user_model.dart';
import '../domain/exceptions/account_creation_exception.dart';
import '../domain/repositories/auth_repository.dart';
import 'account_creation_error_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _usersCollection = 'users';

  @override
  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();

    if (!doc.exists) {
      throw Exception('لا يوجد ملف بيانات لهذا المستخدم');
    }

    final user = UserModel.fromJson(uid, doc.data()!);

    if (!user.isActive) {
      await _auth.signOut();
      throw Exception('هذا الحساب معطّل، تواصلي مع المشرفة');
    }

    return user;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final doc = await _firestore
        .collection(_usersCollection)
        .doc(firebaseUser.uid)
        .get();

    if (!doc.exists) return null;

    return UserModel.fromJson(firebaseUser.uid, doc.data()!);
  }

  static const _secondaryAppName = 'secondary';

  /// يعيد التطبيق الثانوي الموجود إن بقي من محاولة سابقة لم تُغلَق (إغلاق
  /// مفاجئ مثلاً) بدل أن تفشل كل المحاولات التالية بـ`duplicate-app`.
  Future<FirebaseApp> _obtainSecondaryApp() async {
    for (final app in Firebase.apps) {
      if (app.name == _secondaryAppName) return app;
    }
    return Firebase.initializeApp(
      name: _secondaryAppName,
      options: Firebase.app().options,
    );
  }

  /// ينشئ حساب Auth ويحوّل أي خطأ (وأهمها البريد المكرر) إلى
  /// [AccountCreationException] برسالة عربية.
  Future<User> _createAuthUser(
    FirebaseAuth auth,
    String email,
    String password,
  ) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw mapCreateAccountError(e);
    }
  }

  /// يحذف حساب Auth الذي أُنشئ للتو بعد فشل حفظ بياناته في Firestore، حتى لا
  /// يبقى البريد محجوزاً بلا ملف بيانات. يعيد الاستثناء المناسب ليُرمى.
  Future<AccountCreationException> _rollbackAfterProfileFailure(
    User createdUser,
  ) async {
    try {
      await createdUser.delete();
      return const AccountCreationException(
        AccountCreationFailure.profileSaveFailed,
        'تعذّر حفظ بيانات الحساب ولم يتم إنشاؤه، تأكدي من الاتصال بالإنترنت وحاولي مرة أخرى',
      );
    } catch (_) {
      return const AccountCreationException(
        AccountCreationFailure.orphanedAuthAccount,
        'تم إنشاء حساب الدخول لكن تعذّر حفظ بياناته. لا تعيدي المحاولة بنفس البريد، وتواصلي مع المسؤول لإصلاح الحساب',
      );
    }
  }

  @override
  Future<void> createTeacherAccount({
    required String email,
    required String password,
    required String name,
    required String mosqueId,
    String role = 'teacher',
  }) async {
    // Firebase Auth يتعامل مع البريد دون حساسية لحالة الأحرف؛ نوحّد الصيغة
    // هنا حتى يُخزَّن في Firestore بنفس الصيغة التي يعتمدها Auth.
    final normalizedEmail = email.trim().toLowerCase();

    final secondaryApp = await _obtainSecondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final createdUser =
          await _createAuthUser(secondaryAuth, normalizedEmail, password);

      final resolvedRole =
          role == 'mosqueSupervisor' ? UserRole.mosqueSupervisor : UserRole.teacher;

      final newUser = UserModel(
        uid: createdUser.uid,
        name: name.trim(),
        role: resolvedRole,
        mosqueId: mosqueId,
        isActive: true,
        createdAt: DateTime.now(),
        email: normalizedEmail,
      );

      try {
        await _firestore
            .collection(_usersCollection)
            .doc(newUser.uid)
            .set(newUser.toJson());
      } catch (_) {
        throw await _rollbackAfterProfileFailure(createdUser);
      }
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('لا يوجد مستخدم مسجّل دخول');
    await user.updatePassword(newPassword);
  }
  @override
  Stream<List<UserModel>> watchAllTeachers() {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: 'teacher')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromJson(doc.id, doc.data()))
            .toList());
  }
  @override
  Stream<List<UserModel>> watchTeachersByMosque(String mosqueId) {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: 'teacher')
        .where('mosqueId', isEqualTo: mosqueId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromJson(doc.id, doc.data()))
            .toList());
  }
@override
  Future<void> updateTeacherName(String uid, String newName) async {
    await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .update({'name': newName.trim()});
  }
  @override
  Future<void> setTeacherActive(String uid, bool isActive) async {
    await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .update({'isActive': isActive});
  }
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
  @override
  Future<void> updateTeacherAssignments(
    String uid, {
    required List<String> schoolIds,
    required List<String> circleIds,
  }) async {
    await _firestore.collection(_usersCollection).doc(uid).update({
      'assignedSchoolIds': schoolIds,
      'assignedCircleIds': circleIds,
    });
  }
}