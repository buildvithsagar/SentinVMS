import 'package:app/features/device_onboarding/bloc/device_onboarding_bloc.dart';
import 'package:app/features/device_onboarding/data/device_onboarding_repository.dart';
import 'package:app/features/device_onboarding/presentation/widgets/scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class DeviceDetailsFormPage extends StatefulWidget {
  const DeviceDetailsFormPage({
    required this.category,
    required this.mode,
    this.autoStartScan = false,
    super.key,
  });

  final String category;
  final String mode;
  final bool autoStartScan;

  @override
  State<DeviceDetailsFormPage> createState() => _DeviceDetailsFormPageState();
}

class _DeviceDetailsFormPageState extends State<DeviceDetailsFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(text: 'admin');
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
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
      MaterialPageRoute(
        builder: (context) => const ScannerView(),
      ),
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
    // Tactical Industrial Palette Colors
    const primaryBg = Color(0xFF0D0E12);
    const panelBg = Color(0xFF14161F);
    const textBorder = Color(0xFF262A3C);
    const primaryText = Color(0xFFE2E8F0);
    const mutedText = Color(0xFF70788C);
    const accentGreen = Color(0xFF02965E);
    const errorRed = Color(0xFFD32F2F);

    final readableMode = widget.mode == 'insta_on' ? 'InstaOn' : 'IP/Domain';

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
                  const SnackBar(
                    backgroundColor: accentGreen,
                    content: Text(
                      'Device registered successfully!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
                context.pop(); // Returns to select category page
                context.pop(); // Returns to cameras list or dashboard
              } else if (state is DeviceOnboardingFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: errorRed,
                    content: Text(
                      'Failed: ${state.message}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
            },
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: primaryBg,
                  appBar: AppBar(
                    backgroundColor: panelBg,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: primaryText),
                      onPressed: () => context.pop(),
                    ),
                    title: const Text(
                      'Add Device',
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => _submitForm(context),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: accentGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Add Mode Dropdown
                            const Text(
                              'Add Mode',
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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
                                color: panelBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: textBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    readableMode,
                                    style: const TextStyle(
                                      color: primaryText,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: mutedText,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 2. SN (Serial Number) Field
                            const Text(
                              'SN',
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _snController,
                              style: const TextStyle(color: primaryText),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: panelBg,
                                hintText: widget.mode == 'insta_on'
                                    ? 'Enter or scan device SN'
                                    : 'Enter device serial number',
                                hintStyle: const TextStyle(color: mutedText),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: textBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: accentGreen),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: errorRed),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: errorRed),
                                ),
                                suffixIcon: widget.mode == 'insta_on'
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.qr_code_scanner,
                                          color: primaryText,
                                        ),
                                        onPressed: _triggerScanner,
                                      )
                                    : null,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Serial number (SN) is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // 3. Device Name Field
                            const Text(
                              'Device Name',
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: primaryText),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: panelBg,
                                hintText: 'Enter device name (e.g. Backdoor camera)',
                                hintStyle: const TextStyle(color: mutedText),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: textBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: accentGreen),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: errorRed),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: errorRed),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Device Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // 4. Username Field
                            const Text(
                              'Username',
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: primaryText),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: panelBg,
                                hintText: 'Username',
                                hintStyle: const TextStyle(color: mutedText),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: textBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: accentGreen),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: errorRed),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: errorRed),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // 5. Password Field
                            const Text(
                              'Device Password',
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: primaryText),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: panelBg,
                                hintText: 'Enter password',
                                hintStyle: const TextStyle(color: mutedText),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: textBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: accentGreen),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: errorRed),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: errorRed),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: mutedText,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
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
                // Loading Overlay
                BlocBuilder<DeviceOnboardingBloc, DeviceOnboardingState>(
                  builder: (context, state) {
                    if (state is DeviceOnboardingLoading) {
                      return Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(accentGreen),
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
}
