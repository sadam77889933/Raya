import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
class CreateTeacherScreen extends ConsumerStatefulWidget {
  final String? lockedMosqueId;

  const CreateTeacherScreen({super.key, this.lockedMosqueId});

  @override
  ConsumerState<CreateTeacherScreen> createState() =>
      _CreateTeacherScreenState();
}

class _CreateTeacherScreenState extends ConsumerState<CreateTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedMosqueId;
  String _selectedRole = 'teacher';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.lockedMosqueId != null) {
      _selectedMosqueId = widget.lockedMosqueId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMosqueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختاري المسجد')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authRepositoryProvider).createTeacherAccount(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            name: _nameController.text.trim(),
            mosqueId: _selectedMosqueId!,
            role: _selectedRole,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء حساب "${_nameController.text.trim()}" بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() => _selectedMosqueId = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إنشاء الحساب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب معلمة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أدخلي بيانات الحساب الجديد',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 16),

              Text(
                'نوع الحساب',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RoleChip(
                      label: 'معلمة',
                      icon: Icons.school_rounded,
                      isSelected: _selectedRole == 'teacher',
                      onTap: () => setState(() => _selectedRole = 'teacher'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleChip(
                      label: 'مشرفة مسجد',
                      icon: Icons.shield_rounded,
                      isSelected: _selectedRole == 'mosqueSupervisor',
                      onTap: () =>
                          setState(() => _selectedRole = 'mosqueSupervisor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'اسم المعلمة',
                hint: 'الاسم الكامل',
                controller: _nameController,
                isRequired: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

           Consumer(
                builder: (context, ref, _) {
                  final mosques = ref.watch(activeMosquesProvider);

                  // إذا كانت الشاشة مقيَّدة بمسجد واحد (مشرفة مسجد)،
                  // نعرض بطاقة ثابتة بدل قائمة اختيار قابلة للتغيير
                  if (widget.lockedMosqueId != null) {
                    final lockedMosqueName = mosques
                            .where((m) => m.id == widget.lockedMosqueId)
                            .map((m) => m.name)
                            .firstOrNull ??
                        'غير محدد';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اسم المسجد',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.mosque_rounded,
                                  size: 18, color: AppTheme.primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                lockedMosqueName,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.lock_outline_rounded,
                                  size: 15,
                                  color: AppTheme.primaryGreen
                                      .withOpacity(0.5)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return AppDropdownField<String>(
                    label: 'اسم المسجد',
                    hint: mosques.isEmpty
                        ? 'لا توجد مساجد مضافة'
                        : 'اختاري المسجد',
                    value: _selectedMosqueId,
                    items: mosques.map((m) => m.id).toList(),
                    itemLabel: (id) =>
                        mosques.firstWhere((m) => m.id == id).name,
                    isRequired: true,
                    onChanged: (val) =>
                        setState(() => _selectedMosqueId = val),
                  );
                },
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'البريد الإلكتروني',
                hint: 'بريد المعلمة لتسجيل الدخول',
                controller: _emailController,
                isRequired: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'هذا الحقل مطلوب';
                  }
                  if (!val.contains('@')) {
                    return 'أدخلي بريداً صحيحاً';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'كلمة المرور المؤقتة',
                hint: '6 أحرف على الأقل',
                controller: _passwordController,
                isRequired: true,
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'هذا الحقل مطلوب';
                  }
                  if (val.trim().length < 6) {
                    return 'يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'شاركي هذه الكلمة مع المعلمة، ويمكنها تغييرها بعد أول دخول',
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

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_rounded, size: 20),
                  label: Text(_isSubmitting ? 'جاري الإنشاء...' : 'إنشاء الحساب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.lightGreen : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}