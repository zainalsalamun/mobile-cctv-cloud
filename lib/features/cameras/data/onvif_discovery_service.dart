import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mobile_cctv_cloud/features/cameras/domain/discovered_camera.dart';

class OnvifDiscoveryService {
  Future<List<DiscoveredCamera>> discover({
    required void Function(String message) onLog,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final devices = <String, DiscoveredCamera>{};
    final completer = Completer<List<DiscoveredCamera>>();
    final messageId = _messageId();

    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      final datagram = socket.receive();
      if (datagram == null) {
        return;
      }

      final body = utf8.decode(datagram.data, allowMalformed: true);
      final xaddrs = _extractXAddrs(body);
      for (final xaddr in xaddrs) {
        final uri = Uri.tryParse(xaddr);
        if (uri == null || uri.host.isEmpty) {
          continue;
        }
        devices[uri.host] = DiscoveredCamera(
          ip: uri.host,
          source: CameraDiscoverySource.onvif,
          port: uri.hasPort ? uri.port : null,
          xaddr: xaddr,
        );
        onLog('onvif response ip=${uri.host} xaddr=$xaddr');
      }
    });

    final probe = _probeMessage(messageId);
    socket.send(utf8.encode(probe), InternetAddress('239.255.255.250'), 3702);
    onLog('onvif probe sent messageId=$messageId');

    Timer(timeout, () async {
      await subscription.cancel();
      socket.close();
      if (!completer.isCompleted) {
        completer.complete(devices.values.toList());
      }
    });

    return completer.future;
  }

  List<String> _extractXAddrs(String body) {
    final matches = RegExp(
      r'<(?:\w+:)?XAddrs>([^<]+)</(?:\w+:)?XAddrs>',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(body);
    return [
      for (final match in matches)
        ...?match
            .group(1)
            ?.split(RegExp(r'\s+'))
            .where((value) => value.isNotEmpty),
    ];
  }

  String _messageId() {
    final random = Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'uuid:mobile-cctv-cloud-$random';
  }

  String _probeMessage(String messageId) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
  xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
  xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
  xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
  <e:Header>
    <w:MessageID>$messageId</w:MessageID>
    <w:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
    <w:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>
  </e:Header>
  <e:Body>
    <d:Probe>
      <d:Types>dn:NetworkVideoTransmitter</d:Types>
    </d:Probe>
  </e:Body>
</e:Envelope>
''';
  }
}
