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

/// هل يوجد توكن جهاز محفوظ فعلاً في Firestore؟ (انظر توثيق [PushTokenService.hasSavedToken]
/// — يُستخدَم مع المزوّد أعلاه معاً: الإذن قد يكون ممنوحاً دون أن ينجح
/// تسجيل التوكن فعلياً لسبب تقني صامت).
final hasSavedPushTokenProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, uid) => ref.watch(pushTokenServiceProvider).hasSavedToken(uid),
);
