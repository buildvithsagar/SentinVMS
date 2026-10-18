import 'dart:ui';

import 'package:app/features/device_onboarding/device_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Enterprise Device Details Registration Form Screen
/// Refined Apple/Verkada Dark Glassmorphism design system (#0F172A canvas,
/// BackdropFilter glass containers, subtle slate borders, #38BDF8 active blue accents).
class DeviceDetailsFormPage extends StatefulWidget {
  const DeviceDetailsFormPage({
    required this.category,
    required this.mode,
    this.autoStartScan = false,
    this.initialSerialNumber,
    this.initialDeviceName,
    super.key,
  });

  final String category;
  final String mode;
  final bool autoStartScan;
  final String? initialSerialNumber;
  final String? initialDeviceName;

  @override
  State<DeviceDetailsFormPage> createState() => _DeviceDetailsFormPageState();
}

class _DeviceDetailsFormPageState extends State<DeviceDetailsFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialSerialNumber != null) {
      _snController.text = widget.initialSerialNumber!;
    }
    if (widget.initialDeviceName != null) {
      _nameController.text = widget.initialDeviceName!;
    }
    if (widget.autoStartScan && widget.mode == 'insta_on') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerScanner();
      });
    }
  }

  @override
  void dispose() {
    _snController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _triggerScanner() async {
    final scannedCode = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerView()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        _snController.text = scannedCode;
      });
    }
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<DeviceOnboardingBloc>().add(
        DeviceOnboardSubmitted(
          category: widget.category,
          serialNumber: _snController.text.trim(),
          deviceName: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          mode: widget.mode,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subtle Dark Glassmorphism Palette
    const baseCanvas = Color(0xFF0F172A);
    const primaryText = Color(0xFFF8FAFC);
    const mutedText = Color(0xFF94A3B8);
    const activeBlue = Color(0xFF38BDF8);
    const errorRed = Color(0xFFEF4444);
    const glassBorder = Color(0xFF334155);

    final readableMode = widget.mode == 'insta_on'
        ? 'InstaOn P2P'
        : 'IP / Domain';

    return BlocProvider<DeviceOnboardingBloc>(
      create: (context) => DeviceOnboardingBloc(
        repository: GetIt.instance<DeviceOnboardingRepository>(),
      ),
      child: Builder(
        builder: (context) {
          return BlocListener<DeviceOnboardingBloc, DeviceOnboardingState>(
            listener: (context, state) {
              if (state is DeviceOnboardingSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: activeBlue),
                    ),
                    content: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: activeBlue,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Device registered successfully!',
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                context
                  ..pop()
                  ..pop();
              } else if (state is DeviceOnboardingFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF7F1D1D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: errorRed),
                    ),
                    content: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Failed: ${state.message}',
                            style: const TextStyle(color: primaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: baseCanvas,
                  body: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.8, -0.6),
                        radius: 1.2,
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // ── Top Navigation Header Bar ─────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E293B,
                                    ).withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: glassBorder.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: primaryText,
                                      size: 20,
                                    ),
                                    onPressed: () => context.pop(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Register Device',
                                        style: TextStyle(
                                          color: primaryText,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Category: ${widget.category}',
                                        style: const TextStyle(
                                          color: mutedText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                BlocBuilder<
                                  DeviceOnboardingBloc,
                                  DeviceOnboardingState
                                >(
                                  builder: (context, state) {
                                    final isLoading =
                                        state is DeviceOnboardingLoading;
                                    return ElevatedButton.icon(
                                      onPressed: isLoading
                                          ? null
                                          : () => _submitForm(context),
                                      icon: const Icon(
                                        Icons.save_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Save'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: activeBlue,
                                        foregroundColor: const Color(
                                          0xFF0F172A,
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // ── Scrollable Glass Form Body ────────────────
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Form(
                                key: _formKey,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1E293B,
                                        ).withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: glassBorder.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Mode Indicator Chip
                                          const Text(
                                            'ONBOARDING MODE',
                                            style: TextStyle(
                                              color: mutedText,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF0F172A,
                                              ).withValues(alpha: 0.7),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: glassBorder,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      widget.mode == 'insta_on'
                                                          ? Icons
                                                                .qr_code_scanner_rounded
                                                          : Icons.dns_rounded,
                                                      color: activeBlue,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      readableMode,
                                                      style: const TextStyle(
                                                        color: primaryText,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF334155,
                                                    ).withValues(alpha: 0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: glassBorder,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'ACTIVE MODE',
                                                    style: TextStyle(
                                                      color: Color(0xFFCBD5E1),
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // 1. Serial Number Field
                                          _buildFieldHeader(
                                            'SERIAL NUMBER (SN)',
                                            mutedText,
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _snController,
                                            style: const TextStyle(
                                              color: primaryText,
                                            ),
                                            decoration: _buildInputDecoration(
                                              hintText:
                                                  widget.mode == 'insta_on'
                                                  ? 'Enter or scan device serial number'
                                                  : 'Enter device serial number (e.g. SN-98213)',
                                              suffixIcon:
                                                  widget.mode == 'insta_on'
                                                  ? IconButton(
                                                      icon: const Icon(
                                                        Icons
                                                            .qr_code_scanner_rounded,
                                                        color: activeBlue,
                                                      ),
                                                      onPressed:
                                                          _triggerScanner,
                                                    )
                                                  : null,
                                              activeBlue: activeBlue,
                                              glassBorder: glassBorder,
                                              errorRed: errorRed,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Serial number (SN) is required';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // 2. Device Name Field
                                          _buildFieldHeader(
                                            'DEVICE NAME',
                                            mutedText,
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _nameController,
                                            style: const TextStyle(
                                              color: primaryText,
                                            ),
                                            decoration: _buildInputDecoration(
                                              hintText:
                                                  'Enter name (e.g. Main Gate Camera)',
                                              activeBlue: activeBlue,
                                              glassBorder: glassBorder,
                                              errorRed: errorRed,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Device Name is required';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // 3. Username Field
                                          _buildFieldHeader(
                                            'USERNAME',
                                            mutedText,
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _usernameController,
                                            style: const TextStyle(
                                              color: primaryText,
                                            ),
                                            decoration: _buildInputDecoration(
                                              hintText: 'Device admin username',
                                              activeBlue: activeBlue,
                                              glassBorder: glassBorder,
                                              errorRed: errorRed,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Username is required';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // 4. Password Field
                                          _buildFieldHeader(
                                            'DEVICE PASSWORD',
                                            mutedText,
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            style: const TextStyle(
                                              color: primaryText,
                                            ),
                                            decoration: _buildInputDecoration(
                                              hintText:
                                                  'Enter secure device password',
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons
                                                            .visibility_off_rounded
                                                      : Icons
                                                            .visibility_rounded,
                                                  color: mutedText,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _obscurePassword =
                                                        !_obscurePassword;
                                                  });
                                                },
                                              ),
                                              activeBlue: activeBlue,
                                              glassBorder: glassBorder,
                                              errorRed: errorRed,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Device Password is required';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
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

                // Glass Loading Overlay
                BlocBuilder<DeviceOnboardingBloc, DeviceOnboardingState>(
                  builder: (context, state) {
                    if (state is DeviceOnboardingLoading) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: ColoredBox(
                          color: baseCanvas.withValues(alpha: 0.6),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                activeBlue,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldHeader(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required Color activeBlue,
    required Color glassBorder,
    required Color errorRed,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF0F172A).withValues(alpha: 0.7),
      hintText: hintText,
      hintStyle: TextStyle(
        color: const Color(0xFF94A3B8).withValues(alpha: 0.6),
        fontSize: 13,
      ),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: activeBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
