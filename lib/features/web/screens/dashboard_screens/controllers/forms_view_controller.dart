// lib/features/web/screens/dashboard_screens/controllers/forms_view_controller.dart

import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/services/supabase_service.dart';

/// Controller for managing "My Forms" view in the dashboard
///
/// Extracted from WebDashboard to follow Single Responsibility Principle
class FormsViewController extends ChangeNotifier {
  final SupabaseService _supabaseService;

  FormsViewController(this._supabaseService);

  // State
  List<CustomForm> _myForms = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _sortBy = 'recent';
  bool _showChecklistOnly = false;
  bool _showRegularOnly = false;

  // Getters
  List<CustomForm> get myForms => _myForms;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get showChecklistOnly => _showChecklistOnly;
  bool get showRegularOnly => _showRegularOnly;

  // Filtered and sorted forms
  List<CustomForm> get filteredForms {
    var forms = List<CustomForm>.from(_myForms);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      forms = forms.where((form) {
        return form.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (form.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Apply type filter
    if (_showChecklistOnly) {
      forms = forms.where((form) => form.isChecklist == true).toList();
    } else if (_showRegularOnly) {
      forms = forms.where((form) => form.isChecklist != true).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'recent':
        forms.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        break;
      case 'oldest':
        forms.sort((a, b) => (a.createdAt ?? DateTime(1970))
            .compareTo(b.createdAt ?? DateTime(1970)));
        break;
      case 'name_asc':
        forms.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'name_desc':
        forms.sort((a, b) => b.title.compareTo(a.title));
        break;
    }

    return forms;
  }

  // Actions
  Future<void> loadMyForms() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _myForms = await _supabaseService.getMyForms();
    } catch (e) {
      _errorMessage = 'Failed to load forms: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setShowChecklistOnly(bool value) {
    _showChecklistOnly = value;
    if (value) _showRegularOnly = false;
    notifyListeners();
  }

  void setShowRegularOnly(bool value) {
    _showRegularOnly = value;
    if (value) _showChecklistOnly = false;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _showChecklistOnly = false;
    _showRegularOnly = false;
    _sortBy = 'recent';
    notifyListeners();
  }

  Future<void> deleteForm(String formId) async {
    try {
      await _supabaseService.deleteForm(formId);
      _myForms.removeWhere((form) => form.id == formId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete form: $e';
      debugPrint(_errorMessage);
      rethrow;
    }
  }

  Future<void> refresh() async {
    await loadMyForms();
  }
}
