// Updated methods for ChecklistFormScreen with period-based logic

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_image_picker/form_builder_image_picker.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/custom_form.dart';
import '../../models/form_field.dart';
import '../../models/form_response.dart';
import '../../services/supabase_service.dart';
import '../../services/checklist_autosave_service.dart';
import '../../theme/app_theme.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:form_builder_image_picker/form_builder_image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ChecklistFormScreen extends StatefulWidget {
  final CustomForm form;
  final bool isPreview;

  const ChecklistFormScreen({
    super.key,
    required this.form,
    this.isPreview = false,
  });

  @override
  State<ChecklistFormScreen> createState() => _ChecklistFormScreenState();
}

// Helper class for Likert options
class LikertOption {
  final String label;
  final String value;

  LikertOption({required this.label, required this.value});
}

class _ChecklistFormScreenState extends State<ChecklistFormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _supabaseService = SupabaseService();
  final _autoSaveService = ChecklistAutoSaveService();
  bool _isSubmitting = false;
  bool _isSessionActive = false;
  DateTime? _sessionStartTime;
  final Map<String, dynamic> _responses = {};
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  int _completedFields = 0;
  bool _isSaving = false;
  String _savingMessage = '';
  bool _hasLoadedSavedData = false;
  bool _hasAlreadySubmitted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _updateSavingStatus() {
    if (mounted &&
        _autoSaveService.savingStatus.value.containsKey(widget.form.id)) {
      setState(() {
        _isSaving = _autoSaveService.savingStatus.value[widget.form.id]!;
        _savingMessage = _isSaving ? 'Saving changes...' : 'All changes saved';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoSaveService.savingStatus.removeListener(_updateSavingStatus);

    // Force save any pending changes when leaving
    if (_isSessionActive && !widget.isPreview) {
      _autoSaveService.forceSave(widget.form.id);
    }

    super.dispose();
  }

  String _getRecurrenceTypeString(RecurrenceType? recurrenceType) {
    switch (recurrenceType) {
      case RecurrenceType.daily:
        return 'daily';
      case RecurrenceType.weekly:
        return 'weekly';
      case RecurrenceType.monthly:
        return 'monthly';
      case RecurrenceType.yearly:
        return 'yearly';
      case RecurrenceType.once:
        return 'one-time';
      case RecurrenceType.custom:
        return 'custom';
      case null:
        return 'recurring';
    }
  }

// Updated method to check if current time is in window
  bool _isInTimeWindow() {
    if (widget.form.startTime == null || widget.form.endTime == null) {
      return true; // Forms without time constraints are always available
    }

    // Check if form is available for current recurrence period
    if (!_supabaseService.isFormAvailableForCurrentPeriod(widget.form)) {
      return false;
    }

    final now = TimeOfDay.fromDateTime(DateTime.now());
    final currentMinutes = now.hour * 60 + now.minute;

    final startMinutes =
        widget.form.startTime!.hour * 60 + widget.form.startTime!.minute;
    final endMinutes =
        widget.form.endTime!.hour * 60 + widget.form.endTime!.minute;

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  // Updated initialization method with period-aware logic
  void _initializeForm() async {
    // Clean up any old period data first
    await _autoSaveService.cleanupOldPeriodData();

    // Check if this is a checklist form with time constraints
    if (widget.form.startTime != null &&
        widget.form.endTime != null &&
        !_isInTimeWindow() &&
        !widget.isPreview) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Check for previous submissions in current period
    if (!widget.isPreview) {
      await _checkPreviousSubmission();
    }

    // Check for previously saved data from CURRENT period only
    await _checkPreviousData();

    // Listen for auto-save status changes
    _autoSaveService.savingStatus.addListener(_updateSavingStatus);

    setState(() {
      _isLoading = false;
    });
  }

  // Check if there's an active session
  Future<void> _checkActiveSession() async {
    // In a real app, you'd check if the user has an active session for this form
    // This is a simplified example
    setState(() {
      _isSessionActive = false;
      _sessionStartTime = null;
    });
  }

  // Updated method to check previous data for CURRENT period only
  Future<void> _checkPreviousData() async {
    if (!_hasLoadedSavedData) {
      try {
        // Load saved data - this will automatically check if data is from current period
        // and clear old data if it's from a previous period
        final savedData =
            await _autoSaveService.loadSavedResponses(widget.form.id);

        debugPrint(
            "Platform: ${Theme.of(context).platform} - Loaded saved data for current period: $savedData");

        if (savedData != null && savedData.isNotEmpty) {
          setState(() {
            _responses.clear();
            _responses.addAll(savedData);
            _completedFields = _responses.keys.length;
            _hasLoadedSavedData = true;
          });

          // Update form values immediately after loading
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_formKey.currentState != null) {
              _formKey.currentState?.patchValue(savedData.map((key, value) =>
                  MapEntry(
                      key,
                      value is List || value is Map
                          ? value
                          : value.toString())));
            }
          });

          debugPrint(
              "Restored progress from current period: ${_responses.keys.length} fields");
        } else {
          // No saved data for current period - start fresh
          setState(() {
            _responses.clear();
            _completedFields = 0;
            _hasLoadedSavedData = true;
          });
          debugPrint("Starting fresh form for new period");
        }
      } catch (e) {
        debugPrint('Error loading previous data: $e');
        // On error, start fresh
        setState(() {
          _responses.clear();
          _completedFields = 0;
          _hasLoadedSavedData = true;
        });
      }
    }
  }

  // Updated session start method with better period handling
  void _startSession() async {
    // Clean up any old period data before starting
    await _autoSaveService.cleanupOldPeriodData();

    // Try to load any previously saved data from CURRENT period
    if (!_hasLoadedSavedData && !widget.isPreview) {
      await _checkPreviousData();

      // If we found saved data from current period, patch the form values
      if (_hasLoadedSavedData &&
          _responses.isNotEmpty &&
          _formKey.currentState != null) {
        _formKey.currentState?.patchValue(Map.fromEntries(_responses.entries
            .map((entry) => MapEntry(
                entry.key,
                entry.value is List || entry.value is Map
                    ? entry.value
                    : entry.value.toString()))));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Your progress from ${_supabaseService.getRecurrencePeriodDescription(widget.form).toLowerCase()} has been restored'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // No saved data for current period - show fresh start message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Starting fresh checklist for ${_supabaseService.getRecurrencePeriodDescription(widget.form).toLowerCase()}'),
              backgroundColor: AppTheme.infoColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    setState(() {
      _isSessionActive = true;
      _sessionStartTime = DateTime.now();
      // Don't clear responses here - they should already be loaded or empty for new period
    });

    // Calculate time remaining until end time
    if (widget.form.endTime != null) {
      _calculateRemainingTime();

      // Start a timer to update the remaining time
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          _calculateRemainingTime();
        }
      });
    }
  }

  // Helper method to get current period ID for debugging
  Future<String> _getCurrentPeriodId() async {
    final now = DateTime.now();

    switch (widget.form.recurrenceType) {
      case RecurrenceType.daily:
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      case RecurrenceType.weekly:
        final daysFromMonday = now.weekday - 1;
        final mondayOfWeek = now.subtract(Duration(days: daysFromMonday));
        return '${mondayOfWeek.year}-W${_getWeekNumber(mondayOfWeek)}';
      case RecurrenceType.monthly:
        return '${now.year}-${now.month.toString().padLeft(2, '0')}';
      case RecurrenceType.yearly:
        return '${now.year}';
      case RecurrenceType.once:
        return 'once';
      case RecurrenceType.custom:
        return 'once';
      case null:
        return 'once';
    }
  }

