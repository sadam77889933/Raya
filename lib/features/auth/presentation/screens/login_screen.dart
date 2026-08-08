import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _darkGreen = Color(0xFF0A3D22);
  static const _midGreen = Color(0xFF1B6B3A);
  static const _gold = Color(0xFFD4AF37);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
  }
  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _emailController.text);

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'إعادة تعيين كلمة المرور',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخلي بريدك الإلكتروني، وسنُرسل لك رابطاً لإعادة تعيين كلمة المرور',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                hintText: 'البريد الإلكتروني',
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
            child: const Text('إرسال', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !mounted) return;

    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال رابط إعادة التعيين إلى $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تعذّر الإرسال، تأكدي من صحة البريد الإلكتروني'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.checking;

    return Scaffold(
      backgroundColor: _darkGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildFormCard(authState, isLoading),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 46, 24, 30),
      decoration: BoxDecoration(
        color: _darkGreen,
        border: Border(
          bottom: BorderSide(color: _gold.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // قبة رمزية
          CustomPaint(
            size: const Size(90, 55),
            painter: _DomePainter(color: _gold),
          ),
          const SizedBox(height: 10),
          Text(
            'رعاية',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _gold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 60,
            height: 2,
            color: _gold.withOpacity(0.6),
          ),
          const SizedBox(height: 10),
          Text(
            'نظام إدارة حلقات القرآن الكريم',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(AuthState authState, bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تسجيل الدخول',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 22),

            _buildGoldField(
              label: 'البريد الإلكتروني',
              controller: _emailController,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            _buildGoldField(
              label: 'كلمة المرور',
              controller: _passwordController,
              icon: _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              obscureText: _obscurePassword,
              onIconTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),

            if (authState.status == AuthStatus.error) ...[
              const SizedBox(height: 12),
              Text(
                authState.errorMessage ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _midGreen,
                  foregroundColor: _gold,
                  side: BorderSide(color: _gold.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _gold,
                        ),
                      )
                    : const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                    child:
                        Divider(color: _gold.withOpacity(0.3), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.star_rounded, size: 14, color: _gold),
                ),
                Expanded(
                    child:
                        Divider(color: _gold.withOpacity(0.3), thickness: 1)),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              'حسابك يُنشأ من قِبل مشرفة الحلقات فقط\nلا يوجد تسجيل ذاتي لضمان أمان البيانات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: Colors.grey.shade500,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    VoidCallback? onIconTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _darkGreen,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textDirection: TextDirection.ltr,
          validator: (val) =>
              (val == null || val.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: _gold.withOpacity(0.04),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _gold.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _gold.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _midGreen, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(icon, color: _gold, size: 18),
              onPressed: onIconTap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _darkGreen,
        border: Border(top: BorderSide(color: _gold.withOpacity(0.2))),
      ),
      child: Text(
        'الإصدار 1.0.0 · برمجة: صدام البريكي (أبو ود)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13,
          color: _gold.withOpacity(0.7),
        ),
      ),
    );
  }
}

/// رسم قبة مسجد رمزية بسيطة
class _DomePainter extends CustomPainter {
  final Color color;
  _DomePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w / 2, 0);
    path.cubicTo(w * 0.85, 0, w * 0.9, h * 0.5, w * 0.9, h * 0.7);
    path.lineTo(w * 0.1, h * 0.7);
    path.cubicTo(w * 0.1, h * 0.5, w * 0.15, 0, w / 2, 0);
    path.close();

    canvas.drawPath(path, paint);

    // قمة صغيرة
    canvas.drawCircle(Offset(w / 2, -2), 4, paint);

    // قاعدة
    final basePaint = Paint()..color = color.withOpacity(0.7);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.85, w * 0.9, h * 0.08),
      basePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}