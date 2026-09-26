import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/push_token_service.dart';

final pushTokenServiceProvider = Provider<PushTokenService>(
  (ref) => PushTokenService(),
);

/// هل الإذن ممنوح حالياً؟ يُستخدَم لإخفاء بطاقة "تفعيل الإشعارات" إن كان
/// الإذن ممنوحاً أصلاً (لا حاجة لعرضها من الأساس).
final notificationPermissionGrantedProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(pushTokenServiceProvider).hasPermission(),
);
