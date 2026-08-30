import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../data/summer_test_pdf_generator.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_level.dart';
import '../../domain/entities/summer_question_type.dart';
import '../../domain/entities/summer_subject.dart';
import '../../domain/entities/summer_test_question.dart';
import '../providers/summer_test_provider.dart';

/// معاينة ورقة الاختبار على الشاشة قبل التصدير — لا تُظهر أي إجابة صحيحة
/// إطلاقاً (نفس قاعدة مولّد PDF تماماً)، فهي تمثيل مبسَّط لنفس محتوى
/// الملف الذي سيُصدَّر لاحقاً.
class TestPreviewScreen extends ConsumerWidget {
  final String testId;
  final SummerCenter center;
  final SummerLevel level;
  final SummerSubject subject;

  const TestPreviewScreen({
    super.key,
    required this.testId,
    required this.center,
    required this.level,
    required this.subject,
  });

  Future<String?> _generatePdf(BuildContext context, WidgetRef ref) async {
    final test = ref.read(summerTestProvider(testId)).value;
    final questions = ref.read(summerQuestionsProvider(testId)).value ?? const [];
    if (test == null) return null;
    try {
      final mosques = ref.read(activeMosquesProvider);
      final mosque = mosques.where((m) => m.id == center.mosqueId).firstOrNull;

      Uint8List? headerLogoBytes;
      if (mosque?.headerLogoBase64 != null && mosque!.headerLogoBase64!.isNotEmpty) {
        try {
          headerLogoBytes = base64Decode(mosque.headerLogoBase64!);
        } catch (_) {
          // شعار تالف أو غير صالح: نتجاهله ونترك مكانه فارغاً
        }
      }

      return await SummerTestPdfGenerator.generate(
        test: test,
        questions: questions,
        centerName: center.name,
        mosqueName: mosque?.name ?? '',
        levelName: level.name,
        subjectName: subject.name,
        rightHeaderText: mosque?.rightHeaderText,
        leftHeaderText: mosque?.leftHeaderText,
        headerLogoBytes: headerLogoBytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر تصدير الملف: $e')));
      }
      return null;
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final path = await _generatePdf(context, ref);
    if (path == null || !context.mounted) return;
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final path = await _generatePdf(context, ref);
    if (path == null || !context.mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => File(path).readAsBytes());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(summerTestProvider(testId));
    final questionsAsync = ref.watch(summerQuestionsProvider(testId));

    return Scaffold(
      appBar: AppBar(title: const Text('معاينة الاختبار')),
      body: testAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
        data: (test) {
          if (test == null) return const SizedBox.shrink();
          return questionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
            data: (questions) {
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE4E4E4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${test.title} — مادة ${subject.name}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Container(height: 1.4, color: Colors.black87),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.black87)),
                              child: Wrap(
                                spacing: 14,
                                runSpacing: 5,
                                children: [
                                  _metaChip('المسجد', center.name),
                                  _metaChip('المستوى', level.name),
                                  _metaChip('المعلمة', test.teacherName),
                                  _metaChip('التاريخ', '${test.hijriMonth} ${test.hijriYear}هـ'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            for (var i = 0; i < questions.length; i++) ...[
                              _PreviewQuestion(index: i + 1, question: questions[i]),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: questions.isEmpty ? null : () => _share(context, ref),
                            icon: const Icon(Icons.ios_share_rounded, size: 16),
                            label: const Text('مشاركة'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: questions.isEmpty ? null : () => _exportPdf(context, ref),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                            label: const Text('تصدير PDF'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _metaChip(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.black87),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _PreviewQuestion extends StatelessWidget {
  final int index;
  final SummerTestQuestion question;

  const _PreviewQuestion({required this.index, required this.question});

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case SummerQuestionType.multipleChoice:
        final options = (question.typeData['options'] as List?)?.cast<String>() ?? const [];
        const letters = ['أ', 'ب', 'ج', 'د', 'ه‍', 'و'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _qLine('$index. ${question.questionText}'),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 14, top: 3),
                child: Text('${letters[i % letters.length]}) ${options[i]}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
              ),
          ],
        );

      case SummerQuestionType.trueFalse:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _qLine('$index. ${question.questionText}.'),
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 4),
              child: Row(
                children: [
                  _tfBox('صح'),
                  const SizedBox(width: 20),
                  _tfBox('خطأ'),
                ],
              ),
            ),
          ],
        );

      case SummerQuestionType.essay:
      case SummerQuestionType.mention:
      case SummerQuestionType.define:
      case SummerQuestionType.explainWhy:
        final lines = question.typeData['answerLines'] as int? ?? 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _qLine('$index. ${question.questionText}'),
            for (var i = 0; i < lines; i++)
              Container(
                margin: const EdgeInsets.only(top: 12, right: 4, left: 4),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFBBBBBB), width: 0.8))),
              ),
          ],
        );

      case SummerQuestionType.fillBlank:
        return _qLine('$index. ${question.questionText.replaceAll('___', '  ..............  ')}');

      case SummerQuestionType.order:
        final items = (question.typeData['items'] as List?)?.cast<String>() ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _qLine('$index. ${question.questionText}'),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(right: 14, top: 5),
                child: Row(
                  children: [
                    Container(width: 22, height: 16, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade600))),
                    const SizedBox(width: 8),
                    Text(item, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                  ],
                ),
              ),
          ],
        );

      case SummerQuestionType.match:
        final pairs = (question.typeData['pairs'] as List?)?.cast<Map>() ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _qLine('$index. ${question.questionText}'),
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < pairs.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('${i + 1}) ${pairs[i]['left'] as String? ?? ''}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final p in pairs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(p['right'] as String? ?? '', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      default:
        return _qLine('$index. ${question.questionText}');
    }
  }

  Widget _qLine(String text) {
    return Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w700));
  }

  // كلمة الخيار يليها قوس فارغ (تماماً كما في ملف PDF المُصدَّر) بدل صندوق
  // محاط بالكلمة — بلا أي حدود.
  Widget _tfBox(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        const Text('(        )', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
      ],
    );
  }
}
