import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/features/login/bloc/login_bloc.dart';
import 'package:app/features/login/bloc/login_event.dart';
import 'package:app/features/login/bloc/login_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              color: const Color(0xFF14161F),
              shape: const RoundedRectangleBorder(
                // Industrial sharp edges (default is BorderRadius.zero)
                side: BorderSide(color: Color(0xFF70788C), width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: BlocConsumer<LoginBloc, LoginState>(
                  listener: (context, state) {
                    if (state is LoginSuccess) {
                      // Hydrate global session in-memory state
                      context.read<AuthBloc>().add(
                            AuthLoggedIn(
                              accessToken: state.accessToken,
                              user: state.user,
                            ),
                          );
                      // Route to viewport grid
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
                              size: 48,
                              color: Color(0xFF02965E),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'VMS OPERATOR LOGIN',
                              style: theme.textTheme.titleLarge?.copyWith(
                                letterSpacing: 1.5,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'AUTHENTICATE SECURE SESSION',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                letterSpacing: 1,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

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
                                    size: 20,
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
                            decoration: const InputDecoration(
                              labelText: 'ORGANIZATION ID',
                              helperText: 'B2B Tenant Identifier',
                              helperStyle: TextStyle(fontSize: 10),
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
                            decoration: const InputDecoration(
                              labelText: 'EMAIL ADDRESS',
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
                            decoration: InputDecoration(
                              labelText: 'PASSWORD',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF70788C),
                                  size: 20,
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
                            decoration: const InputDecoration(
                              labelText: 'TOTP CODE (2FA)',
                              counterText: '',
                              helperText:
                                  'Optional unless enforced by tenant policy',
                              helperStyle: TextStyle(fontSize: 10),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (_formKey.currentState?.validate() ??
                                        false) {
                                      context.read<LoginBloc>().add(
                                            LoginSubmitted(
                                              customerId: _customerIdController
                                                  .text
                                                  .trim(),
                                              email:
                                                  _emailController.text.trim(),
                                              password:
                                                  _passwordController.text,
                                              totpCode:
                                                  _totpController.text.trim(),
                                            ),
                                          );
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'AUTHENTICATE SESSION',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
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
    );
  }
}
