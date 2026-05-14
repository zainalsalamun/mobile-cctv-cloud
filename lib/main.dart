import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MobileCctvCloudApp());
}

class MobileCctvCloudApp extends StatelessWidget {
  const MobileCctvCloudApp({super.key, this.enableVideo = true});

  final bool enableVideo;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF126A62);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mobile CCTV Cloud',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: CctvHomePage(enableVideo: enableVideo),
    );
  }
}

class CctvHomePage extends StatefulWidget {
  const CctvHomePage({super.key, this.enableVideo = true});

  final bool enableVideo;

  @override
  State<CctvHomePage> createState() => _CctvHomePageState();
}

class _CctvHomePageState extends State<CctvHomePage> {
  static const List<_RtspPreset> _rtspPresets = [
    _RtspPreset('V380 utama', '/live/ch00_1', Icons.hd_outlined),
    _RtspPreset('V380 ringan', '/live/ch00_0', Icons.sd_outlined),
    _RtspPreset('V380 video.h264', '/video.h264', Icons.link_outlined),
    _RtspPreset(
      'EYESEC Dahua main',
      '/cam/realmonitor?channel=1&subtype=0',
      Icons.visibility_outlined,
    ),
    _RtspPreset(
      'EYESEC Dahua sub',
      '/cam/realmonitor?channel=1&subtype=1',
      Icons.visibility_outlined,
    ),
    _RtspPreset(
      'EYESEC Hikvision main',
      '/Streaming/Channels/101',
      Icons.account_tree_outlined,
    ),
    _RtspPreset(
      'EYESEC Hikvision sub',
      '/Streaming/Channels/102',
      Icons.account_tree_outlined,
    ),
    _RtspPreset(
      'EYESEC generic',
      '/h264/ch1/main/av_stream',
      Icons.link_outlined,
    ),
    _RtspPreset('Generic live', '/live', Icons.link_outlined),
    _RtspPreset('Generic stream1', '/stream1', Icons.link_outlined),
    _RtspPreset('Generic onvif1', '/onvif1', Icons.link_outlined),
  ];

  Player? _player;
  VideoController? _videoController;
  late final List<StreamSubscription<dynamic>> _subscriptions;

