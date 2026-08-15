import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/entities/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import 'teachers_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(),
);

enum AuthStatus { checking, signedOut, signedIn, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.checking,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref) : super(const AuthState()) {
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    try {
      final user = await _repo.getCurrentUser();
      state = AuthState(
        status: user != null ? AuthStatus.signedIn : AuthStatus.signedOut,
        user: user,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.checking);
    try {
      final user = await _repo.signIn(email, password);
      state = AuthState(status: AuthStatus.signedIn, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'فشل تسجيل الدخول: البريد أو كلمة المرور غير صحيحة',
      );
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.signedOut);
    _clearCachedMosqueData();
  }

  /// إبطال كل مزوّدات بيانات المساجد/الدور/الحلقات/السجلات/المعلمات
  /// المخزّنة مؤقتاً، حتى لا تبقى بيانات حساب المعلمة السابقة في الذاكرة
  /// عند دخول معلمة أخرى من نفس الجهاز مباشرة بعد تسجيل الخروج.
  void _clearCachedMosqueData() {
    _ref.invalidate(mosquesStreamProvider);
    _ref.invalidate(activeMosquesProvider);
    _ref.invalidate(schoolsStreamProvider);
    _ref.invalidate(schoolsByMosqueProvider);
    _ref.invalidate(activeSchoolsByMosqueProvider);
    _ref.invalidate(teachingCirclesStreamProvider);
    _ref.invalidate(teachingCirclesBySchoolProvider);
    _ref.invalidate(activeTeachingCirclesBySchoolProvider);
    _ref.invalidate(rosterProvider);
    _ref.invalidate(teachersStreamProvider);
    _ref.invalidate(teachersByMosqueProvider);
  }

  void clearError() {
    state = state.copyWith(status: AuthStatus.signedOut, errorMessage: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider), ref),
);