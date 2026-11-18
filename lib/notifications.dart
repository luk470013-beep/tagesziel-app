import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Kapselt alle Erinnerungen. In der Browser-Vorschau ist alles ein No-op.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  static const int morningId = 1;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Erinnerungen funktionieren nur in der Android-App.
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications.init fehlgeschlagen: $e');
    }
  }

  /// Fragt (falls nötig) die Erlaubnis für Benachrichtigungen an.
  Future<bool> ensurePermission() async {
    if (!supported) return false;
    await init();
    final android = _android;
    if (android == null) return false;
    final enabled = await android.areNotificationsEnabled() ?? false;
    if (enabled) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  NotificationDetails _details({required bool morning}) => NotificationDetails(
        android: AndroidNotificationDetails(
          morning ? 'morning' : 'reminders',
          morning ? 'Morgen-Erinnerung' : 'Erinnerungen',
          channelDescription: morning
              ? 'Tägliche Erinnerung, die Tagesziele zu setzen'
              : 'Erinnerungen zu deinen Einträgen',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  Future<AndroidScheduleMode> _mode() async {
    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Nächster passender Termin in der Zukunft.
  tz.TZDateTime _next(DateTime at, Repeat repeat) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(
        tz.local, at.year, at.month, at.day, at.hour, at.minute);
    if (repeat == Repeat.none) return t;
    final step = repeat == Repeat.daily ? 1 : 7;
    if (repeat == Repeat.daily) {
      t = tz.TZDateTime(tz.local, now.year, now.month, now.day, at.hour,
          at.minute);
    }
    while (!t.isAfter(now)) {
      t = tz.TZDateTime(
          tz.local, t.year, t.month, t.day + step, t.hour, t.minute);
    }
    return t;
  }

  /// Plant (oder entfernt) die Erinnerung zu einem Eintrag.
  Future<void> syncEntry(Entry e) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: e.nid);
      final at = e.remindAt;
      if (at == null) return;
      if (e.type == EntryType.goal && e.done) return;
      final when = _next(at, e.repeat);
      if (e.repeat == Repeat.none &&
          !when.isAfter(tz.TZDateTime.now(tz.local))) {
        return;
      }
      await _plugin.zonedSchedule(
        id: e.nid,
        title: e.title,
        body: e.note.isNotEmpty ? e.note : e.type.label,
        scheduledDate: when,
        notificationDetails: _details(morning: false),
        androidScheduleMode: await _mode(),
        matchDateTimeComponents: switch (e.repeat) {
          Repeat.none => null,
          Repeat.daily => DateTimeComponents.time,
          Repeat.weekly => DateTimeComponents.dayOfWeekAndTime,
        },
        payload: e.id,
      );
    } catch (err) {
      debugPrint('Erinnerung konnte nicht geplant werden: $err');
    }
  }

  Future<void> cancelEntry(Entry e) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: e.nid);
    } catch (_) {}
  }

  /// Tägliche Morgen-Erinnerung "Setz dir deine Tagesziele".
  Future<void> syncMorning(Settings s) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: morningId);
      if (!s.morningEnabled) return;
      final now = DateTime.now();
      final when = _next(
        DateTime(now.year, now.month, now.day, s.morningHour, s.morningMinute),
        Repeat.daily,
      );
      await _plugin.zonedSchedule(
        id: morningId,
        title: 'Guten Morgen ☀️',
        body: 'Setz dir deine Tagesziele für heute.',
        scheduledDate: when,
        notificationDetails: _details(morning: true),
        androidScheduleMode: await _mode(),
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (err) {
      debugPrint('Morgen-Erinnerung fehlgeschlagen: $err');
    }
  }

  /// Plant alle Erinnerungen neu (z. B. nach Import).
  Future<void> resyncAll(Iterable<Entry> entries, Settings s) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    for (final e in entries) {
      if (e.hasReminder) await syncEntry(e);
    }
    await syncMorning(s);
  }
}
