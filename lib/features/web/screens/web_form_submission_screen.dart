// lib/screens/web_form_submission_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:jala_form/core/services/checklist_autosave_service.dart';
import 'package:jala_form/services/supabase_service.dart';
import 'package:jala_form/core/services/web_pdf_service.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_field.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:jala_form/features/web/models/likert_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:universal_html/html.dart' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';

class WebFormSubmissionScreen extends StatefulWidget {
  final CustomForm form;
  final bool isPreview;

  const WebFormSubmissionScreen({
    super.key,
    required this.form,
    this.isPreview = false,
  });

  @override
  State<WebFormSubmissionScreen> createState() =>
      _WebFormSubmissionScreenState();
}

class _WebFormSubmissionScreenState extends State<WebFormSubmissionScreen> {
  bool _formSubmitted = false;
  FormResponse? _formResponseData;
  final _formKey = GlobalKey<FormBuilderState>();
  final _supabaseService = SupabaseService();
  final _autoSaveService = ChecklistAutoSaveService();
  bool _isSubmitting = false;
  bool _isLoading = true;
  final Map<String, dynamic> _responses = {};

  // For checklists
  bool _isSessionActive = false;
  DateTime? _sessionStartTime;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  int _completedFields = 0;
  bool _isSaving = false;
  String _savingMessage = '';
  bool _hasLoadedSavedData = false;
  bool _hasAlreadySubmitted = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _checkPreviousData().then((_) => _debugStorageState());

    // Listen for auto-save status changes
    _autoSaveService.savingStatus.addListener(_updateSavingStatus);
  }

  // Update saving status
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
    // Remove listener and force save on dispose
    _autoSaveService.savingStatus.removeListener(_updateSavingStatus);

    // Force save any pending changes when leaving
    if (_isSessionActive && widget.form.isChecklist) {
      _autoSaveService.forceSave(widget.form.id);
    }

    super.dispose();
  }

  void _initializeForm() async {
    // Clean up any old period data first
    await _autoSaveService.cleanupOldPeriodData();

    // Check if this is a checklist form with time constraints
    if (widget.form.isChecklist &&
        widget.form.startTime != null &&
        widget.form.endTime != null &&
        !_isInTimeWindow() &&
        !widget.isPreview) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Check for previous submissions (for checklists that shouldn't allow multiple submissions)
    if (widget.form.isChecklist && !widget.isPreview) {
      await _checkPreviousSubmission();
    }

    // Check for previously saved data from CURRENT period only
    if (widget.form.isChecklist) {
      await _checkPreviousData();
    }

    setState(() {
      _isLoading = false;
    });
  }

// Updated method to check if current time is in window (for daily recurring forms)
  bool _isInTimeWindow() {
    if (!widget.form.isChecklist ||
        widget.form.startTime == null ||
        widget.form.endTime == null) {
      return true; // Regular forms or forms without time constraints are always available
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

// Helper method to convert RecurrenceType enum to string
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
      case null:
        return 'recurring';
      case RecurrenceType.custom:
        return 'custom';
    }
  }

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
        // For custom recurrence, treat like one-time for now
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

// Fixed: Update clearForm to be async and return proper type
  Future<void> _submitForm({bool isAutoSubmit = false}) async {
    if (_isSessionActive && widget.form.isChecklist) {
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
    } else {
      // Regular form submission - validate
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
      if (widget.form.isChecklist) {
        // Fixed: Both methods are now properly awaited
        await _autoSaveService.clearForm(widget.form.id);
        await _supabaseService.deleteDraftResponse(widget.form.id);

        if (mounted) {
          final periodDesc =
              _supabaseService.getRecurrencePeriodDescription(widget.form);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAutoSubmit
                  ? 'Time expired. Form submitted automatically with $_completedFields completed fields for $periodDesc.'
                  : 'Form submitted successfully for $periodDesc!'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // For regular forms, show success screen with PDF download option
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _formSubmitted = true;
            _formResponseData = formResponse;
          });
        }
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
      // Always cancel timer if it exists (for checklists)
      _timer?.cancel();

      if (mounted && !_formSubmitted) {
        setState(() {
          _isSubmitting = false;
          _isSessionActive = false;
        });
      }
    }
  }

// Updated session start method with better period handling
  void _startSession() async {
    // Clean up any old period data before starting
    await _autoSaveService.cleanupOldPeriodData();

    // Try to load any previously saved data from CURRENT period
    if (widget.form.isChecklist && !_hasLoadedSavedData) {
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

    // Calculate time remaining until end time for checklists
    if (widget.form.isChecklist && widget.form.endTime != null) {
      _calculateRemainingTime();

      // Start a timer to update the remaining time
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          _calculateRemainingTime();
        }
      });
    }
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

