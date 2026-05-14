import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RtspDiagnosis {
  const RtspDiagnosis({required this.status, required this.summary});

  final RtspDiagnosisStatus status;
  final String summary;
}

enum RtspDiagnosisStatus { ok, unauthorized, notFound, empty, unknown, failed }

class RtspDiagnosticsService {
  Future<RtspDiagnosis> diagnose(
    String url, {
    required void Function(String message) onLog,
  }) async {
    onLog('diagnose start url=${maskUrl(url)}');

    try {
      final uri = Uri.parse(url);
      final target = _rtspRequestTarget(uri);
      final authHeader = _basicAuthHeader(uri);

      final socket = await Socket.connect(
        uri.host,
        uri.hasPort ? uri.port : 554,
        timeout: const Duration(seconds: 4),
      );
      final response = StringBuffer();
      final subscription = socket.listen((data) {
        response.write(utf8.decode(data, allowMalformed: true));
      });

      socket
        ..write(
          'OPTIONS $target RTSP/1.0\r\n'
          'CSeq: 1\r\n'
          'User-Agent: MobileCctvCloud/1.0\r\n'
          '\r\n',
        )
        ..write(
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
        onLog('diagnose response empty');
        return const RtspDiagnosis(
          status: RtspDiagnosisStatus.empty,
          summary: 'Diagnosa RTSP: tidak ada balasan',
        );
      }

      final lines = raw
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .take(14)
          .join(' | ');
      onLog('diagnose response: $lines');

      if (raw.contains('401')) {
        return const RtspDiagnosis(
          status: RtspDiagnosisStatus.unauthorized,
          summary:
              'Diagnosa RTSP: 401 Unauthorized, username/password salah atau butuh Digest auth',
        );
      }
      if (raw.contains('404')) {
        return const RtspDiagnosis(
          status: RtspDiagnosisStatus.notFound,
          summary: 'Diagnosa RTSP: 404 Not Found, path RTSP salah',
        );
      }
      if (raw.contains('200 OK')) {
        return const RtspDiagnosis(
          status: RtspDiagnosisStatus.ok,
          summary: 'Diagnosa RTSP: 200 OK, path dikenali kamera',
        );
      }
      return const RtspDiagnosis(
        status: RtspDiagnosisStatus.unknown,
        summary: 'Diagnosa RTSP: balasan kamera tidak umum',
      );
    } catch (error) {
      onLog('diagnose failed: $error');
      return RtspDiagnosis(
        status: RtspDiagnosisStatus.failed,
        summary: 'Diagnosa RTSP gagal: $error',
      );
    }
  }

  static String maskUrl(String url) {
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

  String _basicAuthHeader(Uri uri) {
    if (uri.userInfo.isEmpty) {
      return '';
    }
    final username = uri.userInfo.split(':').first;
    final password = uri.userInfo.contains(':')
        ? uri.userInfo.substring(uri.userInfo.indexOf(':') + 1)
        : '';
    final token = base64Encode(utf8.encode('$username:$password'));
    return 'Authorization: Basic $token\r\n';
  }
}
