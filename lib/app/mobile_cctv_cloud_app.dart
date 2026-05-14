import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_cctv_cloud/features/cameras/application/camera_connect_controller.dart';
import 'package:mobile_cctv_cloud/features/cameras/presentation/smart_connect_page.dart';

class MobileCctvCloudApp extends StatelessWidget {
  const MobileCctvCloudApp({super.key, this.enableVideo = true});

  final bool enableVideo;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [videoEnabledProvider.overrideWithValue(enableVideo)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mobile CCTV Cloud',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF126A62),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F8F6),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: const SmartConnectPage(),
      ),
    );
  }
}