// Complete PDF generation method
  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    // Define some styles
    final titleStyle = pw.TextStyle(
        fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900);

    final headerStyle = pw.TextStyle(
        fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800);

    final labelStyle = pw.TextStyle(
        fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700);

    final valueStyle = pw.TextStyle(fontSize: 11, color: PdfColors.black);

    // Create PDF content
    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.blue200))),
              child: pw.Column(children: [
                pw.Text(widget.form.title, style: titleStyle),
                pw.SizedBox(height: 5),
                pw.Text('Form Submission Details',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey700)),
              ]),
            ),
        footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                color: PdfColors.grey700,
                fontSize: 10,
              ),
            )),
        build: (pw.Context context) => [
              // Description
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Text(widget.form.description,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.blue900,
                    )),
              ),

              pw.SizedBox(height: 20),

              // Submission info
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          'Submitted on: ${DateTime.now().toString().substring(0, 19)}',
                          style: pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Form ID: ${widget.form.id.substring(0, 8)}...',
                          style: pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey700)),
                    ]),
              ),

              pw.SizedBox(height: 30),
              pw.Text('FORM RESPONSES', style: headerStyle),
              pw.Divider(color: PdfColors.blue200, thickness: 2),
              pw.SizedBox(height: 10),

              // Form responses
              ...widget.form.fields.map((field) {
                final response = _responses[field.id];

                // Handle empty responses
                if (response == null) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 15),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(field.label, style: labelStyle),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            'No response provided',
                            style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                                fontStyle: pw.FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Format response based on field type
                String displayValue = '';
                if (field.type == FieldType.checkbox && response is List) {
                  displayValue = (response).join(', ');
                } else if (field.type == FieldType.date && response is String) {
                  try {
                    final date = DateTime.parse(response);
                    displayValue = '${date.day}/${date.month}/${date.year}';
                  } catch (e) {
                    displayValue = response.toString();
                  }
                } else if (field.type == FieldType.image) {
                  displayValue = 'Image uploaded (not displayed in PDF)';
                } else {
                  displayValue = response.toString();
                }

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              width: 8,
                              height: 8,
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.blue700,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 5),
                            pw.Text(field.label, style: labelStyle),
                            pw.SizedBox(width: 5),
                            if (field.isRequired)
                              pw.Text('(Required)',
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      color: PdfColors.grey700,
                                      fontStyle: pw.FontStyle.italic)),
                          ]),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(displayValue, style: valueStyle),
                      ),
                    ],
                  ),
                );
              }),
            ]));

    return pdf.save();
  }

// Complete updated _buildFormField method with all field types
  Widget _buildFormField(FormFieldModel field) {
    // Get the saved value for this field
    final savedValue = _responses[field.id];

    // Common onChanged function that matches FormBuilder signature
    void onFieldChanged(dynamic value) {
      if (value != null) {
        setState(() {
          _responses[field.id] = value;
          _updateCompletedFields();
        });

        // Auto-save with the service (now period-aware)
        if (widget.form.isChecklist) {
          _autoSaveService.updateResponse(widget.form.id, field.id, value);
        }
      }
    }

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
          onChanged: onFieldChanged,
          autofocus: false,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
          onChanged: onFieldChanged,
          autofocus: false,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
          onChanged: onFieldChanged,
          autofocus: false,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
          onChanged: onFieldChanged,
          autofocus: false,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
          onChanged: onFieldChanged,
          autofocus: false,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
        );

      case FieldType.dropdown:
        return FormBuilderDropdown<String>(
          name: field.id,
          initialValue: savedValue?.toString(),
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
          onChanged: onFieldChanged,
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
            onChanged: onFieldChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            activeColor: AppTheme.primaryColor,
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
            initialValue: savedValue?.toString(),
            options: field.options!.map((option) {
              return FormBuilderFieldOption(
                value: option,
                child: Text(option),
              );
            }).toList(),
            validator:
                field.isRequired ? FormBuilderValidators.required() : null,
            onChanged: onFieldChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            activeColor: AppTheme.primaryColor,
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
            if (value != null) {
              onFieldChanged(value.toString());
            }
          },
        );

      case FieldType.time:
        // Try to parse the saved value to TimeOfDay
        TimeOfDay? initialTimeValue;
        if (savedValue != null) {
          try {
            // Handle both formats - string like "13:45" and TimeOfDay.toString()
            final valueStr = savedValue.toString();
            if (valueStr.contains(':')) {
              final parts = valueStr.split(':');
              if (parts.length == 2) {
                // Remove any non-numeric parts (like "TimeOfDay(" or ")")
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
          // If we successfully parsed the saved value, use it
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
              // Format the time as a string in HH:MM format for consistent storage
              final formattedTime =
                  TimeOfDay.fromDateTime(value).format(context);
              onFieldChanged(formattedTime);
            }
          },
        );

      case FieldType.image:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                icon: const Icon(
                  Icons.file_upload,
                  color: Colors.white,
                ),
                label: const Text('Upload Image'),
                onPressed: () => _uploadImage(field.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_responses.containsKey(field.id) &&
                  _responses[field.id] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text('Image uploaded'),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        _responses[field.id],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                          child: Icon(Icons.broken_image,
                              size: 64, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );

      case FieldType.likert:
        // Special handling for Likert - break out of normal constraints on mobile
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;

            if (screenWidth < 768) {
              // Mobile: Return without any wrapping containers to maximize width
              return _buildMobileLikertLayoutFullWidth(field);
            } else if (screenWidth < 1024) {
              return _buildTabletLikertLayout(field);
            } else {
              return _buildDesktopLikertTable(field);
            }
          },
        );

      default:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Unsupported field type',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

