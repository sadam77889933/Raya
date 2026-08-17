import 'package:flutter/material.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// ودجت قابلة لإعادة الاستخدام لاختيار "المنهج المصاحب" (تعدد اختيار)
/// لحلقة كاملة خلال شهر واحد.
///
/// القرار المعماري: هذا الاختيار يخص الحلقة كلها وليس طالبة بعينها
/// (لأن كل الطالبات يُدرَّسن نفس المنهج المصاحب في نفس الأيام)، لذلك
/// يظهر مرة واحدة فقط أعلى شاشة بيانات الطالبات، بدل تكراره داخل كل
/// بطاقة طالبة على حدة.
///
/// قابل للطي: يبدأ مفتوحاً إن لم يُختر شيء بعد (لتشجيع المعلمة على
/// الاختيار)، ومطوياً إن كان هناك اختيار سابق (كإعادة فتح تقرير قديم
/// أو الرجوع لنفس الشاشة)، لتوفير مساحة الشاشة خصوصاً على الجوالات
/// الصغيرة — مع إمكانية فتحه وطيّه يدوياً بالضغط على العنوان في أي وقت.
class CompanionCurriculumSelector extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const CompanionCurriculumSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<CompanionCurriculumSelector> createState() =>
      _CompanionCurriculumSelectorState();
}

class _CompanionCurriculumSelectorState
    extends State<CompanionCurriculumSelector> {
  late bool _expanded;
  bool _showAddField = false;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // مطوي افتراضياً فقط إن كان هناك اختيار سابق محفوظ (تعديل تقرير
    // أو رجوع لنفس الشاشة)، وإلا يبقى مفتوحاً ليُلفت نظر المعلمة.
    _expanded = widget.selected.isEmpty;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  List<String> get _fixedOptions => QuranConstants.companionCurriculums
      .where((c) => c != 'أخرى')
      .toList();

  /// أي قيمة مُختارة حالياً وغير موجودة أصلاً ضمن القائمة الثابتة
  /// تعني أنها أُضيفت يدوياً عبر "+ أخرى".
  List<String> get _customSelected =>
      widget.selected.where((c) => !_fixedOptions.contains(c)).toList();

  void _toggle(String value) {
    final updated = [...widget.selected];
    if (updated.contains(value)) {
      updated.remove(value);
    } else {
      updated.add(value);
    }
    widget.onChanged(updated);
  }

  void _addCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    if (!widget.selected.contains(text)) {
      widget.onChanged([...widget.selected, text]);
    }
    _customController.clear();
    setState(() => _showAddField = false);
  }

  void _removeCustom(String value) {
    widget.onChanged(widget.selected.where((c) => c != value).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 12, 14, _expanded ? 14 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.45),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 15,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'المنهج المصاحب لهذا الشهر',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ],
            ),
          ),
          if (!_expanded) ...[
            const SizedBox(height: 4),
            Text(
              widget.selected.isEmpty
                  ? 'لم تُحدَّد بعد — اضغطي هنا للاختيار (اختياري)'
                  : widget.selected.join(' + '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.5,
                fontWeight:
                    widget.selected.isEmpty ? FontWeight.w400 : FontWeight.w700,
                color: widget.selected.isEmpty
                    ? Colors.grey.shade500
                    : AppTheme.primaryGreen,
              ),
            ),
          ],
          if (_expanded) ...[
            const SizedBox(height: 4),
            Text(
              'اختاري كل ما دُرّس للطالبات خلال الشهر (يمكن اختيار أكثر من مادة) — اختيارك يُطبَّق تلقائياً على كل الطالبات',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10.5,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._fixedOptions.map(
                  (c) =>
                      _chip(c, widget.selected.contains(c), () => _toggle(c)),
                ),
                ..._customSelected.map(
                  (c) => _chip(c, true, () => _removeCustom(c)),
                ),
                _addChip(),
              ],
            ),
            if (_showAddField) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.goldAccent.withOpacity(0.06),
                  border:
                      Border.all(color: AppTheme.goldAccent.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customController,
                        autofocus: true,
                        style: const TextStyle(
                            fontFamily: 'Tajawal', fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'اكتبي اسم المنهج الجديد...',
                          hintStyle:
                              TextStyle(fontFamily: 'Tajawal', fontSize: 11),
                        ),
                        onSubmitted: (_) => _addCustom(),
                      ),
                    ),
                    TextButton(
                      onPressed: _addCustom,
                      child: const Text(
                        'إضافة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w700,
                          color: AppTheme.goldAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'سيظهر في التقرير: ${widget.selected.join(' + ')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lightGreen : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 13, color: AppTheme.primaryGreen),
            if (selected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppTheme.primaryGreen : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addChip() {
    return GestureDetector(
      onTap: () => setState(() => _showAddField = !_showAddField),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.goldAccent, width: 1.2),
        ),
        child: const Text(
          '+ أخرى',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.goldAccent,
          ),
        ),
      ),
    );
  }
}
