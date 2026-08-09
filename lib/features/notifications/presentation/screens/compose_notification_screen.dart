import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../providers/notification_provider.dart';

class ComposeNotificationScreen extends ConsumerStatefulWidget {
  const ComposeNotificationScreen({super.key});

  @override
  ConsumerState<ComposeNotificationScreen> createState() =>
      _ComposeNotificationScreenState();
}

class _ComposeNotificationScreenState
    extends ConsumerState<ComposeNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _selectedMosqueId; // null = كل المساجد (فقط للمشرفة العامة)
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      final targetMosqueId =
          user.isMosqueSupervisor ? user.mosqueId : _selectedMosqueId;

      await ref.read(notificationServiceProvider).sendCustomMessage(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            senderName: user.name,
            targetMosqueId: targetMosqueId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الرسالة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isGlobalSupervisor = user?.isSupervisor ?? false;
    final mosques = ref.watch(activeMosquesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إرسال رسالة للمعلمات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGlobalSupervisor) ...[
                Text(
                  'إلى من تريدين إرسال الرسالة؟',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _selectedMosqueId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('كل المساجد',
                          style: TextStyle(
                              fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                    ),
                    ...mosques.map((m) => DropdownMenuItem<String?>(
                          value: m.id,
                          child: Text(m.name,
                              style: const TextStyle(fontFamily: 'Tajawal')),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedMosqueId = val),
                ),
                const SizedBox(height: 20),
              ] else ...[
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
                          'ستُرسَل هذه الرسالة لكل معلمات مسجدك فقط',
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
                const SizedBox(height: 20),
              ],

              AppTextField(
                label: 'عنوان الرسالة',
                hint: 'مثال: تذكير مهم',
                controller: _titleController,
                isRequired: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              Text(
                'نص الرسالة *',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bodyController,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Tajawal'),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                decoration: InputDecoration(
                  hintText: 'اكتبي رسالتك هنا...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_isSending ? 'جاري الإرسال...' : 'إرسال'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}