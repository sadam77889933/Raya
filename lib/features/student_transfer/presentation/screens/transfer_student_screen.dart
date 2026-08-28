import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/teachers_provider.dart';
import '../../../mosques/domain/entities/school.dart';
import '../../../mosques/domain/entities/teaching_circle.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../roster/domain/entities/roster_student.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../providers/student_transfer_provider.dart';

/// شاشة نقل طالبة من حلقة إلى حلقة أخرى (داخل نفس المسجد أو بين مسجدين).
///
/// متاحة فقط لمشرفة المسجد والمشرف العام — تُفتح فقط من بطاقة مخصَّصة في
/// لوحتيهما، ولا يوجد أي رابط أو مسار تصل عبره المعلمة إليها.
class TransferStudentScreen extends ConsumerStatefulWidget {
  /// عند تمرير هذه القيمة (مشرفة مسجد)، يُقفَل حقل "المسجد" في القسمين
  /// (من/إلى) على هذا المسجد فقط، بلا أي قائمة اختيار — فلا يمكنها النقل
  /// من أو إلى مسجد آخر. عند تركها null (المشرف العام)، يظهر حقل اختيار
  /// حقيقي للمسجد في القسمين، فيصبح بإمكانها نقل طالبة بين مسجدين مختلفين.
  final String? lockedMosqueId;

  const TransferStudentScreen({super.key, this.lockedMosqueId});

  @override
  ConsumerState<TransferStudentScreen> createState() =>
      _TransferStudentScreenState();
}

class _TransferStudentScreenState extends ConsumerState<TransferStudentScreen> {
  // من أين (المصدر)
  String? _sourceMosqueId;
  String? _sourceSchoolId;
  String? _sourceCircleId;
  String? _selectedStudentId;

  // إلى أين (الوجهة)
  String? _destMosqueId;
  String? _destSchoolId;
  String? _destCircleId;

  // تاريخ النقل (هجري)
  late String _transferMonth;
  String _transferYear = '';

  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isLocked => widget.lockedMosqueId != null;

