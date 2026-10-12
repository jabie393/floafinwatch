import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/network/reverb_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/auth/domain/user_model.dart';
import '../features/auth/presentation/auth_notifier.dart';
import '../features/developer/dashboard/domain/dashboard_model.dart';
import '../features/developer/dashboard/presentation/dashboard_notifier.dart';
import '../features/developer/payouts/payouts_screen.dart';
import '../features/developer/transactions/transactions_screen.dart';
import 'widget_service.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final widgetService = ref.watch(widgetServiceProvider);
  return FcmService(ref: ref, dio: dio, storage: storage, widgetService: widgetService);
});

/// Top-level background handler untuk menerima sinyal FCM saat app ditutup/background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    final data = message.data;

    debugPrint('[FCM Background] Received data message: $data');

    final storage = SecureStorageService();

    // Verifikasi status login yang tangguh terhadap Keystore background isolate
    bool isLoggedIn = true;
    try {
      final savedLogin = await HomeWidget.getWidgetData<bool>('is_logged_in');
      if (savedLogin != null) {
        isLoggedIn = savedLogin;
      } else {
        final token = await storage.getToken();
        isLoggedIn = token != null && token.isNotEmpty;
      }
    } catch (_) {
      isLoggedIn = true;
    }

    if (!isLoggedIn) {
      debugPrint('[FCM Background] Pengguna belum login atau dalam posisi logout. Mengabaikan notifikasi & sinkronisasi.');
      return;
    }

    try {
      final userCache = await storage.getUserCache();
      if (userCache != null) {
        final user = UserModel.fromRawJson(userCache);
        if (!user.isDeveloper) {
          debugPrint('[FCM Background] Pengguna bukan role ryu_dev. Mengabaikan notifikasi.');
          return;
        }
      }
    } catch (_) {}

    final widgetService = WidgetService(storage: storage);

    DeveloperDashboardData? dashboardData;

    // 1. Coba parse dari payload langsung jika disertakan oleh server
    if (data.containsKey('payload') && data['payload'].toString().isNotEmpty) {
      try {
        final payloadMap = json.decode(data['payload'] as String) as Map<String, dynamic>;
        dashboardData = DeveloperDashboardData.fromJson(payloadMap);
        debugPrint('[FCM Background] Parsed direct payload successfully');
      } catch (e) {
        debugPrint('[FCM Background] Error parsing direct payload: $e');
      }
    }

    // 2. Jika tidak ada payload lengkap, fetch data dashboard terbaru via API dengan saved token
    if (dashboardData == null) {
      try {
        final token = await storage.getToken();
        if (token != null && token.isNotEmpty) {
          final dio = Dio(BaseOptions(
            baseUrl: AppConfig.baseUrl,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
          ));

          final response = await dio.get('/developer/dashboard');
          if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
            final resMap = response.data as Map<String, dynamic>;
            final mapData = resMap['data'] ?? resMap;
            if (mapData is Map<String, dynamic>) {
              dashboardData = DeveloperDashboardData.fromJson(mapData);
              debugPrint('[FCM Background] Fetched fresh dashboard data from API');
            }
          }
        }
      } catch (e) {
        debugPrint('[FCM Background] Error fetching fresh dashboard from API: $e');
      }
    }

    // 3. Update ketiga homescreen widget dengan data terbaru
    if (dashboardData != null) {
      await widgetService.updateWidgetSnapshot(dashboardData);
      debugPrint('[FCM Background] Berhasil memperbarui ketiga widget homescreen secara realtime!');
    } else {
      await widgetService.reRenderWidgets();
    }

    // 4. Periksa preferensi notifikasi pengguna sebelum menampilkan banner notifikasi lokal
    final type = data['type']?.toString().toLowerCase();
    final titleStr = (data['title'] ?? message.notification?.title ?? '').toString();
    final bodyStr = (data['body'] ?? message.notification?.body ?? '').toString();

    final isTransaction = type == 'transaction' ||
        data.containsKey('payment_id') ||
        data.containsKey('order_id') ||
        titleStr.toLowerCase().contains('transaksi') ||
        titleStr.toLowerCase().contains('hak dev');

    final isPayout = type == 'payout' ||
        data.containsKey('payout_id') ||
        data.containsKey('payout_no') ||
        titleStr.toLowerCase().contains('payout') ||
        titleStr.toLowerCase().contains('antrean') ||
        titleStr.toLowerCase().contains('konfirmasi') ||
        titleStr.toLowerCase().contains('bayar ulang') ||
        titleStr.toLowerCase().contains('repay');

    bool shouldShowBanner = true;
    try {
      if (isTransaction) {
        final txEnabled = await storage.isTransactionNotificationEnabled();
        if (!txEnabled) shouldShowBanner = false;
      }
      if (isPayout) {
        final payoutEnabled = await storage.isPayoutNotificationEnabled();
        if (!payoutEnabled) shouldShowBanner = false;
      }
    } catch (_) {}

    // Jika pesan FCM memiliki payload 'notification' resmi (message.notification != null),
    // OS Android (Google Play Services) SUDAH menampilkannya di status bar secara native.
    // Jangan panggil localNotifications.show lagi di background agar notifikasi tidak muncul 2x!
    final hasNativeNotification = message.notification != null;

    if (!hasNativeNotification && shouldShowBanner && titleStr.isNotEmpty) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
      await localNotifications.initialize(
        settings: const InitializationSettings(android: androidInit),
      );
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(FcmService._channel);

      await localNotifications.show(
        id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: titleStr,
        body: bodyStr,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'floafinwatch_v2_channel',
            'Notifikasi Payout & Transaksi F Loafinwatch',
            channelDescription: 'Saluran notifikasi untuk update payout dan transaksi developer realtime',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('floafinwatch'),
            icon: '@drawable/ic_notification',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/floafinwatch'),
            color: Color(0xFF0284C7),
          ),
        ),
        payload: json.encode({
          ...data,
          'title': titleStr,
          'body': bodyStr,
          'type': type,
          'route': FcmService.resolveTargetRoute(data),
        }),
      );
    } else {
      debugPrint('[FCM Background] Banner notifikasi dilewati berdasarkan preferensi pengguna (type=$type)');
    }
  } catch (e, stack) {
    debugPrint('[FCM Background] Error in background handler: $e\n$stack');
  }
}

