import 'package:flutter/foundation.dart';

/// Tipos de evento que el calendario puede mostrar.
///
/// Cada feature que aporte eventos al calendario declara su tipo aquí.
/// El orden define la prioridad visual en la UI.
enum CalendarEventType {
  anniversary,
  specialDate,
  reminder,
  period,
  birthday,
  datePlan,
  custom;

  String get label {
    switch (this) {
      case CalendarEventType.anniversary:
        return 'Aniversario';
      case CalendarEventType.specialDate:
        return 'Día especial';
      case CalendarEventType.reminder:
        return 'Recordatorio';
      case CalendarEventType.period:
        return 'Menstruación';
      case CalendarEventType.birthday:
        return 'Cumpleaños';
      case CalendarEventType.datePlan:
        return 'Cita';
      case CalendarEventType.custom:
        return 'Evento';
    }
  }
}

/// Evento unificado del calendario.
///
/// Cualquier feature que aporte fechas emite instancias de esta clase,
/// y la pantalla de Calendario las muestra en una sola línea de tiempo.
@immutable
class CalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final CalendarEventType type;

  /// id de la feature que originó el evento (diary, reminders, etc.).
  final String sourceFeature;

  final String? notes;
  final bool isAllDay;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    required this.sourceFeature,
    this.notes,
    this.isAllDay = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'type': type.name,
        'sourceFeature': sourceFeature,
        'notes': notes,
        'isAllDay': isAllDay,
      };

  static CalendarEvent fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        date: DateTime.parse(json['date'] as String),
        type: CalendarEventType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => CalendarEventType.custom,
        ),
        sourceFeature: json['sourceFeature'] as String? ?? '',
        notes: json['notes'] as String?,
        isAllDay: json['isAllDay'] as bool? ?? true,
      );

  CalendarEvent copyWith({
    String? title,
    DateTime? date,
    CalendarEventType? type,
    String? sourceFeature,
    String? notes,
    bool? isAllDay,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      type: type ?? this.type,
      sourceFeature: sourceFeature ?? this.sourceFeature,
      notes: notes ?? this.notes,
      isAllDay: isAllDay ?? this.isAllDay,
    );
  }

  /// `true` si este evento cae en el mismo día calendario que [other].
  bool isSameDay(DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;
}