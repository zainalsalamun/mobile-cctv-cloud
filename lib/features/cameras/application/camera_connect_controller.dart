import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobile_cctv_cloud/features/cameras/application/camera_connect_state.dart';
import 'package:mobile_cctv_cloud/features/cameras/data/network_scanner.dart';
import 'package:mobile_cctv_cloud/features/cameras/data/onvif_discovery_service.dart';
import 'package:mobile_cctv_cloud/features/cameras/data/rtsp_diagnostics_service.dart';
import 'package:mobile_cctv_cloud/features/cameras/domain/discovered_camera.dart';
import 'package:mobile_cctv_cloud/features/cameras/domain/rtsp_preset.dart';

final videoEnabledProvider = Provider<bool>((ref) => true);
final networkScannerProvider = Provider<NetworkScanner>(
  (ref) => NetworkScanner(),
);
final rtspDiagnosticsProvider = Provider<RtspDiagnosticsService>(
  (ref) => RtspDiagnosticsService(),
);
final onvifDiscoveryProvider = Provider<OnvifDiscoveryService>(
  (ref) => OnvifDiscoveryService(),
);

final cameraConnectControllerProvider =
    NotifierProvider<CameraConnectController, CameraConnectState>(
      CameraConnectController.new,
    );

class CameraConnectController extends Notifier<CameraConnectState> {
  Player? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  CameraConnectState build() {
    final initial = CameraConnectState.initial();
    if (ref.watch(videoEnabledProvider)) {
      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 512 * 1024,
          title: 'Mobile CCTV Cloud',
        ),
      );
      unawaited(_player!.setVolume(initial.volume));
      final videoController = VideoController(_player!);
      _listenToPlayer();
      ref.onDispose(_disposePlayer);
      return initial.copyWith(
        videoController: videoController,
        debugLogs: [_logLine('MediaKit player initialized')],
      );
    }
    ref.onDispose(_disposePlayer);
    return initial;
  }

  void setIp(String value) {
    state = state.copyWith(ip: value);
    _syncV380UrlFromIp();
  }

  void setUsername(String value) {
    state = state.copyWith(username: value);
  }

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  void setPort(String value) {
    state = state.copyWith(port: value);
  }

  void setRtspUrl(String value) {
    state = state.copyWith(rtspUrl: value);
  }

  Future<void> setMuted(bool value) async {
    final effectiveVolume = value ? 0.0 : state.volume;
    await _player?.setVolume(effectiveVolume);
    state = state.copyWith(isMuted: value);
    _addLog('audio muted=$value volume=${effectiveVolume.round()}');
  }

  Future<void> setVolume(double value) async {
    final volume = value.clamp(0, 100).toDouble();
    await _player?.setVolume(state.isMuted ? 0 : volume);
    state = state.copyWith(volume: volume, isMuted: volume == 0);
    _addLog('audio volume=${volume.round()}');
  }

  void setZoom(double value) {
    final zoom = value.clamp(1, 4).toDouble();
    state = state.copyWith(zoom: zoom);
  }

  void selectHdStream() {
    _selectQualityStream(quality: 'HD', subtype: '0');
  }

  void selectSdStream() {
    _selectQualityStream(quality: 'SD', subtype: '1');
  }

  void selectPreset(RtspPreset preset) {
    _preferSingleScannedIp();
    final url = _buildRtspUrl(preset.path);
    state = state.copyWith(rtspUrl: url, quality: _qualityFromPreset(preset));
    _addLog('preset selected path=${preset.path} url=${_maskUrl(url)}');
  }

  void selectFoundIp(String ip, {bool showStatus = true}) {
    final url = _buildRtspUrl(
      '/cam/realmonitor?channel=1&subtype=0',
      ipOverride: ip,
    );
    state = state.copyWith(
      ip: ip,
      rtspUrl: url,
      status: showStatus ? 'IP $ip dipilih dari hasil scan WiFi' : state.status,
    );
    _addLog('found IP selected ip=$ip url=${_maskUrl(url)}');
  }

  void selectDiscoveredCamera(DiscoveredCamera camera) {
    if (camera.port != null) {
      state = state.copyWith(port: camera.port.toString());
    }
    selectFoundIp(camera.ip);
    _addLog(
      'device selected source=${camera.source.name} ip=${camera.ip} port=${camera.port ?? '-'}',
    );
  }

  Future<void> scanWifiNetwork() async {
    if (state.isScanning) {
      return;
    }

    final preferredPort = int.tryParse(state.port.trim()) ?? 554;
    final ports = {preferredPort, 554, 8554, 5544}.toList();
    state = state.copyWith(
      isScanning: true,
      discoveredCameras: [],
      foundCameraIps: [],
      status: 'Universal Connect: cari CCTV di jaringan...',
    );

    try {
      final discovered = <String, DiscoveredCamera>{};
      final onvifDevices = await ref
          .read(onvifDiscoveryProvider)
          .discover(onLog: _addLog);
      for (final device in onvifDevices) {
        discovered[device.ip] = device;
      }
      _publishDiscovered(discovered.values);

      for (final port in ports) {
        final result = await ref
            .read(networkScannerProvider)
            .scanRtspDevices(
              port: port,
              fallbackLocalIp: state.ip,
              onLog: _addLog,
              onProgress: (progress) {
                final mergedIps = {
                  ...discovered.keys,
                  ...progress.foundIps,
                }.toList();
                state = state.copyWith(
                  foundCameraIps: mergedIps,
                  status:
                      'Universal Connect... ditemukan ${mergedIps.length} kandidat',
                );
              },
            );
        for (final device in result.foundDevices) {
          discovered['${device.ip}:${device.port}'] = device;
        }
        _publishDiscovered(discovered.values);
      }

      final uniqueIps = _uniqueIps(discovered.values);
      if (uniqueIps.length == 1) {
        final firstDevice = discovered.values.firstWhere(
          (device) => device.ip == uniqueIps.single,
        );
        if (firstDevice.port != null) {
          state = state.copyWith(port: firstDevice.port.toString());
        }
        selectFoundIp(uniqueIps.single, showStatus: false);
      }

      final total = uniqueIps.length;
      state = state.copyWith(
        isScanning: false,
        discoveredCameras: discovered.values.toList(),
        foundCameraIps: uniqueIps,
        status: total == 0
            ? 'Tidak ada CCTV ONVIF/RTSP ditemukan. Pastikan CCTV satu WiFi dan ONVIF/RTSP aktif.'
            : 'Universal Connect selesai: $total kandidat kamera ditemukan',
      );
    } catch (error) {
      _addLog('scan failed: $error');
      state = state.copyWith(isScanning: false, status: '$error');
    }
  }

  Future<void> connect() async {
    await _openCurrentUrl(statusPrefix: 'Menghubungkan ke kamera');
  }

  Future<void> autoTryPresets() async {
    if (state.isAutoTrying) {
      return;
    }
    final player = _player;
    if (player == null) {
      state = state.copyWith(status: 'Player video tidak aktif di mode test');
      return;
    }

    state = state.copyWith(isAutoTrying: true);
    _addLog('auto preset started');

    try {
      for (final preset in rtspPresets) {
        final url = _buildRtspUrl(preset.path);
        state = state.copyWith(
          rtspUrl: url,
          status: 'Mencoba ${preset.label}...',
          isPlaying: true,
        );
        _addLog('auto try "${preset.label}" url=${_maskUrl(url)}');

        final result = await _tryOpenForAutoConnect(player, url);
        _addLog('auto result "${preset.label}" success=$result');
        if (result) {
          state = state.copyWith(
            isAutoTrying: false,
            status: 'Berhasil dengan ${preset.label}',
          );
          return;
        }
      }

      _addLog('auto preset finished: all presets failed');
      state = state.copyWith(
        isPlaying: false,
        isAutoTrying: false,
        status:
            'Semua preset gagal. Cek username/password, port RTSP, atau aktifkan ONVIF/RTSP di DVR/kamera.',
      );
    } finally {
      state = state.copyWith(isAutoTrying: false);
    }
  }

  Future<void> diagnoseRtsp() async {
    final url = state.rtspUrl.trim();
    if (url.isEmpty) {
      state = state.copyWith(status: 'Masukkan URL RTSP terlebih dahulu');
      return;
    }

    state = state.copyWith(isDiagnosing: true, status: 'Diagnosa RTSP...');
    final diagnosis = await ref
        .read(rtspDiagnosticsProvider)
        .diagnose(url, onLog: _addLog);
    state = state.copyWith(isDiagnosing: false, status: diagnosis.summary);
  }

  Future<void> stop() async {
    _addLog('stop requested');
    await _player?.stop();
    state = state.copyWith(isPlaying: false, status: 'Stream dihentikan');
  }

  void clearLogs() {
    state = state.copyWith(debugLogs: []);
    debugPrint('[MobileCctvCloud] debug logs cleared');
  }

  Future<bool> _openCurrentUrl({required String statusPrefix}) async {
    final player = _player;
    if (player == null) {
      state = state.copyWith(status: 'Player video tidak aktif di mode test');
      return false;
    }

    final url = state.rtspUrl.trim();
    _addLog('connect url=${_maskUrl(url)}');
    if (url.isEmpty) {
      state = state.copyWith(status: 'Masukkan URL RTSP terlebih dahulu');
      return false;
    }

    state = state.copyWith(status: '$statusPrefix...', isPlaying: true);

    try {
      await player.setVolume(state.isMuted ? 0 : state.volume);
      await player.open(Media(url), play: true);
      _addLog('connect open() returned successfully');
      state = state.copyWith(status: 'Live: $url');
      return true;
    } catch (error) {
      _addLog('connect failed: $error');
      state = state.copyWith(
        isPlaying: false,
        status: 'Gagal membuka stream: $error',
      );
      return false;
    }
  }

  Future<bool> _tryOpenForAutoConnect(Player player, String url) async {
    var hasStartedPlaying = false;
    var hasError = false;
    late final StreamSubscription<String> errorSub;
    late final StreamSubscription<bool> playingSub;

    errorSub = player.stream.error.listen((error) {
      hasError = true;
      _addLog('auto player error: $error');
    });
    playingSub = player.stream.playing.listen((isPlaying) {
      hasStartedPlaying = hasStartedPlaying || isPlaying;
    });

    try {
      await player.setVolume(state.isMuted ? 0 : state.volume);
      await player.open(Media(url), play: true);
      await Future<void>.delayed(const Duration(seconds: 4));
      return hasStartedPlaying && !hasError;
    } catch (error) {
      _addLog('auto open exception: $error');
      return false;
    } finally {
      await errorSub.cancel();
      await playingSub.cancel();
    }
  }

  void _listenToPlayer() {
    _subscriptions
      ..add(
        _player!.stream.buffering.listen((isBuffering) {
          _addLog('player.buffering=$isBuffering');
          if (isBuffering) {
            state = state.copyWith(status: 'Buffering stream kamera...');
          }
        }),
      )
      ..add(
        _player!.stream.error.listen((error) {
          _addLog('player.error=$error');
          state = state.copyWith(
            isPlaying: false,
            status: 'Error player: $error',
          );
        }),
      )
      ..add(
        _player!.stream.playing.listen((isPlaying) {
          _addLog('player.playing=$isPlaying');
          if (isPlaying) {
            state = state.copyWith(
              status: 'Stream berjalan, menunggu frame...',
            );
          }
        }),
      )
      ..add(
        _player!.stream.width.listen((width) {
          _updateResolution(width: width);
        }),
      )
      ..add(
        _player!.stream.height.listen((height) {
          _updateResolution(height: height);
        }),
      )
      ..add(
        _player!.stream.audioBitrate.listen((bitrate) {
          state = state.copyWith(audioKbps: _bitsToKbps(bitrate));
        }),
      )
      ..add(
        _player!.stream.tracks.listen((tracks) {
          final videoKbps = tracks.video
              .map((track) => track.bitrate)
              .whereType<int>()
              .fold<int>(0, (current, next) => next > current ? next : current);
          final audioKbps = tracks.audio
              .map((track) => track.bitrate)
              .whereType<int>()
              .fold<int>(0, (current, next) => next > current ? next : current);
          state = state.copyWith(
            audioAvailable: tracks.audio.length > 1,
            videoKbps: videoKbps > 0
                ? _bitsToKbps(videoKbps.toDouble())
                : state.videoKbps,
            audioKbps: audioKbps > 0
                ? _bitsToKbps(audioKbps.toDouble())
                : state.audioKbps,
          );
          _addLog(
            'tracks video=${tracks.video.length} audio=${tracks.audio.length} '
            'videoKbps=${state.videoKbps} audioKbps=${state.audioKbps}',
          );
        }),
      );
  }

  void _disposePlayer() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _player?.dispose();
    _player = null;
  }

  void _syncV380UrlFromIp() {
    final currentUrl = state.rtspUrl.trim();
    final shouldUpdate =
        currentUrl.isEmpty ||
        currentUrl.contains('/live/ch00_0') ||
        currentUrl.contains('/live/ch00_1') ||
        currentUrl.contains('/video.h264');

    if (shouldUpdate) {
      state = state.copyWith(rtspUrl: _buildRtspUrl('/live/ch00_1'));
    }
  }

  void _preferSingleScannedIp() {
    if (state.foundCameraIps.length == 1 &&
        state.ip.trim() != state.foundCameraIps.single) {
      selectFoundIp(state.foundCameraIps.single, showStatus: false);
    }
  }

  void _publishDiscovered(Iterable<DiscoveredCamera> devices) {
    final list = devices.toList();
    state = state.copyWith(
      discoveredCameras: list,
      foundCameraIps: _uniqueIps(list),
    );
  }

  List<String> _uniqueIps(Iterable<DiscoveredCamera> devices) {
    final ips = <String>{};
    for (final device in devices) {
      ips.add(device.ip);
    }
    return ips.toList();
  }

  void _selectQualityStream({
    required String quality,
    required String subtype,
  }) {
    _preferSingleScannedIp();
    final current = state.rtspUrl;
    String path;

    if (current.contains('/cam/realmonitor')) {
      path = '/cam/realmonitor?channel=1&subtype=$subtype';
    } else if (current.contains('/Streaming/Channels/')) {
      path = subtype == '0'
          ? '/Streaming/Channels/101'
          : '/Streaming/Channels/102';
    } else if (current.contains('/live/ch00_')) {
      path = subtype == '0' ? '/live/ch00_1' : '/live/ch00_0';
    } else {
      path = subtype == '0'
          ? '/cam/realmonitor?channel=1&subtype=0'
          : '/cam/realmonitor?channel=1&subtype=1';
    }

    final url = _buildRtspUrl(path);
    state = state.copyWith(rtspUrl: url, quality: quality);
    _addLog('quality selected $quality url=${_maskUrl(url)}');
  }

  String _qualityFromPreset(RtspPreset preset) {
    final label = preset.label.toLowerCase();
    if (label.contains('sub') || label.contains('ringan')) {
      return 'SD';
    }
    if (label.contains('main') ||
        label.contains('utama') ||
        label.contains('hd')) {
      return 'HD';
    }
    return state.quality;
  }

  void _updateResolution({int? width, int? height}) {
    final current = state.resolution.split('x');
    final currentWidth = current.isNotEmpty
        ? int.tryParse(current.first)
        : null;
    final currentHeight = current.length > 1
        ? int.tryParse(current.last)
        : null;
    final nextWidth = width ?? currentWidth;
    final nextHeight = height ?? currentHeight;

    if (nextWidth == null ||
        nextHeight == null ||
        nextWidth <= 0 ||
        nextHeight <= 0) {
      return;
    }
    state = state.copyWith(resolution: '${nextWidth}x$nextHeight');
  }

  int _bitsToKbps(double? bitsPerSecond) {
    if (bitsPerSecond == null || bitsPerSecond <= 0) {
      return 0;
    }
    return (bitsPerSecond / 1000).round();
  }

  String _buildRtspUrl(String path, {String? ipOverride}) {
    final ip = (ipOverride ?? state.ip).trim();
    if (ip.isEmpty) {
      state = state.copyWith(status: 'Isi IP kamera dulu');
      return state.rtspUrl;
    }

    final username = Uri.encodeComponent(state.username.trim());
    final password = Uri.encodeComponent(state.password.trim());
    final port = state.port.trim();
    final credentials = username.isEmpty
        ? ''
        : password.isEmpty
        ? '$username@'
        : '$username:$password@';
    final host = port.isEmpty ? ip : '$ip:$port';

    return 'rtsp://$credentials$host$path';
  }

  void _addLog(String message) {
    final line = _logLine(message);
    debugPrint('[MobileCctvCloud] $line');
    state = state.copyWith(debugLogs: [line, ...state.debugLogs.take(79)]);
  }

  String _logLine(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    return '$timestamp $message';
  }

  String _maskUrl(String url) => RtspDiagnosticsService.maskUrl(url);
}
