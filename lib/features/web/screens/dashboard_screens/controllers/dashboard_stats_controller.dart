// lib/features/web/screens/dashboard_screens/controllers/dashboard_stats_controller.dart

import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:jala_form/features/forms/models/user_group.dart';

/// Controller for managing dashboard statistics
///
/// Extracted from WebDashboard to follow Single Responsibility Principle
/// Aggregates data from Forms, Responses, and Groups
class DashboardStatsController extends ChangeNotifier {
  // Input data (updated by parent)
  List<CustomForm> _myForms = [];
  List<CustomForm> _availableForms = [];
  Map<String, List<FormResponse>> _formResponses = {};
  List<UserGroup> _myGroups = [];

  // Getters for statistics
  int get totalForms => _myForms.length;
  int get totalAvailableForms => _availableForms.length;
  int get totalGroups => _myGroups.length;

  int get totalResponses {
    return _formResponses.values.fold(0, (sum, responses) => sum + responses.length);
  }

  int get checklistForms {
    return _myForms.where((form) => form.isChecklist == true).length;
  }

  int get regularForms {
    return _myForms.where((form) => form.isChecklist != true).length;
  }

  int get formsWithResponses {
    return _formResponses.entries.where((entry) => entry.value.isNotEmpty).length;
  }

  int get formsWithoutResponses {
    return totalForms - formsWithResponses;
  }

  double get averageResponsesPerForm {
    if (totalForms == 0) return 0;
    return totalResponses / totalForms;
  }

  // Most popular form (most responses)
  CustomForm? get mostPopularForm {
    if (_myForms.isEmpty || _formResponses.isEmpty) return null;

    CustomForm? mostPopular;
    int maxResponses = 0;

    for (final form in _myForms) {
      final responseCount = _formResponses[form.id]?.length ?? 0;
      if (responseCount > maxResponses) {
        maxResponses = responseCount;
        mostPopular = form;
      }
    }

    return mostPopular;
  }

  // Recently created forms (last 7 days)
  int get recentFormsCount {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _myForms.where((form) {
      return form.created_at.isAfter(sevenDaysAgo);
    }).length;
  }

  // Recently received responses (last 7 days)
  int get recentResponsesCount {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    int count = 0;

    for (final responses in _formResponses.values) {
      count += responses.where((response) {
        return response.submitted_at.isAfter(sevenDaysAgo);
      }).length;
    }

    return count;
  }

  // Update methods
  void updateForms(List<CustomForm> myForms, List<CustomForm> availableForms) {
    _myForms = myForms;
    _availableForms = availableForms;
    notifyListeners();
  }

  void updateResponses(Map<String, List<FormResponse>> responses) {
    _formResponses = responses;
    notifyListeners();
  }

  void updateGroups(List<UserGroup> groups) {
    _myGroups = groups;
    notifyListeners();
  }

  // Get stats summary for display
  Map<String, dynamic> getStatsSummary() {
    return {
      'totalForms': totalForms,
      'totalResponses': totalResponses,
      'totalGroups': totalGroups,
      'checklistForms': checklistForms,
      'regularForms': regularForms,
      'formsWithResponses': formsWithResponses,
      'formsWithoutResponses': formsWithoutResponses,
      'averageResponsesPerForm': averageResponsesPerForm.toStringAsFixed(1),
      'recentForms': recentFormsCount,
      'recentResponses': recentResponsesCount,
    };
  }

  // Get forms by status
  List<CustomForm> get activeForms {
    // Forms that have received responses in last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    return _myForms.where((form) {
      final responses = _formResponses[form.id] ?? [];
      return responses.any((r) => r.submitted_at.isAfter(thirtyDaysAgo));
    }).toList();
  }

  List<CustomForm> get inactiveForms {
    // Forms with no responses in last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    return _myForms.where((form) {
      final responses = _formResponses[form.id] ?? [];
      return responses.every((r) => !r.submitted_at.isAfter(thirtyDaysAgo));
    }).toList();
  }

  // Response rate calculation
  double getResponseRate(String formId) {
    final responses = _formResponses[formId]?.length ?? 0;
    // This is a simplified calculation
    // In a real app, you'd compare against sent invitations or views
    return responses.toDouble();
  }

  // Clear all data
  void clear() {
    _myForms = [];
    _availableForms = [];
    _formResponses = {};
    _myGroups = [];
    notifyListeners();
  }
}
