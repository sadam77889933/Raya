import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mosques/domain/entities/mosque.dart';
import '../../../mosques/domain/entities/school.dart';
import '../../../mosques/domain/entities/teaching_circle.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../domain/entities/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/teachers_provider.dart';

class ManageTeachersScreen extends ConsumerStatefulWidget {
  final String? restrictToMosqueId;

  const ManageTeachersScreen({super.key, this.restrictToMosqueId});

  @override
  ConsumerState<ManageTeachersScreen> createState() =>
      _ManageTeachersScreenState();
}

class _ManageTeachersScreenState extends ConsumerState<ManageTeachersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final teachersAsync = widget.restrictToMosqueId != null
        ? ref.watch(teachersByMosqueProvider(widget.restrictToMosqueId!))
        : ref.watch(teachersStreamProvider);
    final mosques = ref.watch(activeMosquesProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('إدارة المعلمات'),
        backgroundColor: Colors.grey.shade100,
      ),
      body: teachersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('حدث خطأ: $err',
              style: const TextStyle(fontFamily: 'Tajawal')),
        ),
        data: (teachers) {
          final activeCount = teachers.where((t) => t.isActive).length;
          final inactiveCount = teachers.length - activeCount;
          final mosqueCount = teachers
              .map((t) => t.mosqueId)
              .where((id) => id != null)
              .toSet()
              .length;

          final filtered = _searchQuery.trim().isEmpty
              ? teachers
              : teachers
                  .where((t) => t.name.contains(_searchQuery.trim()))
                  .toList();

          final activeTeachers =
              filtered.where((t) => t.isActive).toList();
          final inactiveTeachers =
              filtered.where((t) => !t.isActive).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── شريط الإحصائيات ─────────────────────────────
                Row(
                  children: [
                    _StatCard(
                        count: activeCount,
                        label: 'نشطة',
                        color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    _StatCard(
                        count: inactiveCount,
                        label: 'معطّلة',
                        color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    _StatCard(
                        count: mosqueCount,
                        label: 'مساجد',
                        color: AppTheme.goldAccent),
                  ],
                ),
                const SizedBox(height: 14),

                // ─── خانة البحث ─────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ابحثي عن معلمة...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ─── القائمة ─────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد نتائج',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.grey.shade400,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            if (activeTeachers.isNotEmpty) ...[
                              _sectionLabel(
                                'نشطة',
                                activeTeachers.length,
                                color: AppTheme.primaryGreen,
                              ),
                              const SizedBox(height: 8),
                              ...activeTeachers.map(
                                (teacher) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: _TeacherCard(
                                    teacher: teacher,
                                    mosqueName: _mosqueNameFor(
                                        teacher, mosques),
                                    onToggle: (val) => ref
                                        .read(authRepositoryProvider)
                                        .setTeacherActive(
                                            teacher.uid, val),
                                    onEdit: () => _showEditNameDialog(
                                        context, ref, teacher),
                                    onAssign: () => _showAssignDialog(
                                        context, ref, teacher),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (inactiveTeachers.isNotEmpty) ...[
                              _sectionLabel(
                                'معطّلة',
                                inactiveTeachers.length,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 8),
                              ...inactiveTeachers.map(
                                (teacher) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: _TeacherCard(
                                    teacher: teacher,
                                    mosqueName: _mosqueNameFor(
                                        teacher, mosques),
                                    onToggle: (val) => ref
                                        .read(authRepositoryProvider)
                                        .setTeacherActive(
                                            teacher.uid, val),
                                    onEdit: () => _showEditNameDialog(
                                        context, ref, teacher),
                                    onAssign: () => _showAssignDialog(
                                        context, ref, teacher),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
          ),
          );
        },
      ),
    );
  }

  Future<void> _showEditNameDialog(
      BuildContext context, WidgetRef ref, UserModel teacher) async {
    final controller = TextEditingController(text: teacher.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'تعديل اسم المعلمة',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هذا التعديل يغيّر اسمها في كل التقارير القادمة',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                labelText: 'الاسم الكامل',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != teacher.name) {
      await ref.read(authRepositoryProvider).updateTeacherName(
            teacher.uid,
            newName,
          );
    }
  }

  Future<void> _showAssignDialog(
      BuildContext context, WidgetRef ref, UserModel teacher) async {
    final mosqueId = teacher.mosqueId;
    if (mosqueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم تحديد مسجد لهذه المعلمة بعد',
              style: TextStyle(fontFamily: 'Tajawal')),
        ),
      );
      return;
    }

    var selectedSchoolIds = Set<String>.from(teacher.assignedSchoolIds);
    var selectedCircleIds = Set<String>.from(teacher.assignedCircleIds);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'ربط المعلمة: ${teacher.name}',
              style: const TextStyle(
                  fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Consumer(
                builder: (context, ref, _) {
                  final schoolsAsync = ref.watch(schoolsByMosqueProvider(mosqueId));
                  final circlesAsync = ref.watch(teachingCirclesStreamProvider);

                  return schoolsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Text('حدث خطأ: $err',
                        style: const TextStyle(fontFamily: 'Tajawal')),
                    data: (schools) {
                      final activeSchools =
                          schools.where((s) => s.isActive).toList();
                      final allCircles = circlesAsync.value ?? [];
                      final circlesForSelectedSchools = allCircles
                          .where((c) =>
                              c.isActive &&
                              selectedSchoolIds.contains(c.schoolId))
                          .toList();

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'اختاري الدور والحلقات التي تُدرّسها هذه المعلمة',
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Text('🏫',
                                    style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 6),
                                const Text(
                                  'الدور / المدارس',
                                  style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black54),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (activeSchools.isEmpty)
                              const Text(
                                'لا توجد دور/مدارس مضافة لهذا المسجد بعد',
                                style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    color: Colors.orange),
                              )
                            else
                              ...activeSchools.map((school) {
                                final checked =
                                    selectedSchoolIds.contains(school.id);
                                return _AssignChip(
                                  label: school.name,
                                  checked: checked,
                                  onTap: () => setDialogState(() {
                                    if (checked) {
                                      selectedSchoolIds.remove(school.id);
                                      // إزالة حلقات هذه الدار من التحديد أيضاً
                                      final schoolCircleIds = allCircles
                                          .where((c) =>
                                              c.schoolId == school.id)
                                          .map((c) => c.id)
                                          .toSet();
                                      selectedCircleIds
                                          .removeAll(schoolCircleIds);
                                    } else {
                                      selectedSchoolIds.add(school.id);
                                    }
                                  }),
                                );
                              }),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text('📖',
                                    style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 6),
                                const Text(
                                  'الحلقات (من الدور المختارة أعلاه)',
                                  style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black54),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (selectedSchoolIds.isEmpty)
                              const Text(
                                'اختاري دارًا أولاً لعرض حلقاتها',
                                style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    color: Colors.grey),
                              )
                            else if (circlesForSelectedSchools.isEmpty)
                              const Text(
                                'لا توجد حلقات مضافة لهذه الدور بعد',
                                style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    color: Colors.orange),
                              )
                            else
                              ...circlesForSelectedSchools.map((circle) {
                                final checked =
                                    selectedCircleIds.contains(circle.id);
                                return _AssignChip(
                                  label: circle.name,
                                  checked: checked,
                                  onTap: () => setDialogState(() {
                                    if (checked) {
                                      selectedCircleIds.remove(circle.id);
                                    } else {
                                      selectedCircleIds.add(circle.id);
                                    }
                                  }),
                                );
                              }),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child:
                    const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () async {
                  // معرّفات حلقات محذوفة نهائياً قد تبقى عالقة داخل
                  // selectedCircleIds (مثلاً إن كانت مُسندة للمعلمة قبل
                  // حذف حلقتها) — لأن هذه الحلقات لم تعد تظهر كخيارات
                  // قابلة لإلغاء التحديد أصلاً. نستبعدها هنا دائماً عند
                  // الحفظ حتى لا تبقى "مربوطة" بشكل دائم لا يمكن فكّه.
                  // إن لم تكن قائمة الحلقات قد حُمِّلت بعد (حالة نادرة)،
                  // نحفظ التحديد كما هو تفادياً لحذف روابط صحيحة بالخطأ.
                  final circlesSnapshot =
                      ref.read(teachingCirclesStreamProvider);
                  final validCircleIds = circlesSnapshot.hasValue
                      ? selectedCircleIds
                          .where((id) => circlesSnapshot.value!
                              .any((c) => c.id == id))
                          .toList()
                      : selectedCircleIds.toList();

                  await ref.read(authRepositoryProvider).updateTeacherAssignments(
                        teacher.uid,
                        schoolIds: selectedSchoolIds.toList(),
                        circleIds: validCircleIds,
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('حفظ الربط',
                    style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
          );
        },
      ),
    );
  }

  String _mosqueNameFor(UserModel teacher, List<Mosque> mosques) {
    return mosques
            .where((m) => m.id == teacher.mosqueId)
            .map((m) => m.name)
            .firstOrNull ??
        'غير محدد';
  }

  Widget _sectionLabel(String label, int count, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '$label · $count',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatCard({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignChip extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _AssignChip({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: checked ? AppTheme.lightGreen : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: checked ? AppTheme.primaryGreen : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: checked ? AppTheme.primaryGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: checked ? AppTheme.primaryGreen : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: checked ? FontWeight.w700 : FontWeight.w400,
                  color: checked ? AppTheme.primaryGreen : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final UserModel teacher;
  final String mosqueName;
  final void Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onAssign;

  const _TeacherCard({
    required this.teacher,
    required this.mosqueName,
    required this.onToggle,
    required this.onEdit,
    required this.onAssign,
  });

  String get _initials {
    final parts = teacher.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]} ${parts[1][0]}';
    }
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '؟';
  }

  /// "مربوطة" فعلياً تعني وجود حلقة واحدة على الأقل مُسندة لها (وجود
  /// دار فقط بدون حلقة لا يكفي لتتمكن من العمل).
  bool get _isLinked => teacher.assignedCircleIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isActive = teacher.isActive;

    return Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF1B6B3A), Color(0xFF20794A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isActive ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : Colors.grey.shade500,
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
                    teacher.name,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.mosque_rounded,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        mosqueName,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _isLinked ? Icons.link_rounded : Icons.link_off_rounded,
                size: 18,
                color: _isLinked ? AppTheme.primaryGreen : Colors.orange,
              ),
              onPressed: onAssign,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: _isLinked
                  ? 'مربوطة بدار وحلقة — اضغطي للتعديل'
                  : 'غير مربوطة بحلقة بعد — اضغطي للربط',
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.primaryGreen),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Switch(
              value: isActive,
              activeColor: AppTheme.primaryGreen,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}