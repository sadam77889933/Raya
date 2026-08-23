import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/school.dart';
import '../../domain/entities/teaching_circle.dart';
import '../providers/mosque_provider.dart';
import '../providers/school_provider.dart';
import '../providers/teaching_circle_provider.dart';
import 'mosque_branding_screen.dart';

/// شاشة إدارة الهيكل التنظيمي: مسجد ← يحتوي على أكثر من دار/مدرسة ←
/// الدار تحتوي على أكثر من حلقة.
///
/// - المشرفة العامة (restrictToMosqueId == null): تبويبات المساجد + الدور
///   + الحلقات، وترى كل المساجد.
/// - مشرفة المسجد (restrictToMosqueId != null): تبويبا الدور + الحلقات
///   فقط، مقيَّدان بمسجدها هي دون غيره — لا ترى قائمة كل المساجد إطلاقاً.
class ManageMosquesScreen extends StatefulWidget {
  final String? restrictToMosqueId;

  const ManageMosquesScreen({super.key, this.restrictToMosqueId});

  @override
  State<ManageMosquesScreen> createState() => _ManageMosquesScreenState();
}

class _ManageMosquesScreenState extends State<ManageMosquesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool get _isRestricted => widget.restrictToMosqueId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isRestricted ? 2 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRestricted ? 'الدور والحلقات' : 'إدارة المساجد'),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5),
          tabs: [
            if (!_isRestricted) const Tab(text: '🕌  المساجد'),
            const Tab(text: '🏫  الدور'),
            const Tab(text: '📖  الحلقات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (!_isRestricted) const _MosquesTab(),
          _SchoolsTab(restrictToMosqueId: widget.restrictToMosqueId),
          _CirclesTab(restrictToMosqueId: widget.restrictToMosqueId),
        ],
      ),
    );
  }
}

// ═══════════════════════════ تبويب المساجد ═══════════════════════════

