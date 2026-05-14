import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mobile_cctv_cloud/app/mobile_cctv_cloud_app.dart';

export 'package:mobile_cctv_cloud/app/mobile_cctv_cloud_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MobileCctvCloudApp());
}
