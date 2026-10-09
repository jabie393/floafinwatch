import 'package:flutter/services.dart';

class AppSettingsService {
  static const _channel = MethodChannel('com.example.floafinwatch/app_settings');

  /// Membuka halaman "Info Aplikasi" (App Details Settings) secara langsung
  static Future<bool> openAppSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAppSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Membuka halaman pengaturan Autostart MIUI/HyperOS secara langsung
  static Future<bool> openAutostartSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAutostartSettings');
      return res ?? false;
    } catch (_) {
      return openAppSettings();
    }
  }

  /// Meminta sistem Android mengabaikan optimasi baterai (Dialog sistem atau setting langsung)
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mendeteksi apakah izin Mulai Otomatis (Autostart) sudah aktif di sistem
  static Future<bool> isAutostartEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAutostartEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa apakah aplikasi sudah masuk daftar bebas optimasi baterai (No Restrictions)
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final res = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mendeteksi apakah perangkat adalah ekosistem Xiaomi / Redmi / POCO
  static Future<bool> isXiaomiDevice() async {
    try {
      final res = await _channel.invokeMethod<bool>('isXiaomiDevice');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa status lengkap semua izin latar belakang yang dibutuhkan
  static Future<PermissionStatusResult> checkStatus() async {
    final autostart = await isAutostartEnabled();
    final battery = await isIgnoringBatteryOptimizations();
    final isXiaomi = await isXiaomiDevice();
    return PermissionStatusResult(
      isAutostart: autostart,
      isIgnoringBattery: battery,
      isXiaomi: isXiaomi,
    );
  }

  /// Memeriksa apakah semua izin sudah aktif
  static Future<bool> isAllPermissionsGranted() async {
    final status = await checkStatus();
    return status.isAllGranted;
  }
}

class PermissionStatusResult {
  final bool isAutostart;
  final bool isIgnoringBattery;
  final bool isXiaomi;

  const PermissionStatusResult({
    required this.isAutostart,
    required this.isIgnoringBattery,
    required this.isXiaomi,
  });

  bool get isAllGranted => isAutostart && isIgnoringBattery;
}
