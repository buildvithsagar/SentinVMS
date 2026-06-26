import 'dart:io';
import 'dart:math' as math;
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/features/login/bloc/login_bloc.dart';
import 'package:app/features/login/bloc/login_event.dart';
import 'package:app/features/login/bloc/login_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Redesigned premium dark tactical industrial Login Page.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _customerIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _customerIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
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
    String label, {
    String? helper,
    Widget? suffixIcon,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF70788C)),
      labelStyle: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 11,
        letterSpacing: 1,
      ),
      floatingLabelStyle:
          const TextStyle(color: Color(0xFF02965E), letterSpacing: 1),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: const Color(0xFF70788C), size: 18)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF0D0E12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF3A3D45), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF3A3D45), width: 0.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF1A1D23), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF02965E), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 0.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _RadarGridBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                color: const Color(0xFF14161F).withValues(alpha: 0.85),
                elevation: 16,
                shadowColor: Colors.black.withValues(alpha: 0.5),
                shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Color(0xFF3A3D45), width: 0.8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: BlocConsumer<LoginBloc, LoginState>(
                    listener: (context, state) {
                      if (state is LoginSuccess) {
                        context.read<AuthBloc>().add(
                              AuthLoggedIn(
                                accessToken: state.accessToken,
                                user: state.user,
                              ),
                            );
                        context.go('/live_grid');
                      }
                    },
                    builder: (context, state) {
                      final isLoading = state is LoginLoading;

                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Icon
                            const Center(
                              child: Icon(
                                Icons.videocam_outlined,
                                size: 52,
                                color: Color(0xFF02965E),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                'VMS OPERATOR LOGIN',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  letterSpacing: 2,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE0E0E0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'AUTHENTICATE SECURE SESSION',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  letterSpacing: 1.5,
                                  fontSize: 10,
                                  color: const Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Error Banner
                            if (state is LoginFailure) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E0E12),
                                  border: Border.all(
                                    color: const Color(0xFFD32F2F),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFD32F2F),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        state.errorMessage,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: const Color(0xFFE2E8F0),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Organization ID Field
                            TextFormField(
                              controller: _customerIdController,
                              enabled: !isLoading,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 14,
                              ),
                              decoration: _buildInputDecoration(
                                'ORGANIZATION ID',
                                helper: 'B2B Tenant Identifier',
                                prefixIcon: Icons.domain_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Organization ID is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 14,
                              ),
                              decoration: _buildInputDecoration(
                                'EMAIL ADDRESS',
                                prefixIcon: Icons.email_outlined,
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              enabled: !isLoading,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 14,
                              ),
                              decoration: _buildInputDecoration(
                                'PASSWORD',
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF70788C),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // TOTP Field
                            TextFormField(
                              controller: _totpController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              maxLength: 6,
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 14,
                                letterSpacing: 2,
                              ),
                              decoration: _buildInputDecoration(
                                'TOTP CODE (2FA)',
                                helper:
                                    'Optional unless enforced by tenant policy',
                                prefixIcon: Icons.security_outlined,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Submit Button with Physical Tap Feedback
                            _AnimatedSubmitButton(
                              isLoading: isLoading,
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      if (_formKey.currentState?.validate() ??
                                          false) {
                                        context.read<LoginBloc>().add(
                                              LoginSubmitted(
                                                customerId:
                                                    _customerIdController.text
                                                        .trim(),
                                                email: _emailController.text
                                                    .trim(),
                                                password:
                                                    _passwordController.text,
                                                totpCode: _totpController.text
                                                    .trim(),
                                              ),
                                            );
                                      }
                                    },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarGridBackground extends StatefulWidget {
  const _RadarGridBackground({required this.child});
  final Widget child;

  @override
  State<_RadarGridBackground> createState() => _RadarGridBackgroundState();
}

class _RadarGridBackgroundState extends State<_RadarGridBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadarGridPainter(_controller.value),
          child: widget.child,
        );
      },
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  _RadarGridPainter(this.animationValue);
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0D0E12);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF02965E).withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 45.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    final radarPaint = Paint()
      ..color = const Color(0xFF02965E).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (var r = 100; r < maxRadius; r += 120) {
      canvas.drawCircle(center, r.toDouble(), radarPaint);
    }

    final angle = animationValue * 2 * math.pi;
    final endPoint = Offset(
      center.dx + maxRadius * math.cos(angle),
      center.dy + maxRadius * math.sin(angle),
    );

    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF02965E).withValues(alpha: 0.12),
          const Color(0xFF02965E).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..strokeWidth = 2.0;

    canvas.drawLine(center, endPoint, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _AnimatedSubmitButton extends StatefulWidget {
  const _AnimatedSubmitButton({
    required this.onPressed,
    required this.isLoading,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

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
          height: 46,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF02965E),
              disabledBackgroundColor: const Color(0xFF14161F),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                  color: widget.onPressed != null
                      ? const Color(0xFF02965E)
                      : const Color(0xFF3A3D45),
                  width: 0.5,
                ),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFE2E8F0)),
                    ),
                  )
                : Text(
                    'AUTHENTICATE SESSION',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
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
