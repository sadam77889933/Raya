import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/school.dart';
import '../../domain/entities/teaching_circle.dart';
import '../providers/mosque_provider.dart';
import '../providers/school_provider.dart';
import '../providers/teaching_circle_provider.dart';

/// شاشة إدارة الهيكل التنظيمي الكامل (للمشرفة العامة فقط):
/// مسجد ← يحتوي على أكثر من دار/مدرسة ← الدار تحتوي على أكثر من حلقة.
///
/// 3 تبويبات مستقلة، كل واحد له قائمته وزر إضافته الخاص.
class ManageMosquesScreen extends StatefulWidget {
  const ManageMosquesScreen({super.key});

  @override
  State<ManageMosquesScreen> createState() => _ManageMosquesScreenState();
}

class _ManageMosquesScreenState extends State<ManageMosquesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('إدارة المساجد'),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5),
          tabs: const [
            Tab(text: '🕌  المساجد'),
            Tab(text: '🏫  الدور'),
            Tab(text: '📖  الحلقات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MosquesTab(),
          _SchoolsTab(),
          _CirclesTab(),
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
                trailing: Switch(
                  value: mosque.isActive,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (val) => ref
                      .read(mosqueRepositoryProvider)
                      .setActive(mosque.id, val),
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
  const _SchoolsTab();

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

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, School school) async {
    final controller = TextEditingController(text: school.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل اسم الدار/المدرسة',
            style:
                TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Tajawal'),
          decoration: InputDecoration(
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
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != school.name) {
      await ref.read(schoolRepositoryProvider).updateName(school.id, newName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsAsync = ref.watch(schoolsStreamProvider);
    final mosquesAsync = ref.watch(mosquesStreamProvider);
    final mosques = mosquesAsync.value ?? [];

    String mosqueNameFor(String mosqueId) => mosques
            .where((m) => m.id == mosqueId)
            .map((m) => m.name)
            .firstOrNull ??
        'غير محدد';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: mosques.isEmpty
            ? null
            : () => _showAddDialog(context, ref, mosques),
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
          if (mosques.isEmpty) {
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
                subtitle: Text('🕌 ${mosqueNameFor(school.mosqueId)}',
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
                      onPressed: () => _showEditDialog(context, ref, school),
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
  const _CirclesTab();

  Future<void> _showAddDialog(
      BuildContext context, WidgetRef ref, List<School> schools) async {
    final controller = TextEditingController();
    String? selectedSchoolId = schools.isNotEmpty ? schools.first.id : null;

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
          .read(teachingCircleRepositoryProvider)
          .add(result['name']!, result['schoolId']!);
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, TeachingCircle circle) async {
    final controller = TextEditingController(text: circle.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل اسم الحلقة',
            style:
                TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Tajawal'),
          decoration: InputDecoration(
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
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != circle.name) {
      await ref
          .read(teachingCircleRepositoryProvider)
          .updateName(circle.id, newName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(teachingCirclesStreamProvider);
    final schoolsAsync = ref.watch(schoolsStreamProvider);
    final schools = schoolsAsync.value ?? [];

    String schoolNameFor(String schoolId) => schools
            .where((s) => s.id == schoolId)
            .map((s) => s.name)
            .firstOrNull ??
        'غير محدد';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: schools.isEmpty
            ? null
            : () => _showAddDialog(context, ref, schools),
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
        data: (circles) {
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
                      onPressed: () => _showEditDialog(context, ref, circle),
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
