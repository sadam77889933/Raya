import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_level.dart';
import '../providers/summer_center_provider.dart';
import '../providers/summer_level_provider.dart';

/// إدارة مستويات مركز صيفي واحد — بلا أي علاقة بحلقات التحفيظ الحالية.
/// عدد المستويات مفتوح تماماً ويختلف من مسجد لآخر.
class ManageLevelsScreen extends ConsumerStatefulWidget {
  final SummerCenter center;
  const ManageLevelsScreen({super.key, required this.center});

  @override
  ConsumerState<ManageLevelsScreen> createState() => _ManageLevelsScreenState();
}

class _ManageLevelsScreenState extends ConsumerState<ManageLevelsScreen> {
  final _newNameController = TextEditingController();

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  Future<void> _add(int nextOrder) async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(summerCenterRepositoryProvider)
        .addLevel(widget.center.id, widget.center.mosqueId, name, nextOrder);
    _newNameController.clear();
  }

  Future<void> _editName(SummerLevel level) async {
    final controller = TextEditingController(text: level.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل اسم المستوى', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(summerCenterRepositoryProvider).updateLevelName(level.id, newName);
    }
  }

  Future<void> _confirmDeactivate(SummerLevel level) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إخفاء هذا المستوى؟', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        content: const Text(
          'لن يظهر بعد الآن للمعلمات عند إنشاء اختبار جديد، لكن اختباراته السابقة تبقى محفوظة.',
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إخفاء'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(summerCenterRepositoryProvider).setLevelActive(level.id, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelsAsync = ref.watch(summerLevelsByCenterProvider(widget.center.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('المستويات'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.center.name,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600)),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أضيفي مستويات المركز بالترتيب الذي يناسبك',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            Expanded(
              child: levelsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
                data: (levels) {
                  if (levels.isEmpty) {
                    return Center(
                      child: Text('لا توجد مستويات بعد',
                          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
                    );
                  }
                  return ListView.separated(
                    itemCount: levels.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final level = levels[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.lightGreen,
                            child: Text('${i + 1}',
                                style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.primaryGreen, fontWeight: FontWeight.w800)),
                          ),
                          title: Text(level.name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                          subtitle: level.isActive
                              ? null
                              : const Text('مخفي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.orange)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_rounded, size: 19), onPressed: () => _editName(level)),
                              if (level.isActive)
                                IconButton(
                                  icon: const Icon(Icons.visibility_off_outlined, size: 19),
                                  onPressed: () => _confirmDeactivate(level),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 19, color: AppTheme.primaryGreen),
                                  onPressed: () => ref.read(summerCenterRepositoryProvider).setLevelActive(level.id, true),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNameController,
                    style: const TextStyle(fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(hintText: 'اسم المستوى الجديد...'),
                    onSubmitted: (_) => _add(levelsAsync.value?.length ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => _add(levelsAsync.value?.length ?? 0),
                  child: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
