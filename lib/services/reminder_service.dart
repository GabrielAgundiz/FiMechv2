import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/model/car.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ReminderInfo {
  final String serviceName;
  final DateTime? lastDone;
  final DateTime nextDue;
  final int intervalMonths;

  ReminderInfo({
    required this.serviceName,
    this.lastDone,
    required this.nextDue,
    required this.intervalMonths,
  });
}

class ReminderService {
  static const Map<String, int> serviceIntervals = {
    'Cambio de aceite': 3,
    'Rotación de llantas': 6,
    'Revisión de frenos': 12,
    'Cambio de batería': 24,
    'Cambio de filtro de aire': 12,
    'Afinación general': 6,
    'Servicio de transmisión': 24,
    'Cambio de líquido refrigerante': 24,
    'Alineación y balanceo': 6,
    'Servicio de aire acondicionado': 12,
  };

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<List<ReminderInfo>> fetchReminders(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('citas')
        .where('userId', isEqualTo: userId)
        .where('status2', isEqualTo: 'Completado')
        .get();

    final Map<String, DateTime> lastDoneMap = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final motivo = (data['motivo'] as String?) ?? '';
      if (!serviceIntervals.containsKey(motivo)) continue;

      final dynamic dateField = data['date'];
      DateTime? date;
      if (dateField is Timestamp) {
        date = dateField.toDate();
      } else if (dateField is DateTime) {
        date = dateField;
      }
      if (date == null) continue;

      if (!lastDoneMap.containsKey(motivo) ||
          date.isAfter(lastDoneMap[motivo]!)) {
        lastDoneMap[motivo] = date;
      }
    }

    final now = DateTime.now();
    final reminders = <ReminderInfo>[];
    for (final entry in serviceIntervals.entries) {
      final serviceName = entry.key;
      final months = entry.value;
      final lastDone = lastDoneMap[serviceName];
      DateTime nextDue;
      if (lastDone != null) {
        nextDue = DateTime(
            lastDone.year, lastDone.month + months, lastDone.day);
      } else {
        nextDue = now;
      }
      reminders.add(ReminderInfo(
        serviceName: serviceName,
        lastDone: lastDone,
        nextDue: nextDue,
        intervalMonths: months,
      ));
    }
    return reminders;
  }

  /// Builds reminders for a specific car using its stored service dates.
  List<ReminderInfo> fetchRemindersForCar(Car car) {
    final now = DateTime.now();

    final Map<String, DateTime?> carDates = {
      'Cambio de aceite': car.aceite,
      'Afinación general': car.afinacion,
      'Cambio de batería': car.bateria,
      'Servicio de aire acondicionado': car.clima,
      'Cambio de filtro de aire': car.filtroAire,
      'Revisión de frenos': car.frenos,
      'Cambio de líquido refrigerante': car.refrigerante,
      'Rotación de llantas': car.rotacion,
      'Servicio de transmisión': car.transmision,
    };

    final reminders = <ReminderInfo>[];
    for (final entry in carDates.entries) {
      final serviceName = entry.key;
      final lastDone = entry.value;
      final months = serviceIntervals[serviceName] ?? 12;

      final nextDue = lastDone != null
          ? DateTime(lastDone.year, lastDone.month + months, lastDone.day)
          : now;

      reminders.add(ReminderInfo(
        serviceName: serviceName,
        lastDone: lastDone,
        nextDue: nextDue,
        intervalMonths: months,
      ));
    }
    return reminders;
  }

  Future<String> fetchCarModel(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('citas')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final automovil =
            (snapshot.docs.first.data()['automovil'] as String?) ?? '';
        if (automovil.isNotEmpty) return automovil;
      }
    } catch (e) {
      debugPrint('Error fetching car model: $e');
    }
    return 'Tu automóvil';
  }

  Future<void> scheduleReminders(String userId) async {
    await _plugin.cancelAll();
    final reminders = await fetchReminders(userId);
    final now = DateTime.now();
    int notifId = 0;

    for (final reminder in reminders) {
      final daysUntilDue = reminder.nextDue.difference(now).inDays;
      if (daysUntilDue <= 14) {
        final scheduledDate = _nextInstanceOf9AM(
            reminder.nextDue.isBefore(now) ? now : reminder.nextDue);
        await _plugin.zonedSchedule(
          notifId++,
          'Servicio pendiente',
          '${reminder.serviceName} está por vencer o ya venció.',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'reminders_channel',
              'Recordatorios de servicio',
              channelDescription:
                  'Notificaciones de mantenimiento del vehículo',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  tz.TZDateTime _nextInstanceOf9AM(DateTime from) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local, from.year, from.month, from.day, 9);
    if (scheduled.isBefore(now)) {
      scheduled =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }
    return scheduled;
  }
}