// Updated Desktop Likert table with proper radio button logic
  Widget _buildDesktopLikertTable(FormFieldModel field) {
    final questions = field.likertQuestions ?? [];
    final scaleOptions = _parseLikertOptions(field);

    if (questions.isEmpty || scaleOptions.isEmpty) {
      return _buildLikertErrorState();
    }

    // Get saved responses - ensure it's always a Map<String, String>
    Map<String, String> savedResponses = {};
    if (_responses[field.id] is Map) {
      final responseMap = _responses[field.id] as Map;
      responseMap.forEach((key, value) {
        savedResponses[key.toString()] = value.toString();
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9C27B0).withOpacity(0.08),
                  const Color(0xFF9C27B0).withOpacity(0.12),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.poll_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Please rate each statement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9C27B0),
                  ),
                ),
              ],
            ),
          ),

          // Table structure
          Table(
            columnWidths: {
              0: const FlexColumnWidth(4), // Statement column
              ...{ for (var index in List.generate(scaleOptions.length, (index) => index + 1)) index : const FlexColumnWidth(2) },
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 2),
                  ),
                ),
                children: [
                  // Statement header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Statement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  // Option headers
                  ...scaleOptions.map((option) => Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              option.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9C27B0),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 2,
                              width: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
              // Question rows
              ...questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                final questionKey = index.toString();

                return TableRow(
                  decoration: BoxDecoration(
                    color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade100,
                        width: index == questions.length - 1 ? 0 : 1,
                      ),
                    ),
                  ),
                  children: [
                    // Question cell
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9C27B0),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              question,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Radio button cells
                    ...scaleOptions.map((option) {
                      // Check if THIS specific option is selected for THIS specific question
                      final isSelected =
                          savedResponses[questionKey] == option.value;

                      return Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Radio button
                            GestureDetector(
                              onTap: widget.isPreview
                                  ? null
                                  : () {
                                      // Create a fresh map for responses
                                      Map<String, String> newResponses = {};

                                      // Copy existing responses
                                      if (_responses[field.id] is Map) {
                                        final existingMap =
                                            _responses[field.id] as Map;
                                        existingMap.forEach((key, value) {
                                          newResponses[key.toString()] =
                                              value.toString();
                                        });
                                      }

                                      // Set ONLY this question's response (this will overwrite any previous selection for this question)
                                      newResponses[questionKey] = option.value;

                                      // Update the state
                                      setState(() {
                                        _responses[field.id] = newResponses;
                                        _updateCompletedFields();
                                      });

                                      // Debug print to verify state
                                      print(
                                          'Question $questionKey selected: ${option.value}');
                                      print(
                                          'All responses for field ${field.id}: $newResponses');

                                      // Auto-save
                                      if (widget.form.isChecklist) {
                                        _autoSaveService.updateResponse(
                                            widget.form.id,
                                            field.id,
                                            newResponses);
                                      }
                                    },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF9C27B0)
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  color: Colors.white,
                                ),
                                child: isSelected
                                    ? Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF9C27B0),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Label under radio button
                            Text(
                              option.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF9C27B0)
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),

          // Progress footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.05),
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
                      Icons.checklist_rtl,
                      size: 16,
                      color: Color(0xFF9C27B0),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Progress: ${savedResponses.length}/${questions.length} questions answered',
                      style: const TextStyle(
                        color: Color(0xFF9C27B0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Progress bar
                Container(
                  width: 200,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: questions.isEmpty
                        ? 0
                        : savedResponses.length / questions.length,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Also update the tablet layout to use proper radio button groups
  Widget _buildTabletLikertLayout(FormFieldModel field) {
    final questions = field.likertQuestions ?? [];
    final scaleOptions = _parseLikertOptions(field);

    if (questions.isEmpty || scaleOptions.isEmpty) {
      return _buildLikertErrorState();
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
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9C27B0).withOpacity(0.08),
                  const Color(0xFF9C27B0).withOpacity(0.12),
                ],
              ),
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
                    color: const Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.poll_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Please rate each statement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9C27B0),
                  ),
                ),
              ],
            ),
          ),

          // Scale options legend
          Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: scaleOptions
                  .map((option) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF9C27B0).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          option.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9C27B0),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Questions
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final questionKey = index.toString();
            final selectedValue = savedResponses[questionKey];

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Options with single selection
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: scaleOptions.map((option) {
                      final isSelected = selectedValue == option.value;

                      return GestureDetector(
                        onTap: widget.isPreview
                            ? null
                            : () {
                                Map<String, dynamic> currentResponses = {};
                                if (_responses[field.id] is Map) {
                                  currentResponses = Map<String, dynamic>.from(
                                      _responses[field.id]);
                                }
                                // Only set this question's response, clearing any previous selection for this question
                                currentResponses[questionKey] = option.value;

                                setState(() {
                                  _responses[field.id] = currentResponses;
                                  _updateCompletedFields();
                                });

                                // Auto-save
                                if (widget.form.isChecklist) {
                                  _autoSaveService.updateResponse(
                                      widget.form.id,
                                      field.id,
                                      currentResponses);
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF9C27B0)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF9C27B0)
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
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),

          // Progress footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.checklist_rtl,
                  size: 16,
                  color: Color(0xFF9C27B0),
                ),
                const SizedBox(width: 8),
                Text(
                  'Progress: ${savedResponses.length}/${questions.length} questions answered',
                  style: const TextStyle(
                    color: Color(0xFF9C27B0),
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

// Fixed Mobile Likert layout without const issues
  Widget _buildMobileLikertLayoutFullWidth(FormFieldModel field) {
    final questions = field.likertQuestions ?? [];
    final scaleOptions = _parseLikertOptions(field);

    if (questions.isEmpty || scaleOptions.isEmpty) {
      return _buildLikertErrorState();
    }

    // Get saved responses
    Map<String, String> savedResponses = {};
    if (_responses[field.id] is Map) {
      final responseMap = _responses[field.id] as Map;
      responseMap.forEach((key, value) {
        savedResponses[key.toString()] = value.toString();
      });
    }

    return Container(
      width: MediaQuery.of(context).size.width, // Use full screen width
      margin: const EdgeInsets.symmetric(horizontal: 8), // Minimal side margins
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Full width
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9C27B0).withOpacity(0.08),
                  const Color(0xFF9C27B0).withOpacity(0.12),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.poll_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Rate each statement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Questions - Maximum width usage
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final questionKey = index.toString();
            final selectedValue = savedResponses[questionKey];

            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: 12,
                top: index == 0
                    ? 8
                    : 0, // Fixed: Use EdgeInsets.only without const
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.1),
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
                            color: const Color(0xFF9C27B0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            question,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Options - Full width with fixed margins
                  Column(
                    children: scaleOptions.asMap().entries.map((optionEntry) {
                      final optionIndex = optionEntry.key;
                      final option = optionEntry.value;
                      final isSelected = selectedValue == option.value;

                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                          left: 8,
                          right: 8,
                          bottom: 6,
                          top: optionIndex == 0
                              ? 8
                              : 0, // Fixed: Use optionIndex instead
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.isPreview
                                ? null
                                : () {
                                    Map<String, String> newResponses = {};

                                    if (_responses[field.id] is Map) {
                                      final existingMap =
                                          _responses[field.id] as Map;
                                      existingMap.forEach((key, value) {
                                        newResponses[key.toString()] =
                                            value.toString();
                                      });
                                    }

                                    newResponses[questionKey] = option.value;

                                    setState(() {
                                      _responses[field.id] = newResponses;
                                      _updateCompletedFields();
                                    });

                                    if (widget.form.isChecklist) {
                                      _autoSaveService.updateResponse(
                                          widget.form.id,
                                          field.id,
                                          newResponses);
                                    }
                                  },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF9C27B0).withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF9C27B0)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Radio button
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? const Color(0xFF9C27B0)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF9C27B0)
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
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
                                  // Option text - takes all remaining space
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF9C27B0)
                                            : const Color(0xFF333333),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        fontSize: 14,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  // Selected indicator
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9C27B0),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Selected',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
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

                  const SizedBox(height: 8), // Bottom spacing for each question
                ],
              ),
            );
          }),

          // Progress footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.checklist_rtl,
                      size: 14,
                      color: Color(0xFF9C27B0),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Progress: ${savedResponses.length}/${questions.length} questions answered',
                        style: const TextStyle(
                          color: Color(0xFF9C27B0),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                Container(
                  width: double.infinity,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: questions.isEmpty
                        ? 0
                        : savedResponses.length / questions.length,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikertField(FormFieldModel field) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;

        // Adjusted breakpoints for better mobile detection
        if (screenWidth >= 1024) {
          return _buildDesktopLikertTable(field);
        } else if (screenWidth >= 768) {
          return _buildTabletLikertLayout(field);
        } else {
          return _buildMobileLikertLayoutFullWidth(field);
        }
      },
    );
  }

