import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static const MethodChannel _appChannel =
      MethodChannel('com.example.gov_translator/app_channel');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Stream<dynamic> get overlayEvents =>
      isSupported ? FlutterOverlayWindow.overlayListener : const Stream.empty();

  static Future<bool> isActive() async {
    if (!isSupported) {
      return false;
    }

    try {
      return await FlutterOverlayWindow.isActive();
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> isPermissionGranted() async {
    if (!isSupported) {
      return false;
    }

    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }

    try {
      return await FlutterOverlayWindow.requestPermission() ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> showOverlay() async {
    if (!isSupported) {
      return;
    }

    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerRight,
        width: 100,
        height: 100,
      );
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> closeOverlay() async {
    if (!isSupported) {
      return;
    }

    try {
      await FlutterOverlayWindow.closeOverlay();
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> shareData(String data) async {
    if (!isSupported) {
      return;
    }

    try {
      await FlutterOverlayWindow.shareData(data);
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> moveToBackground() async {
    if (!isSupported) {
      return;
    }

    try {
      await _appChannel.invokeMethod('moveToBackground');
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> bringToForeground() async {
    if (!isSupported) {
      return;
    }

    try {
      await _appChannel.invokeMethod('bringToForeground');
    } on MissingPluginException {
      return;
    }
  }
}
