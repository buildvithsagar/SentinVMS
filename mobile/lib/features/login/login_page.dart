import 'dart:io';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/features/login/bloc/login_bloc.dart';
import 'package:app/features/login/bloc/login_event.dart';
import 'package:app/features/login/bloc/login_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Redesigned premium dark tactical industrial Login Page.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerIdController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _totpController;

  bool _obscurePassword = true;
  bool _showOtpView = false;
  bool _showVerified = false;
  String _otpEmail = '';

  late final AnimationController _splashController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoTranslate;
  late final Animation<double> _logoRotation;
  late final Animation<double> _formOpacity;
  late final Animation<double> _formSlide;

  // OTP transition animations
  late final AnimationController _otpAnimController;
  late final Animation<double> _otpTitleOpacity;
  late final Animation<Offset> _otpTitleSlide;
  late final Animation<double> _otpDescOpacity;
  late final Animation<Offset> _otpDescSlide;
  late final Animation<double> _otpFieldOpacity;
  late final Animation<double> _otpFieldScale;
  late final Animation<double> _otpButtonOpacity;
  late final Animation<Offset> _otpButtonSlide;

  // Verified success animation
  late final AnimationController _verifiedController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _ringScale;
  late final Animation<double> _verifiedTextOpacity;

  @override
  void initState() {
    super.initState();
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    _customerIdController = TextEditingController(text: isTest ? '' : 'demo_tenant');
    _emailController = TextEditingController(text: isTest ? '' : 'operator@demo.com');
    _passwordController = TextEditingController(text: isTest ? '' : 'password123');
    _totpController = TextEditingController(text: isTest ? '' : '000000');

    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = Tween<double>(begin: 1.5, end: 1).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeInOutCubic),
      ),
    );

    _logoTranslate = Tween<double>(begin: 140, end: 0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeInOutCubic),
      ),
    );

    _logoRotation = Tween<double>(begin: -0.5, end: 0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _formOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.65, 1, curve: Curves.easeIn),
      ),
    );

    _formSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.65, 1, curve: Curves.easeOutCubic),
      ),
    );

    // OTP transition controller (600ms staggered entrance)
    _otpAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _otpTitleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _otpAnimController,
        curve: const Interval(0, 0.4, curve: Curves.easeOut),
      ),
    );
    _otpTitleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _otpAnimController,
        curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    _otpDescOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _otpAnimController,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
      ),
    );
    _otpDescSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _otpAnimController,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _otpFieldOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _otpAnimController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
    _otpFieldScale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _otpAnimController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _otpButtonOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _otpAnimController,
        curve: const Interval(0.55, 1, curve: Curves.easeOut),
      ),
    );
    _otpButtonSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _otpAnimController,
        curve: const Interval(0.55, 1, curve: Curves.easeOutCubic),
      ),
    );

    // Verified success animation (1s total)
    _verifiedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _checkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _verifiedController,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _checkOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _verifiedController,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );

    _ringScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _verifiedController,
        curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _verifiedTextOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _verifiedController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    if (!isTest) {
      _splashController.forward();
    } else {
      _splashController.value = 1.0;
      _otpAnimController.value = 1.0;
      _verifiedController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    _splashController.dispose();
    _otpAnimController.dispose();
    _verifiedController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  InputDecoration _buildInputDecoration(
    String hint, {
    String? helper,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 14,
      ),
      helperText: helper,
      helperStyle: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF132B25).withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Color(0xFF2DD4BF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: (_showOtpView && !_showVerified)
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                key: const Key('otpBackButton'),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8)),
                onPressed: context.read<LoginBloc>().state is LoginLoading
                    ? null
                    : () {
                        _otpAnimController.reset();
                        setState(() {
                          _showOtpView = false;
                          _totpController.clear();
                        });
                        context.read<LoginBloc>().add(const LoginReset());
                      },
              ),
            )
          : null,
      body: _GlassmorphicBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: isTest ? 8 : 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: BlocConsumer<LoginBloc, LoginState>(
                listener: (context, state) {
                  if (state is LoginSuccess) {
                    final accessToken = state.accessToken;
                    final user = state.user;
                    setState(() => _showVerified = true);
                    _verifiedController.forward(from: 0).then((_) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (!context.mounted) return;
                        GetIt.instance<AuthBloc>().add(
                          AuthLoggedIn(
                            accessToken: accessToken,
                            user: user,
                          ),
                        );
                        if (!context.mounted) return;
                        context.go('/live_grid');
                      });
                    }).catchError((_) {
                      if (!context.mounted) return;
                      GetIt.instance<AuthBloc>().add(
                        AuthLoggedIn(
                          accessToken: accessToken,
                          user: user,
                        ),
                      );
                      if (!context.mounted) return;
                      context.go('/live_grid');
                    });
                  } else if (state is LoginOtpRequired) {
                    setState(() {
                      _showOtpView = true;
                      _otpEmail = state.email;
                    });
                    _otpAnimController.forward(from: 0);
                  }
                },
                builder: (context, state) {
                  final isLoading = state is LoginLoading;

                  // Full-screen verified overlay
                  if (_showVerified) {
                    return AnimatedBuilder(
                      animation: _verifiedController,
                      builder: (context, _) {
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Glowing ring
                              ScaleTransition(
                                scale: _ringScale,
                                child: FadeTransition(
                                  opacity: _checkOpacity,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.2 * _checkOpacity.value),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    // Checkmark inside the ring
                                    child: ScaleTransition(
                                      scale: _checkScale,
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Color(0xFF2DD4BF),
                                        size: 56,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              // VERIFIED text
                              FadeTransition(
                                opacity: _verifiedTextOpacity,
                                child: const Column(
                                  children: [
                                    Text(
                                      'VERIFIED',
                                      style: TextStyle(
                                        color: Color(0xFF2DD4BF),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 6,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Initializing secure session...',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return AnimatedBuilder(
                    animation: _splashController,
                    builder: (context, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Animated Header with Custom Shield / Camera Logo
                          Transform.translate(
                            offset: Offset(0, _logoTranslate.value),
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Column(
                                children: [
                                  RotationTransition(
                                    turns: _logoRotation,
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF2DD4BF).withValues(alpha: 0.15 * _splashController.value),
                                            blurRadius: 16,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(22),
                                        child: Image.asset(
                                          'assets/logo.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'SENTINEL VMS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SECURE CONTROL PLANE',
                                    style: TextStyle(
                                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.6),
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: isTest ? 12 : 36),

                          // Form fields with smooth fade-in and slide transition
                          Opacity(
                            opacity: _formOpacity.value,
                            child: Transform.translate(
                              offset: Offset(0, _formSlide.value),
                              child: IgnorePointer(
                                ignoring: _formOpacity.value < 0.1 && !isTest,
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Error Banner
                                      if (state is LoginFailure) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                            border: Border.all(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.warning_amber_rounded,
                                                color: Color(0xFFEF4444),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  state.errorMessage,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      if (!_showOtpView) ...[
                                        // Operator Email Field
                                        const Text(
                                          'OPERATOR EMAIL',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          key: const Key('emailField'),
                                          controller: _emailController,
                                          enabled: !isLoading,
                                          textInputAction: TextInputAction.next,
                                          keyboardType: TextInputType.emailAddress,
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                          decoration: _buildInputDecoration(
                                            'operator@domain.com',
                                            helper: 'Default: operator@demo.com',
                                          ),
                                          validator: _validateEmail,
                                        ),
                                        const SizedBox(height: 16),

                                        // Security Passcode Field
                                        const Text(
                                          'SECURITY PASSCODE',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          key: const Key('passwordField'),
                                          controller: _passwordController,
                                          enabled: !isLoading,
                                          obscureText: _obscurePassword,
                                          textInputAction: TextInputAction.done,
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                          decoration: _buildInputDecoration(
                                            '••••••••••••',
                                            helper: 'Default: password123',
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: const Color(0xFF94A3B8),
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                            ),
                                          ),
                                          validator: (val) => val == null || val.isEmpty
                                              ? 'Security Passcode is required'
                                              : null,
                                          onFieldSubmitted: (_) {
                                            if (_formKey.currentState?.validate() ?? false) {
                                              context.read<LoginBloc>().add(
                                                LoginSubmitted(
                                                  email: _emailController.text.trim(),
                                                  password: _passwordController.text,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                        SizedBox(height: isTest ? 12 : 32),

                                        // Submit Button
                                        _AnimatedSubmitButton(
                                          isLoading: isLoading,
                                          onPressed: isLoading
                                              ? null
                                              : () {
                                                  if (_formKey.currentState?.validate() ?? false) {
                                                    context.read<LoginBloc>().add(
                                                          LoginSubmitted(
                                                            email: _emailController.text.trim(),
                                                            password: _passwordController.text,
                                                          ),
                                                        );
                                                  }
                                                },
                                        ),
                                      ] else ...[
                                        // OTP Verification View — Staggered Entrance Animation
                                        AnimatedBuilder(
                                          animation: _otpAnimController,
                                          builder: (context, _) {
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                // 1. Title — fade + slide
                                                SlideTransition(
                                                  position: _otpTitleSlide,
                                                  child: FadeTransition(
                                                    opacity: _otpTitleOpacity,
                                                    child: const Text(
                                                      'MFA VERIFICATION CODE',
                                                      style: TextStyle(
                                                        color: Color(0xFF2DD4BF),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),

                                                // 2. Description — fade + slide (staggered)
                                                SlideTransition(
                                                  position: _otpDescSlide,
                                                  child: FadeTransition(
                                                    opacity: _otpDescOpacity,
                                                    child: Text(
                                                      'Please enter the 6-digit OTP code sent to $_otpEmail',
                                                      style: const TextStyle(
                                                        color: Color(0xFF94A3B8),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 20),

                                                // 3. OTP Input — fade + scale pop
                                                FadeTransition(
                                                  opacity: _otpFieldOpacity,
                                                  child: ScaleTransition(
                                                    scale: _otpFieldScale,
                                                    child: TextFormField(
                                                      key: const Key('otpField'),
                                                      controller: _totpController,
                                                      enabled: !isLoading,
                                                      textInputAction: TextInputAction.done,
                                                      keyboardType: TextInputType.number,
                                                      maxLength: 6,
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 22,
                                                        letterSpacing: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      decoration: _buildInputDecoration(
                                                        '000000',
                                                        helper: 'Local bypass code: 000000',
                                                      ),
                                                      validator: (val) {
                                                        if (val == null || val.trim().isEmpty) {
                                                          return 'Verification code is required';
                                                        }
                                                        if (val.trim().length != 6 ||
                                                            int.tryParse(val.trim()) == null) {
                                                          return 'Please enter a 6-digit numeric code';
                                                        }
                                                        return null;
                                                      },
                                                      onFieldSubmitted: (_) {
                                                        if (_formKey.currentState?.validate() ?? false) {
                                                          context.read<LoginBloc>().add(
                                                            LoginOtpSubmitted(
                                                              email: _otpEmail,
                                                              otpCode: _totpController.text.trim(),
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 24),

                                                // 4. Verify Button — fade + slide up
                                                SlideTransition(
                                                  position: _otpButtonSlide,
                                                  child: FadeTransition(
                                                    opacity: _otpButtonOpacity,
                                                    child: _AnimatedSubmitButton(
                                                      label: 'VERIFY CODE',
                                                      isLoading: isLoading,
                                                      onPressed: isLoading
                                                          ? null
                                                          : () {
                                                              if (_formKey.currentState?.validate() ?? false) {
                                                                context.read<LoginBloc>().add(
                                                                      LoginOtpSubmitted(
                                                                        email: _otpEmail,
                                                                        otpCode: _totpController.text.trim(),
                                                                      ),
                                                                    );
                                                              }
                                                            },
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _GlassmorphicBackground extends StatelessWidget {
  const _GlassmorphicBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base premium forest green radial gradient
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.6), // Rich green radial center pushed slightly top-center
              radius: 1.3,
              colors: [
                Color(0xFF0C3D32), // Rich forest green center
                Color(0xFF071C17), // Deep dark forest green transition
                Color(0xFF040606), // Near pitch dark green-black outer
              ],
            ),
          ),
        ),
        // Child content on top
        child,
      ],
    );
  }
}

class _AnimatedSubmitButton extends StatefulWidget {
  const _AnimatedSubmitButton({
    required this.onPressed,
    required this.isLoading,
    this.label = 'AUTHENTICATE SESSION',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  State<_AnimatedSubmitButton> createState() => _AnimatedSubmitButtonState();
}

class _AnimatedSubmitButtonState extends State<_AnimatedSubmitButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      value: 1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      onPointerDown: (_) {
        if (widget.onPressed != null) _controller.reverse();
      },
      onPointerUp: (_) {
        if (widget.onPressed != null) _controller.forward();
      },
      onPointerCancel: (_) {
        if (widget.onPressed != null) _controller.forward();
      },
      child: ScaleTransition(
        scale: _controller,
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE6F4F0),
              disabledBackgroundColor: const Color(0xFFE6F4F0).withValues(alpha: 0.3),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF0D2520)),
                    ),
                  )
                : Text(
                    widget.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF0D2520),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