  final TextEditingController _ipController = TextEditingController(
    text: '192.168.1.10',
  );
  final TextEditingController _usernameController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '554',
  );
  final TextEditingController _urlController = TextEditingController(
    text: 'rtsp://192.168.1.10/live/ch00_1',
  );

  bool _isPlaying = false;
  bool _isScanning = false;
  bool _isAutoTrying = false;
  final List<String> _foundCameraIps = [];
  String _status = 'Belum terhubung';

  @override
  void initState() {
    super.initState();
    _subscriptions = [];
    if (widget.enableVideo) {
      _player = Player();
      _videoController = VideoController(_player!);
      _subscriptions
        ..add(
          _player!.stream.buffering.listen((isBuffering) {
            if (mounted && isBuffering) {
              setState(() => _status = 'Buffering stream kamera...');
            }
          }),
        )
        ..add(
          _player!.stream.error.listen((error) {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _status = 'Error player: $error';
              });
            }
          }),
        )
        ..add(
          _player!.stream.playing.listen((isPlaying) {
            if (mounted && isPlaying) {
              setState(() => _status = 'Stream berjalan, menunggu frame...');
            }
          }),
        );
    }
    _ipController.addListener(_syncRtspFromIp);
  }

  @override
  void dispose() {
    _ipController.removeListener(_syncRtspFromIp);
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _urlController.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await _openCurrentUrl(statusPrefix: 'Menghubungkan ke kamera');
  }

  Future<bool> _openCurrentUrl({required String statusPrefix}) async {
    final player = _player;
    if (player == null) {
      setState(() => _status = 'Player video tidak aktif di mode test');
      return false;
    }

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _status = 'Masukkan URL RTSP terlebih dahulu');
      return false;
    }

    setState(() {
      _status = '$statusPrefix...';
      _isPlaying = true;
    });

    try {
      await player.open(Media(url), play: true);
      setState(() => _status = 'Live: $url');
      return true;
    } catch (error) {
      setState(() {
        _isPlaying = false;
        _status = 'Gagal membuka stream: $error';
      });
      return false;
    }
  }

  Future<void> _autoTryPresets() async {
    if (_isAutoTrying) {
      return;
    }

    final player = _player;
    if (player == null) {
      setState(() => _status = 'Player video tidak aktif di mode test');
      return;
    }

    setState(() => _isAutoTrying = true);

    try {
      for (final preset in _rtspPresets) {
        if (!mounted) {
          return;
        }

        _urlController.text = _buildRtspUrl(preset.path);
        setState(() {
          _status = 'Mencoba ${preset.label}...';
          _isPlaying = true;
        });

        final result = await _tryOpenForAutoConnect(player);
        if (result) {
          if (mounted) {
            setState(() => _status = 'Berhasil dengan ${preset.label}');
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isPlaying = false;
          _status =
              'Semua preset gagal. Cek username/password, port RTSP, atau aktifkan ONVIF/RTSP di DVR/kamera.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAutoTrying = false);
      }
    }
  }

  Future<bool> _tryOpenForAutoConnect(Player player) async {
    final completer = Completer<bool>();
    late final StreamSubscription<String> errorSub;
    late final StreamSubscription<bool> playingSub;

    void complete(bool value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    errorSub = player.stream.error.listen((_) => complete(false));
    playingSub = player.stream.playing.listen((isPlaying) {
      if (isPlaying) {
        complete(true);
      }
    });

    try {
      await player.open(Media(_urlController.text.trim()), play: true);
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    } finally {
      await errorSub.cancel();
      await playingSub.cancel();
    }
  }

  Future<void> _stop() async {
    await _player?.stop();
    setState(() {
      _isPlaying = false;
      _status = 'Stream dihentikan';
    });
  }

  Future<void> _scanWifiNetwork() async {
    if (_isScanning) {
      return;
    }

    final port = int.tryParse(_portController.text.trim()) ?? 554;
    var localIp = await NetworkInfo().getWifiIP();
    localIp ??= _ipController.text.trim();
    final subnet = _subnetPrefix(localIp);

    if (subnet == null) {
      setState(() => _status = 'Tidak bisa membaca subnet WiFi perangkat');
      return;
    }

    setState(() {
      _isScanning = true;
      _foundCameraIps.clear();
      _status = 'Scan WiFi $subnet.0/24 pada port $port...';
    });

    final found = <String>[];
    try {
      for (var start = 1; start <= 254; start += 32) {
        final end = (start + 31).clamp(1, 254);
        final checks = <Future<String?>>[];
        for (var host = start; host <= end; host++) {
          final ip = '$subnet.$host';
          if (ip == localIp) {
            continue;
          }
          checks.add(_checkRtspPort(ip, port));
        }

        final results = await Future.wait(checks);
        found.addAll(results.whereType<String>());
        if (!mounted) {
          return;
        }
        setState(() {
          _foundCameraIps
            ..clear()
            ..addAll(found);
          _status =
              'Scan WiFi $subnet.0/24... ditemukan ${found.length} kandidat';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = found.isEmpty
              ? 'Tidak ada perangkat RTSP di port $port. Coba port 5544 atau cek CCTV sudah satu WiFi.'
              : 'Scan selesai: ${found.length} kandidat kamera ditemukan';
        });
      }
    }
  }

  Future<String?> _checkRtspPort(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 350),
      );
      socket.destroy();
      return ip;
    } catch (_) {
      return null;
    }
  }

  String? _subnetPrefix(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return null;
    }
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((part) => part == null || part < 0 || part > 255)) {
      return null;
    }
    return '${octets[0]}.${octets[1]}.${octets[2]}';
  }

  void _syncRtspFromIp() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      return;
    }
    final currentUrl = _urlController.text.trim();
    final shouldUpdate =
        currentUrl.isEmpty ||
        currentUrl.contains('/live/ch00_0') ||
        currentUrl.contains('/live/ch00_1') ||
        currentUrl.contains('/video.h264');

    if (shouldUpdate) {
      _urlController.text = _buildRtspUrl('/live/ch00_1');
    }
  }

  void _useStream(String path) {
    _urlController.text = _buildRtspUrl(path);
  }

  void _useFoundIp(String ip) {
    _ipController.text = ip;
    _urlController.text = _buildRtspUrl('/cam/realmonitor?channel=1&subtype=0');
    setState(() => _status = 'IP $ip dipilih dari hasil scan WiFi');
  }

  String _buildRtspUrl(String path) {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() => _status = 'Isi IP kamera dulu');
      return _urlController.text;
    }

    final username = Uri.encodeComponent(_usernameController.text.trim());
    final password = Uri.encodeComponent(_passwordController.text.trim());
    final port = _portController.text.trim();
    final credentials = username.isEmpty
        ? ''
        : password.isEmpty
        ? '$username@'
        : '$username:$password@';
    final host = port.isEmpty ? ip : '$ip:$port';

    return 'rtsp://$credentials$host$path';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile CCTV Cloud'),
        actions: [
          IconButton(
            tooltip: 'Stop stream',
            onPressed: _isPlaying ? _stop : null,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF111816),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _isPlaying && _videoController != null
                      ? Video(
                          controller: _videoController!,
                          controls: NoVideoControls,
                        )
                      : const _EmptyPreview(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _isPlaying ? colorScheme.primary : colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'IP kamera',
                prefixIcon: Icon(Icons.router_outlined),
                hintText: '192.168.1.10',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
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
              decoration: const InputDecoration(
                labelText: 'Port RTSP',
                prefixIcon: Icon(Icons.settings_ethernet_outlined),
                hintText: '554',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _isScanning ? null : _scanWifiNetwork,
              icon: _isScanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find_outlined),
              label: Text(_isScanning ? 'Scan WiFi berjalan...' : 'Scan WiFi'),
            ),
            if (_foundCameraIps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ip in _foundCameraIps)
                    ActionChip(
                      avatar: const Icon(Icons.router_outlined, size: 18),
                      label: Text(ip),
                      onPressed: () => _useFoundIp(ip),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL RTSP',
                prefixIcon: Icon(Icons.videocam_outlined),
                hintText: 'rtsp://192.168.1.10/live/ch00_1',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _rtspPresets)
                  _StreamPresetChip(
                    label: preset.label,
                    icon: preset.icon,
                    onPressed: () => _useStream(preset.path),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _isAutoTrying ? null : _autoTryPresets,
              icon: _isAutoTrying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_search_outlined),
              label: Text(
                _isAutoTrying ? 'Mencoba preset...' : 'Auto Coba Preset',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Hubungkan CCTV'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _stop,
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
            'Masukkan IP atau URL RTSP kamera',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _StreamPresetChip extends StatelessWidget {
  const _StreamPresetChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class _RtspPreset {
  const _RtspPreset(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
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
              'Catatan koneksi RTSP',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pastikan HP dan kamera berada di jaringan yang sama. Untuk V380, coba /live/ch00_0, /live/ch00_1, atau /video.h264. Untuk EYESEC, isi username/password kamera lalu coba preset Dahua, Hikvision, dan generic.',
            ),
          ],
        ),
      ),
    );
  }
}
