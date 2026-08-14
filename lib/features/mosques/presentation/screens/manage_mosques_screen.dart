import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mosque.dart';
import '../providers/mosque_provider.dart';

class ManageMosquesScreen extends ConsumerWidget {
  const ManageMosquesScreen({super.key});

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
      appBar: AppBar(
        title: const Text('إدارة المساجد'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: TextButton.icon(
              onPressed: () => _showAddDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إضافة'),
            ),
          ),
        ],
      ),
      body: mosquesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'حدث خطأ: $err',
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
        ),
        data: (mosques) {
          if (mosques.isEmpty) {
            return Center(
              child: Text(
                'لا توجد مساجد مضافة بعد',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: Colors.grey.shade400,
                ),
              ),
            );
          }
          final activeMosques =
              mosques.where((m) => m.isActive).toList();
          final inactiveMosques =
              mosques.where((m) => !m.isActive).toList();

          Widget mosqueTile(Mosque mosque) {
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

          Widget sectionLabel(String label, int count, Color color) {
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeMosques.isNotEmpty) ...[
                sectionLabel(
                    'نشطة', activeMosques.length, AppTheme.primaryGreen),
                ...activeMosques.map(mosqueTile),
                const SizedBox(height: 10),
              ],
              if (inactiveMosques.isNotEmpty) ...[
                sectionLabel('غير نشطة', inactiveMosques.length,
                    Colors.grey.shade500),
                ...inactiveMosques.map(mosqueTile),
              ],
            ],
          );
        },
      ),
    );
  }
}