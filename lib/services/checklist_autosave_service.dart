// Updated ChecklistAutoSaveService with period-awareness

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_form.dart';
import 'supabase_service.dart';

class ChecklistAutoSaveService {
  static final ChecklistAutoSaveService _instance =
      ChecklistAutoSaveService._internal();
  final SupabaseService _supabaseService = SupabaseService();
  final _storage = SharedPreferences.getInstance();
  final ValueNotifier<Map<String, bool>> savingStatus = ValueNotifier({});

  // Map to track form responses and save timers
  final Map<String, Map<String, dynamic>> _formResponses = {};
  final Map<String, Timer> _saveTimers = {};

  // Constants
  static const Duration _saveInterval = Duration(seconds: 5);

  factory ChecklistAutoSaveService() {
    return _instance;
  }

  ChecklistAutoSaveService._internal();

  String _getStorageKey(String formId) => 'form_draft_$formId';
  String _getPeriodKey(String formId) => 'form_period_$formId';

  // Helper method to get current period identifier
  String _getCurrentPeriodId(CustomForm form) {
    final now = DateTime.now();

    switch (form.recurrenceType) {
      case RecurrenceType.daily:
        // Use date as period ID: YYYY-MM-DD
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      case RecurrenceType.weekly:
        // Use year and week number as period ID
        final daysFromMonday = now.weekday - 1;
        final mondayOfWeek = now.subtract(Duration(days: daysFromMonday));
        return '${mondayOfWeek.year}-W${_getWeekNumber(mondayOfWeek)}';

      case RecurrenceType.monthly:
        // Use year and month as period ID: YYYY-MM
        return '${now.year}-${now.month.toString().padLeft(2, '0')}';

      case RecurrenceType.yearly:
        // Use year as period ID
        return '${now.year}';

      case RecurrenceType.once:
        // For one-time forms, use form ID as period (never changes)
        return 'once';

      case RecurrenceType.custom:
        // For custom recurrence, you can implement custom logic here
        // For now, treat it like one-time forms
        return 'once';

      case null:
        // For forms without recurrence type, use form ID as period
        return 'once';
    }
  }

  // Helper method to get week number
  int _getWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  // Load saved responses only if they belong to current period
  Future<Map<String, dynamic>?> loadSavedResponses(String formId) async {
    try {
      final prefs = await _storage;

      // Get the form to determine current period
      final form = await _supabaseService.getFormById(formId);
      final currentPeriodId = _getCurrentPeriodId(form);

      // Check stored period
      final String? storedPeriodId = prefs.getString(_getPeriodKey(formId));

      // If no stored period or different period, clear old data
      if (storedPeriodId == null || storedPeriodId != currentPeriodId) {
        debugPrint(
            'Period changed from $storedPeriodId to $currentPeriodId. Clearing old draft data.');
        await _clearOldPeriodData(formId);
        return null;
      }

      // Load data from current period
      final String? jsonData = prefs.getString(_getStorageKey(formId));

      if (jsonData != null && jsonData.isNotEmpty) {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        debugPrint(
            'Loaded saved data for current period ($currentPeriodId): $data');
        return data;
      }
    } catch (e) {
      debugPrint('Error loading saved responses: $e');
    }
    return null;
  }

  // Clear old period data
  Future<void> _clearOldPeriodData(String formId) async {
    try {
      final prefs = await _storage;
      await prefs.remove(_getStorageKey(formId));
      await prefs.remove(_getPeriodKey(formId));

      // Also clear from Supabase drafts
      await _supabaseService.deleteDraftResponse(formId);

      debugPrint('Cleared old period data for form $formId');
    } catch (e) {
      debugPrint('Error clearing old period data: $e');
    }
  }

  // Update response value and trigger save timer with period tracking
  Future<void> updateResponse(
      String formId, String fieldId, dynamic value) async {
    try {
      // Mark saving in progress
      _updateSavingStatus(formId, true);

      // Get the form to determine current period
      final form = await _supabaseService.getFormById(formId);
      final currentPeriodId = _getCurrentPeriodId(form);

      final prefs = await _storage;

      // Store current period ID
      await prefs.setString(_getPeriodKey(formId), currentPeriodId);

      // Load current data (will be empty if period changed)
      Map<String, dynamic> currentData = await loadSavedResponses(formId) ?? {};

      // Update or remove the value
      if (value == null) {
        currentData.remove(fieldId);
      } else {
        currentData[fieldId] = value;
      }

      // Save back to storage with period information
      await prefs.setString(_getStorageKey(formId), json.encode(currentData));

      // Also update in-memory cache
      _formResponses[formId] = currentData;

      // Schedule database save
      _scheduleDbSave(formId);

      debugPrint(
          "Updated data for form $formId (period: $currentPeriodId), field $fieldId: $value");

      // Mark saving complete
      _updateSavingStatus(formId, false);
    } catch (e) {
      debugPrint('Error updating response: $e');
      _updateSavingStatus(formId, false);
    }
  }

