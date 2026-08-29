import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/summer_question_type.dart';
import '../../domain/entities/summer_test_question.dart';
import '../providers/summer_center_provider.dart';

IconData iconForQuestionType(String type) {
  switch (type) {
    case SummerQuestionType.trueFalse:
      return Icons.rule_rounded;
    case SummerQuestionType.multipleChoice:
      return Icons.checklist_rounded;
    case SummerQuestionType.essay:
      return Icons.edit_note_rounded;
    case SummerQuestionType.fillBlank:
      return Icons.space_bar_rounded;
    case SummerQuestionType.order:
      return Icons.low_priority_rounded;
    case SummerQuestionType.match:
      return Icons.sync_alt_rounded;
    case SummerQuestionType.mention:
      return Icons.format_list_bulleted_rounded;
    case SummerQuestionType.define:
      return Icons.menu_book_rounded;
    case SummerQuestionType.explainWhy:
      return Icons.psychology_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

/// ورقة سفلية لاختيار نوع سؤال جديد (9 أنواع) — تُعرض فقط عند إضافة سؤال
/// جديد؛ لا يمكن تغيير نوع سؤال موجود لاحقاً (يبقى ثابتاً عند التعديل).
Future<String?> showQuestionTypeChooser(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    // مع isScrollControlled: تُتاح الورقة كامل ارتفاع الشاشة عند الحاجة،
    // وبداخلها SingleChildScrollView + SafeArea يضمنان تمرير المحتوى
    // بدل فيضانه على الشاشات الأصغر أو عند ظهور فتحة سفلية إضافية
    // (زر التنقّل بالإيماءات) بدل قصّ آخر صف من الأنواع.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
              const Text('اختاري نوع السؤال',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
              const SizedBox(height: 4),
              Text('لكل نوع حقوله الخاصة وشكله المناسب عند الطباعة',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: SummerQuestionType.all.map((type) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(ctx).pop(type),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconForQuestionType(type), size: 22, color: AppTheme.primaryGreen),
                          const SizedBox(height: 7),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              SummerQuestionType.label(type),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// افتح محرر سؤال. لإضافة سؤال جديد مرّري [existing] = null (سيُعرض
/// اختيار النوع أولاً، ثم محرر النوع المختار)، ولتعديل سؤال موجود مرّري
/// [existing] فقط — يبقى نوعه ثابتاً ولا يظهر اختيار نوع جديد.
///
/// مرّري [auditedByUid]/[auditedByName] فقط عندما تكون من تفتح المحرر
/// مشرفة تراجع اختبار معلمة أخرى (يُسجَّل التعديل في auditLog وتراه
/// المعلمة لاحقاً)؛ اتركيهما null عندما تعدّل المعلمة سؤالها الخاص.
Future<bool> showQuestionEditorSheet(
  BuildContext context, {
  required String testId,
  double order = 0,
  SummerTestQuestion? existing,
  String? auditedByUid,
  String? auditedByName,
}) async {
  var type = existing?.type;
  if (type == null) {
    type = await showQuestionTypeChooser(context);
    if (type == null) return false;
  }
  if (!context.mounted) return false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _QuestionEditorSheet(
      testId: testId,
      type: type!,
      order: order,
      existing: existing,
      auditedByUid: auditedByUid,
      auditedByName: auditedByName,
    ),
  );
  return saved ?? false;
}

class _QuestionEditorSheet extends ConsumerStatefulWidget {
  final String testId;
  final String type;
  final double order;
  final SummerTestQuestion? existing;
  final String? auditedByUid;
  final String? auditedByName;

  const _QuestionEditorSheet({
    required this.testId,
    required this.type,
    required this.order,
    this.existing,
    this.auditedByUid,
    this.auditedByName,
  });

  @override
  ConsumerState<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends ConsumerState<_QuestionEditorSheet> {
  late final TextEditingController _questionController;
  bool _saving = false;

  // صح/خطأ
  bool _tfCorrect = true;

  // اختيار من متعدد
  late List<TextEditingController> _optionControllers;
  int? _correctIndex;

  // مقالي/اذكري/عرّفي/عللي
  int _answerLines = 3;

  // أكمل الفراغ
  late List<TextEditingController> _blankAnswerControllers;

  // رتّب
  late List<TextEditingController> _orderItemControllers;

  // وصّل
  late List<TextEditingController> _matchLeftControllers;
  late List<TextEditingController> _matchRightControllers;

  bool get _isEdit => widget.existing != null;
  bool get _isSupervisorEdit => widget.auditedByUid != null;

  /// يُعيد بناء الواجهة عند كل تغيير نص، حتى يعكس زر الحفظ صلاحية الإدخال
  /// فوراً (وليس فقط بعد إضافة/حذف عنصر الذي يستدعي setState أصلاً).
  void _markDirty() {
    if (mounted) setState(() {});
  }

  TextEditingController _newController([String text = '']) {
    final c = TextEditingController(text: text);
    c.addListener(_markDirty);
    return c;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final typeData = existing?.typeData ?? const <String, dynamic>{};
    _questionController = _newController(existing?.questionText ?? '');

    if (widget.type == SummerQuestionType.trueFalse) {
      _tfCorrect = typeData['correctAnswer'] as bool? ?? true;
    }

    final options = (typeData['options'] as List?)?.cast<String>() ?? const <String>['', ''];
    _optionControllers = options.isEmpty
        ? [_newController(), _newController()]
        : options.map((o) => _newController(o)).toList();
    _correctIndex = typeData['correctIndex'] as int?;

    _answerLines = typeData['answerLines'] as int? ?? 3;

    final blankAnswers = (typeData['answers'] as List?)?.cast<String>() ?? const <String>[];
    _blankAnswerControllers = blankAnswers.map((a) => _newController(a)).toList();

    final orderItems = (typeData['items'] as List?)?.cast<String>() ?? const <String>['', ''];
    _orderItemControllers = orderItems.isEmpty
        ? [_newController(), _newController()]
        : orderItems.map((i) => _newController(i)).toList();

    final pairs = (typeData['pairs'] as List?)?.cast<Map>() ?? const <Map>[];
    if (pairs.isEmpty) {
      _matchLeftControllers = [_newController()];
      _matchRightControllers = [_newController()];
    } else {
      _matchLeftControllers = pairs.map((p) => _newController(p['left'] as String? ?? '')).toList();
      _matchRightControllers = pairs.map((p) => _newController(p['right'] as String? ?? '')).toList();
    }

    if (widget.type == SummerQuestionType.fillBlank) {
      _questionController.addListener(_syncBlankAnswersCount);
    }
  }

  int get _blanksCount => '___'.allMatches(_questionController.text).length;

  void _syncBlankAnswersCount() {
    final needed = _blanksCount;
    if (_blankAnswerControllers.length == needed) return;
    setState(() {
      if (_blankAnswerControllers.length < needed) {
        while (_blankAnswerControllers.length < needed) {
          _blankAnswerControllers.add(_newController());
        }
      } else {
        _blankAnswerControllers = _blankAnswerControllers.sublist(0, needed);
      }
    });
  }

  void _insertBlank() {
    final selection = _questionController.selection;
    final text = _questionController.text;
    final insertAt = selection.start >= 0 ? selection.start : text.length;
    final newText = text.replaceRange(insertAt, insertAt < 0 ? 0 : (selection.end >= 0 ? selection.end : insertAt), '___');
    _questionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + 3),
    );
    _syncBlankAnswersCount();
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    for (final c in _blankAnswerControllers) {
      c.dispose();
    }
    for (final c in _orderItemControllers) {
      c.dispose();
    }
    for (final c in _matchLeftControllers) {
      c.dispose();
    }
    for (final c in _matchRightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildTypeData() {
    switch (widget.type) {
      case SummerQuestionType.trueFalse:
        return {'correctAnswer': _tfCorrect};
      case SummerQuestionType.multipleChoice:
        return {
          'options': _optionControllers.map((c) => c.text.trim()).toList(),
          'correctIndex': _correctIndex,
        };
      case SummerQuestionType.essay:
      case SummerQuestionType.mention:
      case SummerQuestionType.define:
      case SummerQuestionType.explainWhy:
        return {'answerLines': _answerLines};
      case SummerQuestionType.fillBlank:
        return {'answers': _blankAnswerControllers.map((c) => c.text.trim()).toList()};
      case SummerQuestionType.order:
        return {'items': _orderItemControllers.map((c) => c.text.trim()).toList()};
      case SummerQuestionType.match:
        return {
          'pairs': List.generate(_matchLeftControllers.length, (i) {
            return {
              'left': _matchLeftControllers[i].text.trim(),
              'right': _matchRightControllers[i].text.trim(),
            };
          }),
        };
      default:
        return {};
    }
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    switch (widget.type) {
      case SummerQuestionType.multipleChoice:
        final filled = _optionControllers.where((c) => c.text.trim().isNotEmpty).length;
        return filled >= 2 && _correctIndex != null && _correctIndex! < _optionControllers.length;
      case SummerQuestionType.order:
        return _orderItemControllers.where((c) => c.text.trim().isNotEmpty).length >= 2;
      case SummerQuestionType.match:
        for (var i = 0; i < _matchLeftControllers.length; i++) {
          if (_matchLeftControllers[i].text.trim().isEmpty || _matchRightControllers[i].text.trim().isEmpty) {
            return false;
          }
        }
        return _matchLeftControllers.isNotEmpty;
      default:
        return true;
    }
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(summerCenterRepositoryProvider);
    final typeData = _buildTypeData();
    final questionText = _questionController.text.trim();
    try {
      if (_isEdit) {
        await repo.updateQuestion(
          testId: widget.testId,
          questionId: widget.existing!.id,
          type: widget.type,
          questionText: questionText,
          typeData: typeData,
          auditedByUid: widget.auditedByUid,
          auditedByName: widget.auditedByName,
        );
      } else {
        await repo.addQuestion(
          testId: widget.testId,
          type: widget.type,
          order: widget.order,
          questionText: questionText,
          typeData: typeData,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fieldLabel(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.w700, color: color ?? Colors.grey.shade700)),
    );
  }

  Widget _questionTextField() {
    return TextField(
      controller: _questionController,
      maxLines: 3,
      minLines: 1,
      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
      decoration: const InputDecoration(hintText: 'اكتبي نص السؤال هنا...'),
    );
  }

  Widget _buildTypeFields() {
    switch (widget.type) {
      case SummerQuestionType.trueFalse:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('الإجابة الصحيحة'),
            Row(
              children: [
                Expanded(child: _tfOption('صح', true)),
                const SizedBox(width: 10),
                Expanded(child: _tfOption('خطأ', false)),
              ],
            ),
          ],
        );

      case SummerQuestionType.multipleChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('الخيارات — حدّدي الإجابة الصحيحة'),
            for (var i = 0; i < _optionControllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Radio<int>(
                      value: i,
                      groupValue: _correctIndex,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (value) => setState(() => _correctIndex = value),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[i],
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5),
                        decoration: InputDecoration(hintText: 'الخيار ${i + 1}'),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 17, color: Colors.grey),
                        onPressed: () => setState(() {
                          _optionControllers.removeAt(i).dispose();
                          if (_correctIndex == i) _correctIndex = null;
                        }),
                      ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _optionControllers.add(_newController())),
              icon: const Icon(Icons.add_rounded, size: 17, color: AppTheme.goldAccent),
              label: const Text('إضافة خيار', style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.goldAccent, fontWeight: FontWeight.w700)),
            ),
          ],
        );

      case SummerQuestionType.essay:
      case SummerQuestionType.mention:
      case SummerQuestionType.define:
      case SummerQuestionType.explainWhy:
        return Row(
          children: [
            _fieldLabel('عدد أسطر الإجابة عند الطباعة'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: _answerLines > 1 ? () => setState(() => _answerLines--) : null,
            ),
            Text('$_answerLines', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: _answerLines < 10 ? () => setState(() => _answerLines++) : null,
            ),
          ],
        );

      case SummerQuestionType.fillBlank:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _insertBlank,
                icon: const Icon(Icons.space_bar_rounded, size: 15, color: AppTheme.goldAccent),
                label: const Text('إدراج فراغ', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: AppTheme.goldAccent, fontWeight: FontWeight.w700)),
              ),
            ),
            if (_blankAnswerControllers.isNotEmpty) ...[
              _fieldLabel('الإجابات الصحيحة للفراغات (اختياري)'),
              for (var i = 0; i < _blankAnswerControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFFBF3E2), borderRadius: BorderRadius.circular(7)),
                        child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.goldAccent)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _blankAnswerControllers[i],
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5),
                          decoration: const InputDecoration(hintText: 'الإجابة'),
                        ),
                      ),
                    ],
                  ),
                ),
              Text('تُطبع الفراغات في ورقة الاختبار كأسطر منقّطة فارغة بنفس مواضعها.',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade500, height: 1.7)),
            ],
          ],
        );

      case SummerQuestionType.order:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('العناصر بالترتيب الصحيح'),
            for (var i = 0; i < _orderItemControllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Column(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 22),
                          icon: const Icon(Icons.arrow_upward_rounded, size: 15),
                          onPressed: i > 0
                              ? () => setState(() {
                                    final item = _orderItemControllers.removeAt(i);
                                    _orderItemControllers.insert(i - 1, item);
                                  })
                              : null,
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 22),
                          icon: const Icon(Icons.arrow_downward_rounded, size: 15),
                          onPressed: i < _orderItemControllers.length - 1
                              ? () => setState(() {
                                    final item = _orderItemControllers.removeAt(i);
                                    _orderItemControllers.insert(i + 1, item);
                                  })
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(7)),
                      child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _orderItemControllers[i],
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5),
                        decoration: InputDecoration(hintText: 'العنصر ${i + 1}'),
                      ),
                    ),
                    if (_orderItemControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 17, color: Colors.grey),
                        onPressed: () => setState(() => _orderItemControllers.removeAt(i).dispose()),
                      ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _orderItemControllers.add(_newController())),
              icon: const Icon(Icons.add_rounded, size: 17, color: AppTheme.goldAccent),
              label: const Text('إضافة عنصر', style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.goldAccent, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(color: const Color(0xFFF3FAF4), borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shuffle_rounded, size: 14, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'تُطبع العناصر في ورقة الاختبار بترتيب مخلوط تلقائياً، مع مربّع فارغ أمام كل عنصر تكتب فيه الطالبة رقمه الصحيح.',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade700, height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case SummerQuestionType.match:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('الأزواج المتطابقة'),
            for (var i = 0; i < _matchLeftControllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _matchLeftControllers[i],
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                        decoration: const InputDecoration(hintText: 'العمود الأول'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.sync_alt_rounded, size: 16, color: AppTheme.goldAccent),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _matchRightControllers[i],
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                        decoration: const InputDecoration(hintText: 'العمود الثاني'),
                      ),
                    ),
                    if (_matchLeftControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 17, color: Colors.grey),
                        onPressed: () => setState(() {
                          _matchLeftControllers.removeAt(i).dispose();
                          _matchRightControllers.removeAt(i).dispose();
                        }),
                      ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => setState(() {
                _matchLeftControllers.add(_newController());
                _matchRightControllers.add(_newController());
              }),
              icon: const Icon(Icons.add_rounded, size: 17, color: AppTheme.goldAccent),
              label: const Text('إضافة زوج', style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.goldAccent, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(color: const Color(0xFFF3FAF4), borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shuffle_rounded, size: 14, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'يُطبع العمود الثاني بترتيب مخلوط تلقائياً في ورقة الاختبار، وتصل الطالبة بينهما بخط أو برقم.',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade700, height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _tfOption(String label, bool value) {
    final selected = _tfCorrect == value;
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => setState(() => _tfCorrect = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? AppTheme.primaryGreen : const Color(0xFFECECEC), width: 1.4),
        ),
        child: Text(label,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(_isEdit ? 'تعديل السؤال' : 'إضافة سؤال',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFBF3E2), borderRadius: BorderRadius.circular(20)),
                      child: Text(SummerQuestionType.label(widget.type),
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.goldAccent)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _fieldLabel(widget.type == SummerQuestionType.fillBlank ? 'نص السؤال — اضغطي "إدراج فراغ" في موضع النقص' : 'نص السؤال'),
              _questionTextField(),
              const SizedBox(height: 14),
              _buildTypeFields(),
              if (_isSupervisorEdit) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFBF3E2), borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.history_rounded, size: 13, color: AppTheme.goldAccent),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'يُسجَّل في الاختبار أن هذا السؤال عُدِّل بواسطة المشرفة مع التاريخ — ويظهر ذلك للمعلمة صاحبة الاختبار.',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFF6B5416), height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_isValid && !_saving) ? _save : null,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEdit ? 'حفظ التعديل' : 'حفظ السؤال'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