// Helper method to parse Likert options
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

// Helper method for error state
  Widget _buildLikertErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Likert scale not properly configured. Please check questions and options.',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadImage(String fieldId) async {
    // Create file input element
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    // Wait for the user to select a file
    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        reader.onLoadEnd.listen((event) async {
          if (reader.result != null) {
            setState(() {
              _isSubmitting = true;
            });

            try {
              final bytes = reader.result as Uint8List;
              final imagePath = 'form_images/${const Uuid().v4()}.jpg';

              // Upload to Supabase
              final imageUrl = await _supabaseService.uploadImage(
                'form_images',
                imagePath,
                bytes,
              );

              // Get public URL
              final publicUrl = await _supabaseService.getImageUrl(
                'form_images',
                imagePath,
              );

              setState(() {
                _responses[fieldId] = publicUrl;
                _updateCompletedFields();
                _isSubmitting = false;
              });

              // Auto-save with the service
              if (widget.form.isChecklist) {
                _autoSaveService.updateResponse(
                    widget.form.id, fieldId, publicUrl);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error uploading image: ${e.toString()}')),
                );
                setState(() {
                  _isSubmitting = false;
                });
              }
            }
          }
        });
      }
    });
  }

  void _updateCompletedFields() {
    _completedFields = _responses.keys.length;
  }

