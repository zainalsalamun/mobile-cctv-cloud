class DiscoveredCamera {
  const DiscoveredCamera({
    required this.ip,
    required this.source,
    this.port,
    this.xaddr,
  });

  final String ip;
  final CameraDiscoverySource source;
  final int? port;
  final String? xaddr;

  String get label {
    final portLabel = port == null ? '' : ':$port';
    return '$ip$portLabel';
  }
}

enum CameraDiscoverySource { onvif, rtsp }
