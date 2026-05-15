import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobile_cctv_cloud/features/cameras/application/camera_connect_controller.dart';
import 'package:mobile_cctv_cloud/features/cameras/application/camera_connect_state.dart';
import 'package:mobile_cctv_cloud/features/cameras/domain/rtsp_preset.dart';
import 'package:mobile_cctv_cloud/features/cameras/presentation/widgets/debug_log_panel.dart';

class SmartConnectPage extends ConsumerStatefulWidget {
  const SmartConnectPage({super.key});

  @override
  ConsumerState<SmartConnectPage> createState() => _SmartConnectPageState();
}

class _SmartConnectPageState extends ConsumerState<SmartConnectPage> {
  late final TextEditingController _ipController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _portController;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(cameraConnectControllerProvider);
    _ipController = TextEditingController(text: initial.ip);
    _usernameController = TextEditingController(text: initial.username);
    _passwordController = TextEditingController(text: initial.password);
    _portController = TextEditingController(text: initial.port);
    _urlController = TextEditingController(text: initial.rtspUrl);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraConnectControllerProvider);
    final controller = ref.read(cameraConnectControllerProvider.notifier);

    ref.listen<CameraConnectState>(cameraConnectControllerProvider, (
      previous,
      next,
    ) {
      _syncControllerText(_ipController, next.ip);
      _syncControllerText(_usernameController, next.username);
      _syncControllerText(_passwordController, next.password);
      _syncControllerText(_portController, next.port);
      _syncControllerText(_urlController, next.rtspUrl);
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile CCTV Cloud'),
        actions: [
          IconButton(
            tooltip: 'Stop stream',
            onPressed: state.isPlaying ? controller.stop : null,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('smart-connect-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _VideoPreview(state: state),
            const SizedBox(height: 16),
            Text(
              state.status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: state.isPlaying
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            _StreamControls(state: state, controller: controller),
            const SizedBox(height: 16),
            DebugLogPanel(logs: state.debugLogs, onClear: controller.clearLogs),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.isScanning ? null : controller.scanWifiNetwork,
              icon: state.isScanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find_outlined),
              label: Text(
                state.isScanning ? 'Mencari CCTV...' : 'Cari CCTV di WiFi',
              ),
            ),
            if (state.foundCameraIps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ip in state.foundCameraIps)
                    ActionChip(
                      avatar: const Icon(Icons.router_outlined, size: 18),
                      label: Text(ip),
                      onPressed: () => controller.selectFoundIp(ip),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.url,
              onChanged: controller.setIp,
              decoration: const InputDecoration(
                labelText: 'IP kamera',
                prefixIcon: Icon(Icons.router_outlined),
                hintText: '192.168.1.3',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    onChanged: controller.setUsername,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: 'admin',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: controller.setPassword,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              onChanged: controller.setPort,
              decoration: const InputDecoration(
                labelText: 'Port RTSP',
                prefixIcon: Icon(Icons.settings_ethernet_outlined),
                hintText: '554',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              onChanged: controller.setRtspUrl,
              decoration: const InputDecoration(
                labelText: 'URL RTSP',
                prefixIcon: Icon(Icons.videocam_outlined),
                hintText: 'rtsp://admin:password@192.168.1.3:554/...',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in rtspPresets)
                  ActionChip(
                    avatar: Icon(preset.icon, size: 18),
                    label: Text(preset.label),
                    onPressed: () => controller.selectPreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: state.isAutoTrying ? null : controller.autoTryPresets,
              icon: state.isAutoTrying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_search_outlined),
              label: Text(
                state.isAutoTrying ? 'Mencoba preset...' : 'Smart Connect',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.isDiagnosing ? null : controller.diagnoseRtsp,
              icon: state.isDiagnosing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bug_report_outlined),
              label: Text(state.isDiagnosing ? 'Diagnosa...' : 'Diagnosa RTSP'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.connect,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Hubungkan CCTV'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.stop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Putuskan Stream'),
            ),
            const SizedBox(height: 24),
            const _ConnectionNotes(),
          ],
        ),
      ),
    );
  }

  void _syncControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.state});

  final CameraConnectState state;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111816),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: state.isPlaying && state.videoController != null
              ? Transform.scale(
                  scale: state.zoom,
                  child: Video(
                    controller: state.videoController!,
                    controls: NoVideoControls,
                  ),
                )
              : const _EmptyPreview(),
        ),
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.linked_camera_outlined, color: Colors.white70, size: 48),
          SizedBox(height: 12),
          Text(
            'Preview CCTV',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Cari CCTV di WiFi lalu hubungkan',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _StreamControls extends StatelessWidget {
  const _StreamControls({required this.state, required this.controller});

  final CameraConnectState state;
  final CameraConnectController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: state.quality == 'HD',
                  avatar: const Icon(Icons.hd_outlined, size: 18),
                  label: const Text('HD'),
                  onSelected: (_) => controller.selectHdStream(),
                ),
                FilterChip(
                  selected: state.quality == 'SD',
                  avatar: const Icon(Icons.sd_outlined, size: 18),
                  label: const Text('SD'),
                  onSelected: (_) => controller.selectSdStream(),
                ),
                ActionChip(
                  avatar: Icon(
                    state.isMuted
                        ? Icons.volume_off_outlined
                        : Icons.volume_up_outlined,
                    size: 18,
                  ),
                  label: Text(state.isMuted ? 'Audio mati' : 'Audio hidup'),
                  onPressed: () => controller.setMuted(!state.isMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.zoom_in_outlined, size: 20),
                const SizedBox(width: 8),
                Text('${state.zoom.toStringAsFixed(1)}x'),
                Expanded(
                  child: Slider(
                    value: state.zoom,
                    min: 1,
                    max: 4,
                    divisions: 6,
                    label: '${state.zoom.toStringAsFixed(1)}x',
                    onChanged: controller.setZoom,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.volume_up_outlined, size: 20),
                const SizedBox(width: 8),
                Text('${state.volume.round()}%'),
                Expanded(
                  child: Slider(
                    value: state.volume,
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: '${state.volume.round()}%',
                    onChanged: controller.setVolume,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.aspect_ratio_outlined,
                  label: 'Resolusi ${state.resolution}',
                ),
                _InfoChip(
                  icon: Icons.speed_outlined,
                  label: state.videoKbps > 0
                      ? 'Video ${state.videoKbps} kbps'
                      : 'Video kbps belum terbaca',
                ),
                _InfoChip(
                  icon: Icons.graphic_eq_outlined,
                  label: state.audioAvailable
                      ? state.audioKbps > 0
                            ? 'Audio ${state.audioKbps} kbps'
                            : 'Audio tersedia'
                      : 'Audio belum terdeteksi',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ConnectionNotes extends StatelessWidget {
  const _ConnectionNotes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Connect',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alur ideal untuk user rumahan: Cari CCTV di WiFi, isi username/password, lalu Smart Connect mencoba format stream umum secara otomatis.',
            ),
          ],
        ),
      ),
    );
  }
}
