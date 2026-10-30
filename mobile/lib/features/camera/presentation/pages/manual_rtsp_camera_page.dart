import 'package:app/core/core.dart';
import 'package:app/features/camera/camera.dart';
import 'package:app/features/stream_demo/stream_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class ManualRtspCameraPage extends StatefulWidget {
  const ManualRtspCameraPage({super.key});

  @override
  State<ManualRtspCameraPage> createState() => _ManualRtspCameraPageState();
}

class _ManualRtspCameraPageState extends State<ManualRtspCameraPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _subUrlController = TextEditingController();

  String _codec = 'AUTO';
  Uri? _testedUri;
  RtspPlayerStatus? _playerStatus;
  bool _showUrl = false;
  bool _showSubUrl = false;
  bool _saving = false;

  bool get _isLive => _playerStatus == RtspPlayerStatus.live;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _subUrlController.dispose();
    super.dispose();
  }

  void _testCamera() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uri = RtspUriParser.tryParse(_urlController.text);
    if (uri == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _urlController.text = uri.toString();
      _testedUri = uri;
      _playerStatus = RtspPlayerStatus.connecting;
    });
  }

  Future<void> _pasteUrl(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => controller.text = value);
  }

  Future<void> _saveCamera() async {
    final uri = _testedUri;
    if (uri == null ||
        !_isLive ||
        _saving ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final subStreamValue = _subUrlController.text.trim();
    final subStreamUri = subStreamValue.isEmpty
        ? null
        : RtspUriParser.tryParse(subStreamValue);
    setState(() => _saving = true);
    try {
      final camera = await GetIt.instance<CameraRepository>().addLocalCamera(
        name: _nameController.text,
        rtspUri: uri,
        codec: _codec,
        subStreamUri: subStreamUri,
      );
      if (mounted) context.pop(camera.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera could not be saved. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add RTSP camera')),
      body: SafeArea(
        top: false,
        child: VmsContentConstraint(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const VmsPageTitle(
                title: 'Connect a CCTV camera',
                subtitle: 'Test the live feed before saving it to this phone.',
              ),
              const SizedBox(height: 16),
              VmsSurfaceCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Camera name',
                          hintText: 'Main gate camera',
                          prefixIcon: Icon(Icons.videocam_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a camera name.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _urlController,
                        obscureText: !_showUrl,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'RTSP URL',
                          hintText: 'rtsp://user:password@camera:554/path',
                          prefixIcon: const Icon(Icons.link_rounded),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Paste',
                                onPressed: () => _pasteUrl(_urlController),
                                icon: const Icon(Icons.content_paste_rounded),
                              ),
                              IconButton(
                                tooltip: _showUrl ? 'Hide URL' : 'Show URL',
                                onPressed: () =>
                                    setState(() => _showUrl = !_showUrl),
                                icon: Icon(
                                  _showUrl
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                        validator: RtspUriParser.validate,
                        onChanged: (_) {
                          if (_testedUri != null) {
                            setState(() {
                              _testedUri = null;
                              _playerStatus = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subUrlController,
                        obscureText: !_showSubUrl,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Low-resolution sub-stream (optional)',
                          hintText: 'rtsp://user:password@camera:554/sub',
                          helperText:
                              'Automatically used for 3×3 and 4×4 grids.',
                          prefixIcon: const Icon(Icons.grid_view_rounded),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Paste sub-stream URL',
                                onPressed: () => _pasteUrl(_subUrlController),
                                icon: const Icon(Icons.content_paste_rounded),
                              ),
                              IconButton(
                                tooltip: _showSubUrl ? 'Hide URL' : 'Show URL',
                                onPressed: () =>
                                    setState(() => _showSubUrl = !_showSubUrl),
                                icon: Icon(
                                  _showSubUrl
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          return RtspUriParser.validate(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _codec,
                        decoration: const InputDecoration(
                          labelText: 'Camera codec',
                          prefixIcon: Icon(Icons.memory_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'AUTO',
                            child: Text('Auto detect'),
                          ),
                          DropdownMenuItem(value: 'H264', child: Text('H.264')),
                          DropdownMenuItem(
                            value: 'H265',
                            child: Text('H.265 / HEVC'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _codec = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _testCamera,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('TEST LIVE FEED'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_testedUri != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Camera preview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                RtspPlayerPane(
                  key: ValueKey(_testedUri),
                  uri: _testedUri!,
                  onStatusChanged: (status) {
                    if (mounted) setState(() => _playerStatus = status);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  _isLive
                      ? 'Live feed verified. You can save this camera.'
                      : _playerStatus == RtspPlayerStatus.failed
                      ? 'Connection failed. Check URL, credentials, camera network and codec.'
                      : 'Waiting for live video before save is enabled...',
                  style: TextStyle(
                    color: _isLive
                        ? VmsColors.success
                        : VmsColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isLive && !_saving ? _saveCamera : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('SAVE CAMERA'),
                ),
              ],
              const SizedBox(height: 24),
              const VmsInfoBanner(
                icon: Icons.security_rounded,
                title: 'Private and device-local',
                message:
                    'The phone must be able to reach the camera address. Use the same Wi-Fi or VPN for private cameras. Credentials are stored in encrypted device storage.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
