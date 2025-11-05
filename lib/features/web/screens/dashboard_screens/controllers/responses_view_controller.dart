// lib/features/web/screens/dashboard_screens/controllers/responses_view_controller.dart

import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:jala_form/services/supabase_service.dart';

/// Controller for managing "Responses" view in the dashboard
///
/// Extracted from WebDashboard to follow Single Responsibility Principle
class ResponsesViewController extends ChangeNotifier {
  final SupabaseService _supabaseService;

  ResponsesViewController(this._supabaseService);

  // State
  Map<String, List<FormResponse>> _formResponses = {};
  List<CustomForm> _myForms = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String? _selectedFormId;

  // Getters
  Map<String, List<FormResponse>> get formResponses => _formResponses;
  List<CustomForm> get myForms => _myForms;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedFormId => _selectedFormId;

  // Get responses for selected form
  List<FormResponse> get selectedFormResponses {
    if (_selectedFormId == null) return [];
    return _formResponses[_selectedFormId] ?? [];
  }

  // Get filtered responses
  List<FormResponse> get filteredResponses {
    var responses = selectedFormResponses;

    if (_searchQuery.isNotEmpty) {
      responses = responses.where((response) {
        final submitterEmail = response.submittedBy ?? '';
        return submitterEmail.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return responses;
  }

  // Total response count across all forms
  int get totalResponseCount {
    return _formResponses.values.fold(0, (sum, responses) => sum + responses.length);
  }

  // Actions
  Future<void> loadResponses(List<CustomForm> forms) async {
    _isLoading = true;
    _errorMessage = '';
    _myForms = forms;
    notifyListeners();

    try {
      final formIds = forms.map((form) => form.id).toList();

      if (formIds.isEmpty) {
        _formResponses = {};
      } else {
        // Use batch fetching for better performance
        _formResponses = await _supabaseService.getFormResponsesBatch(formIds);
      }
    } catch (e) {
      _errorMessage = 'Failed to load responses: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectForm(String? formId) {
    _selectedFormId = formId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> deleteResponse(String formId, String responseId) async {
    try {
      await _supabaseService.deleteFormResponse(responseId);

      // Remove from local state
      if (_formResponses.containsKey(formId)) {
        _formResponses[formId]!.removeWhere((r) => r.id == responseId);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to delete response: $e';
      debugPrint(_errorMessage);
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (_myForms.isNotEmpty) {
      await loadResponses(_myForms);
    }
  }

  // Get response count for a specific form
  int getResponseCount(String formId) {
    return _formResponses[formId]?.length ?? 0;
  }

  // Get forms with responses
  List<CustomForm> get formsWithResponses {
    return _myForms.where((form) {
      final count = getResponseCount(form.id);
      return count > 0;
    }).toList();
  }

  // Get forms without responses
  List<CustomForm> get formsWithoutResponses {
    return _myForms.where((form) {
      final count = getResponseCount(form.id);
      return count == 0;
    }).toList();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }
}
