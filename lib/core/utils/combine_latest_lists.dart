import 'dart:async';

/// يدمج عدة تدفقات قوائم في تدفق واحد: بعد أن يُصدر **كل** تدفق قيمته الأولى
/// يُصدر قائمة واحدة مسطَّحة (بترتيب التدفقات)، ثم يُعيد الإصدار كلما أصدر
/// أيٌّ منها قيمة جديدة. خطأ أي تدفق يُمرَّر كما هو، ويُغلَق الناتج عندما
/// تُغلَق كل التدفقات؛ وإلغاء الاشتراك فيه يُلغي كل الاشتراكات الداخلية.
///
/// بلا تدفقات: قائمة فارغة واحدة. بتدفق واحد: يُعاد هو نفسه.
Stream<List<T>> combineLatestLists<T>(List<Stream<List<T>>> sources) {
  if (sources.isEmpty) return Stream<List<T>>.value(<T>[]);
  if (sources.length == 1) return sources.first;

  final subscriptions = <StreamSubscription<List<T>>>[];
  final latest = List<List<T>?>.filled(sources.length, null);
  var received = 0;
  var open = sources.length;
  late final StreamController<List<T>> controller;

  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < sources.length; i++) {
        subscriptions.add(sources[i].listen(
          (value) {
            if (latest[i] == null) received++;
            latest[i] = value;
            if (received == sources.length) {
              controller.add([for (final part in latest) ...?part]);
            }
          },
          onError: controller.addError,
          onDone: () {
            open--;
            if (open == 0) controller.close();
          },
        ));
      }
    },
    onPause: () {
      for (final subscription in subscriptions) {
        subscription.pause();
      }
    },
    onResume: () {
      for (final subscription in subscriptions) {
        subscription.resume();
      }
    },
    onCancel: () =>
        Future.wait([for (final subscription in subscriptions) subscription.cancel()]),
  );
  return controller.stream;
}
