import 'package:media_kit_video/media_kit_video.dart';

class CameraConnectState {
  const CameraConnectState({
    required this.ip,
    required this.username,
    required this.password,
    required this.port,
    required this.rtspUrl,
    required this.status,
    this.isPlaying = false,
    this.isScanning = false,
    this.isAutoTrying = false,
    this.isDiagnosing = false,
    this.isMuted = false,
    this.volume = 100,
    this.zoom = 1,
    this.quality = 'Auto',
    this.videoKbps = 0,
    this.audioKbps = 0,
    this.resolution = '-',
    this.audioAvailable = false,
    this.videoController,
    this.foundCameraIps = const [],
    this.debugLogs = const [],
  });

  factory CameraConnectState.initial() {
    return const CameraConnectState(
      ip: '192.168.1.10',
      username: 'admin',
      password: '',
      port: '554',
      rtspUrl: 'rtsp://192.168.1.10/live/ch00_1',
      status: 'Belum terhubung',
    );
  }

  final String ip;
  final String username;
  final String password;
  final String port;
  final String rtspUrl;
  final String status;
  final bool isPlaying;
  final bool isScanning;
  final bool isAutoTrying;
  final bool isDiagnosing;
  final bool isMuted;
  final double volume;
  final double zoom;
  final String quality;
  final int videoKbps;
  final int audioKbps;
  final String resolution;
  final bool audioAvailable;
  final VideoController? videoController;
  final List<String> foundCameraIps;
  final List<String> debugLogs;

  CameraConnectState copyWith({
    String? ip,
    String? username,
    String? password,
    String? port,
    String? rtspUrl,
    String? status,
    bool? isPlaying,
    bool? isScanning,
    bool? isAutoTrying,
    bool? isDiagnosing,
    bool? isMuted,
    double? volume,
    double? zoom,
    String? quality,
    int? videoKbps,
    int? audioKbps,
    String? resolution,
    bool? audioAvailable,
    VideoController? videoController,
    List<String>? foundCameraIps,
    List<String>? debugLogs,
  }) {
    return CameraConnectState(
      ip: ip ?? this.ip,
      username: username ?? this.username,
      password: password ?? this.password,
      port: port ?? this.port,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      status: status ?? this.status,
      isPlaying: isPlaying ?? this.isPlaying,
      isScanning: isScanning ?? this.isScanning,
      isAutoTrying: isAutoTrying ?? this.isAutoTrying,
      isDiagnosing: isDiagnosing ?? this.isDiagnosing,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      zoom: zoom ?? this.zoom,
      quality: quality ?? this.quality,
      videoKbps: videoKbps ?? this.videoKbps,
      audioKbps: audioKbps ?? this.audioKbps,
      resolution: resolution ?? this.resolution,
      audioAvailable: audioAvailable ?? this.audioAvailable,
      videoController: videoController ?? this.videoController,
      foundCameraIps: foundCameraIps ?? this.foundCameraIps,
      debugLogs: debugLogs ?? this.debugLogs,
    );
  }
}
