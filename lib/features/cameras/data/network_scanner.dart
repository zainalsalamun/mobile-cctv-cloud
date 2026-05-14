import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

class ScanProgress {
  const ScanProgress({
    required this.rangeStart,
    required this.rangeEnd,
    required this.foundIps,
  });

  final int rangeStart;
  final int rangeEnd;
  final List<String> foundIps;
}

class WifiScanResult {
  const WifiScanResult({
    required this.localIp,
    required this.subnet,
    required this.port,
    required this.foundIps,
  });

  final String localIp;
  final String subnet;
  final int port;
  final List<String> foundIps;
}

class NetworkScanner {
  Future<WifiScanResult> scanRtspDevices({
    required int port,
    required void Function(String message) onLog,
    required void Function(ScanProgress progress) onProgress,
    String? fallbackLocalIp,
  }) async {
    var localIp = await NetworkInfo().getWifiIP();
    localIp ??= fallbackLocalIp?.trim();
    final subnet = _subnetPrefix(localIp ?? '');

    if (localIp == null || subnet == null) {
      throw const NetworkScanException(
        'Tidak bisa membaca subnet WiFi perangkat',
      );
    }

    onLog('scan requested localIp=$localIp port=$port subnet=$subnet');
    final found = <String>[];

    for (var start = 1; start <= 254; start += 32) {
      final end = (start + 31).clamp(1, 254);
      final checks = <Future<String?>>[];

      for (var host = start; host <= end; host++) {
        final ip = '$subnet.$host';
        if (ip == localIp) {
          continue;
        }
        checks.add(_checkRtspPort(ip, port, onLog));
      }

      final results = await Future.wait(checks);
      found.addAll(results.whereType<String>());
      onProgress(
        ScanProgress(rangeStart: start, rangeEnd: end, foundIps: [...found]),
      );
      onLog(
        'scan progress ${start.toString().padLeft(3, '0')}-$end found=${found.join(', ')}',
      );
    }

    onLog(
      'scan finished port=$port total=${found.length} found=${found.join(', ')}',
    );
    return WifiScanResult(
      localIp: localIp,
      subnet: subnet,
      port: port,
      foundIps: found,
    );
  }

  Future<String?> _checkRtspPort(
    String ip,
    int port,
    void Function(String message) onLog,
  ) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 350),
      );
      socket.destroy();
      onLog('port open $ip:$port');
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
}

class NetworkScanException implements Exception {
  const NetworkScanException(this.message);

  final String message;

  @override
  String toString() => message;
}
