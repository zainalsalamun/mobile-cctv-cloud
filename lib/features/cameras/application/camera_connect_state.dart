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
      videoController: videoController ?? this.videoController,
      foundCameraIps: foundCameraIps ?? this.foundCameraIps,
      debugLogs: debugLogs ?? this.debugLogs,
    );
  }
}
