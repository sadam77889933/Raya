import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// بطاقة ترحيب زجاجية (Glassmorphism) تظهر اسم المعلمة أعلى شاشتها،
/// فوق خلفية خضراء متدرجة، مع بريق ذهبي عابر وتحية تتغيّر تلقائياً
/// حسب وقت الجهاز (صباحاً / مساءً).
///
/// الحركات المستخدمة:
/// - دخول واحد فقط (fade + slide + scale) يعمل مرة واحدة عند فتح الشاشة.
/// - فقاعة ضوئية خلفية تتحرك بهدوء بشكل متكرر (تكلفتها منخفضة جداً،
///   حركة انتقال بسيطة بلا إعادة رسم للنص).
/// - بريق ذهبي عابر (shimmer) يمر فوق البطاقة كل بضع ثوانٍ.
/// - وهج خفيف حول الأيقونة فقط.
/// كل هذه الحركات معزولة عن إعادة بناء النص، لذلك أثرها على الأداء ضئيل جداً.
class TeacherWelcomeBanner extends StatefulWidget {
  /// اسم المستخدمة الظاهر بعد كلمة "أستاذة / ".
  final String name;

  /// عنوان الدور الظاهر قبل الاسم، افتراضياً "أستاذة".
  final String roleLabel;

  const TeacherWelcomeBanner({
    super.key,
    required this.name,
    this.roleLabel = 'أستاذة',
  });

  @override
  State<TeacherWelcomeBanner> createState() => _TeacherWelcomeBannerState();
}

class _TeacherWelcomeBannerState extends State<TeacherWelcomeBanner>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // انيميشن الدخول: يعمل مرة واحدة فقط ثم يتوقف نهائياً.
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );

    // فقاعة الخلفية العائمة — حركة بطيئة جداً ورخيصة (translate فقط).
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // البريق الذهبي العابر فوق البطاقة الزجاجية، يتكرر كل ~3.2 ثانية.
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // البريق يتحرك من يمين البطاقة إلى يسارها خلال 45% الأولى من الزمن،
    // ثم يتوقف (يختفي خارج البطاقة) خلال الـ 55% المتبقية، تماماً كما في
    // نموذج المعاينة، قبل أن تُعيد الحلقة الكرّة تلقائياً.
    _shimmerAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.6, end: 1.3)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.3),
        weight: 55,
      ),
    ]).animate(_shimmerController);

    // وهج ناعم خفيف حول الأيقونة فقط.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  /// تحية ديناميكية حسب وقت الجهاز: من منتصف الليل (00:00) وحتى الظهر
  /// (قبل 12:00) تظهر "صبّحك الله بالخير"، ومن الظهر وحتى منتصف الليل
  /// تظهر "مساك الله بالخير".
  bool get _isMorning => DateTime.now().hour < 12;

  String get _greeting =>
      _isMorning ? 'صبّحك الله بالخير' : 'مساك الله بالخير';

  String get _icon => _isMorning ? '☀️' : '🌙';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.6),
                  radius: 1.2,
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.9),
                    AppTheme.primaryGreen,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // فقاعة ضوئية خلفية عائمة بحركة خفيفة جداً.
                  AnimatedBuilder(
                    animation: _floatAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: -45 + _floatAnimation.value,
                        right: -45,
                        child: child!,
                      );
                    },
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),

                  // البطاقة الزجاجية نفسها.
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // البريق الذهبي العابر.
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _shimmerAnimation,
                                  builder: (context, child) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: FractionalTranslation(
                                        translation: Offset(
                                          _shimmerAnimation.value,
                                          0,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerRight,
                                              end: Alignment.centerLeft,
                                              colors: [
                                                Colors.transparent,
                                                AppTheme.goldAccent
                                                    .withOpacity(0.28),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.35, 0.5, 0.65],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // المحتوى الفعلي (أيقونة + نص) فوق البريق.
                              Row(
                                children: [
                                  AnimatedBuilder(
                                    animation: _glowAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              Colors.white.withOpacity(0.18),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.goldAccent
                                                  .withOpacity(
                                                0.35 * _glowAnimation.value,
                                              ),
                                              blurRadius:
                                                  14 * _glowAnimation.value,
                                              spreadRadius:
                                                  1.5 * _glowAnimation.value,
                                            ),
                                          ],
                                        ),
                                        child: child,
                                      );
                                    },
                                    child: Center(
                                      child: Text(
                                        _icon,
                                        style:
                                            const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _greeting,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.white
                                                .withOpacity(0.88),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${widget.roleLabel} / ${widget.name}',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
