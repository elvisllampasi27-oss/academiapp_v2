import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as zonas;
import 'package:timezone/timezone.dart' as tz;

import '../domain/recordatorios.dart';

/// Recordatorios con flutter_local_notifications (solo Android). Las horas
/// son de Perú. Sin alarmas exactas: Android puede entregarlos con unos
/// minutos de margen, que para un recordatorio de estudio basta.
class ServicioRecordatoriosLocales implements ServicioRecordatorios {
  final FlutterLocalNotificationsPlugin _plugin;
  Future<tz.Location>? _lima;

  ServicioRecordatoriosLocales({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios',
      'Recordatorios de estudio',
      channelDescription: 'Tus temas del día y el examen del sábado.',
    ),
  );

  Future<tz.Location> _iniciar() => _lima ??= () async {
    zonas.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    return tz.getLocation('America/Lima');
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> pedirPermiso() async {
    await _iniciar();
    final android = _android;
    if (android == null) return false;
    if (await android.areNotificationsEnabled() == true) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> programar(List<Recordatorio> recordatorios) async {
    final lima = await _iniciar();
    await _plugin.cancelAll();
    for (final r in recordatorios) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.titulo,
        body: r.cuerpo,
        scheduledDate: tz.TZDateTime(
          lima,
          r.cuando.year,
          r.cuando.month,
          r.cuando.day,
          r.cuando.hour,
          r.cuando.minute,
        ),
        notificationDetails: _detalles,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
