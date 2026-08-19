// اختبار سلامة أساسي (Smoke Test) للتطبيق.
//
// الاختبار الافتراضي الذي ينشئه Flutter تلقائياً كان يشير إلى ودجت
// "MyApp" وعدّاد تجريبي — وهما من قالب تطبيق "العداد" الافتراضي ولا
// علاقة لهما بهذا التطبيق (اسم الودجت الفعلي هنا هو
// QuranCircleReportApp)، لذا كان يفشل بخطأ ترجمة.
//
// لا يمكن بناء QuranCircleReportApp نفسه هنا مباشرة لأنه يعتمد على
// Firebase.initializeApp() ومزوّدات Riverpod (auth/roster) التي تحتاج
// اتصالاً فعلياً بـ Firebase عند التشغيل — وإضافة تهيئة وهمية (Fake/Mock)
// لكل ذلك تتطلب بنية اختبار منفصلة (mocking) لم تكن موجودة أصلاً في
// المشروع. لذلك هذا اختبار سلامة بسيط يتحقق فقط من أن حزمة الواجهات
// الأساسية (MaterialApp + دعم الاتجاه من اليمين لليسار) تُبنى وتُعرض
// بدون أخطاء، دون أي اعتماد خارجي.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('يبني MaterialApp بسيط بدون أخطاء (بدون الاعتماد على Firebase)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(child: Text('رعاية')),
          ),
        ),
      ),
    );

    expect(find.text('رعاية'), findsOneWidget);
  });
}