// Helper method for week number calculation
  int _getWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  void _calculateRemainingTime() {
    if (widget.form.endTime == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Create DateTime objects for end time
    final endTimeMinutes =
        widget.form.endTime!.hour * 60 + widget.form.endTime!.minute;
    final endDateTime = today.add(Duration(minutes: endTimeMinutes));

    // Calculate remaining time
    final remaining = endDateTime.difference(now);

    // If time is up, auto-submit the form
    if (remaining.isNegative) {
      _timer?.cancel();
      _submitForm(isAutoSubmit: true);
      return;
    }

    setState(() {
      _remainingTime = remaining;
    });
  }

  String _formatRemainingTime() {
    final hours = _remainingTime.inHours;
    final minutes = _remainingTime.inMinutes.remainder(60);
    final seconds = _remainingTime.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Updated submit form method with better period handling
  Future<void> _submitForm({bool isAutoSubmit = false}) async {
    if (!_isSessionActive && !isAutoSubmit) return;

    if (!isAutoSubmit) {
      // Manual submission - validate form
      if (!_formKey.currentState!.saveAndValidate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required fields'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _supabaseService.getCurrentUser();

      final formResponse = FormResponse(
        id: const Uuid().v4(),
        form_id: widget.form.id,
        responses: _responses,
        respondent_id: user?.id,
        submitted_at: DateTime.now(),
      );

      // Submit form response to Supabase
      await _supabaseService.submitFormResponse(formResponse);

      // Clear ALL draft data after successful submission (both local and remote)
      await _autoSaveService.clearForm(widget.form.id);
      await _supabaseService.deleteDraftResponse(widget.form.id);

      if (mounted) {
        _timer?.cancel();
        final periodDesc =
            _supabaseService.getRecurrencePeriodDescription(widget.form);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAutoSubmit
                ? 'Time expired. Form submitted automatically with $_completedFields completed fields for $periodDesc.'
                : 'Checklist submitted successfully for $periodDesc!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSessionActive = false;
        });
      }
    }
  }

// Enhanced debug method to show period information
  Future<void> _debugStorageState() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    debugPrint("==== Storage Debug ====");
    debugPrint("Platform: ${Theme.of(context).platform}");
    debugPrint("All keys: $allKeys");

    // Show current period info
    try {
      final currentPeriodId = await _getCurrentPeriodId();
      debugPrint("Current period ID: $currentPeriodId");
    } catch (e) {
      debugPrint("Error getting period ID: $e");
    }

    for (final key in allKeys) {
      if (key.contains('form_draft') || key.contains('form_period')) {
        debugPrint("Form data for $key: ${prefs.getString(key)}");
      }
    }

    final formKey = 'form_draft_${widget.form.id}';
    final periodKey = 'form_period_${widget.form.id}';
    debugPrint("Looking for draft key: $formKey");
    debugPrint("Looking for period key: $periodKey");
    debugPrint("Has draft? ${prefs.containsKey(formKey)}");
    debugPrint("Has period? ${prefs.containsKey(periodKey)}");

    if (prefs.containsKey(formKey)) {
      debugPrint("Draft value: ${prefs.getString(formKey)}");
    }
    if (prefs.containsKey(periodKey)) {
      debugPrint("Period value: ${prefs.getString(periodKey)}");
    }
  }

  // Updated session start screen with period information
  Widget _buildSessionStartScreen() {
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final currentMinutes = now.hour * 60 + now.minute;

    bool isInTimeWindow = true;
    String message = 'Ready to start the checklist?';

    // Check if user has already submitted in current period
    if (_hasAlreadySubmitted) {
      final periodDescription =
          _supabaseService.getRecurrencePeriodDescription(widget.form);
      message =
          'You have already submitted this checklist for $periodDescription. Please try again in the next period.';
      isInTimeWindow = false;
    } else {
      // Check for in-progress data
      bool hasInProgressData = _responses.isNotEmpty;

      if (hasInProgressData) {
        final periodDescription =
            _supabaseService.getRecurrencePeriodDescription(widget.form);
        message =
            'You have a checklist in progress for $periodDescription. Would you like to continue?';
      } else {
        final periodDescription =
            _supabaseService.getRecurrencePeriodDescription(widget.form);
        message = 'Ready to start the checklist for $periodDescription?';
      }

      // Time window checks for daily recurring forms
      if (widget.form.startTime != null &&
          widget.form.endTime != null &&
          !widget.isPreview) {
        final startMinutes =
            widget.form.startTime!.hour * 60 + widget.form.startTime!.minute;
        final endMinutes =
            widget.form.endTime!.hour * 60 + widget.form.endTime!.minute;

        if (currentMinutes < startMinutes) {
          isInTimeWindow = false;
          message =
              'This checklist is not yet available. It will be available at ${widget.form.startTime!.format(context)}.';
        } else if (currentMinutes > endMinutes) {
          isInTimeWindow = false;
          final periodDescription =
              _supabaseService.getRecurrencePeriodDescription(widget.form);
          message =
              'This checklist is no longer available for $periodDescription. The submission window has closed.';
        }
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isSmallScreen = constraints.maxWidth < 600;
      bool hasInProgressData = _responses.isNotEmpty && !_hasAlreadySubmitted;

      // Consistent button text based on real data state
      final String buttonText =
          hasInProgressData ? 'Continue Checklist' : 'Start Checklist';

      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? double.infinity : 600,
          minHeight: isSmallScreen ? 400 : 500,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Improved checklist icon with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
              decoration: BoxDecoration(
                color: _hasAlreadySubmitted
                    ? Colors.green.withOpacity(0.15)
                    : (hasInProgressData
                        ? AppTheme.secondaryColor.withOpacity(0.15)
                        : AppTheme.primaryColor.withOpacity(0.1)),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_hasAlreadySubmitted
                            ? Colors.green
                            : (hasInProgressData
                                ? AppTheme.secondaryColor
                                : AppTheme.primaryColor))
                        .withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _hasAlreadySubmitted
                    ? Icons.check_circle
                    : (hasInProgressData
                        ? Icons.playlist_add_check
                        : Icons.checklist),
                size: isSmallScreen ? 60 : 80,
                color: _hasAlreadySubmitted
                    ? Colors.green
                    : (hasInProgressData
                        ? AppTheme.secondaryColor
                        : AppTheme.primaryColor),
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 36),

            // Form title
            Text(
              widget.form.title,
              style: TextStyle(
                fontSize: isSmallScreen ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),

            // Description
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16),
              child: Text(
                widget.form.description,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: AppTheme.textSecondaryColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),

            // Show progress if there's saved data (and not already submitted)
            if (hasInProgressData) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.successColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_note,
                            color: AppTheme.successColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Progress Saved',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_completedFields of ${widget.form.fields.length} fields completed',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _completedFields / widget.form.fields.length,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.successColor),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 32),
            ],

            // Recurrence period info
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 12 : 16,
                  horizontal: isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.infoColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: AppTheme.infoColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Period: ${_supabaseService.getRecurrencePeriodDescription(widget.form)}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.infoColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  if (widget.form.startTime != null &&
                      widget.form.endTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          color: AppTheme.infoColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Available: ${widget.form.startTime!.format(context)} - ${widget.form.endTime!.format(context)}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.infoColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),

            // Message card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: (isInTimeWindow && !_hasAlreadySubmitted)
                    ? AppTheme.primaryColor.withOpacity(0.06)
                    : AppTheme.errorColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isInTimeWindow && !_hasAlreadySubmitted)
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : AppTheme.errorColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w500,
                  color: (isInTimeWindow && !_hasAlreadySubmitted)
                      ? AppTheme.textPrimaryColor
                      : AppTheme.errorColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: isSmallScreen ? 32 : 40),

            // Start/continue button (only if allowed)
            if ((isInTimeWindow || widget.isPreview) && !_hasAlreadySubmitted)
              SizedBox(
                width: double.infinity,
                height: isSmallScreen ? 50 : 60,
                child: ElevatedButton.icon(
                  icon: Icon(
                    hasInProgressData
                        ? Icons.play_circle_filled
                        : Icons.play_arrow,
                    size: isSmallScreen ? 24 : 28,
                    color: Colors.white,
                  ),
                  label: Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasInProgressData
                        ? AppTheme.secondaryColor
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _startSession,
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      );
    });
  }

  Widget _buildActiveSession() {
    return Column(
      children: [
        // Progress indicator with saving status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: $_completedFields of ${widget.form.fields.length} fields completed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  if (_isSaving || _savingMessage.isNotEmpty)
                    Row(
                      children: [
                        if (_isSaving)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _savingMessage,
                          style: TextStyle(
                            color: _isSaving
                                ? AppTheme.secondaryColor
                                : AppTheme.successColor,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _completedFields / widget.form.fields.length,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.successColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),

        // Form content
        Expanded(
          child: Container(
            color: AppTheme.backgroundColor,
            child: FormBuilder(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Form fields
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.form.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.form.description,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const Divider(height: 32),
                          ...widget.form.fields
                              .map((field) => _buildFormField(field)),
                        ],
                      ),
                    ),
                  ),

                  // Submit button
                  if (!widget.isPreview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.check_circle,
                            size: 24,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Submit Checklist',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _submitForm(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

// Updated _buildFormField method with period-aware styling
  Widget _buildFormField(FormFieldModel field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field header with icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getColorForFieldType(field.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForFieldType(field.type),
                  color: _getColorForFieldType(field.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (_responses.containsKey(field.id) &&
                        _responses[field.id] != null)
                      const Text(
                        'Filled',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (field.isRequired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Field input
          _buildFieldInput(field),

          if (field != widget.form.fields.last)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Divider(),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldInput(FormFieldModel field) {
    // Get the saved value for this field
    final savedValue = _responses[field.id];

    switch (field.type) {
      case FieldType.text:
        return FormBuilderTextField(
          name: field.id,
          initialValue: savedValue?.toString(),
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          onChanged: (value) {
            _updateFieldValue(field.id, value);
          },
        );

      case FieldType.email:
        return FormBuilderTextField(
          name: field.id,
          initialValue: savedValue?.toString(),
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            prefixIcon: const Icon(Icons.email, color: AppTheme.primaryColor),
          ),
          validator: FormBuilderValidators.compose([
            if (field.isRequired) FormBuilderValidators.required(),
            FormBuilderValidators.email(),
          ]),
          keyboardType: TextInputType.emailAddress,
          onChanged: (value) {
            _updateFieldValue(field.id, value);
          },
        );

      case FieldType.number:
        return FormBuilderTextField(
          name: field.id,
          initialValue: savedValue?.toString(),
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            prefixIcon: const Icon(Icons.numbers, color: AppTheme.primaryColor),
          ),
          validator: FormBuilderValidators.compose([
            if (field.isRequired) FormBuilderValidators.required(),
            FormBuilderValidators.numeric(),
          ]),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            _updateFieldValue(field.id, value);
          },
        );

      case FieldType.multiline:
        return FormBuilderTextField(
          name: field.id,
          initialValue: savedValue?.toString(),
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          maxLines: 3,
          minLines: 3,
          onChanged: (value) {
            _updateFieldValue(field.id, value);
          },
        );

      case FieldType.textarea:
        return FormBuilderTextField(
          name: field.id,
          initialValue: savedValue?.toString(),
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            alignLabelWithHint: true,
          ),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          maxLines: 8,
          minLines: 6,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          onChanged: (value) {
            _updateFieldValue(field.id, value);
          },
        );

      case FieldType.time:
        // Try to parse the saved value to TimeOfDay
        TimeOfDay? initialTimeValue;
        if (savedValue != null) {
          try {
            final valueStr = savedValue.toString();
            if (valueStr.contains(':')) {
              final parts = valueStr.split(':');
              if (parts.length == 2) {
                final hourStr = parts[0].replaceAll(RegExp(r'[^\d]'), '');
                final minuteStr = parts[1].replaceAll(RegExp(r'[^\d]'), '');

                initialTimeValue = TimeOfDay(
                  hour: int.parse(hourStr),
                  minute: int.parse(minuteStr),
                );
              }
            }
          } catch (e) {
            debugPrint('Error parsing time value: $e');
          }
        }

        return FormBuilderDateTimePicker(
          name: field.id,
          inputType: InputType.time,
          initialValue: initialTimeValue != null
              ? DateTime(
                  2022, 1, 1, initialTimeValue.hour, initialTimeValue.minute)
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            suffixIcon:
                const Icon(Icons.access_time, color: AppTheme.primaryColor),
          ),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          onChanged: (value) {
            if (value != null) {
              final formattedTime =
                  TimeOfDay.fromDateTime(value).format(context);
              _updateFieldValue(field.id, formattedTime);
            } else {
              _updateFieldValue(field.id, null);
            }
          },
        );

      case FieldType.dropdown:
        return FormBuilderDropdown<String>(
          name: field.id,
          initialValue: savedValue != null ? savedValue.toString() : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          items: field.options!.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          onChanged: (value) {
            _updateFieldValue(field.id, value);
          },
        );

      case FieldType.checkbox:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: FormBuilderCheckboxGroup<String>(
            name: field.id,
            orientation: OptionsOrientation.vertical,
            initialValue:
                savedValue is List ? List<String>.from(savedValue) : null,
            options: field.options!.map((option) {
              return FormBuilderFieldOption(
                value: option,
                child: Text(option),
              );
            }).toList(),
            validator:
                field.isRequired ? FormBuilderValidators.required() : null,
            onChanged: (value) {
              _updateFieldValue(field.id, value);
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            activeColor: AppTheme.secondaryColor,
          ),
        );

      case FieldType.radio:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: FormBuilderRadioGroup<String>(
            name: field.id,
            orientation: OptionsOrientation.vertical,
            initialValue: savedValue != null ? savedValue.toString() : null,
            options: field.options!.map((option) {
              return FormBuilderFieldOption(
                value: option,
                child: Text(option),
              );
            }).toList(),
            validator:
                field.isRequired ? FormBuilderValidators.required() : null,
            onChanged: (value) {
              _updateFieldValue(field.id, value);
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            activeColor: AppTheme.secondaryColor,
          ),
        );

      case FieldType.date:
        // Try to parse the saved date value
        DateTime? initialDateValue;
        if (savedValue != null) {
          try {
            initialDateValue = DateTime.parse(savedValue.toString());
          } catch (e) {
            debugPrint('Error parsing date value: $e');
          }
        }

        return FormBuilderDateTimePicker(
          name: field.id,
          inputType: InputType.date,
          initialValue: initialDateValue,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            suffixIcon:
                const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
          ),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          onChanged: (value) {
            _updateFieldValue(field.id, value?.toString());
          },
        );

      case FieldType.likert:
        return _buildLikertInput(field);

      // NEW: Image upload support for checklist
      case FieldType.image:
        return _buildImageField(field);

      default:
        return Container();
    }
  }

// Add this new method to your _ChecklistFormScreenState class:
  Widget _buildImageField(FormFieldModel field) {
    final savedValue = _responses[field.id];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _getColorForFieldType(field.type).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _getColorForFieldType(field.type).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getColorForFieldType(field.type).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getColorForFieldType(field.type),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Image Upload',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getColorForFieldType(field.type),
                        ),
                      ),
                      if (field.placeholder != null &&
                          field.placeholder!.isNotEmpty)
                        Text(
                          field.placeholder!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getColorForFieldType(field.type)
                                .withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                if (savedValue != null &&
                    savedValue.toString().isNotEmpty &&
                    savedValue != 'uploading')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.successColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Uploaded',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (savedValue == 'uploading')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Uploading...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Image picker content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show current image if exists
                if (savedValue != null &&
                    savedValue.toString().isNotEmpty &&
                    savedValue != 'uploading')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        savedValue.toString(),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey.shade100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Image picker
                FormBuilderImagePicker(
                  name: field.id,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxImages: 1,
                  previewWidth: 150,
                  previewHeight: 150,
                  validator: field.isRequired
                      ? FormBuilderValidators.required()
                      : null,
                  showDecoration: true,
                  fit: BoxFit.cover,
                  backgroundColor: Colors.grey.shade50,
                  cameraIcon: Icon(
                    Icons.camera_alt,
                    color: _getColorForFieldType(field.type),
                  ),
                  galleryIcon: Icon(
                    Icons.photo_library,
                    color: _getColorForFieldType(field.type),
                  ),
                  onChanged: (value) async {
                    if (value != null && value.isNotEmpty) {
                      // Show loading state
                      setState(() {
                        _responses[field.id] = 'uploading';
                      });

                      try {
                        if (value[0] is XFile) {
                          XFile imageFile = value[0] as XFile;
                          final imagePath =
                              'checklist_images/${const Uuid().v4()}.jpg';

                          // Read image bytes
                          final imageBytes =
                              await File(imageFile.path).readAsBytes();

                          // Upload to Supabase
                          await _supabaseService.uploadImage(
                            'form_images',
                            imagePath,
                            imageBytes,
                          );

                          // Get public URL
                          final publicUrl = await _supabaseService.getImageUrl(
                            'form_images',
                            imagePath,
                          );

                          // Update the field value with the URL
                          _updateFieldValue(field.id, publicUrl);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Image uploaded successfully'),
                                  ],
                                ),
                                backgroundColor: AppTheme.successColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        // Remove the loading state
                        setState(() {
                          _responses.remove(field.id);
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Error uploading image: ${e.toString()}'),
                                  ),
                                ],
                              ),
                              backgroundColor: AppTheme.errorColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      }
                    } else {
                      // Image was removed
                      _updateFieldValue(field.id, null);
                    }
                  },
                ),

                // Upload instructions
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getColorForFieldType(field.type).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getColorForFieldType(field.type).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: _getColorForFieldType(field.type),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap camera to take a photo or gallery to select an image',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getColorForFieldType(field.type),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikertInput(FormFieldModel field) {
    final questions = field.likertQuestions ?? [];

    // Parse scale options from the options field
    final scaleOptions = _parseLikertOptions(field);

    if (questions.isEmpty || scaleOptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          'Likert scale not properly configured',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Get saved responses
    Map<String, dynamic> savedResponses = {};
    if (_responses[field.id] is Map) {
      savedResponses = Map<String, dynamic>.from(_responses[field.id]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _getColorForFieldType(field.type).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _getColorForFieldType(field.type).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getColorForFieldType(field.type).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getColorForFieldType(field.type),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.poll_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Rate each statement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9C27B0),
                  ),
                ),
              ],
            ),
          ),

          // Table
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;

              if (isSmallScreen) {
                return _buildVerticalLikertLayoutChecklist(
                    field, questions, scaleOptions, savedResponses);
              } else {
                return _buildHorizontalLikertTableChecklist(
                    field, questions, scaleOptions, savedResponses);
              }
            },
          ),

          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getColorForFieldType(field.type).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.checklist_rtl,
                  size: 16,
                  color: _getColorForFieldType(field.type),
                ),
                const SizedBox(width: 8),
                Text(
                  'Progress: ${savedResponses.length}/${questions.length} questions answered',
                  style: TextStyle(
                    color: _getColorForFieldType(field.type),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalLikertTableChecklist(
    FormFieldModel field,
    List<String> questions,
    List<LikertOption> scaleOptions,
    Map<String, dynamic> savedResponses,
  ) {
    return Column(
      children: questions.asMap().entries.map((entry) {
        final index = entry.key;
        final question = entry.value;
        final questionKey = index.toString();
        final selectedValue = savedResponses[questionKey];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getColorForFieldType(field.type).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _getColorForFieldType(field.type),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Options in horizontal layout
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: scaleOptions.map((option) {
                      final isSelected = selectedValue == option.value;

                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Map<String, dynamic> currentResponses = {};
                              if (_responses[field.id] is Map) {
                                currentResponses = Map<String, dynamic>.from(
                                    _responses[field.id]);
                              }
                              currentResponses[questionKey] = option.value;
                              _updateFieldValue(field.id, currentResponses);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _getColorForFieldType(field.type)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? _getColorForFieldType(field.type)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF333333),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVerticalLikertLayoutChecklist(
    FormFieldModel field,
    List<String> questions,
    List<LikertOption> scaleOptions,
    Map<String, dynamic> savedResponses,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final questionKey = index.toString();
          final selectedValue = savedResponses[questionKey];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getColorForFieldType(field.type).withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _getColorForFieldType(field.type),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: scaleOptions.map((option) {
                      final isSelected = selectedValue == option.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Map<String, dynamic> currentResponses = {};
                              if (_responses[field.id] is Map) {
                                currentResponses = Map<String, dynamic>.from(
                                    _responses[field.id]);
                              }
                              currentResponses[questionKey] = option.value;
                              _updateFieldValue(field.id, currentResponses);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _getColorForFieldType(field.type)
                                        .withOpacity(0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? _getColorForFieldType(field.type)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _getColorForFieldType(field.type)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? _getColorForFieldType(field.type)
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? _getColorForFieldType(field.type)
                                            : const Color(0xFF333333),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<LikertOption> _parseLikertOptions(FormFieldModel field) {
    // If field.options contains likert scale options in format "label|value"
    if (field.options != null && field.options!.isNotEmpty) {
      return field.options!.map((option) {
        if (option.contains('|')) {
          final parts = option.split('|');
          return LikertOption(
            label: parts[0].trim(),
            value: parts.length > 1 ? parts[1].trim() : parts[0].trim(),
          );
        } else {
          return LikertOption(label: option, value: option);
        }
      }).toList();
    }

    // Fallback to default scale if no custom options
    final scale = field.likertScale ?? 5;
    final startLabel = field.likertStartLabel ?? 'Strongly Disagree';
    final endLabel = field.likertEndLabel ?? 'Strongly Agree';
    final middleLabel = field.likertMiddleLabel;

    List<LikertOption> options = [];

    for (int i = 1; i <= scale; i++) {
      String label;
      if (i == 1) {
        label = startLabel;
      } else if (i == scale) {
        label = endLabel;
      } else if (i == ((scale + 1) ~/ 2) &&
          middleLabel != null &&
          middleLabel.isNotEmpty) {
        label = middleLabel;
      } else {
        label = i.toString();
      }
      options.add(LikertOption(label: label, value: 'scale_$i'));
    }

    return options;
  }

  void _updateFieldValue(String fieldId, dynamic value) {
    setState(() {
      if (value != null && value.toString().isNotEmpty) {
        _responses[fieldId] = value;

        // Auto-save the response (now period-aware)
        if (!widget.isPreview) {
          _autoSaveService.updateResponse(widget.form.id, fieldId, value);
        }

        // Recalculate completed fields count
        _completedFields = _responses.keys.length;
      } else if (_responses.containsKey(fieldId)) {
        _responses.remove(fieldId);
        _completedFields = _responses.keys.length;

        // Auto-save the removal (now period-aware)
        if (!widget.isPreview) {
          _autoSaveService.updateResponse(widget.form.id, fieldId, null);
        }
      }
    });
  }

  // Updated method to check for previous submissions in current period
  Future<void> _checkPreviousSubmission() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null) return;

    try {
      // Use the new method that checks current recurrence period only
      final hasSubmittedInCurrentPeriod = await _supabaseService
          .hasUserSubmittedInCurrentPeriod(widget.form.id, user.id);

      if (mounted) {
        setState(() {
          _hasAlreadySubmitted = hasSubmittedInCurrentPeriod;
        });
      }
    } catch (e) {
      debugPrint('Error checking previous submission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isPreview
              ? 'Preview: ${widget.form.title}'
              : widget.form.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          if (_isSessionActive && !widget.isPreview && !_hasAlreadySubmitted)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.check_circle),
                onPressed: _isSubmitting ? null : () => _submitForm(),
                tooltip: 'Submit Checklist',
              ),
            ),
        ],
        // Custom bottom component for timer
        bottom: _isSessionActive
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Started: ${_sessionStartTime != null ? TimeOfDay.fromDateTime(_sessionStartTime!).format(context) : ""}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (widget.form.endTime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _formatRemainingTime(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading || _isSubmitting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    _isSubmitting
                        ? 'Submitting your checklist...'
                        : 'Loading checklist...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            )
          : _hasAlreadySubmitted
              ? _buildAlreadySubmittedScreen()
              : _isSessionActive
                  ? _buildActiveSession()
                  : Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildSessionStartScreen(),
                      ),
                    ),
    );
  }

  Widget _buildAlreadySubmittedScreen() {
    final periodDescription =
        _supabaseService.getRecurrencePeriodDescription(widget.form);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 72,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.form.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You have already submitted this checklist for $periodDescription',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info, color: AppTheme.infoColor),
                      SizedBox(width: 8),
                      Text(
                        'Submission Rules',
                        style: TextStyle(
                          color: AppTheme.infoColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can submit this ${_getRecurrenceTypeString(widget.form.recurrenceType)} checklist once per ${_getRecurrenceTypeString(widget.form.recurrenceType)}. Please try again in the next period.',
                    style: const TextStyle(
                      color: AppTheme.infoColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
        return AppTheme.primaryColor;
      case FieldType.number:
        return Colors.deepPurple;
      case FieldType.email:
        return Colors.teal;
      case FieldType.multiline:
        return Colors.indigo;
      case FieldType.textarea:
        return Colors.blue;
      case FieldType.dropdown:
        return Colors.amber;
      case FieldType.checkbox:
        return Colors.green;
      case FieldType.radio:
        return Colors.deepOrange;
      case FieldType.date:
        return Colors.red;
      case FieldType.time:
        return Colors.purple;
      case FieldType.image:
        return Colors.pink;
      case FieldType.likert:
        return const Color(0xFF9C27B0);
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getIconForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
        return Icons.text_fields;
      case FieldType.number:
        return Icons.numbers;
      case FieldType.email:
        return Icons.email;
      case FieldType.multiline:
        return Icons.short_text;
      case FieldType.textarea:
        return Icons.text_snippet;
      case FieldType.dropdown:
        return Icons.arrow_drop_down_circle;
      case FieldType.checkbox:
        return Icons.check_box;
      case FieldType.radio:
        return Icons.radio_button_checked;
      case FieldType.date:
        return Icons.calendar_today;
      case FieldType.time:
        return Icons.access_time;
      case FieldType.image:
        return Icons.image;
      case FieldType.likert:
        return Icons.poll_outlined;
      default:
        return Icons.input;
    }
  }
}
