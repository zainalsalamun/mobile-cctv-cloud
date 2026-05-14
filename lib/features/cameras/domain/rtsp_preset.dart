import 'package:flutter/material.dart';

class RtspPreset {
  const RtspPreset({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final String path;
  final IconData icon;
}

const rtspPresets = [
  RtspPreset(
    label: 'V380 utama',
    path: '/live/ch00_1',
    icon: Icons.hd_outlined,
  ),
  RtspPreset(
    label: 'V380 ringan',
    path: '/live/ch00_0',
    icon: Icons.sd_outlined,
  ),
  RtspPreset(
    label: 'V380 video.h264',
    path: '/video.h264',
    icon: Icons.link_outlined,
  ),
  RtspPreset(
    label: 'EYESEC Dahua main',
    path: '/cam/realmonitor?channel=1&subtype=0',
    icon: Icons.visibility_outlined,
  ),
  RtspPreset(
    label: 'EYESEC Dahua sub',
    path: '/cam/realmonitor?channel=1&subtype=1',
    icon: Icons.visibility_outlined,
  ),
  RtspPreset(
    label: 'EYESEC Hikvision main',
    path: '/Streaming/Channels/101',
    icon: Icons.account_tree_outlined,
  ),
  RtspPreset(
    label: 'EYESEC Hikvision sub',
    path: '/Streaming/Channels/102',
    icon: Icons.account_tree_outlined,
  ),
  RtspPreset(
    label: 'EYESEC generic',
    path: '/h264/ch1/main/av_stream',
    icon: Icons.link_outlined,
  ),
  RtspPreset(label: 'Generic live', path: '/live', icon: Icons.link_outlined),
  RtspPreset(
    label: 'Generic stream1',
    path: '/stream1',
    icon: Icons.link_outlined,
  ),
  RtspPreset(
    label: 'Generic onvif1',
    path: '/onvif1',
    icon: Icons.link_outlined,
  ),
];
