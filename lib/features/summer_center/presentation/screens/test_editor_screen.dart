import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/summer_test_pdf_generator.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_level.dart';
import '../../domain/entities/summer_question_type.dart';
import '../../domain/entities/summer_subject.dart';
import '../../domain/entities/summer_test.dart';
import '../../domain/entities/summer_test_question.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../providers/summer_center_provider.dart';
import '../providers/summer_test_provider.dart';
import '../widgets/question_editor_sheet.dart';
import 'test_preview_screen.dart';

/// شاشة إنشاء/تعديل اختبار — مشتركة بين المعلمة (صاحبة الاختبار) والمشرفة
/// (عند المراجعة)، بفارق واحد فقط يتحكم فيه [isSupervisorView]: تعديل
/// المشرفة لسؤال يُسجَّل في auditLog وتراه المعلمة لاحقاً، بينما تعديل
/// المعلمة لسؤالها الخاص لا يُسجَّل. حذف أي سؤال يُسجَّل دوماً بغض النظر
/// عن الفاعل (نفس منطق الـrepository).
class TestEditorScreen extends ConsumerWidget {
  final String testId;
  final SummerCenter center;
  final SummerLevel level;
  final SummerSubject subject;
  final String currentUid;
  final String currentName;
  final bool isSupervisorView;

  const TestEditorScreen({
    super.key,
    required this.testId,
    required this.center,
    required this.level,
    required this.subject,
    required this.currentUid,
    required this.currentName,
    required this.isSupervisorView,
  });

  Future<void> _renameTitle(BuildContext context, WidgetRef ref, SummerTest test) async {
    final controller = TextEditingController(text: test.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل عنوان الاختبار', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await ref.read(summerCenterRepositoryProvider).updateTestTitle(test.id, newTitle);
    }
  }

  Future<void> _addQuestion(BuildContext context, List<SummerTestQuestion> questions) async {
    final nextOrder = questions.isEmpty ? 1000.0 : questions.map((q) => q.order).reduce((a, b) => a > b ? a : b) + 1000.0;
    await showQuestionEditorSheet(context, testId: testId, order: nextOrder);
  }

