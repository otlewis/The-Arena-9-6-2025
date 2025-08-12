import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class JitsiPermissions {
  static Future<bool> requestPermissions(BuildContext context) async {
    // Request camera and microphone permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    
    bool allGranted = true;
    
    // Check if all permissions are granted
    statuses.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        allGranted = false;
      }
    });
    
    // If not all granted, show dialog
    if (!allGranted && context.mounted) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Permissions Required'),
            content: const Text(
              'Camera and microphone permissions are required for video calls. '
              'Please grant these permissions in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );
    }
    
    return allGranted;
  }
  
  static Future<bool> checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    
    return cameraStatus.isGranted && micStatus.isGranted;
  }
}