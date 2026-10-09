import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/developer/dashboard/domain/dashboard_model.dart';
import 'widget_service.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final widgetService = ref.watch(widgetServiceProvider);
  return FcmService(dio: dio, storage: storage, widgetService: widgetService);
});

/// Top-level background handler untuk menerima sinyal FCM saat app ditutup/background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final data = message.data;

    // Jika pesan membawa payload untuk update homescreen widget secara realtime
    if (data.containsKey('action') && data['action'] == 'sync_widgets' ||
        data.containsKey('summary')) {
      final storage = SecureStorageService();
      final widgetService = WidgetService(storage: storage);

      if (data.containsKey('payload')) {
        final payloadMap = json.decode(data['payload'] as String) as Map<String, dynamic>;
        final dashboardData = DeveloperDashboardData.fromJson(payloadMap);
        await widgetService.updateWidgetSnapshot(dashboardData);
      } else {
        // Fallback: update dengan snapshot yang ada
        final cached = await widgetService.getLastWidgetSnapshot();
        if (cached != null) {
          debugPrint('[FCM Background] Widget snapshot synchronized');
        }
      }
    }
  } catch (e) {
    debugPrint('[FCM Background] Error in background handler: $e');
  }
}

class FcmService {
  final Dio dio;
  final SecureStorageService storage;
  final WidgetService widgetService;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  FcmService({
    required this.dio,
    required this.storage,
    required this.widgetService,
  });

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'floafinwatch_channel',
    'Notifikasi Payout & Transaksi F Loafinwatch',
    description: 'Saluran notifikasi untuk update payout dan transaksi developer realtime',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Inisialisasi seluruh listener FCM & Local Notifications
  Future<void> initialize({void Function(String route)? onNavigate}) async {
    // 1. Request Izin Notifikasi (Android 13+ & iOS)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[FCM] Izin notifikasi disetujui');
    }

    // 2. Setup Local Notifications untuk pop-up banner saat foreground
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Klik notifikasi saat app aktif / foreground
        debugPrint('[FCM Local] Notification clicked: ${response.payload}');
        String targetRoute = '/dev/payouts';
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final payload = json.decode(response.payload!) as Map<String, dynamic>;
            targetRoute = payload['route'] as String? ?? '/dev/payouts';
          } catch (_) {}
        }
        onNavigate?.call(targetRoute);
      },
    );

    // Buat Notification Channel di Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Ambil dan kirim token ke server
    await registerTokenToServer();

    // Listener jika token Firebase diperbarui
    _fcm.onTokenRefresh.listen((newToken) async {
      await _sendTokenToServer(newToken);
    });

    // 4. Foreground Message Handler (Saat aplikasi sedang dibuka)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[FCM Foreground] Pesan diterima: ${message.notification?.title}');

      // Jika ada instruksi update widget
      if (message.data['action'] == 'sync_widgets' || message.data.containsKey('payload')) {
        try {
          if (message.data.containsKey('payload')) {
            final payloadMap = json.decode(message.data['payload'] as String) as Map<String, dynamic>;
            final dashboardData = DeveloperDashboardData.fromJson(payloadMap);
            await widgetService.updateWidgetSnapshot(dashboardData);
          }
        } catch (e) {
          debugPrint('[FCM Foreground] Error updating widget: $e');
        }
      }

      // Tampilkan banner notifikasi lokal
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@drawable/ic_notification',
              largeIcon: const DrawableResourceAndroidBitmap('@mipmap/floafinwatch'),
              color: const Color(0xFF0284C7),
            ),
          ),
          payload: json.encode(message.data),
        );
      }
    });

    // 5. Interaksi saat notifikasi di-tap dari background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM Tap] Notifikasi dibuka dari background: ${message.data}');
      final route = message.data['route'] as String? ?? '/dev/payouts';
      onNavigate?.call(route);
    });

    // 6. Interaksi saat notifikasi di-tap saat app mati total (cold start)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM Cold] Notifikasi membuka aplikasi dari mati: ${initialMessage.data}');
      final route = initialMessage.data['route'] as String? ?? '/dev/payouts';
      onNavigate?.call(route);
    }
  }

  /// Ambil token dari Firebase dan kirim ke backend Laravel
  Future<void> registerTokenToServer() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[FCM] Device Token: $token');
        await storage.saveString('fcm_device_token', token);
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    final authToken = await storage.getToken();
    if (authToken == null || authToken.isEmpty) {
      // User belum login, token akan dikirim saat login sukses
      return;
    }

    try {
      await dio.post(
        '/developer/fcm-token',
        data: {'fcm_token': token},
      );
      debugPrint('[FCM] Token berhasil disinkronkan ke server');
    } catch (e) {
      debugPrint('[FCM] Gagal mengirim token ke server: $e');
    }
  }
}