class _MosquesTab extends ConsumerWidget {
  const _MosquesTab();

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'إضافة مسجد جديد',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Tajawal'),
          decoration: const InputDecoration(hintText: 'اسم المسجد'),
        ),
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
            child: const Text('إضافة', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await ref.read(mosqueRepositoryProvider).add(name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mosquesAsync = ref.watch(mosquesStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة مسجد',
            style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: mosquesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('حدث خطأ: $err',
              style: const TextStyle(fontFamily: 'Tajawal')),
        ),
        data: (mosques) {
          if (mosques.isEmpty) {
            return _EmptyState(text: 'لا توجد مساجد مضافة بعد');
          }
          final active = mosques.where((m) => m.isActive).toList();
          final inactive = mosques.where((m) => !m.isActive).toList();

          Widget tile(Mosque mosque) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  Icons.mosque_rounded,
                  color: mosque.isActive
                      ? AppTheme.primaryGreen
                      : Colors.grey.shade400,
                ),
                title: Text(
                  mosque.name,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: mosque.isActive
                        ? Colors.black87
                        : Colors.grey.shade500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.image_outlined,
                          size: 20, color: AppTheme.primaryGreen),
                      tooltip: 'الختم وبيانات المشرفة',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MosqueBrandingScreen(mosque: mosque),
                        ),
                      ),
                    ),
                    Switch(
                      value: mosque.isActive,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (val) => ref
                          .read(mosqueRepositoryProvider)
                          .setActive(mosque.id, val),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              if (active.isNotEmpty) ...[
                _sectionLabel('نشطة', active.length, AppTheme.primaryGreen),
                ...active.map(tile),
                const SizedBox(height: 10),
              ],
              if (inactive.isNotEmpty) ...[
                _sectionLabel(
                    'غير نشطة', inactive.length, Colors.grey.shade500),
                ...inactive.map(tile),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════ تبويب الدور/المدارس ═══════════════════════════

class _SchoolsTab extends ConsumerWidget {
  final String? restrictToMosqueId;

  const _SchoolsTab({this.restrictToMosqueId});

  /// حوار إضافة دار عند المشرفة العامة: تختار المسجد من قائمة.
  Future<void> _showAddDialog(
      BuildContext context, WidgetRef ref, List<Mosque> mosques) async {
    final controller = TextEditingController();
    String? selectedMosqueId =
        mosques.isNotEmpty ? mosques.first.id : null;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'إضافة دار / مدرسة جديدة',
            style:
                TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedMosqueId,
                decoration: InputDecoration(
                  labelText: 'المسجد التابعة له *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: mosques
                    .map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name,
                              style: const TextStyle(fontFamily: 'Tajawal')),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedMosqueId = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Tajawal'),
                decoration: InputDecoration(
                  labelText: 'اسم الدار / المدرسة',
                  hintText: 'مثال: خديجة رضي الله عنها',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty &&
                    selectedMosqueId != null) {
                  Navigator.of(ctx).pop({
                    'name': controller.text.trim(),
                    'mosqueId': selectedMosqueId!,
                  });
                }
              },
              child:
                  const Text('إضافة', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await ref
          .read(schoolRepositoryProvider)
          .add(result['name']!, result['mosqueId']!);
    }
  }

  /// حوار إضافة دار عند مشرفة المسجد: المسجد محدَّد مسبقاً بمسجدها
  /// (لا تختاره)، فقط تكتب اسم الدار.
  Future<void> _showAddDialogRestricted(
      BuildContext context, WidgetRef ref, String mosqueId) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'إضافة دار / مدرسة جديدة',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Tajawal'),
          decoration: InputDecoration(
            labelText: 'اسم الدار / المدرسة',
            hintText: 'مثال: خديجة رضي الله عنها',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
            child: const Text('إضافة', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await ref.read(schoolRepositoryProvider).add(name, mosqueId);
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref,
      School school, List<Mosque> mosques, bool isRestricted) async {
    final controller = TextEditingController(text: school.name);
    String? selectedMosqueId = school.mosqueId;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل اسم الدار/المدرسة',
              style: TextStyle(
                  fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مشرفة المسجد لا تملك إلا مسجدها هي، فلا داعي لعرض قائمة
              // اختيار مسجد آخر لها — فقط المشرفة العامة تقدر تعيد ربط
              // الدار بمسجد مختلف.
              if (!isRestricted) ...[
                DropdownButtonFormField<String>(
                  value: selectedMosqueId,
                  decoration: InputDecoration(
                    labelText: 'المسجد التابعة له *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: mosques
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name,
                                style: const TextStyle(fontFamily: 'Tajawal')),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedMosqueId = val),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Tajawal'),
                decoration: InputDecoration(
                  labelText: 'اسم الدار / المدرسة',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty &&
                    selectedMosqueId != null) {
                  Navigator.of(ctx).pop({
                    'name': controller.text.trim(),
                    'mosqueId': selectedMosqueId!,
                  });
                }
              },
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final newName = result['name']!;
    final newMosqueId = isRestricted ? school.mosqueId : result['mosqueId']!;
    if (newName.isNotEmpty && newName != school.name) {
      await ref.read(schoolRepositoryProvider).updateName(school.id, newName);
    }
    if (newMosqueId != school.mosqueId) {
      await ref
          .read(schoolRepositoryProvider)
          .updateMosqueId(school.id, newMosqueId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRestricted = restrictToMosqueId != null;

    final schoolsAsync = isRestricted
        ? ref.watch(schoolsByMosqueProvider(restrictToMosqueId!))
        : ref.watch(schoolsStreamProvider);
    final mosquesAsync = ref.watch(mosquesStreamProvider);
    final mosques = mosquesAsync.value ?? [];

    String mosqueNameFor(String mosqueId) => mosques
            .where((m) => m.id == mosqueId)
            .map((m) => m.name)
            .firstOrNull ??
        'غير محدد';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isRestricted
            ? () => _showAddDialogRestricted(
                context, ref, restrictToMosqueId!)
            : (mosques.isEmpty
                ? null
                : () => _showAddDialog(context, ref, mosques)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة دار / مدرسة',
            style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: schoolsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('حدث خطأ: $err',
              style: const TextStyle(fontFamily: 'Tajawal')),
        ),
        data: (schools) {
          if (!isRestricted && mosques.isEmpty) {
            return _EmptyState(
                text: 'أضيفي مسجداً أولاً من تبويب "المساجد"');
          }
          if (schools.isEmpty) {
            return _EmptyState(text: 'لا توجد دور/مدارس مضافة بعد');
          }
          final active = schools.where((s) => s.isActive).toList();
          final inactive = schools.where((s) => !s.isActive).toList();

          Widget tile(School school) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  Icons.school_rounded,
                  color: school.isActive
                      ? AppTheme.primaryGreen
                      : Colors.grey.shade400,
                ),
                title: Text(school.name,
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: school.isActive
                            ? Colors.black87
                            : Colors.grey.shade500)),
                subtitle: isRestricted
                    ? null
                    : Text('🕌 ${mosqueNameFor(school.mosqueId)}',
                        style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          size: 18, color: AppTheme.primaryGreen),
                      onPressed: () => _showEditDialog(
                          context, ref, school, mosques, isRestricted),
                    ),
                    Switch(
                      value: school.isActive,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (val) => ref
                          .read(schoolRepositoryProvider)
                          .setActive(school.id, val),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              if (active.isNotEmpty) ...[
                _sectionLabel('نشطة', active.length, AppTheme.primaryGreen),
                ...active.map(tile),
                const SizedBox(height: 10),
              ],
              if (inactive.isNotEmpty) ...[
                _sectionLabel(
                    'غير نشطة', inactive.length, Colors.grey.shade500),
                ...inactive.map(tile),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════ تبويب الحلقات ═══════════════════════════

class _CirclesTab extends ConsumerWidget {
  final String? restrictToMosqueId;

  const _CirclesTab({this.restrictToMosqueId});

  Future<void> _showAddDialog(
      BuildContext context, WidgetRef ref, List<School> schools) async {
    final controller = TextEditingController();
    String? selectedSchoolId = schools.isNotEmpty ? schools.first.id : null;
    String selectedCircleTime = TeachingCircle.defaultCircleTime;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'إضافة حلقة جديدة',
            style:
                TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedSchoolId,
                decoration: InputDecoration(
                  labelText: 'الدار / المدرسة التابعة لها *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: schools
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name,
                              style: const TextStyle(fontFamily: 'Tajawal')),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedSchoolId = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Tajawal'),
                decoration: InputDecoration(
                  labelText: 'اسم الحلقة',
                  hintText: 'مثال: رياض الجنان',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCircleTime,
                decoration: InputDecoration(
                  labelText: 'وقت الحلقة',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: TeachingCircle.circleTimeOptions
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t,
                              style: const TextStyle(fontFamily: 'Tajawal')),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedCircleTime = val!),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty &&
                    selectedSchoolId != null) {
                  Navigator.of(ctx).pop({
                    'name': controller.text.trim(),
                    'schoolId': selectedSchoolId!,
                    'circleTime': selectedCircleTime,
                  });
                }
              },
              child:
                  const Text('إضافة', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await ref.read(teachingCircleRepositoryProvider).add(
            result['name']!,
            result['schoolId']!,
            circleTime: result['circleTime']!,
          );
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref,
      TeachingCircle circle, List<School> schools) async {
    final controller = TextEditingController(text: circle.name);
    String? selectedSchoolId = circle.schoolId;
    String selectedCircleTime = circle.circleTime;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل اسم الحلقة',
              style: TextStyle(
                  fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "schools" هنا هي الدور النشطة فقط (تُمرَّر من الشاشة
              // الرئيسية). إن كانت دار الحلقة الحالية قد عُطِّلت لاحقاً،
              // فلن تظهر ضمن الخيارات — نتحقق من وجودها فعلياً قبل تمرير
              // قيمتها للقائمة المنسدلة تفادياً لانهيار Flutter الشهير
              // (قيمة لا تطابق أي عنصر ضمن items).
              DropdownButtonFormField<String>(
                value: schools.any((s) => s.id == selectedSchoolId)
                    ? selectedSchoolId
                    : null,
                decoration: InputDecoration(
                  labelText: 'الدار / المدرسة التابعة لها *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: schools
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name,
                              style: const TextStyle(fontFamily: 'Tajawal')),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedSchoolId = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Tajawal'),
                decoration: InputDecoration(
                  labelText: 'اسم الحلقة',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: TeachingCircle.circleTimeOptions
                        .contains(selectedCircleTime)
                    ? selectedCircleTime
                    : TeachingCircle.defaultCircleTime,
                decoration: InputDecoration(
                  labelText: 'وقت الحلقة',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: TeachingCircle.circleTimeOptions
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t,
                              style: const TextStyle(fontFamily: 'Tajawal')),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedCircleTime = val!),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty &&
                    selectedSchoolId != null) {
                  Navigator.of(ctx).pop({
                    'name': controller.text.trim(),
                    'schoolId': selectedSchoolId!,
                    'circleTime': selectedCircleTime,
                  });
                }
              },
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final newName = result['name']!;
    final newSchoolId = result['schoolId']!;
    final newCircleTime = result['circleTime']!;
    if (newName.isNotEmpty && newName != circle.name) {
      await ref
          .read(teachingCircleRepositoryProvider)
          .updateName(circle.id, newName);
    }
    if (newSchoolId != circle.schoolId) {
      await ref
          .read(teachingCircleRepositoryProvider)
          .updateSchoolId(circle.id, newSchoolId);
    }
    if (newCircleTime != circle.circleTime) {
      await ref
          .read(teachingCircleRepositoryProvider)
          .updateCircleTime(circle.id, newCircleTime);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRestricted = restrictToMosqueId != null;

    final circlesAsync = ref.watch(teachingCirclesStreamProvider);
    final schoolsAsync = isRestricted
        ? ref.watch(schoolsByMosqueProvider(restrictToMosqueId!))
        : ref.watch(schoolsStreamProvider);
    final schools = schoolsAsync.value ?? [];
    final schoolIds = schools.map((s) => s.id).toSet();
    // عند إضافة/تعديل حلقة، لا يجوز اختيار دار معطَّلة كدار تابعة لها —
    // القائمتان (schools الكاملة) تبقيان كما هما لأغراض أخرى (عرض اسم
    // الدار لحلقة موجودة، وتحديد الحلقات الظاهرة) حتى لو كانت الدار
    // معطَّلة الآن.
    final activeSchools = schools.where((s) => s.isActive).toList();

    String schoolNameFor(String schoolId) => schools
            .where((s) => s.id == schoolId)
            .map((s) => s.name)
            .firstOrNull ??
        'غير محدد';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: activeSchools.isEmpty
            ? null
            : () => _showAddDialog(context, ref, activeSchools),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة حلقة',
            style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: circlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('حدث خطأ: $err',
              style: const TextStyle(fontFamily: 'Tajawal')),
        ),
        data: (allCircles) {
          // نعرض فقط الحلقات التابعة للدور الظاهرة حالياً (كل الدور
          // للمشرفة العامة، أو دور مسجدها فقط لمشرفة المسجد).
          final circles =
              allCircles.where((c) => schoolIds.contains(c.schoolId)).toList();

          if (schools.isEmpty) {
            return _EmptyState(
                text: 'أضيفي دار/مدرسة أولاً من تبويب "الدور"');
          }
          if (circles.isEmpty) {
            return _EmptyState(text: 'لا توجد حلقات مضافة بعد');
          }
          final active = circles.where((c) => c.isActive).toList();
          final inactive = circles.where((c) => !c.isActive).toList();

          Widget tile(TeachingCircle circle) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  Icons.menu_book_rounded,
                  color: circle.isActive
                      ? AppTheme.primaryGreen
                      : Colors.grey.shade400,
                ),
                title: Text(circle.name,
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: circle.isActive
                            ? Colors.black87
                            : Colors.grey.shade500)),
                subtitle: Text('🏫 ${schoolNameFor(circle.schoolId)}',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.grey.shade500)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          size: 18, color: AppTheme.primaryGreen),
                      onPressed: () =>
                          _showEditDialog(context, ref, circle, activeSchools),
                    ),
                    Switch(
                      value: circle.isActive,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (val) => ref
                          .read(teachingCircleRepositoryProvider)
                          .setActive(circle.id, val),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              if (active.isNotEmpty) ...[
                _sectionLabel('نشطة', active.length, AppTheme.primaryGreen),
                ...active.map(tile),
                const SizedBox(height: 10),
              ],
              if (inactive.isNotEmpty) ...[
                _sectionLabel(
                    'غير نشطة', inactive.length, Colors.grey.shade500),
                ...inactive.map(tile),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════ عناصر مشتركة ═══════════════════════════

Widget _sectionLabel(String label, int count, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade400),
        textAlign: TextAlign.center,
      ),
    );
  }
}
