import 'package:flutter/material.dart';
import 'form_field.dart';

enum RecurrenceType {
  once, // One-time form
  daily, // Every day
  weekly, // Every week
  monthly, // Every month
  yearly, // Every year
  custom; // Custom schedule

  String toJson() => name;
  static RecurrenceType fromJson(String json) {
    return values.byName(json);
  }
}

enum FormVisibility {
  public, // Visible to all authenticated users
  private; // Visible only to specified users/groups

  String toJson() => name;
  static FormVisibility fromJson(String json) {
    return values.byName(json);
  }
}

class CustomForm {
  static const String _keyId = 'id';
  static const String _keyTitle = 'title';
  static const String _keyDescription = 'description';
  static const String _keyFields = 'fields';
  static const String _keyCreatedBy = 'created_by';
  static const String _keyCreatedAt = 'created_at';
  static const String _keyFormVisibility = 'form_visibility';
  static const String _keyIsRecurring = 'is_recurring';
  static const String _keyRecurrenceType = 'recurrence_type';
  static const String _keyRecurrenceConfig = 'recurrence_config';
  static const String _keyStartTime = 'start_time';
  static const String _keyEndTime = 'end_time';
  static const String _keyStartDate = 'start_date';
  static const String _keyEndDate = 'end_date';
  static const String _keyTimeZone = 'time_zone';
  static const String _keyIsChecklist = 'is_checklist';

  final String id;
  final String title;
  final String description;
  final List<FormFieldModel> fields;
  final String created_by; // Snake case to match Supabase column name
  final DateTime created_at; // Snake case to match Supabase column name

  // New fields for access control
  final FormVisibility visibility;

  // New fields for scheduling
  final bool isRecurring;
  final RecurrenceType? recurrenceType;
  final Map<String, dynamic>? recurrenceConfig; // Store custom recurrence settings as JSON
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final DateTime? startDate;
  final DateTime? endDate;
  final String timeZone;
  final bool isChecklist;

  const CustomForm({
    required this.id,
    required this.title,
    required this.description,
    required this.fields,
    required this.created_by,
    required this.created_at,
    this.visibility = FormVisibility.public,
    this.isRecurring = false,
    this.recurrenceType,
    this.recurrenceConfig,
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
    this.timeZone = 'UTC',
    this.isChecklist = false,
  });

  CustomForm copyWith({
    String? id,
    String? title,
    String? description,
    List<FormFieldModel>? fields,
    String? created_by,
    DateTime? created_at,
    FormVisibility? visibility,
    bool? isRecurring,
    RecurrenceType? recurrenceType,
    Map<String, dynamic>? recurrenceConfig,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    DateTime? startDate,
    DateTime? endDate,
    String? timeZone,
    bool? isChecklist,
  }) {
    return CustomForm(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fields: fields ?? this.fields,
      created_by: created_by ?? this.created_by,
      created_at: created_at ?? this.created_at,
      visibility: visibility ?? this.visibility,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceConfig: recurrenceConfig ?? this.recurrenceConfig,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timeZone: timeZone ?? this.timeZone,
      isChecklist: isChecklist ?? this.isChecklist,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      _keyId: id,
      _keyTitle: title,
      _keyDescription: description,
      _keyFields: fields.map((field) => field.toJson()).toList(),
      _keyCreatedBy: created_by,
      _keyCreatedAt: created_at.toIso8601String(),
      _keyFormVisibility: visibility.toJson(),
      _keyIsRecurring: isRecurring,
      _keyRecurrenceType: recurrenceType?.toJson(),
      _keyRecurrenceConfig: recurrenceConfig,
      _keyStartTime: startTime != null
          ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
          : null,
      _keyEndTime: endTime != null
          ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
          : null,
      _keyStartDate: startDate?.toIso8601String().split('T').first,
      _keyEndDate: endDate?.toIso8601String().split('T').first,
      _keyTimeZone: timeZone,
      _keyIsChecklist: isChecklist,
    };
  }

  factory CustomForm.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTimeOfDay(String? timeString) {
      if (timeString == null) return null;
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
      return null;
    }

    DateTime? parseDate(String? dateString) {
      if (dateString == null) return null;
      return DateTime.tryParse(dateString);
    }
    
    List<dynamic> fieldsJson = [];
    if (json[_keyFields] != null && json[_keyFields] is List) {
      fieldsJson = json[_keyFields] as List<dynamic>;
    }

    return CustomForm(
      id: json[_keyId] ?? '', // Provide default if necessary or handle error
      title: json[_keyTitle] ?? '',
      description: json[_keyDescription] ?? '',
      fields: fieldsJson.map((field) => FormFieldModel.fromJson(field)).toList(),
      created_by: json[_keyCreatedBy] ?? '',
      created_at: parseDate(json[_keyCreatedAt]?.toString()) ?? DateTime.now(), // Ensure DateTime is not null
      visibility: json[_keyFormVisibility] != null
          ? FormVisibility.fromJson(json[_keyFormVisibility])
          : FormVisibility.public,
      isRecurring: json[_keyIsRecurring] ?? false,
      recurrenceType: json[_keyRecurrenceType] != null
          ? RecurrenceType.fromJson(json[_keyRecurrenceType])
          : null,
      recurrenceConfig: json[_keyRecurrenceConfig] as Map<String, dynamic>?,
      startTime: parseTimeOfDay(json[_keyStartTime]?.toString()),
      endTime: parseTimeOfDay(json[_keyEndTime]?.toString()),
      startDate: parseDate(json[_keyStartDate]?.toString()),
      endDate: parseDate(json[_keyEndDate]?.toString()),
      timeZone: json[_keyTimeZone] ?? 'UTC',
      isChecklist: json[_keyIsChecklist] ?? false,
    );
  }
}