// Updated session start screen with improved responsiveness
  Widget _buildSessionStartScreen() {
    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isPhone = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1200;
      final isDesktop = screenWidth >= 1200;

      // Responsive values
      final cardPadding = isPhone ? 20.0 : (isTablet ? 32.0 : 40.0);
      final iconSize = isPhone ? 70.0 : (isTablet ? 85.0 : 100.0);
      final titleSize = isPhone ? 24.0 : (isTablet ? 28.0 : 32.0);
      final maxCardWidth =
          isPhone ? double.infinity : (isTablet ? 650.0 : 750.0);

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

      bool hasInProgressData = _responses.isNotEmpty && !_hasAlreadySubmitted;
      final String buttonText =
          hasInProgressData ? 'Continue Checklist' : 'Start Checklist';

      return Center(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            margin: EdgeInsets.symmetric(
              horizontal: isPhone ? 16 : 24,
              vertical: isPhone ? 20 : 32,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isPhone ? 20 : 28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: isPhone ? 20 : 32,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: isPhone ? 8 : 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced animated icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: EdgeInsets.all(isPhone ? 24 : 32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _hasAlreadySubmitted
                                  ? [
                                      Colors.green.withOpacity(0.15),
                                      Colors.green.withOpacity(0.25)
                                    ]
                                  : hasInProgressData
                                      ? [
                                          AppTheme.secondaryColor
                                              .withOpacity(0.15),
                                          AppTheme.secondaryColor
                                              .withOpacity(0.25)
                                        ]
                                      : [
                                          AppTheme.primaryColor
                                              .withOpacity(0.15),
                                          AppTheme.primaryColor
                                              .withOpacity(0.25)
                                        ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_hasAlreadySubmitted
                                        ? Colors.green
                                        : hasInProgressData
                                            ? AppTheme.secondaryColor
                                            : AppTheme.primaryColor)
                                    .withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            _hasAlreadySubmitted
                                ? Icons.check_circle_rounded
                                : hasInProgressData
                                    ? Icons.edit_note_rounded
                                    : Icons.checklist_rtl_rounded,
                            size: iconSize,
                            color: _hasAlreadySubmitted
                                ? Colors.green.shade600
                                : hasInProgressData
                                    ? AppTheme.secondaryColor
                                    : AppTheme.primaryColor,
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: isPhone ? 32 : 40),

                  // Enhanced title with better typography
                  Text(
                    widget.form.title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: isPhone ? 16 : 20),

                  // Enhanced description
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: isPhone ? double.infinity : 500,
                    ),
                    child: Text(
                      widget.form.description,
                      style: TextStyle(
                        fontSize: isPhone ? 15 : 17,
                        color: AppTheme.textSecondaryColor,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  SizedBox(height: isPhone ? 32 : 40),

                  // Progress card with enhanced design
                  if (hasInProgressData) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isPhone ? 20 : 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.successColor.withOpacity(0.08),
                            AppTheme.successColor.withOpacity(0.12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
                        border: Border.all(
                          color: AppTheme.successColor.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successColor.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isPhone ? 12 : 14),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.successColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.trending_up_rounded,
                                  color: AppTheme.successColor,
                                  size: isPhone ? 24 : 28,
                                ),
                              ),
                              SizedBox(width: isPhone ? 16 : 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Progress Saved',
                                      style: TextStyle(
                                        fontSize: isPhone ? 18 : 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.successColor,
                                      ),
                                    ),
                                    SizedBox(height: isPhone ? 4 : 6),
                                    Text(
                                      '$_completedFields of ${widget.form.fields.length} fields completed',
                                      style: TextStyle(
                                        fontSize: isPhone ? 14 : 16,
                                        color: AppTheme.textSecondaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isPhone ? 20 : 24),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _completedFields /
                                    widget.form.fields.length,
                                backgroundColor: Colors.white.withOpacity(0.7),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.successColor),
                                minHeight: isPhone ? 12 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isPhone ? 32 : 40),
                  ],

                  // Enhanced period info card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isPhone ? 20 : 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.infoColor.withOpacity(0.08),
                          AppTheme.infoColor.withOpacity(0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
                      border: Border.all(
                        color: AppTheme.infoColor.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.infoColor.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isPhone ? 10 : 12),
                              decoration: BoxDecoration(
                                color: AppTheme.infoColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.schedule_rounded,
                                color: AppTheme.infoColor,
                                size: isPhone ? 20 : 24,
                              ),
                            ),
                            SizedBox(width: isPhone ? 12 : 16),
                            Expanded(
                              child: Text(
                                'Period: ${_supabaseService.getRecurrencePeriodDescription(widget.form)}',
                                style: TextStyle(
                                  fontSize: isPhone ? 15 : 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.infoColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.form.startTime != null &&
                            widget.form.endTime != null) ...[
                          SizedBox(height: isPhone ? 12 : 16),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isPhone ? 8 : 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.infoColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.access_time_filled_rounded,
                                  color: AppTheme.infoColor,
                                  size: isPhone ? 16 : 18,
                                ),
                              ),
                              SizedBox(width: isPhone ? 12 : 16),
                              Expanded(
                                child: Text(
                                  'Available: ${widget.form.startTime!.format(context)} - ${widget.form.endTime!.format(context)}',
                                  style: TextStyle(
                                    fontSize: isPhone ? 13 : 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.infoColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: isPhone ? 32 : 40),

                  // Enhanced message card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isPhone ? 20 : 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (isInTimeWindow && !_hasAlreadySubmitted)
                            ? [
                                AppTheme.primaryColor.withOpacity(0.06),
                                AppTheme.primaryColor.withOpacity(0.1),
                              ]
                            : [
                                AppTheme.errorColor.withOpacity(0.06),
                                AppTheme.errorColor.withOpacity(0.1),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
                      border: Border.all(
                        color: (isInTimeWindow && !_hasAlreadySubmitted)
                            ? AppTheme.primaryColor.withOpacity(0.25)
                            : AppTheme.errorColor.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isInTimeWindow && !_hasAlreadySubmitted)
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : AppTheme.errorColor.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: isPhone ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: (isInTimeWindow && !_hasAlreadySubmitted)
                            ? AppTheme.textPrimaryColor
                            : AppTheme.errorColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: isPhone ? 40 : 48),

                  // Enhanced start/continue button
                  if ((isInTimeWindow || widget.isPreview) &&
                      !_hasAlreadySubmitted)
                    Container(
                      width: double.infinity,
                      height: isPhone ? 56 : 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
                        boxShadow: [
                          BoxShadow(
                            color: (hasInProgressData
                                    ? AppTheme.secondaryColor
                                    : AppTheme.primaryColor)
                                .withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasInProgressData
                                ? Icons.play_circle_filled_rounded
                                : Icons.rocket_launch_rounded,
                            size: isPhone ? 24 : 28,
                            color: Colors.white,
                          ),
                        ),
                        label: Text(
                          buttonText,
                          style: TextStyle(
                            fontSize: isPhone ? 17 : 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasInProgressData
                              ? AppTheme.secondaryColor
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(isPhone ? 16 : 20),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isPhone ? 24 : 32,
                            vertical: isPhone ? 16 : 20,
                          ),
                        ),
                        onPressed: _startSession,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

// Updated checklist active session with better responsive design
  Widget _buildChecklistActiveSession() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1200;

        return Column(
          children: [
            // Enhanced progress indicator
            Container(
              margin: EdgeInsets.all(isPhone ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isPhone ? 16 : 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isPhone ? 8 : 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.1),
                                AppTheme.primaryColor.withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.trending_up_rounded,
                            color: AppTheme.primaryColor,
                            size: isPhone ? 20 : 24,
                          ),
                        ),
                        SizedBox(width: isPhone ? 12 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progress: $_completedFields of ${widget.form.fields.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                  fontSize: isPhone ? 15 : 16,
                                ),
                              ),
                              if (_isSaving || _savingMessage.isNotEmpty)
                                SizedBox(height: isPhone ? 6 : 8),
                              if (_isSaving || _savingMessage.isNotEmpty)
                                Row(
                                  children: [
                                    if (_isSaving)
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.secondaryColor,
                                        ),
                                      ),
                                    if (_isSaving) const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _savingMessage,
                                        style: TextStyle(
                                          color: _isSaving
                                              ? AppTheme.secondaryColor
                                              : AppTheme.successColor,
                                          fontSize: isPhone ? 12 : 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isPhone ? 12 : 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _completedFields / widget.form.fields.length,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.successColor,
                          ),
                          minHeight: isPhone ? 10 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Enhanced timer display
            Container(
              margin: EdgeInsets.symmetric(horizontal: isPhone ? 8 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 16 : 20,
                  vertical: isPhone ? 14 : 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.play_circle_filled_rounded,
                            color: Colors.white,
                            size: isPhone ? 16 : 18,
                          ),
                        ),
                        SizedBox(width: isPhone ? 8 : 10),
                        Text(
                          'Started: ${_sessionStartTime != null ? TimeOfDay.fromDateTime(_sessionStartTime!).format(context) : ""}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: isPhone ? 14 : 15,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isPhone ? 12 : 16,
                        vertical: isPhone ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            color: Colors.white,
                            size: isPhone ? 16 : 18,
                          ),
                          SizedBox(width: isPhone ? 6 : 8),
                          Text(
                            _formatRemainingTime(),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: isPhone ? 14 : 15,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Enhanced form content
            Expanded(
              child: Container(
                color: Colors.grey.shade50,
                child: FormBuilder(
                  key: _formKey,
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.all(isPhone ? 12 : 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Enhanced form header card
                            Container(
                              margin:
                                  EdgeInsets.only(bottom: isPhone ? 16 : 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(isPhone ? 16 : 20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isPhone ? 20 : 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                              EdgeInsets.all(isPhone ? 12 : 14),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primaryColor
                                                    .withOpacity(0.1),
                                                AppTheme.primaryColor
                                                    .withOpacity(0.2),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.assignment_rounded,
                                            color: AppTheme.primaryColor,
                                            size: isPhone ? 24 : 28,
                                          ),
                                        ),
                                        SizedBox(width: isPhone ? 16 : 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.form.title,
                                                style: TextStyle(
                                                  fontSize: isPhone ? 20 : 24,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppTheme.textPrimaryColor,
                                                  height: 1.2,
                                                ),
                                              ),
                                              if (widget.form.description
                                                  .isNotEmpty) ...[
                                                SizedBox(
                                                    height: isPhone ? 6 : 8),
                                                Text(
                                                  widget.form.description,
                                                  style: TextStyle(
                                                    fontSize: isPhone ? 15 : 16,
                                                    color: AppTheme
                                                        .textSecondaryColor,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Form fields
                            ...widget.form.fields
                                .map((field) => _buildFieldEntry(field)),

                            // Enhanced submit button
                            Container(
                              margin: EdgeInsets.only(
                                top: isPhone ? 20 : 24,
                                bottom: isPhone ? 24 : 32,
                              ),
                              height: isPhone ? 56 : 64,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(isPhone ? 16 : 20),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.successColor.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                icon: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: isPhone ? 24 : 28,
                                    color: Colors.white,
                                  ),
                                ),
                                label: Text(
                                  'Submit Checklist',
                                  style: TextStyle(
                                    fontSize: isPhone ? 17 : 19,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        isPhone ? 16 : 20),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isPhone ? 24 : 32,
                                    vertical: isPhone ? 16 : 20,
                                  ),
                                ),
                                onPressed: () => _submitForm(),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

// Updated _buildFieldEntry method to not constrain Likert on mobile
  Widget _buildFieldEntry(FormFieldModel field) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1200;

        // Special handling for Likert on mobile - don't wrap in normal field container
        if (field.type == FieldType.likert && isPhone) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field label outside the main container
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getColorForFieldType(field.type).withOpacity(0.1),
                            _getColorForFieldType(field.type).withOpacity(0.15),
                          ],
                        ),
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
                      child: Text(
                        field.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    if (field.isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Likert field with full width
              _buildFormField(field),
              const SizedBox(height: 20),
            ],
          );
        }

        // Normal field container for other field types or larger screens
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: isPhone ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isPhone ? 18 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced field header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isPhone ? 10 : 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getColorForFieldType(field.type).withOpacity(0.1),
                            _getColorForFieldType(field.type).withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(isPhone ? 10 : 12),
                      ),
                      child: Icon(
                        _getIconForFieldType(field.type),
                        color: _getColorForFieldType(field.type),
                        size: isPhone ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: isPhone ? 14 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.label,
                            style: TextStyle(
                              fontSize: isPhone ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                              height: 1.3,
                            ),
                          ),
                          if (field.placeholder != null &&
                              field.placeholder!.isNotEmpty) ...[
                            SizedBox(height: isPhone ? 4 : 6),
                            Text(
                              field.placeholder!,
                              style: TextStyle(
                                fontSize: isPhone ? 13 : 14,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (field.isRequired)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isPhone ? 8 : 10,
                          vertical: isPhone ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.errorColor.withOpacity(0.1),
                              AppTheme.errorColor.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.errorColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Required',
                          style: TextStyle(
                            fontSize: isPhone ? 11 : 12,
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isPhone ? 16 : 20),
                // Enhanced field input
                _buildFormField(field),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlreadySubmittedScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
        final maxWidth = isPhone ? double.infinity : (isTablet ? 550.0 : 650.0);

        return Container(
          color: Colors.grey.shade50,
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                margin: EdgeInsets.all(isPhone ? 20 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isPhone ? 20 : 28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: isPhone ? 20 : 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(isPhone ? 28 : 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Enhanced icon
                      Container(
                        padding: EdgeInsets.all(isPhone ? 20 : 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.successColor.withOpacity(0.1),
                              AppTheme.successColor.withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: isPhone ? 72 : 88,
                          color: AppTheme.successColor,
                        ),
                      ),

                      SizedBox(height: isPhone ? 32 : 40),

                      Text(
                        widget.form.title,
                        style: TextStyle(
                          fontSize: isPhone ? 24 : 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isPhone ? 20 : 24),

                      Text(
                        'Already Submitted',
                        style: TextStyle(
                          fontSize: isPhone ? 20 : 24,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isPhone ? 16 : 20),

                      // FIXED: Better text wrapping and constraints
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isPhone
                              ? constraints.maxWidth -
                                  96 // Account for padding and margins
                              : (isTablet ? 400.0 : 450.0),
                        ),
                        child: Text(
                          'You have already completed this checklist for the current period.',
                          style: TextStyle(
                            fontSize: isPhone ? 16 : 18,
                            color: AppTheme.textSecondaryColor,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),

                      SizedBox(height: isPhone ? 32 : 40),

                      // Enhanced info card - FIXED OVERFLOW
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isPhone ? 20 : 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.infoColor.withOpacity(0.08),
                              AppTheme.infoColor.withOpacity(0.12),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(isPhone ? 16 : 20),
                          border: Border.all(
                            color: AppTheme.infoColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isPhone ? 10 : 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.infoColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.info_rounded,
                                    color: AppTheme.infoColor,
                                    size: isPhone ? 20 : 24,
                                  ),
                                ),
                                SizedBox(width: isPhone ? 12 : 16),
                                Expanded(
                                  child: Text(
                                    'Each user can only submit once during the specified time period.',
                                    style: TextStyle(
                                      fontSize: isPhone ? 14 : 16,
                                      color: AppTheme.infoColor,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isPhone ? 40 : 48),

                      // Enhanced back button
                      Container(
                        width: double.infinity,
                        height: isPhone ? 52 : 60,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(isPhone ? 14 : 16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: isPhone ? 20 : 24,
                          ),
                          label: Text(
                            'Go Back',
                            style: TextStyle(
                              fontSize: isPhone ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(isPhone ? 14 : 16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
      default:
        return Icons.input;
    }
  }

// Updated PDF download method using the new web service
  void _downloadPdf() async {
    try {
      debugPrint('Starting PDF generation for web');

      if (_formResponseData == null) {
        throw Exception('No form response data available');
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Generating PDF...'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Use the web PDF service to generate and download PDF
      final webPdfService = WebPdfService();
      await webPdfService.generateAndDownloadPdf(
          widget.form, _formResponseData!);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF download started successfully!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating/downloading PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

// Enhanced success screen with better responsive design
  Widget _buildSubmissionSuccessScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
        final maxWidth = isPhone ? double.infinity : (isTablet ? 650.0 : 750.0);

        return Container(
          color: Colors.grey.shade50,
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                margin: EdgeInsets.all(isPhone ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isPhone ? 20 : 28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: isPhone ? 20 : 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(isPhone ? 28 : 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Enhanced success animation
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: EdgeInsets.all(isPhone ? 24 : 32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.successColor.withOpacity(0.1),
                                    AppTheme.successColor.withOpacity(0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.successColor.withOpacity(0.3),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: isPhone ? 80 : 100,
                                color: AppTheme.successColor,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isPhone ? 32 : 40),

                      // Enhanced title
                      Text(
                        'Form Submitted Successfully!',
                        style: TextStyle(
                          fontSize: isPhone ? 26 : 32,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isPhone ? 16 : 20),

                      Text(
                        widget.form.title,
                        style: TextStyle(
                          fontSize: isPhone ? 18 : 22,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isPhone ? 12 : 16),

                      Container(
                        constraints: BoxConstraints(
                          maxWidth: isPhone ? double.infinity : 400,
                        ),
                        child: Text(
                          'Your response has been recorded successfully.',
                          style: TextStyle(
                            fontSize: isPhone ? 16 : 18,
                            color: AppTheme.textSecondaryColor,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: isPhone ? 40 : 48),

                      // Enhanced PDF download section
                      Container(
                        padding: EdgeInsets.all(isPhone ? 24 : 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.06),
                              Colors.blue.withOpacity(0.12),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(isPhone ? 18 : 22),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isPhone ? 14 : 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.withOpacity(0.1),
                                        Colors.blue.withOpacity(0.2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.blue.shade600,
                                    size: isPhone ? 28 : 32,
                                  ),
                                ),
                                SizedBox(width: isPhone ? 16 : 20),
                                Expanded(
                                  child: Text(
                                    'Download Your Submission',
                                    style: TextStyle(
                                      fontSize: isPhone ? 18 : 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade700,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isPhone ? 16 : 20),
                            Text(
                              'Get a beautifully formatted PDF copy of your form submission with all responses and images.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isPhone ? 14 : 16,
                                color: AppTheme.textSecondaryColor,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: isPhone ? 24 : 28),
                            Container(
                              width: double.infinity,
                              height: isPhone ? 52 : 60,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(isPhone ? 14 : 16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                icon: Icon(
                                  Icons.download_rounded,
                                  color: Colors.white,
                                  size: isPhone ? 20 : 24,
                                ),
                                label: Text(
                                  'Download PDF',
                                  style: TextStyle(
                                    fontSize: isPhone ? 16 : 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        isPhone ? 14 : 16),
                                  ),
                                ),
                                onPressed: _downloadPdf,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isPhone ? 32 : 40),

                      // Enhanced summary card
                      Container(
                        padding: EdgeInsets.all(isPhone ? 20 : 24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius:
                              BorderRadius.circular(isPhone ? 16 : 20),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Submission Summary',
                              style: TextStyle(
                                fontSize: isPhone ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            SizedBox(height: isPhone ? 16 : 20),
                            _buildSummaryRow(
                              'Fields Completed:',
                              '${_responses.length} of ${widget.form.fields.length}',
                              isPhone,
                            ),
                            SizedBox(height: isPhone ? 12 : 16),
                            _buildSummaryRow(
                              'Submitted At:',
                              _formResponseData != null
                                  ? '${_formResponseData!.submitted_at.day}/${_formResponseData!.submitted_at.month}/${_formResponseData!.submitted_at.year} ${_formResponseData!.submitted_at.hour}:${_formResponseData!.submitted_at.minute.toString().padLeft(2, '0')}'
                                  : 'Now',
                              isPhone,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isPhone ? 40 : 48),

                      // Enhanced return button
                      Container(
                        width: double.infinity,
                        height: isPhone ? 52 : 60,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(isPhone ? 14 : 16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: isPhone ? 20 : 24,
                          ),
                          label: Text(
                            'Return to Forms',
                            style: TextStyle(
                              fontSize: isPhone ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(isPhone ? 14 : 16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isPhone) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isPhone ? 14 : 15,
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isPhone ? 14 : 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

// Updated build method - REGULAR FORMS NOW MATCH CHECKLIST STYLE
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1200;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.form.isChecklist ? 'Complete Checklist' : 'Fill Form',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isPhone ? 18 : 20,
              ),
            ),
            elevation: 0,
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_isSessionActive && widget.form.isChecklist)
                Padding(
                  padding: EdgeInsets.only(right: isPhone ? 8 : 12),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                      ),
                    ),
                    onPressed: _isSubmitting ? null : () => _submitForm(),
                    tooltip: 'Submit Checklist',
                  ),
                ),
            ],
          ),
          body: _isLoading || _isSubmitting
              ? Container(
                  color: Colors.grey.shade50,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isPhone ? 20 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(height: isPhone ? 24 : 32),
                        Text(
                          _isSubmitting
                              ? 'Submitting form...'
                              : 'Loading form...',
                          style: TextStyle(
                            fontSize: isPhone ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _formSubmitted
                  ? _buildSubmissionSuccessScreen()
                  : _hasAlreadySubmitted
                      ? _buildAlreadySubmittedScreen()
                      : widget.form.isChecklist && !_isSessionActive
                          ? Container(
                              color: Colors.grey.shade50,
                              child: _buildSessionStartScreen(),
                            )
                          : widget.form.isChecklist && _isSessionActive
                              ? _buildChecklistActiveSession()
                              : _buildRegularFormWithChecklistStyle(), // NEW METHOD
        );
      },
    );
  }

// NEW METHOD: Regular form with checklist-style layout
  Widget _buildRegularFormWithChecklistStyle() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1200;

        return Column(
          children: [
            // Progress indicator (like checklist)
            Container(
              margin: EdgeInsets.all(isPhone ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isPhone ? 16 : 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isPhone ? 8 : 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.1),
                                AppTheme.primaryColor.withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.description_rounded,
                            color: AppTheme.primaryColor,
                            size: isPhone ? 20 : 24,
                          ),
                        ),
                        SizedBox(width: isPhone ? 12 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Form Progress: ${_responses.length} of ${widget.form.fields.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                  fontSize: isPhone ? 15 : 16,
                                ),
                              ),
                              SizedBox(height: isPhone ? 4 : 6),
                              Text(
                                'Fill all fields to submit',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: isPhone ? 12 : 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isPhone ? 12 : 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: widget.form.fields.isEmpty
                              ? 0
                              : _responses.length / widget.form.fields.length,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                          minHeight: isPhone ? 10 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form content (matching checklist style)
            Expanded(
              child: Container(
                color: Colors.grey.shade50,
                child: FormBuilder(
                  key: _formKey,
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.all(isPhone ? 12 : 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Enhanced form header card (matching checklist)
                            Container(
                              margin:
                                  EdgeInsets.only(bottom: isPhone ? 16 : 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(isPhone ? 16 : 20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isPhone ? 20 : 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                              EdgeInsets.all(isPhone ? 12 : 14),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primaryColor
                                                    .withOpacity(0.1),
                                                AppTheme.primaryColor
                                                    .withOpacity(0.2),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.description_rounded,
                                            color: AppTheme.primaryColor,
                                            size: isPhone ? 24 : 28,
                                          ),
                                        ),
                                        SizedBox(width: isPhone ? 16 : 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.form.title,
                                                style: TextStyle(
                                                  fontSize: isPhone ? 20 : 24,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppTheme.textPrimaryColor,
                                                  height: 1.2,
                                                ),
                                              ),
                                              if (widget.form.description
                                                  .isNotEmpty) ...[
                                                SizedBox(
                                                    height: isPhone ? 6 : 8),
                                                Text(
                                                  widget.form.description,
                                                  style: TextStyle(
                                                    fontSize: isPhone ? 15 : 16,
                                                    color: AppTheme
                                                        .textSecondaryColor,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Form fields (same as checklist)
                            ...widget.form.fields
                                .map((field) => _buildFieldEntry(field)),

                            // Enhanced submit button (matching checklist style)
                            Container(
                              margin: EdgeInsets.only(
                                top: isPhone ? 20 : 24,
                                bottom: isPhone ? 24 : 32,
                              ),
                              height: isPhone ? 56 : 64,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(isPhone ? 16 : 20),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                icon: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.send_rounded,
                                    size: isPhone ? 24 : 28,
                                    color: Colors.white,
                                  ),
                                ),
                                label: Text(
                                  'Submit Form',
                                  style: TextStyle(
                                    fontSize: isPhone ? 17 : 19,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        isPhone ? 16 : 20),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isPhone ? 24 : 32,
                                    vertical: isPhone ? 16 : 20,
                                  ),
                                ),
                                onPressed: () => _submitForm(),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Updated responsive helper method
  double _getResponsiveValue(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return mobile;
    if (width < 1200) return tablet;
    return desktop;
  }

// Updated responsive padding method
  EdgeInsets _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return const EdgeInsets.all(16);
    if (width < 900) return const EdgeInsets.all(24);
    return const EdgeInsets.all(32);
  }
}
