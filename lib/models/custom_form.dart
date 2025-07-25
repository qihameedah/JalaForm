import 'package:flutter/material.dart';
import 'form_field.dart';

enum RecurrenceType {
  once, // One-time form
  daily, // Every day
  weekly, // Every week
  monthly, // Every month
  yearly, // Every year
  custom, // Custom schedule
}

enum FormVisibility {
  public, // Visible to all authenticated users
  private, // Visible only to specified users/groups
}

class CustomForm {
  String id;
  String title;
  String description;
  List<FormFieldModel> fields;
  String created_by; // Snake case to match Supabase column name
  DateTime created_at; // Snake case to match Supabase column name

  // New fields for access control
  FormVisibility visibility;

  // New fields for scheduling
  bool isRecurring;
  RecurrenceType? recurrenceType;
  Map<String, dynamic>?
      recurrenceConfig; // Store custom recurrence settings as JSON
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  DateTime? startDate;
  DateTime? endDate;
  String timeZone;
  bool isChecklist;

  CustomForm({
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'fields': fields.map((field) => field.toJson()).toList(),
      'created_by': created_by,
      'created_at': created_at.toIso8601String(),
      'form_visibility': visibility.toString().split('.').last,
      'is_recurring': isRecurring,
      'recurrence_type': recurrenceType?.toString().split('.').last,
      'recurrence_config': recurrenceConfig,
      'start_time': startTime != null
          ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'end_time': endTime != null
          ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'time_zone': timeZone,
      'is_checklist': isChecklist,
    };
  }

  factory CustomForm.fromJson(Map<String, dynamic> json) {
    // Parse time strings into TimeOfDay objects
    TimeOfDay? startTime;
    if (json['start_time'] != null) {
      final parts = json['start_time'].toString().split(':');
      if (parts.length == 2) {
        startTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    TimeOfDay? endTime;
    if (json['end_time'] != null) {
      final parts = json['end_time'].toString().split(':');
      if (parts.length == 2) {
        endTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    // Handle potential null fields array
    List<dynamic> fieldsJson = [];
    if (json['fields'] != null) {
      fieldsJson = json['fields'] as List<dynamic>;
    }

    return CustomForm(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      fields:
          fieldsJson.map((field) => FormFieldModel.fromJson(field)).toList(),
      created_by: json['created_by'],
      created_at: DateTime.parse(json['created_at']),
      visibility: FormVisibility.values.firstWhere(
          (e) =>
              e.toString() ==
              'FormVisibility.${json['form_visibility'] ?? 'public'}',
          orElse: () => FormVisibility.public),
      isRecurring: json['is_recurring'] ?? false,
      recurrenceType: json['recurrence_type'] != null
          ? RecurrenceType.values.firstWhere(
              (e) =>
                  e.toString() == 'RecurrenceType.${json['recurrence_type']}',
              orElse: () => RecurrenceType.once)
          : null,
      recurrenceConfig: json['recurrence_config'],
      startTime: startTime,
      endTime: endTime,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate:
          json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      timeZone: json['time_zone'] ?? 'UTC',
      isChecklist: json['is_checklist'] ?? false,
    );
  }
}
