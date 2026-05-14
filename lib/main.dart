import 'dart:async';
import 'dart:convert';
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
  bool _isDiagnosing = false;
  final List<String> _foundCameraIps = [];
  final List<String> _debugLogs = [];
  String _status = 'Belum terhubung';

  @override
  void initState() {
    super.initState();
    _subscriptions = [];
    if (widget.enableVideo) {
      _player = Player();
      _videoController = VideoController(_player!);
      _addDebugLog('MediaKit player initialized');
      _subscriptions
        ..add(
          _player!.stream.buffering.listen((isBuffering) {
            _addDebugLog('player.buffering=$isBuffering');
            if (mounted && isBuffering) {
              setState(() => _status = 'Buffering stream kamera...');
            }
          }),
        )
        ..add(
          _player!.stream.error.listen((error) {
            _addDebugLog('player.error=$error');
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
            _addDebugLog('player.playing=$isPlaying');
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
    _addDebugLog('connect url=${_maskUrl(url)}');
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
      _addDebugLog('connect open() returned successfully');
      setState(() => _status = 'Live: $url');
      return true;
    } catch (error) {
      _addDebugLog('connect failed: $error');
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
    _addDebugLog('auto preset started');

    try {
      for (final preset in _rtspPresets) {
        if (!mounted) {
          return;
        }

        _urlController.text = _buildRtspUrl(preset.path);
        _addDebugLog(
          'auto try "${preset.label}" url=${_maskUrl(_urlController.text)}',
        );
        setState(() {
          _status = 'Mencoba ${preset.label}...';
          _isPlaying = true;
        });

        final result = await _tryOpenForAutoConnect(player);
        _addDebugLog('auto result "${preset.label}" success=$result');
        if (result) {
          if (mounted) {
            setState(() => _status = 'Berhasil dengan ${preset.label}');
          }
          return;
        }
      }

      if (mounted) {
        _addDebugLog('auto preset finished: all presets failed');
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
        onTimeout: () {
          _addDebugLog('auto timeout waiting for playing event');
          return false;
        },
      );
    } catch (error) {
      _addDebugLog('auto open exception: $error');
      return false;
    } finally {
      await errorSub.cancel();
      await playingSub.cancel();
    }
  }

  Future<void> _stop() async {
    _addDebugLog('stop requested');
    await _player?.stop();
    setState(() {
      _isPlaying = false;
      _status = 'Stream dihentikan';
    });
  }

  Future<void> _diagnoseRtsp() async {
    if (_isDiagnosing) {
      return;
    }

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _status = 'Masukkan URL RTSP terlebih dahulu');
      return;
    }

    setState(() {
      _isDiagnosing = true;
      _status = 'Diagnosa RTSP...';
    });
    _addDebugLog('diagnose start url=${_maskUrl(url)}');

    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : 554;
      final target = _rtspRequestTarget(uri);
      final username = uri.userInfo.split(':').first;
      final password = uri.userInfo.contains(':')
          ? uri.userInfo.substring(uri.userInfo.indexOf(':') + 1)
          : '';
      final authHeader = username.isEmpty
          ? ''
          : 'Authorization: Basic ${base64Encode(utf8.encode('$username:$password'))}\r\n';

      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      final response = StringBuffer();
      final subscription = socket.listen((data) {
        response.write(utf8.decode(data, allowMalformed: true));
      });

      socket.write(
        'OPTIONS $target RTSP/1.0\r\n'
        'CSeq: 1\r\n'
        'User-Agent: MobileCctvCloud/1.0\r\n'
        '\r\n',
      );
      socket.write(
        'DESCRIBE $target RTSP/1.0\r\n'
        'CSeq: 2\r\n'
        'User-Agent: MobileCctvCloud/1.0\r\n'
        'Accept: application/sdp\r\n'
        '$authHeader'
        '\r\n',
      );
      await socket.flush();
      await Future<void>.delayed(const Duration(seconds: 2));
      await subscription.cancel();
      socket.destroy();

      final raw = response.toString().trim();
      if (raw.isEmpty) {
        _addDebugLog('diagnose response empty');
        setState(() => _status = 'Diagnosa RTSP: tidak ada balasan');
        return;
      }

      final lines = raw
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .take(14)
          .join(' | ');
      _addDebugLog('diagnose response: $lines');

      if (raw.contains('401')) {
        setState(
          () => _status =
              'Diagnosa RTSP: 401 Unauthorized, username/password salah atau butuh Digest auth',
        );
      } else if (raw.contains('404')) {
        setState(
          () => _status = 'Diagnosa RTSP: 404 Not Found, path RTSP salah',
        );
      } else if (raw.contains('200 OK')) {
        setState(() => _status = 'Diagnosa RTSP: 200 OK, path dikenali kamera');
      } else {
        setState(() => _status = 'Diagnosa RTSP: balasan kamera tidak umum');
      }
    } catch (error) {
      _addDebugLog('diagnose failed: $error');
      setState(() => _status = 'Diagnosa RTSP gagal: $error');
    } finally {
      if (mounted) {
        setState(() => _isDiagnosing = false);
      }
    }
  }

  Future<void> _scanWifiNetwork() async {
    if (_isScanning) {
      return;
    }

    final port = int.tryParse(_portController.text.trim()) ?? 554;
    var localIp = await NetworkInfo().getWifiIP();
    localIp ??= _ipController.text.trim();
    final subnet = _subnetPrefix(localIp);
    _addDebugLog('scan requested localIp=$localIp port=$port subnet=$subnet');

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
        _addDebugLog(
          'scan progress ${start.toString().padLeft(3, '0')}-$end found=${found.join(', ')}',
        );
      }
    } finally {
      if (mounted) {
        if (found.length == 1) {
          _selectFoundIp(found.single, showStatus: false);
        }
        _addDebugLog(
          'scan finished port=$port total=${found.length} found=${found.join(', ')}',
        );
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
      _addDebugLog('port open $ip:$port');
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
    _preferSingleScannedIp();
    _urlController.text = _buildRtspUrl(path);
    _addDebugLog(
      'preset selected path=$path url=${_maskUrl(_urlController.text)}',
    );
  }

  void _preferSingleScannedIp() {
    if (_foundCameraIps.length == 1 &&
        _ipController.text.trim() != _foundCameraIps.single) {
      _selectFoundIp(_foundCameraIps.single, showStatus: false);
    }
  }

  void _useFoundIp(String ip) {
    _selectFoundIp(ip);
  }

  void _selectFoundIp(String ip, {bool showStatus = true}) {
    _ipController.text = ip;
    _urlController.text = _buildRtspUrl('/cam/realmonitor?channel=1&subtype=0');
    _addDebugLog(
      'found IP selected ip=$ip url=${_maskUrl(_urlController.text)}',
    );
    if (showStatus) {
      setState(() => _status = 'IP $ip dipilih dari hasil scan WiFi');
    }
  }

  void _clearDebugLogs() {
    setState(_debugLogs.clear);
    debugPrint('[MobileCctvCloud] debug logs cleared');
  }

  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final line = '$timestamp $message';
    debugPrint('[MobileCctvCloud] $line');
    if (!mounted) {
      _debugLogs.add(line);
      return;
    }
    setState(() {
      _debugLogs.insert(0, line);
      if (_debugLogs.length > 80) {
        _debugLogs.removeLast();
      }
    });
  }

  String _maskUrl(String url) {
    return url.replaceFirstMapped(
      RegExp(r'rtsp://([^:@/]+):([^@/]+)@'),
      (match) => 'rtsp://${match.group(1)}:***@',
    );
  }

  String _rtspRequestTarget(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return 'rtsp://${uri.host}$port$path$query';
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
            _DebugLogPanel(logs: _debugLogs, onClear: _clearDebugLogs),
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
            OutlinedButton.icon(
              onPressed: _isDiagnosing ? null : _diagnoseRtsp,
              icon: _isDiagnosing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bug_report_outlined),
              label: Text(_isDiagnosing ? 'Diagnosa...' : 'Diagnosa RTSP'),
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

class _DebugLogPanel extends StatelessWidget {
  const _DebugLogPanel({required this.logs, required this.onClear});

  final List<String> logs;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF121715),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Debug Log',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: logs.isEmpty ? null : onClear,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  logs.isEmpty ? 'Belum ada log.' : logs.reversed.join('\n'),
                  style: const TextStyle(
                    color: Color(0xFFE3ECE7),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