  // Schedule database save with debouncing
  void _scheduleDbSave(String formId) {
    // Cancel existing timer
    if (_saveTimers.containsKey(formId)) {
      _saveTimers[formId]!.cancel();
    }

    // Create new timer
    _saveTimers[formId] = Timer(_saveInterval, () {
      _saveFormProgress(formId);
      _saveTimers.remove(formId);
    });
  }

  void _updateSavingStatus(String formId, bool isSaving) {
    final currentStatus = Map<String, bool>.from(savingStatus.value);
    currentStatus[formId] = isSaving;
    savingStatus.value = currentStatus;
  }

  // Save form progress to database
  Future<void> _saveFormProgress(String formId) async {
    if (!_formResponses.containsKey(formId) ||
        _formResponses[formId]!.isEmpty) {
      return;
    }

    try {
      _updateSavingStatus(formId, true);

      final data = _formResponses[formId]!;
      await _supabaseService.saveDraftResponse(formId, data);

      debugPrint('Auto-saved form progress for form $formId');
    } catch (e) {
      debugPrint('Error auto-saving form progress: $e');
    } finally {
      _updateSavingStatus(formId, false);
    }
  }

  // Force save all pending changes
  Future<void> forceSave(String formId) async {
    if (_saveTimers.containsKey(formId)) {
      _saveTimers[formId]!.cancel();
      _saveTimers.remove(formId);
    }

    await _saveFormProgress(formId);
  }

  // Clear form responses and cancel timers
  Future<void> clearForm(String formId) async {
    try {
      // Cancel timer
      if (_saveTimers.containsKey(formId)) {
        _saveTimers[formId]!.cancel();
        _saveTimers.remove(formId);
      }

      // Remove from memory
      _formResponses.remove(formId);

      // Clear from local storage
      final prefs = await _storage;
      await prefs.remove(_getStorageKey(formId));
      await prefs.remove(_getPeriodKey(formId));

      // Clear from database
      await _supabaseService.deleteDraftResponse(formId);

      // Update saving status
      final newStatus = Map<String, bool>.from(savingStatus.value);
      newStatus.remove(formId);
      savingStatus.value = newStatus;

      debugPrint('Cleared all data for form $formId');
    } catch (e) {
      debugPrint('Error clearing form: $e');
    }
  }

  // Check if current data belongs to current period
  Future<bool> isDataFromCurrentPeriod(String formId) async {
    try {
      final prefs = await _storage;
      final form = await _supabaseService.getFormById(formId);
      final currentPeriodId = _getCurrentPeriodId(form);
      final storedPeriodId = prefs.getString(_getPeriodKey(formId));

      return storedPeriodId == currentPeriodId;
    } catch (e) {
      debugPrint('Error checking period: $e');
      return false;
    }
  }

  // Clean up data from previous periods for all forms
  Future<void> cleanupOldPeriodData() async {
    try {
      final prefs = await _storage;
      final allKeys = prefs.getKeys();

      // Get all form draft keys
      final formKeys =
          allKeys.where((key) => key.startsWith('form_draft_')).toList();

      for (final key in formKeys) {
        final formId = key.replaceFirst('form_draft_', '');

        try {
          final form = await _supabaseService.getFormById(formId);
          final currentPeriodId = _getCurrentPeriodId(form);
          final storedPeriodId = prefs.getString(_getPeriodKey(formId));

          if (storedPeriodId != null && storedPeriodId != currentPeriodId) {
            await _clearOldPeriodData(formId);
          }
        } catch (e) {
          // If we can't get the form, just skip it
          debugPrint('Could not check period for form $formId: $e');
        }
      }
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  // Save all pending forms (call when app is going to background)
  Future<void> saveAllPending() async {
    for (final formId in _saveTimers.keys.toList()) {
      _saveTimers[formId]!.cancel();
      await _saveFormProgress(formId);
    }
    _saveTimers.clear();
  }

  // Dispose timers
  void dispose() {
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
  }
}
