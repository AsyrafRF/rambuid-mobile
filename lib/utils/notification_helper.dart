import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
  'hotspot_channel',
  'Hotspot Notifications',
  channelDescription: 'Notifikasi saat hotspot aktif atau IP berubah',
  importance: Importance.high,
  priority: Priority.high,
  showWhen: false,
);

const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

/// Notifikasi saat fallback/hotspot aktif kembali
Future<void> showFallbackNotification(String ssid) async {
  await flutterLocalNotificationsPlugin.show(
    0,
    '📡 Hotspot Aktif',
    'Koneksi gagal. Hotspot "$ssid" telah aktif kembali.',
    platformDetails,
  );
}

/// Notifikasi saat alamat IP Raspberry Pi berubah
Future<void> showIPChangeNotification(String newIP) async {
  const androidDetails = AndroidNotificationDetails(
    'ip_change_channel',
    'IP Address Change',
    importance: Importance.high,
    priority: Priority.high,
  );

  const notificationDetails = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    1, // Gunakan ID berbeda agar tidak tumpang tindih dengan notifikasi fallback
    '🌐 IP RPi Berubah',
    'Alamat IP RPi sekarang: $newIP',
    notificationDetails,
  );
}
