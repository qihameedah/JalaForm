// lib/features/web/screens/dashboard_screens/controllers/available_forms_view_controller.dart

import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/services/supabase_service.dart';

/// Controller for managing Available Forms view
///
/// Extracted from WebDashboard to follow Single Responsibility Principle
/// Manages forms that are shared with/available to the current user
class AvailableFormsViewController extends ChangeNotifier {
  final SupabaseService _supabaseService;

  AvailableFormsViewController(this._supabaseService);

  // State
  List<CustomForm> _availableForms = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortBy = 'recent'; // 'recent', 'alphabetical', 'oldest'
  bool _showChecklistOnly = false;
  bool _showRegularOnly = false;

  // Getters
  List<CustomForm> get availableForms => _availableForms;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get showChecklistOnly => _showChecklistOnly;
  bool get showRegularOnly => _showRegularOnly;

  /// Get filtered and sorted forms based on current filters
  List<CustomForm> get filteredForms {
    var forms = List<CustomForm>.from(_availableForms);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      forms = forms.where((form) {
        final titleMatch = form.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final descriptionMatch = form.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        return titleMatch || descriptionMatch;
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
        forms.sort((a, b) => b.created_at.compareTo(a.created_at));
        break;
      case 'alphabetical':
        forms.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'oldest':
        forms.sort((a, b) => a.created_at.compareTo(b.created_at));
        break;
      default:
        // Default to recent
        forms.sort((a, b) => b.created_at.compareTo(a.created_at));
    }

    return forms;
  }

  /// Get count of filtered forms
  int get filteredCount => filteredForms.length;

  /// Get total available forms count (unfiltered)
  int get totalCount => _availableForms.length;

  /// Check if any filters are active
  bool get hasActiveFilters {
    return _searchQuery.isNotEmpty ||
           _showChecklistOnly ||
           _showRegularOnly;
  }

  /// Load available forms from database
  Future<void> loadAvailableForms() async {
    _isLoading = true;
    notifyListeners();

    try {
      _availableForms = await _supabaseService.getAvailableForms();
      debugPrint('[AvailableFormsViewController] Loaded ${_availableForms.length} available forms');
    } catch (e) {
      debugPrint('[AvailableFormsViewController] Failed to load available forms: $e');
      _availableForms = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh available forms
  Future<void> refresh() async {
    await loadAvailableForms();
  }

  /// Set search query
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  /// Clear search query
  void clearSearch() {
    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      notifyListeners();
    }
  }

  /// Set sort option
  void setSortBy(String sortBy) {
    if (_sortBy != sortBy) {
      _sortBy = sortBy;
      notifyListeners();
    }
  }

  /// Toggle checklist filter
  void toggleChecklistFilter() {
    _showChecklistOnly = !_showChecklistOnly;
    if (_showChecklistOnly) {
      _showRegularOnly = false; // Can't show both filters
    }
    notifyListeners();
  }

  /// Toggle regular forms filter
  void toggleRegularFilter() {
    _showRegularOnly = !_showRegularOnly;
    if (_showRegularOnly) {
      _showChecklistOnly = false; // Can't show both filters
    }
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    bool changed = false;

    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      changed = true;
    }

    if (_showChecklistOnly) {
      _showChecklistOnly = false;
      changed = true;
    }

    if (_showRegularOnly) {
      _showRegularOnly = false;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Get forms by type
  List<CustomForm> getFormsByType({required bool isChecklist}) {
    return _availableForms.where((form) => form.isChecklist == isChecklist).toList();
  }

  /// Get checklist forms count
  int get checklistCount {
    return _availableForms.where((form) => form.isChecklist == true).length;
  }

  /// Get regular forms count
  int get regularCount {
    return _availableForms.where((form) => form.isChecklist != true).length;
  }

  /// Find form by ID
  CustomForm? findFormById(String formId) {
    try {
      return _availableForms.firstWhere((form) => form.id == formId);
    } catch (e) {
      return null;
    }
  }

  /// Check if form is available
  bool isFormAvailable(String formId) {
    return _availableForms.any((form) => form.id == formId);
  }

  /// Get recently added forms (last 7 days)
  List<CustomForm> get recentlyAdded {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _availableForms.where((form) {
      return form.created_at.isAfter(sevenDaysAgo);
    }).toList();
  }

  /// Get count of recently added forms
  int get recentlyAddedCount => recentlyAdded.length;

  /// Clear all data
  void clear() {
    _availableForms = [];
    _isLoading = false;
    _searchQuery = '';
    _sortBy = 'recent';
    _showChecklistOnly = false;
    _showRegularOnly = false;
    notifyListeners();
  }

  /// Update forms list (for external updates)
  void updateForms(List<CustomForm> forms) {
    _availableForms = forms;
    notifyListeners();
  }

  /// Add a single form to the list
  void addForm(CustomForm form) {
    if (!_availableForms.any((f) => f.id == form.id)) {
      _availableForms.add(form);
      notifyListeners();
    }
  }

  /// Remove a form from the list
  void removeForm(String formId) {
    final index = _availableForms.indexWhere((f) => f.id == formId);
    if (index != -1) {
      _availableForms.removeAt(index);
      notifyListeners();
    }
  }

  /// Update a single form in the list
  void updateForm(CustomForm updatedForm) {
    final index = _availableForms.indexWhere((f) => f.id == updatedForm.id);
    if (index != -1) {
      _availableForms[index] = updatedForm;
      notifyListeners();
    }
  }
}