  Future<void> _showQuestionMenu(
    BuildContext context,
    WidgetRef ref,
    List<SummerTestQuestion> questions,
    int index,
  ) async {
    final question = questions[index];
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryGreen),
              title: const Text('تعديل السؤال', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              enabled: index > 0,
              leading: const Icon(Icons.arrow_upward_rounded),
              title: const Text('نقل لأعلى', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(ctx).pop('up'),
            ),
            ListTile(
              enabled: index < questions.length - 1,
              leading: const Icon(Icons.arrow_downward_rounded),
              title: const Text('نقل لأسفل', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(ctx).pop('down'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('حذف السؤال', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    final repo = ref.read(summerCenterRepositoryProvider);

    switch (action) {
      case 'edit':
        await showQuestionEditorSheet(
          context,
          testId: testId,
          existing: question,
          auditedByUid: isSupervisorView ? currentUid : null,
          auditedByName: isSupervisorView ? currentName : null,
        );
        break;
      case 'up':
        final prev = questions[index - 1];
        await repo.updateQuestionOrder(question.id, prev.order);
        await repo.updateQuestionOrder(prev.id, question.order);
        break;
      case 'down':
        final next = questions[index + 1];
        await repo.updateQuestionOrder(question.id, next.order);
        await repo.updateQuestionOrder(next.id, question.order);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('حذف هذا السؤال؟', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
            content: const Text(
              'سيُحذف هذا السؤال وتُعاد ترقيم الأسئلة تلقائياً بعد الحفظ.',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await repo.deleteQuestion(
            testId: testId,
            questionId: question.id,
            questionSnapshot: question.questionText,
            byUid: currentUid,
            byName: currentName,
          );
        }
        break;
    }
  }

  Future<String?> _generatePdf(BuildContext context, WidgetRef ref, SummerTest test, List<SummerTestQuestion> questions) async {
    try {
      final mosques = ref.read(activeMosquesProvider);
      final mosqueName = mosques.where((m) => m.id == center.mosqueId).map((m) => m.name).firstOrNull ?? '';
      return await SummerTestPdfGenerator.generate(
        test: test,
        questions: questions,
        centerName: center.name,
        mosqueName: mosqueName,
        levelName: level.name,
        subjectName: subject.name,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر تصدير الملف: $e')));
      }
      return null;
    }
  }

  Future<void> _previewPdf(BuildContext context, WidgetRef ref, SummerTest test, List<SummerTestQuestion> questions) async {
    final path = await _generatePdf(context, ref, test, questions);
    if (path == null || !context.mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => File(path).readAsBytes(), name: test.title);
  }

  Future<void> _sharePdf(BuildContext context, WidgetRef ref, SummerTest test, List<SummerTestQuestion> questions) async {
    final path = await _generatePdf(context, ref, test, questions);
    if (path == null || !context.mounted) return;
    await Share.shareXFiles([XFile(path)], subject: test.title);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(summerTestProvider(testId));
    final questionsAsync = ref.watch(summerQuestionsProvider(testId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء اختبار'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'معاينة',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TestPreviewScreen(testId: testId, center: center, level: level, subject: subject),
              ),
            ),
          ),
        ],
      ),
      body: testAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
        data: (test) {
          if (test == null) {
            return const Center(child: Text('تعذّر العثور على الاختبار', style: TextStyle(fontFamily: 'Tajawal')));
          }
          return questionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
            data: (questions) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
                      ),
                      child: Column(
                        children: [
                          _infoRow('المركز', center.name),
                          _infoRow('المستوى', level.name),
                          _infoRow('المادة', subject.name),
                          _infoRow('المعلمة', test.teacherName),
                          _infoRow('التاريخ', '${test.hijriMonth} ${test.hijriYear}هـ', last: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _renameTitle(context, ref, test),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3FAF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCFE9D3), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primaryGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(test.title.isEmpty ? 'اضغطي لإضافة عنوان' : test.title,
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 3.5, height: 15, decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            const Text('الأسئلة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                          ],
                        ),
                        Text(
                          questions.length == 1 ? 'سؤال واحد' : '${questions.length} أسئلة',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: questions.isEmpty
                          ? Center(
                              child: Text('لا توجد أسئلة بعد — اضغطي "إضافة سؤال" بالأسفل',
                                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
                            )
                          : ListView.separated(
                              itemCount: questions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) => _QuestionCard(
                                index: i,
                                question: questions[i],
                                onMenu: () => _showQuestionMenu(context, ref, questions, i),
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: questions.isEmpty ? null : () => _sharePdf(context, ref, test, questions),
                            icon: const Icon(Icons.ios_share_rounded, size: 17),
                            label: const Text('مشاركة'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: questions.isEmpty ? null : () => _previewPdf(context, ref, test, questions),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                            label: const Text('تصدير PDF'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: testAsync.value == null
          ? null
          : questionsAsync.maybeWhen(
              data: (questions) => FloatingActionButton.extended(
                backgroundColor: AppTheme.goldAccent,
                onPressed: () => _addQuestion(context, questions),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('إضافة سؤال', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
              ),
              orElse: () => null,
            ),
    );
  }

  Widget _infoRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade500)),
          Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final SummerTestQuestion question;
  final VoidCallback onMenu;

  const _QuestionCard({required this.index, required this.question, required this.onMenu});

  Color _bgColorFor(String type) {
    switch (type) {
      case SummerQuestionType.multipleChoice:
        return const Color(0xFFE8F5E9);
      case SummerQuestionType.trueFalse:
        return const Color(0xFFFBF3E2);
      case SummerQuestionType.fillBlank:
        return const Color(0xFFE3F2FD);
      case SummerQuestionType.order:
        return const Color(0xFFE0F2F1);
      case SummerQuestionType.match:
        return const Color(0xFFFCE4EC);
      default:
        return const Color(0xFFEDEBFA);
    }
  }

  Color _fgColorFor(String type) {
    switch (type) {
      case SummerQuestionType.multipleChoice:
        return AppTheme.primaryGreen;
      case SummerQuestionType.trueFalse:
        return AppTheme.goldAccent;
      case SummerQuestionType.fillBlank:
        return const Color(0xFF1565C0);
      case SummerQuestionType.order:
        return const Color(0xFF00695C);
      case SummerQuestionType.match:
        return const Color(0xFFAD1457);
      default:
        return const Color(0xFF5E4B9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColorFor(question.type);
    final fg = _fgColorFor(question.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(8)),
            child: Text('${index + 1}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF616161))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(SummerQuestionType.label(question.type),
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
                ),
                const SizedBox(height: 5),
                Text(question.questionText, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: Color(0xFF333333), height: 1.6)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFC7C7C7)), onPressed: onMenu),
        ],
      ),
    );
  }
}