class FcmService {
  final Ref ref;
  final Dio dio;
  final SecureStorageService storage;
  final WidgetService widgetService;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  FcmService({
    required this.ref,
    required this.dio,
    required this.storage,
    required this.widgetService,
  });

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'floafinwatch_v2_channel',
    'Notifikasi Payout & Transaksi F Loafinwatch',
    description: 'Saluran notifikasi untuk update payout dan transaksi developer realtime',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('floafinwatch'),
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

    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}

    // 2. Setup Local Notifications untuk pop-up banner saat foreground
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Klik notifikasi saat app aktif / foreground
        debugPrint('[FCM Local] Notification clicked: ${response.payload}');
        String targetRoute = '/dev/dashboard';
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final payload = json.decode(response.payload!) as Map<String, dynamic>;
            targetRoute = resolveTargetRoute(payload);
          } catch (_) {
            targetRoute = '/dev/dashboard';
          }
        }
        onNavigate?.call(targetRoute);
      },
    );

    // Buat Notification Channel di Android & bersihkan channel lama tanpa sound kustom
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.deleteNotificationChannel(channelId: 'floafinwatch_channel');
    await androidImplementation?.deleteNotificationChannel(channelId: 'floafinwatch_custom_channel');
    await androidImplementation?.createNotificationChannel(_channel);

    // 3. Ambil dan kirim token ke server
    await registerTokenToServer();

    // Listener jika token Firebase diperbarui
    _fcm.onTokenRefresh.listen((newToken) async {
      await _sendTokenToServer(newToken);
    });

    // 4. Foreground Message Handler (Saat aplikasi sedang dibuka)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[FCM Foreground] Pesan diterima: ${message.data}');

      final token = await storage.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM Foreground] Pengguna belum login atau dalam posisi logout. Mengabaikan pesan.');
        return;
      }

      final userCache = await storage.getUserCache();
      if (userCache != null) {
        try {
          final user = UserModel.fromRawJson(userCache);
          if (!user.isDeveloper) {
            debugPrint('[FCM Foreground] Pengguna bukan role ryu_dev. Mengabaikan pesan.');
            return;
          }
        } catch (_) {}
      }

      // Jika ada instruksi update widget
      if (message.data['action'] == 'sync_widgets' || message.data.containsKey('payload')) {
        try {
          if (message.data.containsKey('payload') && message.data['payload'].toString().isNotEmpty) {
            final payloadMap = json.decode(message.data['payload'] as String) as Map<String, dynamic>;
            final dashboardData = DeveloperDashboardData.fromJson(payloadMap);
            await widgetService.updateWidgetSnapshot(dashboardData);
          } else {
            final response = await dio.get('/developer/dashboard');
            if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
              final resMap = response.data as Map<String, dynamic>;
              final mapData = resMap['data'] ?? resMap;
              if (mapData is Map<String, dynamic>) {
                final dashboardData = DeveloperDashboardData.fromJson(mapData);
                await widgetService.updateWidgetSnapshot(dashboardData);
              }
            }
          }
        } catch (e) {
          debugPrint('[FCM Foreground] Error updating widget: $e');
        }

        // Sinkronisasi realtime layar dalam aplikasi (Dashboard, Payouts, Transactions)
        try {
          ref.read(authNotifierProvider.notifier).refreshProfile();
          ref.read(dashboardNotifierProvider.notifier).loadData(isRefresh: true);
          ref.read(realtimeSyncTriggerProvider.notifier).trigger();
          ref.invalidate(transactionsProvider);
          ref.invalidate(payoutsProvider);
          debugPrint('[FCM Foreground] Auto-sync layar in-app berhasil dipicu.');
        } catch (e) {
          debugPrint('[FCM Foreground] Catatan refresh Riverpod: $e');
        }
      }

      // Tampilkan banner notifikasi lokal jika diizinkan preferensi pengguna
      final data = message.data;
      final type = data['type']?.toString().toLowerCase();
      final titleStr = (message.notification?.title ?? data['title'] ?? '').toString();
      final bodyStr = (message.notification?.body ?? data['body'] ?? '').toString();

      final isTransaction = type == 'transaction' ||
          data.containsKey('payment_id') ||
          data.containsKey('order_id') ||
          titleStr.toLowerCase().contains('transaksi') ||
          titleStr.toLowerCase().contains('hak dev');

      final isPayout = type == 'payout' ||
          data.containsKey('payout_id') ||
          data.containsKey('payout_no') ||
          titleStr.toLowerCase().contains('payout') ||
          titleStr.toLowerCase().contains('antrean') ||
          titleStr.toLowerCase().contains('konfirmasi') ||
          titleStr.toLowerCase().contains('bayar ulang') ||
          titleStr.toLowerCase().contains('repay');

      bool shouldShowBanner = true;
      if (isTransaction) {
        final txEnabled = await storage.isTransactionNotificationEnabled();
        if (!txEnabled) shouldShowBanner = false;
      }
      if (isPayout) {
        final payoutEnabled = await storage.isPayoutNotificationEnabled();
        if (!payoutEnabled) shouldShowBanner = false;
      }

      if (shouldShowBanner && titleStr.isNotEmpty) {
        _localNotifications.show(
          id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: titleStr,
          body: bodyStr,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'floafinwatch_v2_channel',
              'Notifikasi Payout & Transaksi F Loafinwatch',
              channelDescription: 'Saluran notifikasi untuk update payout dan transaksi developer realtime',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('floafinwatch'),
              icon: '@drawable/ic_notification',
              largeIcon: DrawableResourceAndroidBitmap('@mipmap/floafinwatch'),
              color: Color(0xFF0284C7),
            ),
          ),
          payload: json.encode({
            ...message.data,
            'title': titleStr,
            'body': bodyStr,
            'type': type,
            'route': resolveTargetRoute(message.data),
          }),
        );
      } else {
        debugPrint('[FCM Foreground] Banner notifikasi dilewati berdasarkan preferensi pengguna (type=$type)');
      }
    });

    // 5. Interaksi saat notifikasi di-tap dari background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final token = await storage.getToken();
      if (token == null || token.isEmpty) return;

      debugPrint('[FCM Tap] Notifikasi dibuka dari background: ${message.data}');
      final route = resolveTargetRoute(message.data);
      onNavigate?.call(route);
    });

    // 6. Interaksi saat notifikasi di-tap saat app mati total (cold start FCM)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      final token = await storage.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[FCM Cold] Notifikasi membuka aplikasi dari mati: ${initialMessage.data}');
        final route = resolveTargetRoute(initialMessage.data);
        onNavigate?.call(route);
      }
    }

    // 7. Interaksi saat notifikasi lokal di-tap saat app mati total (cold start Local Notification)
    try {
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payloadStr = launchDetails.notificationResponse?.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          final payload = json.decode(payloadStr) as Map<String, dynamic>;
          final route = resolveTargetRoute(payload);
          debugPrint('[FCM Local Cold] Local notification launched app with route: $route');
          onNavigate?.call(route);
        }
      }
    } catch (_) {}
  }

  /// Memetakan data payload notifikasi ke route yang tepat di aplikasi:
  /// - Transaksi -> /dev/transactions
  /// - Payout -> /dev/payouts
  static String resolveTargetRoute(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return '/dev/dashboard';

    // 1. Jika rute eksplisit ditentukan oleh backend
    final explicitRoute = data['route']?.toString().trim();
    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      if (explicitRoute.contains('transaction')) return '/dev/transactions';
      if (explicitRoute.contains('payout')) return '/dev/payouts';
      if (explicitRoute.contains('dashboard')) return '/dev/dashboard';
      return explicitRoute;
    }

    // 2. Berdasarkan field 'type' (transaction / payout)
    final type = data['type']?.toString().toLowerCase().trim();
    if (type == 'transaction') return '/dev/transactions';
    if (type == 'payout') return '/dev/payouts';

    // 3. Berdasarkan atribut kunci ID/Order/No
    if (data.containsKey('payment_id') || data.containsKey('order_id')) {
      return '/dev/transactions';
    }
    if (data.containsKey('payout_id') || data.containsKey('payout_no')) {
      return '/dev/payouts';
    }

    // 4. Fallback pencocokan kata kunci pada judul & pesan
    final title = (data['title'] ?? '').toString().toLowerCase();
    final body = (data['body'] ?? '').toString().toLowerCase();

    if (title.contains('transaksi') ||
        body.contains('transaksi') ||
        title.contains('hak dev') ||
        body.contains('hak dev') ||
        title.contains('pendapatan') ||
        body.contains('pendapatan') ||
        title.contains('order') ||
        body.contains('order')) {
      return '/dev/transactions';
    }

    if (title.contains('payout') ||
        body.contains('payout') ||
        title.contains('antrean') ||
        body.contains('antrean') ||
        title.contains('cair') ||
        body.contains('cair') ||
        title.contains('konfirmasi') ||
        body.contains('konfirmasi') ||
        title.contains('bayar ulang') ||
        body.contains('bayar ulang') ||
        title.contains('repay') ||
        body.contains('repay')) {
      return '/dev/payouts';
    }

    return '/dev/dashboard';
  }

  /// Ambil token dari Firebase dan kirim ke backend Laravel jika user role developer
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

  /// Hapus token di server Laravel & Firebase Messaging saat logout
  Future<void> unregisterTokenFromServer() async {
    try {
      final authToken = await storage.getToken();
      if (authToken != null && authToken.isNotEmpty) {
        try {
          await dio.post(
            '/developer/fcm-token',
            data: {'fcm_token': ''},
          );
        } catch (_) {}
      }
      await _fcm.deleteToken();
      await storage.deleteKey('fcm_device_token');
      debugPrint('[FCM] Token berhasil dihapus dari server & Firebase Messaging');
    } catch (e) {
      debugPrint('[FCM] Error unregistering token: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    final authToken = await storage.getToken();
    if (authToken == null || authToken.isEmpty) {
      // User belum login, token akan dikirim saat login sukses
      return;
    }

    final userCache = await storage.getUserCache();
    if (userCache != null) {
      try {
        final user = UserModel.fromRawJson(userCache);
        if (!user.isDeveloper) {
          debugPrint('[FCM] User bukan role ryu_dev. Tidak mengirim token ke server.');
          return;
        }
      } catch (_) {}
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
