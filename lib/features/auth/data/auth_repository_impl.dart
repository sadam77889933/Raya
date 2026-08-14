import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/user_model.dart';
import '../domain/repositories/auth_repository.dart';

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

  @override
  @override
  Future<void> createTeacherAccount({
    required String email,
    required String password,
    required String name,
    required String mosqueId,
    String role = 'teacher',
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'secondary',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final resolvedRole =
          role == 'mosqueSupervisor' ? UserRole.mosqueSupervisor : UserRole.teacher;

      final newUser = UserModel(
        uid: credential.user!.uid,
        name: name.trim(),
        role: resolvedRole,
        mosqueId: mosqueId,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_usersCollection)
          .doc(newUser.uid)
          .set(newUser.toJson());
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
}