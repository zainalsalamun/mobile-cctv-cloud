import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_cctv_cloud/main.dart';

void main() {
  testWidgets('shows CCTV connection form', (tester) async {
    await tester.pumpWidget(const MobileCctvCloudApp(enableVideo: false));

    expect(find.text('Mobile CCTV Cloud'), findsOneWidget);
    expect(find.text('IP kamera'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -720));
    await tester.pumpAndSettle();

    expect(find.text('URL RTSP'), findsOneWidget);
    expect(find.text('EYESEC Dahua main'), findsOneWidget);
  });
}
