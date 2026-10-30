import 'package:app/core/core.dart';
import 'package:app/features/stream_demo/models/stream_demo_source.dart';
import 'package:app/features/stream_demo/presentation/widgets/hls_player_pane.dart';
import 'package:app/features/stream_demo/presentation/widgets/local_gateway_player_pane.dart';
import 'package:app/features/stream_demo/presentation/widgets/rtsp_player_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef StreamDemoPlayerBuilder =
    Widget Function(BuildContext context, StreamDemoSource source);

class StreamDemoPage extends StatefulWidget {
  const StreamDemoPage({this.playerBuilder, super.key});

  final StreamDemoPlayerBuilder? playerBuilder;

  @override
  State<StreamDemoPage> createState() => _StreamDemoPageState();
}

class _StreamDemoPageState extends State<StreamDemoPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _gatewayController = TextEditingController();
  final _gatewayTokenController = TextEditingController();
  var _mode = StreamDemoMode.directRtsp;
  var _compatibilityMode = true;
  var _obscureCameraUrl = true;
  StreamDemoSource? _activeSource;
  var _connectionRevision = 0;

  @override
  void dispose() {
    _urlController.dispose();
    _gatewayController.dispose();
    _gatewayTokenController.dispose();
    super.dispose();
  }

  void _selectMode(StreamDemoMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _activeSource = null;
      _urlController.clear();
    });
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _urlController.text = text;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream URL pasted from clipboard.')),
      );
    }
  }

  void _connect() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final source = StreamDemoSourceParser.parse(
      _urlController.text,
      _mode,
      gatewayUrl: _gatewayController.text,
      gatewayToken: _gatewayTokenController.text,
      compatibilityMode: _compatibilityMode,
    );
    if (source == null) return;
    setState(() {
      _activeSource = source;
      _connectionRevision++;
    });
  }

  void _disconnect() {
    setState(() => _activeSource = null);
  }

  Widget _defaultPlayerBuilder(BuildContext context, StreamDemoSource source) {
    return switch (source.mode) {
      StreamDemoMode.directRtsp => RtspPlayerPane(uri: source.uri),
      StreamDemoMode.localGateway => LocalGatewayPlayerPane(
        gatewayBaseUri: source.gatewayUri!,
        rtspUri: source.uri,
        compatibilityMode: source.compatibilityMode,
        gatewayToken: source.gatewayToken,
      ),
      StreamDemoMode.serverHls => HlsPlayerPane(uri: source.uri),
    };
  }

  @override
  Widget build(BuildContext context) {
    final source = _activeSource;
    return Scaffold(
      drawer: const VmsDrawer(currentRoute: '/stream_demo'),
      appBar: AppBar(
        title: const VmsPageTitle(
          title: 'Stream Diagnostics',
          subtitle: 'Camera and gateway validation',
        ),
        actions: [
          const VmsEnvironmentBadge(),
          IconButton(
            tooltip: 'Connection guidance',
            onPressed: _showConnectionHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PageIntro(),
                  const SizedBox(height: 20),
                  _PreviewPanel(
                    source: source,
                    onDisconnect: _disconnect,
                    child: source == null
                        ? const _IdlePreview()
                        : KeyedSubtree(
                            key: ValueKey(
                              '${source.mode}-${source.uri}-$_connectionRevision',
                            ),
                            child:
                                (widget.playerBuilder ?? _defaultPlayerBuilder)(
                                  context,
                                  source,
                                ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel(
                    step: '01',
                    title: 'Choose connection method',
                    caption: 'Smart Gateway is recommended for H.265 cameras.',
                  ),
                  const SizedBox(height: 12),
                  _ConnectionMethodPicker(
                    selected: _mode,
                    onSelected: _selectMode,
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel(
                    step: '02',
                    title: 'Enter stream details',
                    caption: 'Credentials remain in memory only.',
                  ),
                  const SizedBox(height: 12),
                  _ConnectionForm(
                    formKey: _formKey,
                    mode: _mode,
                    urlController: _urlController,
                    gatewayController: _gatewayController,
                    gatewayTokenController: _gatewayTokenController,
                    compatibilityMode: _compatibilityMode,
                    obscureCameraUrl: _obscureCameraUrl,
                    connected: source != null,
                    onCompatibilityChanged: (value) {
                      setState(() => _compatibilityMode = value);
                    },
                    onCameraUrlVisibilityChanged: () {
                      setState(() {
                        _obscureCameraUrl = !_obscureCameraUrl;
                      });
                    },
                    onPaste: _pasteUrl,
                    onConnect: _connect,
                  ),
                  const SizedBox(height: 16),
                  const _NetworkHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showConnectionHelp() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: VmsColors.surface,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before you connect',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16),
              _HelpRow(
                icon: Icons.wifi_rounded,
                text:
                    'Keep the phone, gateway computer, and CCTV mutually reachable.',
              ),
              _HelpRow(
                icon: Icons.hub_outlined,
                text:
                    'Use Smart Gateway when the camera is H.265 or direct RTSP is blocked.',
              ),
              _HelpRow(
                icon: Icons.security_outlined,
                text:
                    'Use the full RTSP URL supplied by the camera owner, including credentials.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: VmsColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: VmsColors.primary.withValues(alpha: 0.22),
            ),
          ),
          child: const Icon(Icons.videocam_outlined, color: VmsColors.primary),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect a CCTV camera',
                style: TextStyle(
                  color: VmsColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.source,
    required this.onDisconnect,
    required this.child,
  });

  final StreamDemoSource? source;
  final VoidCallback onDisconnect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VmsColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VmsColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: source == null
                      ? VmsColors.textMuted
                      : VmsColors.warning,
                  shape: BoxShape.circle,
                  boxShadow: source == null
                      ? null
                      : [
                          BoxShadow(
                            color: VmsColors.warning.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                source == null ? 'CAMERA PREVIEW' : 'CONNECTION SESSION',
                style: const TextStyle(
                  color: VmsColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              if (source != null)
                TextButton.icon(
                  key: const Key('disconnectStreamButton'),
                  onPressed: onDisconnect,
                  icon: const Icon(Icons.stop_circle_outlined, size: 17),
                  label: const Text('STOP'),
                  style: TextButton.styleFrom(
                    foregroundColor: VmsColors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _IdlePreview extends StatelessWidget {
  const _IdlePreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('idlePreview'),
      height: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF020504),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: const Center(
          child: Icon(
            Icons.connected_tv_outlined,
            color: VmsColors.textMuted,
            size: 42,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.step,
    required this.title,
    required this.caption,
  });

  final String step;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: VmsColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: VmsColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: VmsColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: const TextStyle(
                  color: VmsColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionMethodPicker extends StatelessWidget {
  const _ConnectionMethodPicker({
    required this.selected,
    required this.onSelected,
  });

  final StreamDemoMode selected;
  final ValueChanged<StreamDemoMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth < 560;
        final width = twoColumns
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MethodCard(
              width: width,
              icon: Icons.link_rounded,
              title: 'Direct RTSP',
              subtitle: 'Fast local test',
              selected: selected == StreamDemoMode.directRtsp,
              onTap: () => onSelected(StreamDemoMode.directRtsp),
            ),
            _MethodCard(
              width: width,
              icon: Icons.hub_outlined,
              title: 'Smart Gateway',
              subtitle: 'Best for H.265',
              recommended: true,
              selected: selected == StreamDemoMode.localGateway,
              onTap: () => onSelected(StreamDemoMode.localGateway),
            ),
            _MethodCard(
              width: width,
              icon: Icons.dns_outlined,
              title: 'Server HLS',
              subtitle: 'Existing playlist',
              selected: selected == StreamDemoMode.serverHls,
              onTap: () => onSelected(StreamDemoMode.serverHls),
            ),
          ],
        );
      },
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: selected ? VmsColors.surfaceHigh : VmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? VmsColors.primary : VmsColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: selected
                          ? VmsColors.primary
                          : VmsColors.textSecondary,
                      size: 22,
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: VmsColors.primary,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VmsColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  recommended ? '$subtitle • Recommended' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: recommended
                        ? VmsColors.primary
                        : VmsColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionForm extends StatelessWidget {
  const _ConnectionForm({
    required this.formKey,
    required this.mode,
    required this.urlController,
    required this.gatewayController,
    required this.gatewayTokenController,
    required this.compatibilityMode,
    required this.obscureCameraUrl,
    required this.connected,
    required this.onCompatibilityChanged,
    required this.onCameraUrlVisibilityChanged,
    required this.onPaste,
    required this.onConnect,
  });

  final GlobalKey<FormState> formKey;
  final StreamDemoMode mode;
  final TextEditingController urlController;
  final TextEditingController gatewayController;
  final TextEditingController gatewayTokenController;
  final bool compatibilityMode;
  final bool obscureCameraUrl;
  final bool connected;
  final ValueChanged<bool> onCompatibilityChanged;
  final VoidCallback onCameraUrlVisibilityChanged;
  final VoidCallback onPaste;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VmsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: VmsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mode == StreamDemoMode.localGateway) ...[
                TextFormField(
                  key: const Key('gatewayUrlField'),
                  controller: gatewayController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: StreamDemoSourceParser.validateGateway,
                  decoration: const InputDecoration(
                    labelText: 'Gateway computer URL',
                    hintText: 'http://192.168.1.10:8090',
                    prefixIcon: Icon(Icons.computer_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('streamUrlField'),
                controller: urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                obscureText:
                    mode != StreamDemoMode.serverHls && obscureCameraUrl,
                validator: (value) =>
                    StreamDemoSourceParser.validate(value, mode),
                onFieldSubmitted: (_) => onConnect(),
                decoration: InputDecoration(
                  labelText: mode == StreamDemoMode.serverHls
                      ? 'HLS playlist URL'
                      : 'Camera RTSP URL',
                  hintText: mode.hint,
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mode != StreamDemoMode.serverHls)
                        IconButton(
                          tooltip: obscureCameraUrl
                              ? 'Show camera URL'
                              : 'Hide camera URL',
                          onPressed: onCameraUrlVisibilityChanged,
                          icon: Icon(
                            obscureCameraUrl
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Paste URL',
                        onPressed: onPaste,
                        icon: const Icon(Icons.content_paste_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (mode == StreamDemoMode.localGateway) ...[
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const Key('gatewayAdvancedSettings'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    leading: const Icon(
                      Icons.tune_rounded,
                      color: VmsColors.textSecondary,
                    ),
                    title: const Text(
                      'Advanced gateway settings',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Compatibility conversion is enabled',
                      style: TextStyle(fontSize: 11),
                    ),
                    children: [
                      TextFormField(
                        key: const Key('gatewayTokenField'),
                        controller: gatewayTokenController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Gateway access token',
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        key: const Key('compatibilityModeSwitch'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        value: compatibilityMode,
                        onChanged: onCompatibilityChanged,
                        activeTrackColor: VmsColors.primary,
                        title: const Text(
                          'H.265 compatibility conversion',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: const Text(
                          'Recommended for reliable playback on Android devices.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('connectStreamButton'),
                onPressed: onConnect,
                icon: Icon(
                  connected ? Icons.refresh_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(connected ? 'RECONNECT CAMERA' : 'CONNECT CAMERA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkHint extends StatelessWidget {
  const _NetworkHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VmsColors.information.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: VmsColors.information.withValues(alpha: 0.16),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lan_outlined, color: VmsColors.information, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Network check: the gateway computer must be able to reach the CCTV camera. Avoid localhost URLs for a camera on another device.',
              style: TextStyle(
                color: VmsColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: VmsColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: VmsColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
