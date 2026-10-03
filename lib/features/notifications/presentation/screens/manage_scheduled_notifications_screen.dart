import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../domain/entities/scheduled_notification.dart';
import '../providers/scheduled_notification_provider.dart';

class ManageScheduledNotificationsScreen extends ConsumerWidget {
  const ManageScheduledNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final restrictToMosqueId =
        (user != null && user.isMosqueSupervisor) ? user.mosqueId : null;

    final notificationsAsync =
        ref.watch(scheduledNotificationsProvider(restrictToMosqueId));

    return Scaffold(
      appBar: AppBar(title: const Text('الرسائل المجدولة')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('حدث خطأ: $err')),
        data: (notifications) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تُرسَل تلقائياً عند فتح أي شخص للتطبيق في يوم الإرسال أو بعده',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد رسائل مجدولة',
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                color: Colors.grey.shade400),
                          ),
                        )
                      : ListView.separated(
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final s = notifications[index];
                            return _ScheduledCard(
                              scheduled: s,
                              onEdit: () => _showEditorDialog(
                                context,
                                ref,
                                restrictToMosqueId,
                                existing: s,
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showEditorDialog(context, ref, restrictToMosqueId),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('جدولة رسالة جديدة'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditorDialog(
      BuildContext context, WidgetRef ref, String? lockedMosqueId,
      {ScheduledNotification? existing}) async {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final bodyController = TextEditingController(text: existing?.body ?? '');
    final dayController = TextEditingController(
        text: existing != null ? existing.hijriDayOfMonth.toString() : '');
    String? selectedMosqueId = existing?.targetMosqueId ?? lockedMosqueId;

    final user = ref.read(authProvider).user;
    final mosques = ref.read(activeMosquesProvider);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEditing ? 'تعديل الرسالة المجدولة' : 'جدولة رسالة جديدة',
            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'عنوان الرسالة',
                  hint: 'مثال: تذكير شهري',
                  controller: titleController,
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                Text('نص الرسالة',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                TextField(
                  controller: bodyController,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('تُرسَل كل شهر هجري في يوم',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                TextField(
                  controller: dayController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                  decoration: InputDecoration(
                    hintText: 'مثال: 25',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (lockedMosqueId == null) ...[
                  const SizedBox(height: 12),
                  Text('إلى من؟',
                      style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: selectedMosqueId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('كل المساجد',
                            style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                      ...mosques.map((m) => DropdownMenuItem<String?>(
                            value: m.id,
                            child:
                                Text(m.name, style: const TextStyle(fontFamily: 'Tajawal')),
                          )),
                    ],
                    onChanged: (val) =>
                        setState(() => selectedMosqueId = val),
                  ),
                ],
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () async {
                final day = int.tryParse(dayController.text.trim());
                if (titleController.text.trim().isEmpty ||
                    bodyController.text.trim().isEmpty ||
                    day == null ||
                    day < 1 ||
                    day > 30) {
                  return;
                }

                if (isEditing) {
                  await ref.read(scheduledNotificationServiceProvider).update(
                        id: existing.id,
                        title: titleController.text.trim(),
                        body: bodyController.text.trim(),
                        hijriDayOfMonth: day,
                        targetMosqueId: selectedMosqueId,
                      );
                } else {
                  await ref.read(scheduledNotificationServiceProvider).create(
                        title: titleController.text.trim(),
                        body: bodyController.text.trim(),
                        hijriDayOfMonth: day,
                        senderName: user?.name ?? '',
                        targetMosqueId: selectedMosqueId,
                      );
                }

                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(isEditing ? 'حفظ التعديلات' : 'جدولة',
                  style: const TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledCard extends StatelessWidget {
  final ScheduledNotification scheduled;
  final VoidCallback onEdit;

  const _ScheduledCard({required this.scheduled, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return Opacity(
          opacity: scheduled.isActive ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${scheduled.hijriDayOfMonth}',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scheduled.title,
                          style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(scheduled.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined,
                      size: 20, color: Colors.grey.shade600),
                  tooltip: 'تعديل',
                ),
                Switch(
                  value: scheduled.isActive,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (val) => ref
                      .read(scheduledNotificationServiceProvider)
                      .setActive(scheduled.id, val),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}