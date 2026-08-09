import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
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
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final teacher = filtered[index];
                            final mosqueName = mosques
                                    .where((m) => m.id == teacher.mosqueId)
                                    .map((m) => m.name)
                                    .firstOrNull ??
                                'غير محدد';
                            return _TeacherCard(
                              teacher: teacher,
                              mosqueName: mosqueName,
                              onToggle: (val) => ref
                                  .read(authRepositoryProvider)
                                  .setTeacherActive(teacher.uid, val),
                              onEdit: () => _showEditNameDialog(
                                  context, ref, teacher),
                            );
                          },
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

class _TeacherCard extends StatelessWidget {
  final UserModel teacher;
  final String mosqueName;
  final void Function(bool) onToggle;
  final VoidCallback onEdit;

  const _TeacherCard({
    required this.teacher,
    required this.mosqueName,
    required this.onToggle,
    required this.onEdit,
  });

  String get _initials {
    final parts = teacher.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]} ${parts[1][0]}';
    }
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '؟';
  }

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