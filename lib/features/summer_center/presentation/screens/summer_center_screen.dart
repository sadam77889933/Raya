import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/domain/entities/mosque.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../domain/entities/summer_center.dart';
import '../providers/summer_center_provider.dart';
import 'manage_levels_screen.dart';
import 'manage_subjects_screen.dart';
import 'summer_assignments_screen.dart';
import 'summer_tests_settings_screen.dart';
import 'supervisor_tests_list_screen.dart';

/// شاشة "المركز الصيفي" — نقطة الدخول الوحيدة لهذا النظام المستقل تماماً
/// عن نظام الحلقات المعتاد. تجمع بين اختيار المسجد (للمشرف العام فقط)،
/// اختيار/إنشاء المركز، ولوحة أقسامه (المستويات/المواد/التوزيع/الاختبارات/
/// الإعدادات) في شاشة واحدة، تفادياً لتنقّل إضافي لا داعي له في الحالة
/// الشائعة (مركز فعّال واحد لكل مسجد).
class SummerCenterScreen extends ConsumerStatefulWidget {
  const SummerCenterScreen({super.key});

  @override
  ConsumerState<SummerCenterScreen> createState() =>
      _SummerCenterScreenState();
}

class _SummerCenterScreenState extends ConsumerState<SummerCenterScreen> {
  String? _mosqueFilter; // null = لم تُختَر بعد (للمشرف العام فقط)
  String? _selectedCenterId;

  Future<void> _createCenter(String mosqueId) async {
    final nameController = TextEditingController(text: 'المركز الصيفي');
    final hijriYearController =
        TextEditingController(text: '${HijriCalendar.now().hYear}');
    final periodController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إنشاء مركز صيفي جديد',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                  decoration: const InputDecoration(labelText: 'اسم المركز'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hijriYearController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                  decoration: const InputDecoration(labelText: 'السنة الهجرية'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: periodController,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                  decoration: const InputDecoration(
                    labelText: 'الفترة (اختياري)',
                    hintText: 'مثال: محرَّم – صفر',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.of(ctx).pop({
                  'name': nameController.text.trim(),
                  'hijriYear': hijriYearController.text.trim(),
                  'periodLabel': periodController.text.trim(),
                });
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    final newId = await ref.read(summerCenterRepositoryProvider).addCenter(
          name: result['name']!,
          mosqueId: mosqueId,
          hijriYear: result['hijriYear']!,
          periodLabel: result['periodLabel']!.isEmpty ? null : result['periodLabel'],
        );
    if (mounted) setState(() => _selectedCenterId = newId);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final isGlobalSupervisor = user.isSupervisor;
    final effectiveMosqueId =
        isGlobalSupervisor ? _mosqueFilter : user.mosqueId;

    return Scaffold(
      appBar: AppBar(title: const Text('المركز الصيفي')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _buildBody(isGlobalSupervisor, effectiveMosqueId),
        ),
      ),
    );
  }

  Widget _buildBody(bool isGlobalSupervisor, String? effectiveMosqueId) {
    if (isGlobalSupervisor && effectiveMosqueId == null) {
      final allMosques = ref.watch(activeMosquesProvider);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('اختاري المسجد لعرض مركزه الصيفي',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          ...allMosques.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MosqueTile(
                  mosque: m,
                  onTap: () => setState(() => _mosqueFilter = m.id),
                ),
              )),
        ],
      );
    }

    if (effectiveMosqueId == null) {
      return const Center(
        child: Text('لا يوجد مسجد مرتبط بحسابك بعد',
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
      );
    }

    final centersAsync =
        ref.watch(summerCentersByMosqueProvider(effectiveMosqueId));

    return centersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('تعذّر تحميل المركز الصيفي',
            style: const TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
      ),
      data: (centers) {
        if (centers.isEmpty) {
          return _buildEmptyState(effectiveMosqueId, isGlobalSupervisor);
        }

        final active = centers.where((c) => c.isActive).toList();
        final currentId = _selectedCenterId ??
            (active.isNotEmpty ? active.first.id : centers.first.id);
        final current =
            centers.where((c) => c.id == currentId).firstOrNull ?? centers.first;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGlobalSupervisor)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _mosqueFilter = null;
                      _selectedCenterId = null;
                    }),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                    label: const Text('تغيير المسجد'),
                  ),
                ),
              if (centers.length > 1)
                _CenterSwitcher(
                  centers: centers,
                  selectedId: current.id,
                  onChanged: (id) => setState(() => _selectedCenterId = id),
                ),
              _CenterHeaderCard(center: current),
              const SizedBox(height: 18),
              _SectionCard(
                icon: Icons.stairs_rounded,
                title: 'المستويات',
                subtitle: 'إضافة وتعديل مستويات المركز',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ManageLevelsScreen(center: current),
                )),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.menu_book_rounded,
                title: 'المواد',
                subtitle: 'إضافة وتعديل مواد المركز',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ManageSubjectsScreen(center: current),
                )),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.assignment_ind_rounded,
                title: 'توزيع المعلمات',
                subtitle: 'إسناد المعلمات إلى المستويات والمواد',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SummerAssignmentsScreen(center: current),
                )),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.quiz_rounded,
                title: 'اختبارات المعلمات',
                subtitle: 'مشاهدة ومراجعة وتصدير PDF',
                iconColor: AppTheme.goldAccent,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SupervisorTestsListScreen(center: current),
                )),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.settings_rounded,
                title: 'إعدادات الاختبارات',
                subtitle: 'تفعيل/تعطيل شاشة "اختباراتي" للمعلمات',
                iconColor: AppTheme.goldAccent,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SummerTestsSettingsScreen(center: current),
                )),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _createCenter(effectiveMosqueId),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('مركز صيفي جديد'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String mosqueId, bool isGlobalSupervisor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wb_sunny_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('لا يوجد مركز صيفي بعد لهذا المسجد',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('أنشئي مركزاً لتبدئي بإضافة المستويات والمواد',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _createCenter(mosqueId),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إنشاء مركز صيفي'),
        ),
      ],
    );
  }
}

class _MosqueTile extends StatelessWidget {
  final Mosque mosque;
  final VoidCallback onTap;
  const _MosqueTile({required this.mosque, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.mosque_rounded, color: AppTheme.primaryGreen),
        title: Text(mosque.name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.arrow_back_ios_rounded, size: 14),
        onTap: onTap,
      ),
    );
  }
}

class _CenterSwitcher extends StatelessWidget {
  final List<SummerCenter> centers;
  final String selectedId;
  final ValueChanged<String> onChanged;
  const _CenterSwitcher({
    required this.centers,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: selectedId,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.wb_sunny_outlined, size: 18),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: centers
            .map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.name}${c.isActive ? '' : ' (مؤرشف)'}'),
                ))
            .toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }
}

class _CenterHeaderCard extends StatelessWidget {
  final SummerCenter center;
  const _CenterHeaderCard({required this.center});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.primaryGreen, Color(0xFF2E8B57)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(center.name,
              style: const TextStyle(
                  fontFamily: 'Tajawal', color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            center.periodLabel != null
                ? 'السنة ${center.hijriYear}هـ · ${center.periodLabel}'
                : 'السنة ${center.hijriYear}هـ',
            style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _pill(center.isActive ? 'فعّال' : 'مؤرشف', Icons.check_circle_outline),
              _pill(
                center.testsEnabledForTeachers ? 'الاختبارات مفعَّلة' : 'الاختبارات معطَّلة',
                Icons.quiz_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppTheme.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