  @override
  void initState() {
    super.initState();
    _sourceMosqueId = widget.lockedMosqueId;
    _destMosqueId = widget.lockedMosqueId;
    final today = HijriCalendar.now();
    _transferMonth = QuranConstants.hijriMonths[today.hMonth - 1];
    _transferYear = today.hYear.toString();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool _canSubmit() {
    if (_selectedStudentId == null) return false;
    if (_sourceCircleId == null) return false;
    if (_destCircleId == null) return false;
    if (_destCircleId == _sourceCircleId) return false;
    if (!_isLocked && (_destMosqueId == null || _destSchoolId == null)) {
      return false;
    }
    if (_transferYear.trim().isEmpty) return false;
    return true;
  }

  // ───────────────────────── حلّ الأسماء المقروءة ─────────────────────────

  String _mosqueNameOf(String? id) {
    if (id == null) return '';
    return ref.read(activeMosquesProvider).where((m) => m.id == id).firstOrNull?.name ?? '';
  }

  String _schoolNameOf(String? mosqueId, String? schoolId) {
    if (mosqueId == null || schoolId == null) return '';
    return ref
            .read(activeSchoolsByMosqueProvider(mosqueId))
            .where((s) => s.id == schoolId)
            .firstOrNull
            ?.name ??
        '';
  }

  String _circleNameOf(String? schoolId, String? circleId) {
    if (schoolId == null || circleId == null) return '';
    return ref
            .read(activeTeachingCirclesBySchoolProvider(schoolId))
            .where((c) => c.id == circleId)
            .firstOrNull
            ?.name ??
        '';
  }

  String _studentNameOf(String? circleId, String? studentId) {
    if (circleId == null || studentId == null) return '';
    return ref
            .read(rosterProvider(circleId))
            .activeStudents
            .where((s) => s.id == studentId)
            .firstOrNull
            ?.name ??
        '';
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]} ${parts[1][0]}';
    }
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '؟';
  }

  // ───────────────────────────── تنفيذ النقل ──────────────────────────────

  Future<void> _onConfirmPressed() async {
    final studentName = _studentNameOf(_sourceCircleId, _selectedStudentId);
    final fromMosqueName = _mosqueNameOf(_sourceMosqueId);
    final fromSchoolName = _schoolNameOf(_sourceMosqueId, _sourceSchoolId);
    final fromCircleName = _circleNameOf(_sourceSchoolId, _sourceCircleId);
    final toMosqueName = _mosqueNameOf(_destMosqueId);
    final toSchoolName = _schoolNameOf(_destMosqueId, _destSchoolId);
    final toCircleName = _circleNameOf(_destSchoolId, _destCircleId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppTheme.lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 10),
            const Text(
              'تأكيد النقل',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  height: 1.9,
                  color: Colors.black87,
                ),
                children: [
                  const TextSpan(text: 'سيتم نقل الطالبة '),
                  TextSpan(
                    text: studentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                  ),
                  const TextSpan(text: ' من '),
                  TextSpan(
                    text: '$fromCircleName – $fromSchoolName – $fromMosqueName',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' إلى '),
                  TextSpan(
                    text: '$toCircleName – $toSchoolName – $toMosqueName',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.goldAccent),
                  ),
                  const TextSpan(text: ' ابتداءً من '),
                  TextSpan(
                    text: '$_transferMonth ${_transferYear.trim()}هـ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'التقارير السابقة للطالبة تبقى كما هي ولا تتأثر بهذا النقل.',
              style: TextStyle(
                  fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأكيد النقل', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    final user = ref.read(authProvider).user;

    try {
      await ref.read(studentTransferRepositoryProvider).transferStudent(
            studentId: _selectedStudentId!,
            studentName: studentName,
            fromMosqueId: _sourceMosqueId!,
            fromMosqueName: fromMosqueName,
            fromSchoolId: _sourceSchoolId!,
            fromSchoolName: fromSchoolName,
            fromCircleId: _sourceCircleId!,
            fromCircleName: fromCircleName,
            toMosqueId: _destMosqueId!,
            toMosqueName: toMosqueName,
            toSchoolId: _destSchoolId!,
            toSchoolName: toSchoolName,
            toCircleId: _destCircleId!,
            toCircleName: toCircleName,
            transferHijriMonth: _transferMonth,
            transferHijriYear: _transferYear.trim(),
            performedByUid: user?.uid ?? '',
            performedByName: user?.name ?? '',
            reason: _reasonController.text.trim(),
          );

      // إشعارات النقل: خطوة "أفضل جهد" منفصلة تماماً عن معاملة النقل نفسها
      // أعلاه — نجاح النقل لا يجوز أبداً أن يتوقف على نجاح إرسال الإشعار.
      // انظر توثيق _sendTransferNotifications للتفاصيل.
      await _sendTransferNotifications(
        studentName: studentName,
        fromMosqueName: fromMosqueName,
        fromCircleName: fromCircleName,
        toMosqueName: toMosqueName,
        toCircleName: toCircleName,
        performedByName: user?.name ?? '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم نقل الطالبة "$studentName" بنجاح',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      // نميّز رفض الصلاحيات عن بقية الأخطاء بدل رسالة "تأكدي من الإنترنت"
      // المضلِّلة في هذه الحالة تحديداً — يساعد هذا على تشخيص المشكلة الحقيقية
      // (مثلاً: قواعد أمان Firestore لا تسمح بعد بالكتابة في مجموعة النقل
      // الجديدة) بدل الإيحاء بأنها مشكلة اتصال بالإنترنت.
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'ليس لديكِ صلاحية لتنفيذ عملية النقل. تواصلي مع مطوّر التطبيق.'
          : 'تعذّر تنفيذ النقل (${e.code}). تأكدي من الاتصال بالإنترنت وحاولي مرة أخرى';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade600,
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade600,
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'تعذّر تنفيذ النقل، تأكدي من الاتصال بالإنترنت وحاولي مرة أخرى',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// يرسل إشعارات النقل الثلاثة (معلمة المصدر، معلمة الوجهة، المشرف العام)
  /// بعد نجاح النقل فعلياً. عمداً بدون أي `throw` يخرج من هذه الدالة —
  /// فشل الإشعار (مثلاً: خطأ شبكة عابر) يجب ألا يُظهر عملية النقل الناجحة
  /// فعلياً وكأنها فشلت، تماماً كما لا يُفشِل notifyReportCreated رفعَ
  /// التقرير في شاشة التصدير.
  ///
  /// تحديد معلمة كل حلقة: TeachingCircle لا يحمل معرّف معلمة مباشرة، فيُبحث
  /// عنها ضمن قائمة كل المعلمات (assignedCircleIds تحمل معرّفات حلقاتها) —
  /// نفس الأسلوب المُتَّبع فعلاً في شاشة إدارة المعلمات. إن لم توجد معلمة
  /// مرتبطة بالحلقة حالياً، يُتخطَّى إشعارها فقط دون التأثير على البقية.
  Future<void> _sendTransferNotifications({
    required String studentName,
    required String fromMosqueName,
    required String fromCircleName,
    required String toMosqueName,
    required String toCircleName,
    required String performedByName,
  }) async {
    try {
      final teachers = await ref.read(teachersStreamProvider.future);
      final fromTeacherUid = teachers
          .where((t) => t.assignedCircleIds.contains(_sourceCircleId))
          .firstOrNull
          ?.uid;
      final toTeacherUid = teachers
          .where((t) => t.assignedCircleIds.contains(_destCircleId))
          .firstOrNull
          ?.uid;

      await ref.read(notificationServiceProvider).notifyStudentTransfer(
            studentName: studentName,
            performedByName: performedByName,
            fromMosqueId: _sourceMosqueId ?? '',
            fromMosqueName: fromMosqueName,
            fromCircleName: fromCircleName,
            toMosqueId: _destMosqueId ?? '',
            toMosqueName: toMosqueName,
            toCircleName: toCircleName,
            transferHijriMonth: _transferMonth,
            transferHijriYear: _transferYear.trim(),
            fromTeacherUid: fromTeacherUid,
            toTeacherUid: toTeacherUid,
          );
    } catch (_) {
      // أفضل جهد فقط — النقل نفسه نجح بالفعل قبل الوصول لهذه الخطوة.
    }
  }

  // ─────────────────────────────── الواجهة ────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نقل طالبة')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('من أين؟ (الوضع الحالي)', AppTheme.primaryGreen),
              const SizedBox(height: 14),
              _buildMosqueField(
                label: 'المسجد',
                value: _sourceMosqueId,
                onChanged: (val) => setState(() {
                  _sourceMosqueId = val;
                  _sourceSchoolId = null;
                  _sourceCircleId = null;
                  _selectedStudentId = null;
                }),
              ),
              const SizedBox(height: 14),
              _buildSchoolDropdown(
                label: 'الدار',
                mosqueId: _sourceMosqueId,
                value: _sourceSchoolId,
                onChanged: (val) => setState(() {
                  _sourceSchoolId = val;
                  _sourceCircleId = null;
                  _selectedStudentId = null;
                }),
              ),
              const SizedBox(height: 14),
              _buildCircleDropdown(
                label: 'الحلقة',
                schoolId: _sourceSchoolId,
                value: _sourceCircleId,
                onChanged: (val) => setState(() {
                  _sourceCircleId = val;
                  _selectedStudentId = null;
                  if (_destCircleId == val) _destCircleId = null;
                }),
              ),
              const SizedBox(height: 14),
              _buildStudentDropdown(),

              if (_selectedStudentId != null) ...[
                const SizedBox(height: 18),
                _buildCurrentStudentCard(),
              ],

              const SizedBox(height: 26),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 12),

              _sectionTitle('إلى أين؟ (الوجهة الجديدة)', AppTheme.goldAccent),
              const SizedBox(height: 14),
              _buildMosqueField(
                label: 'المسجد الوجهة',
                value: _destMosqueId,
                onChanged: (val) => setState(() {
                  _destMosqueId = val;
                  _destSchoolId = null;
                  _destCircleId = null;
                }),
              ),
              const SizedBox(height: 14),
              _buildSchoolDropdown(
                label: 'الدار الوجهة',
                mosqueId: _destMosqueId,
                value: _destSchoolId,
                onChanged: (val) => setState(() {
                  _destSchoolId = val;
                  _destCircleId = null;
                }),
              ),
              const SizedBox(height: 14),
              _buildCircleDropdown(
                label: 'الحلقة الوجهة',
                schoolId: _destSchoolId,
                value: _destCircleId,
                excludeCircleId: _sourceCircleId,
                onChanged: (val) => setState(() => _destCircleId = val),
              ),
              if (_sourceCircleId != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'الحلقة الحالية للطالبة لا تظهر هنا كوجهة',
                        style: TextStyle(
                            fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 26),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 12),

              _sectionTitle('تاريخ النقل (هجري)', AppTheme.primaryGreen),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(flex: 3, child: _buildMonthDropdown()),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _buildYearField()),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'مُعبَّأ تلقائياً بالشهر الهجري الحالي — يمكنك تغييره',
                      style: TextStyle(
                          fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              const Text(
                'سبب النقل (اختياري)',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'مثلاً: انتقال إقامة الأسرة، أو رغبة ولي الأمر...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _canSubmit() && !_isSubmitting ? _onConfirmPressed : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.swap_horiz_rounded, size: 20),
                  label: Text(_isSubmitting ? 'جارِ النقل...' : 'تأكيد النقل'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
              fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildMosqueField({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    if (_isLocked) {
      final name = _mosqueNameOf(widget.lockedMosqueId);
      return _ReadOnlyFieldChip(label: label, value: name.isEmpty ? '—' : name);
    }
    final mosques = ref.watch(activeMosquesProvider);
    return DropdownButtonFormField<String>(
      value: mosques.any((m) => m.id == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: mosques
          .map((m) => DropdownMenuItem(
                value: m.id,
                child: Text(m.name, style: const TextStyle(fontFamily: 'Tajawal')),
              ))
          .toList(),
      onChanged: onChanged,
      hint: const Text('اختاري المسجد', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
    );
  }

  Widget _buildSchoolDropdown({
    required String label,
    required String? mosqueId,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final List<School> schools =
        mosqueId == null ? const [] : ref.watch(activeSchoolsByMosqueProvider(mosqueId));
    return DropdownButtonFormField<String>(
      value: schools.any((s) => s.id == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: schools
          .map((s) => DropdownMenuItem(
                value: s.id,
                child: Text(s.name, style: const TextStyle(fontFamily: 'Tajawal')),
              ))
          .toList(),
      onChanged: mosqueId == null ? null : onChanged,
      disabledHint:
          const Text('اختاري المسجد أولاً', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
      hint: const Text('اختاري الدار', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
    );
  }

  Widget _buildCircleDropdown({
    required String label,
    required String? schoolId,
    required String? value,
    required ValueChanged<String?> onChanged,
    String? excludeCircleId,
  }) {
    final List<TeachingCircle> allCircles = schoolId == null
        ? const []
        : ref.watch(activeTeachingCirclesBySchoolProvider(schoolId));
    final circles = excludeCircleId == null
        ? allCircles
        : allCircles.where((c) => c.id != excludeCircleId).toList();
    return DropdownButtonFormField<String>(
      value: circles.any((c) => c.id == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: circles
          .map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name, style: const TextStyle(fontFamily: 'Tajawal')),
              ))
          .toList(),
      onChanged: schoolId == null ? null : onChanged,
      disabledHint:
          const Text('اختاري الدار أولاً', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
      hint: const Text('اختاري الحلقة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
    );
  }

  Widget _buildStudentDropdown() {
    final List<RosterStudent> students = _sourceCircleId == null
        ? const []
        : ref.watch(rosterProvider(_sourceCircleId!)).activeStudents;
    return DropdownButtonFormField<String>(
      value: students.any((s) => s.id == _selectedStudentId) ? _selectedStudentId : null,
      decoration: InputDecoration(
        labelText: 'الطالبة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: students
          .map((s) => DropdownMenuItem(
                value: s.id,
                child: Text(s.name, style: const TextStyle(fontFamily: 'Tajawal')),
              ))
          .toList(),
      onChanged: _sourceCircleId == null
          ? null
          : (val) => setState(() => _selectedStudentId = val),
      disabledHint:
          const Text('اختاري الحلقة أولاً', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
      hint: const Text('اختاري الطالبة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
    );
  }

  Widget _buildMonthDropdown() {
    return DropdownButtonFormField<String>(
      value: _transferMonth,
      decoration: InputDecoration(
        labelText: 'الشهر',
        filled: true,
        fillColor: AppTheme.lightGreen.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.4)),
        ),
      ),
      items: QuranConstants.hijriMonths
          .map((m) => DropdownMenuItem(
                value: m,
                child: Text(m, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
              ))
          .toList(),
      onChanged: (val) => setState(() => _transferMonth = val ?? _transferMonth),
    );
  }

  Widget _buildYearField() {
    return TextFormField(
      initialValue: _transferYear,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      onChanged: (val) => setState(() => _transferYear = val),
      style: const TextStyle(fontFamily: 'Tajawal'),
      decoration: InputDecoration(
        labelText: 'السنة',
        filled: true,
        fillColor: AppTheme.lightGreen.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.4)),
        ),
      ),
    );
  }

  Widget _buildCurrentStudentCard() {
    final name = _studentNameOf(_sourceCircleId, _selectedStudentId);
    final mosqueName = _mosqueNameOf(_sourceMosqueId);
    final schoolName = _schoolNameOf(_sourceMosqueId, _sourceSchoolId);
    final circleName = _circleNameOf(_sourceSchoolId, _sourceCircleId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _initialsOf(name),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطالبة المختارة حالياً',
                  style: TextStyle(
                      fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$name — $circleName · $schoolName · $mosqueName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// حقل "مقفل" (المسجد لمشرفة المسجد) — يعرض القيمة كنص ثابت برمز قفل بدل
/// قائمة اختيار، بنفس الشكل المُعتمَد في النموذج المرئي.
class _ReadOnlyFieldChip extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyFieldChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Tajawal', fontSize: 14, color: Colors.grey.shade700),
                ),
              ),
              Icon(Icons.lock_outline_rounded, size: 15, color: Colors.grey.shade400),
            ],
          ),
        ),
      ],
    );
  }
}
