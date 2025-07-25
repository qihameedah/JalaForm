// lib/services/supabase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jala_form/models/form_permission.dart';
import 'package:jala_form/models/group_member.dart';
import 'package:jala_form/models/user_group.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/custom_form.dart';
import '../models/form_response.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient _client;
  static bool _initialized = false;
  RealtimeChannel? _formsChannel;
  RealtimeChannel? _formPermissionsChannel;
  // Stream controllers for real-time updates
  final StreamController<List<CustomForm>> _formsStreamController =
      StreamController<List<CustomForm>>.broadcast();
  final StreamController<List<CustomForm>> _availableFormsStreamController =
      StreamController<List<CustomForm>>.broadcast();

  // Getters for the streams
  Stream<List<CustomForm>> get formsStream => _formsStreamController.stream;
  Stream<List<CustomForm>> get availableFormsStream =>
      _availableFormsStreamController.stream;

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal() {
    if (_initialized) {
      _client = Supabase.instance.client;
    } else {
      throw Exception(
          'SupabaseService not initialized. Call initialize() first.');
    }
  }

  // Add a getter to safely access the client
  SupabaseClient get client => _client;

  // Initialize Supabase with improved error handling and connection management
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Add a small delay to ensure network is properly initialized
      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize with timeout
      await Supabase.initialize(
        url: 'https://nacwvaycdmltjkmkbwsp.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hY3d2YXljZG1sdGprbWtid3NwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwOTk5NjcsImV4cCI6MjA2NDY3NTk2N30.8_FXXHehG2zgDY7mS7vXz5FMeVIK9baohMIzvKO7o6g',
        // Enable debug logging in debug mode
        debug: kDebugMode,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException(
              'Supabase initialization timed out. Please check your internet connection.');
        },
      );

      _initialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _withRetry(() => _client.rpc('list_all_users'));
      return _ensureListOfMaps(response);
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  // Initialize real-time subscriptions
  Future<void> initializeRealTimeSubscriptions() async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      // Subscribe to forms table changes
      _formsChannel = _client
          .channel('forms_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'forms',
            callback: (payload) {
              debugPrint('Forms table changed: ${payload.eventType}');
              _handleFormsChange(payload);
            },
          )
          .subscribe();

      // Subscribe to form_permissions table changes
      _formPermissionsChannel = _client
          .channel('form_permissions_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'form_permissions',
            callback: (payload) {
              debugPrint('Form permissions changed: ${payload.eventType}');
              _handleFormPermissionsChange(payload);
            },
          )
          .subscribe();

      debugPrint('Real-time subscriptions initialized successfully');
    } catch (e) {
      debugPrint('Error initializing real-time subscriptions: $e');
    }
  }

  // Handle forms table changes
  void _handleFormsChange(PostgresChangePayload payload) async {
    try {
      // Reload all forms and emit to streams
      await _refreshFormsStreams();
    } catch (e) {
      debugPrint('Error handling forms change: $e');
    }
  }

  // Handle form permissions changes
  void _handleFormPermissionsChange(PostgresChangePayload payload) async {
    try {
      // Reload available forms since permissions affect what forms are visible
      await _refreshAvailableFormsStream();
    } catch (e) {
      debugPrint('Error handling form permissions change: $e');
    }
  }

  // Refresh forms streams
  Future<void> _refreshFormsStreams() async {
    try {
      // Get all forms (for MyFormsScreen)
      final allForms = await getForms();
      _formsStreamController.add(allForms);

      // Get available forms (for AvailableFormsScreen)
      final availableForms = await getAvailableForms();
      _availableFormsStreamController.add(availableForms);
    } catch (e) {
      debugPrint('Error refreshing forms streams: $e');
    }
  }

  // Refresh only available forms stream
  Future<void> _refreshAvailableFormsStream() async {
    try {
      final availableForms = await getAvailableForms();
      _availableFormsStreamController.add(availableForms);
    } catch (e) {
      debugPrint('Error refreshing available forms stream: $e');
    }
  }

  // Method to manually trigger forms refresh
  Future<void> refreshForms() async {
    await _refreshFormsStreams();
  }

  // Clean up subscriptions
  Future<void> disposeRealTime() async {
    try {
      await _formsChannel?.unsubscribe();
      await _formPermissionsChannel?.unsubscribe();
      await _formsStreamController.close();
      await _availableFormsStreamController.close();
      debugPrint('Real-time subscriptions disposed');
    } catch (e) {
      debugPrint('Error disposing real-time subscriptions: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _withRetry(() => _client
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .single());
      return _ensureMap(response);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

// Helper method to calculate the current recurrence period boundaries
  Map<String, DateTime> _getCurrentRecurrencePeriod(CustomForm form) {
    final now = DateTime.now();
    DateTime periodStart;
    DateTime periodEnd;

    switch (form.recurrenceType) {
      case RecurrenceType.daily:
        // For daily recurrence, period is the current day
        periodStart = DateTime(now.year, now.month, now.day);
        periodEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;

      case RecurrenceType.weekly:
        // For weekly recurrence, period is the current week (Monday to Sunday)
        final daysFromMonday = now.weekday - 1;
        periodStart = DateTime(now.year, now.month, now.day - daysFromMonday);
        periodEnd = DateTime(
            now.year, now.month, now.day - daysFromMonday + 6, 23, 59, 59, 999);
        break;

      case RecurrenceType.monthly:
        // For monthly recurrence, period is the current month
        periodStart = DateTime(now.year, now.month, 1);
        periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        break;

      case RecurrenceType.yearly:
        // For yearly recurrence, period is the current year
        periodStart = DateTime(now.year, 1, 1);
        periodEnd = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;

      case null:
      default:
        // For non-recurring forms or unknown types, use the entire form date range
        periodStart = form.startDate ?? DateTime(now.year, now.month, now.day);
        periodEnd = form.endDate ??
            DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
    }

    return {
      'start': periodStart,
      'end': periodEnd,
    };
  }

// Updated method to check if user has submitted in current recurrence period
  Future<bool> hasUserSubmittedInCurrentPeriod(
      String formId, String userId) async {
    try {
      // Get the form to check its recurrence settings
      final form = await getFormById(formId);

      // Get the current recurrence period boundaries
      final period = _getCurrentRecurrencePeriod(form);

      // Query for submissions within the current period
      final query = _client
          .from('form_responses')
          .select('id')
          .eq('form_id', formId)
          .eq('respondent_id', userId)
          .gte('submitted_at', period['start']!.toIso8601String())
          .lte('submitted_at', period['end']!.toIso8601String());

      final response = await _withRetry(() => query);

      // Return true if user has already submitted in this period
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking user submission in current period: $e');
      return false;
    }
  }

// Updated method for counting submissions in current period
  Future<int> checkUserFormSubmissionInCurrentPeriod(
      String formId, String userId) async {
    try {
      // Get the form to check its recurrence settings
      final form = await getFormById(formId);

      // Get the current recurrence period boundaries
      final period = _getCurrentRecurrencePeriod(form);

      // Query for submissions within the current period
      final query = _client
          .from('form_responses')
          .select('id')
          .eq('form_id', formId)
          .eq('respondent_id', userId)
          .gte('submitted_at', period['start']!.toIso8601String())
          .lte('submitted_at', period['end']!.toIso8601String());

      final response = await _withRetry(() => query);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error checking user form submission in current period: $e');
      return 0;
    }
  }

// New method to check if form is available for current recurrence period
  bool isFormAvailableForCurrentPeriod(CustomForm form) {
    final now = DateTime.now();

    // Check if form is within its overall date range
    if (form.startDate != null && now.isBefore(form.startDate!)) {
      return false;
    }
    if (form.endDate != null && now.isAfter(form.endDate!)) {
      return false;
    }

    // For recurring forms, check if we're in a valid recurrence period
    if (form.isRecurring && form.recurrenceType != null) {
      // For daily recurrence, check time window
      if (form.recurrenceType == RecurrenceType.daily) {
        if (form.startTime != null && form.endTime != null) {
          final currentTime = TimeOfDay.fromDateTime(now);
          final currentMinutes = currentTime.hour * 60 + currentTime.minute;
          final startMinutes =
              form.startTime!.hour * 60 + form.startTime!.minute;
          final endMinutes = form.endTime!.hour * 60 + form.endTime!.minute;

          return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
        }
      }

      // For weekly recurrence, check if today is in allowed days
      if (form.recurrenceType == RecurrenceType.weekly) {
        // You can add specific weekday checking here if needed
        // For now, assume all days in the week are valid
        return true;
      }

      // For monthly recurrence, check if today is valid
      if (form.recurrenceType == RecurrenceType.monthly) {
        // You can add specific day-of-month checking here if needed
        return true;
      }
    }

    return true;
  }

// New method to get the period description for user display
  String getRecurrencePeriodDescription(CustomForm form) {
    final period = _getCurrentRecurrencePeriod(form);
    final now = DateTime.now();

    switch (form.recurrenceType) {
      case RecurrenceType.daily:
        return 'Today (${_formatDate(now)})';
      case RecurrenceType.weekly:
        return 'This Week (${_formatDate(period['start']!)} - ${_formatDate(period['end']!)})';
      case RecurrenceType.monthly:
        return 'This Month (${_getMonthName(now.month)} ${now.year})';
      case RecurrenceType.yearly:
        return 'This Year (${now.year})';
      default:
        return 'Current Period';
    }
  }

// Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

// Helper method to get month name
  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

// Updated method to clean old draft responses (keep only current period)
  Future<void> cleanOldDraftResponses(String formId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      final form = await getFormById(formId);
      final period = _getCurrentRecurrencePeriod(form);

      // Delete draft responses that are older than current period
      await _withRetry(() => _client
          .from('form_drafts')
          .delete()
          .eq('form_id', formId)
          .eq('user_id', user.id)
          .lt('updated_at', period['start']!.toIso8601String()));
    } catch (e) {
      debugPrint('Error cleaning old draft responses: $e');
    }
  }

// Updated method to get draft response for current period only
  Future<Map<String, dynamic>?> getDraftResponseForCurrentPeriod(
      String formId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final form = await getFormById(formId);
      final period = _getCurrentRecurrencePeriod(form);

      final response = await _withRetry(() => _client
          .from('form_drafts')
          .select()
          .eq('form_id', formId)
          .eq('user_id', user.id)
          .gte('updated_at', period['start']!.toIso8601String())
          .lte('updated_at', period['end']!.toIso8601String())
          .order('updated_at', ascending: false)
          .limit(1));

      if (response.isNotEmpty) {
        return response[0]['data'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting draft response for current period: $e');
      return null;
    }
  }

  Future<void> createUserProfile(String userId, String username) async {
    try {
      await _withRetry(() => _client.from('user_profiles').insert({
            'user_id': userId,
            'username': username,
            'created_at': DateTime.now().toIso8601String(),
          }));
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _withRetry(() =>
          _client.from('user_profiles').update(data).eq('user_id', userId));
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<bool> hasUserSubmittedForm(String formId, String userId) async {
    try {
      final form = await getFormById(formId);

      var query = _client
          .from('form_responses')
          .select('id')
          .eq('form_id', formId)
          .eq('respondent_id', userId);

      if (form.startDate != null) {
        query = query.gte('submitted_at', form.startDate!.toIso8601String());
      }

      if (form.endDate != null) {
        final adjustedEndDate = form.endDate!.add(const Duration(days: 1));
        query = query.lt('submitted_at', adjustedEndDate.toIso8601String());
      }

      final response = await _withRetry(() => query);
      final responseList = _ensureListOfMaps(response);
      return responseList.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking user form submission: $e');
      return false;
    }
  }

  Future<int> checkUserFormSubmission(String formId, String userId,
      DateTime? startDate, DateTime? endDate) async {
    try {
      // Start building the query - use only one argument in select()
      var query = _client
          .from('form_responses')
          .select('id') // Just select one field, without the count option
          .eq('form_id', formId)
          .eq('respondent_id', userId);

      // Add date range if specified
      if (startDate != null) {
        query = query.gte('submitted_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        // Add one day to end date to include the entire end day
        final adjustedEndDate = endDate.add(const Duration(days: 1));
        query = query.lt('submitted_at', adjustedEndDate.toIso8601String());
      }

      final response = await _withRetry(() => query);

      // Count the results manually since the count property isn't available
      return (response as List).length;
    } catch (e) {
      debugPrint('Error checking user form submission: $e');
      return 0;
    }
  }

  // User Authentication with retry logic
  Future<User?> signUp(String email, String password, String username) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // Store username in auth metadata
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              'Sign up timed out. Please check your internet connection.');
        },
      );

      // If user was created successfully, create a profile
      if (response.user != null) {
        try {
          await createUserProfile(response.user!.id, username);
        } catch (e) {
          debugPrint('Error creating user profile: $e');
          // Continue anyway, as the auth part worked
        }
      }

      return response.user;
    } catch (e) {
      debugPrint('Error during sign up: $e');
      rethrow;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final response = await _client.auth
          .signInWithPassword(
        email: email,
        password: password,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              'Sign in timed out. Please check your internet connection.');
        },
      );

      // Enhanced session persistence
      await _saveSession(response.session);

      return response.user;
    } catch (e) {
      debugPrint('Error during sign in: $e');

      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('connection failed') ||
          e is TimeoutException) {
        throw Exception(
            'Cannot connect to the server. Please check your internet connection and try again.');
      }

      rethrow;
    }
  }

  Future<void> _saveSession(Session? session) async {
    if (session != null) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Save access token
        if (session.accessToken != null) {
          await prefs.setString('access_token', session.accessToken!);
        }

        // Save refresh token
        if (session.refreshToken != null) {
          await prefs.setString('refresh_token', session.refreshToken!);
        }

        // Save expiry info for better session management
        if (session.expiresAt != null) {
          await prefs.setInt('expires_at', session.expiresAt!);
        }

        // For debugging
        debugPrint('Session saved successfully');
      } catch (e) {
        debugPrint('Error saving session: $e');
      }
    }
  }

  // ignore: unused_element
// Improved session restoration

  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');
      final expiresAt = prefs.getInt('expires_at');

      if (accessToken == null) {
        return false;
      }

      // Check if token is expired
      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now >= expiresAt) {
          // Token expired, try refresh flow
          try {
            final response = await _client.auth.refreshSession();
            await _saveSession(response.session);
            return response.user != null;
          } catch (e) {
            debugPrint('Error refreshing session: $e');
            await clearSession();
            return false;
          }
        }
      }

      // Set the existing session
      try {
        await _client.auth.setSession(accessToken);
        return _client.auth.currentUser != null;
      } catch (e) {
        debugPrint('Error restoring session: $e');
        await clearSession();
        return false;
      }
    } catch (e) {
      debugPrint('Error in session restoration: $e');
      return false;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('expires_at');
    await prefs.remove('savedEmail');
    await prefs.remove('savedPassword');
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      try {
        await _client.auth.setSession(accessToken);
      } catch (e) {
        debugPrint('Error loading session: $e');
        // Clear token if invalid
        await prefs.remove('access_token');
      }
    }
  }

  Future<void> signOut() async {
    try {
      await disposeRealTime(); // ADD THIS LINE
      await _client.auth.signOut();
      await clearSession();
    } catch (e) {
      debugPrint('Error during sign out: $e');
      rethrow;
    }
  }

  User? getCurrentUser() {
    try {
      return _client.auth.currentUser;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Get username from user profile or metadata
  Future<String> getUsername(String userId) async {
    try {
      // First try to get from user profile table
      final profile = await getUserProfile(userId);
      if (profile != null && profile['username'] != null) {
        return profile['username'];
      }

      // If not found, try to get from auth metadata
      final user = _client.auth.currentUser;
      if (user != null &&
          user.userMetadata != null &&
          user.userMetadata!['username'] != null) {
        return user.userMetadata!['username'];
      }

      // If still not found, return email or default
      if (user != null && user.email != null) {
        return user.email!.split('@')[0]; // Use part before @ as username
      }

      return 'User';
    } catch (e) {
      debugPrint('Error getting username: $e');
      return 'User';
    }
  }

  // Update user password
  Future<void> updatePassword(String oldPassword, String newPassword) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not logged in or email not available');
      }

      // Verify current password first by signing in
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: oldPassword,
      );

      // Update password
      await _client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } catch (e) {
      debugPrint('Error updating password: $e');
      rethrow;
    }
  }

  Future<String> createForm(CustomForm form) async {
    try {
      final response = await _withRetry(
          () => _client.from('forms').insert(form.toJson()).select());
      final responseList = _ensureListOfMaps(response);
      if (responseList.isNotEmpty) {
        return responseList[0]['id']?.toString() ?? '';
      }
      throw Exception('No form ID returned from creation');
    } catch (e) {
      debugPrint('Error creating form: $e');
      rethrow;
    }
  }

  Future<List<CustomForm>> getForms() async {
    try {
      final response = await _withRetry(() => _client.from('forms').select());
      final responseList = _ensureListOfMaps(response);

      return responseList.map<CustomForm>((json) {
        try {
          return CustomForm.fromJson(json);
        } catch (e) {
          debugPrint('Error parsing form JSON: $e, JSON: $json');
          rethrow;
        }
      }).toList();
    } catch (e) {
      debugPrint('Error getting forms: $e');
      return [];
    }
  }

  Future<CustomForm> getFormById(String formId) async {
    try {
      final response = await _withRetry(
          () => _client.from('forms').select().eq('id', formId).single());
      final responseMap = _ensureMap(response);
      return CustomForm.fromJson(responseMap);
    } catch (e) {
      debugPrint('Error getting form by ID: $e');
      rethrow;
    }
  }

  Future<void> updateForm(CustomForm form) async {
    try {
      await _withRetry(
          () => _client.from('forms').update(form.toJson()).eq('id', form.id));
    } catch (e) {
      debugPrint('Error updating form: $e');
      rethrow;
    }
  }

  Future<void> deleteForm(String formId) async {
    try {
      await _withRetry(() => _client.from('forms').delete().eq('id', formId));
    } catch (e) {
      debugPrint('Error deleting form: $e');
      rethrow;
    }
  }

  Future<String?> saveDraftResponse(
      String formId, Map<String, dynamic> data) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Check if draft already exists
      final existingDrafts = await _withRetry(() => _client
          .from('form_drafts')
          .select()
          .eq('form_id', formId)
          .eq('user_id', user.id));

      final existingDraftsList = _ensureListOfMaps(existingDrafts);

      if (existingDraftsList.isNotEmpty) {
        // Update existing draft
        final draftId = existingDraftsList[0]['id']?.toString();
        if (draftId != null) {
          await _withRetry(() => _client.from('form_drafts').update({
                'data': data,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', draftId));
          return draftId;
        }
      }

      // Create new draft
      final response =
          await _withRetry(() => _client.from('form_drafts').insert({
                'form_id': formId,
                'user_id': user.id,
                'data': data,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              }).select());

      final responseList = _ensureListOfMaps(response);
      if (responseList.isNotEmpty) {
        return responseList[0]['id']?.toString();
      }

      return null;
    } catch (e) {
      debugPrint('Error saving draft response: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDraftResponse(String formId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final response = await _withRetry(() => _client
          .from('form_drafts')
          .select()
          .eq('form_id', formId)
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(1));

      final responseList = _ensureListOfMaps(response);
      if (responseList.isNotEmpty) {
        final data = responseList[0]['data'];
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting draft response: $e');
      return null;
    }
  }

  Future<void> deleteDraftResponse(String formId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      await _withRetry(() => _client
          .from('form_drafts')
          .delete()
          .eq('form_id', formId)
          .eq('user_id', user.id));
    } catch (e) {
      debugPrint('Error deleting draft response: $e');
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      // First, delete all members associated with this group
      await _withRetry(
          () => _client.from('group_members').delete().eq('group_id', groupId));

      // Next, delete any form permissions associated with this group
      await _withRetry(() =>
          _client.from('form_permissions').delete().eq('group_id', groupId));

      // Finally, delete the group itself
      await _withRetry(
          () => _client.from('user_groups').delete().eq('id', groupId));
    } catch (e) {
      debugPrint('Error deleting group: $e');
      rethrow;
    }
  }

  Future<String> submitFormResponse(FormResponse response) async {
    try {
      final result = await _withRetry(() =>
          _client.from('form_responses').insert(response.toJson()).select());
      final resultList = _ensureListOfMaps(result);

      if (resultList.isNotEmpty) {
        // Delete any draft after successful submission
        if (response.form_id != null && response.respondent_id != null) {
          await deleteDraftResponse(response.form_id);
        }
        return resultList[0]['id']?.toString() ?? '';
      }

      throw Exception('No response ID returned from submission');
    } catch (e) {
      debugPrint('Error submitting form response: $e');
      rethrow;
    }
  }

  Future<List<FormResponse>> getFormResponses(String formId) async {
    try {
      final response = await _withRetry(
          () => _client.from('form_responses').select().eq('form_id', formId));
      final responseList = _ensureListOfMaps(response);

      return responseList.map<FormResponse>((json) {
        try {
          return FormResponse.fromJson(json);
        } catch (e) {
          debugPrint('Error parsing form response JSON: $e, JSON: $json');
          rethrow;
        }
      }).toList();
    } catch (e) {
      debugPrint('Error getting form responses: $e');
      return [];
    }
  }

  // Image Upload with error handling
  Future<String> uploadImage(
      String bucketName, String path, Uint8List bytes) async {
    try {
      final response = await _withRetry(
          () => _client.storage.from(bucketName).uploadBinary(path, bytes));
      return response;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<String> getImageUrl(String bucketName, String path) async {
    try {
      return _client.storage.from(bucketName).getPublicUrl(path);
    } catch (e) {
      debugPrint('Error getting image URL: $e');
      rethrow;
    }
  }

  // Helper method for retry logic
  Future<T> _withRetry<T>(Future<T> Function() operation,
      {int maxRetries = 3}) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException(
                'Operation timed out. Please check your internet connection.');
          },
        );
      } catch (e) {
        // Don't retry on auth errors, invalid requests, etc.
        if (!_isRetryableError(e) || attempts >= maxRetries) {
          rethrow;
        }

        // Exponential backoff
        final delay = Duration(milliseconds: 1000 * attempts);
        debugPrint(
            'Retrying operation after $delay (attempt $attempts/$maxRetries)');
        await Future.delayed(delay);
      }
    }
  }

  // Determine if an error should trigger a retry
  bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('host lookup') ||
        error is TimeoutException;
  }

  // Check if we're currently connected to Supabase
  Future<bool> checkConnection() async {
    try {
      // Simple ping-like operation
      await _client
          .from('forms')
          .select('id')
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      debugPrint('Connection check failed: $e');
      return false;
    }
  }

  // User Groups Methods
  Future<String> createUserGroup(UserGroup group) async {
    try {
      final response = await _withRetry(
          () => _client.from('user_groups').insert(group.toJson()).select());
      return response[0]['id'];
    } catch (e) {
      debugPrint('Error creating user group: $e');
      rethrow;
    }
  }

  Future<List<UserGroup>> getUserGroups() async {
    try {
      final response = await _withRetry(() => _client
          .from('user_groups')
          .select('*, group_members!inner(user_id)')
          .eq('group_members.user_id', _client.auth.currentUser!.id));
      return response
          .map<UserGroup>((json) => UserGroup.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting user groups: $e');
      return [];
    }
  }

  Future<List<UserGroup>> getMyCreatedGroups() async {
    try {
      final response = await _withRetry(() => _client
          .from('user_groups')
          .select()
          .eq('created_by', _client.auth.currentUser!.id));
      return response
          .map<UserGroup>((json) => UserGroup.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting created groups: $e');
      return [];
    }
  }

  Future<void> addGroupMember(GroupMember member) async {
    try {
      await _withRetry(
          () => _client.from('group_members').insert(member.toJson()));
    } catch (e) {
      debugPrint('Error adding group member: $e');
      rethrow;
    }
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    try {
      await _withRetry(() => _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId));
    } catch (e) {
      debugPrint('Error removing group member: $e');
      rethrow;
    }
  }

// Updated getGroupMembers method in SupabaseService
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      // Call the custom RPC function instead of the problematic join
      final response = await _withRetry(() => _client
          .rpc('get_group_members', params: {'group_id_param': groupId}));

      return response.map<GroupMember>((json) {
        return GroupMember(
          group_id: json['group_id'],
          user_id: json['user_id'],
          added_by: json['added_by'],
          added_at: DateTime.parse(json['added_at']),
          user_email: json['email'],
          user_name: json['username'],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting group members: $e');
      return [];
    }
  }

  // Form Permissions Methods
  Future<void> addFormPermission(FormPermission permission) async {
    try {
      await _withRetry(
          () => _client.from('form_permissions').insert(permission.toJson()));
    } catch (e) {
      debugPrint('Error adding form permission: $e');
      rethrow;
    }
  }

  Future<void> removeFormPermission(String formId,
      {String? userId, String? groupId}) async {
    try {
      var query =
          _client.from('form_permissions').delete().eq('form_id', formId);

      if (userId != null) {
        query = query.eq('user_id', userId);
      } else if (groupId != null) {
        query = query.eq('group_id', groupId);
      }

      await _withRetry(() => query);
    } catch (e) {
      debugPrint('Error removing form permission: $e');
      rethrow;
    }
  }

  Future<List<FormPermission>> getFormPermissions(String formId) async {
    try {
      // First get the permissions
      final permissionsResponse = await _withRetry(() =>
          _client.from('form_permissions').select().eq('form_id', formId));

      // Then fetch user and group details separately
      List<FormPermission> permissions = [];

      for (var perm in permissionsResponse) {
        String? userEmail;
        String? groupName;

        // If there's a user_id, fetch the user's email
        if (perm['user_id'] != null) {
          try {
            final userResponse = await _withRetry(() => _client
                .from('user_profiles')
                .select('user_id, email:user_id(email)')
                .eq('user_id', perm['user_id'])
                .single());

            // If user_profiles doesn't have email, try auth.users via RPC
            if (userResponse['email'] == null) {
              final usersList = await getAllUsers();
              final user = usersList.firstWhere(
                (u) => u['id'] == perm['user_id'],
                orElse: () => {'email': null},
              );
              userEmail = user['email'];
            } else {
              userEmail = userResponse['email']['email'];
            }
          } catch (e) {
            debugPrint('Error fetching user email: $e');
            // Try to get from getAllUsers as fallback
            try {
              final usersList = await getAllUsers();
              final user = usersList.firstWhere(
                (u) => u['id'] == perm['user_id'],
                orElse: () => {'email': null},
              );
              userEmail = user['email'];
            } catch (e2) {
              debugPrint('Fallback error fetching user email: $e2');
            }
          }
        }

        // If there's a group_id, fetch the group name
        if (perm['group_id'] != null) {
          try {
            final groupResponse = await _withRetry(() => _client
                .from('user_groups')
                .select('name')
                .eq('id', perm['group_id'])
                .single());
            groupName = groupResponse['name'];
          } catch (e) {
            debugPrint('Error fetching group name: $e');
          }
        }

        permissions.add(FormPermission(
          id: perm['id'],
          form_id: perm['form_id'],
          user_id: perm['user_id'],
          group_id: perm['group_id'],
          created_at: DateTime.parse(perm['created_at']),
          user_email: userEmail,
          group_name: groupName,
        ));
      }

      return permissions;
    } catch (e) {
      debugPrint('Error getting form permissions: $e');
      return [];
    }
  }

// Add these helper methods after the existing constructor and before getAllUsers()
  List<Map<String, dynamic>> _ensureListOfMaps(dynamic response) {
    if (response == null) return [];

    if (response is List) {
      return response.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else if (item is Map) {
          return Map<String, dynamic>.from(item);
        } else {
          debugPrint(
              'Warning: Unexpected item type in list: ${item.runtimeType}');
          return <String, dynamic>{};
        }
      }).toList();
    }

    debugPrint('Warning: Expected List but got ${response.runtimeType}');
    return [];
  }

  Map<String, dynamic> _ensureMap(dynamic response) {
    if (response == null) return {};

    if (response is Map<String, dynamic>) {
      return response;
    } else if (response is Map) {
      return Map<String, dynamic>.from(response);
    } else {
      debugPrint('Warning: Expected Map but got ${response.runtimeType}');
      return {};
    }
  }

  Future<List<CustomForm>> getAvailableForms() async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      final response =
          await _withRetry(() => _client.rpc('get_available_forms'));
      final responseList = _ensureListOfMaps(response);

      final forms = responseList.map<CustomForm>((json) {
        try {
          return CustomForm.fromJson(json);
        } catch (e) {
          debugPrint('Error parsing available form JSON: $e, JSON: $json');
          rethrow;
        }
      }).toList();

      // Filter out forms created by the current user
      final formsFromOthers =
          forms.where((form) => form.created_by != user.id).toList();

      // Filter forms that are active based on schedule
      final now = DateTime.now();
      final activeFormsWithSchedule = formsFromOthers.where((form) {
        try {
          // Skip forms without scheduling
          if (!form.isRecurring && form.startDate == null) return true;

          // Check date range
          if (form.startDate != null && now.isBefore(form.startDate!)) {
            return false;
          }
          if (form.endDate != null && now.isAfter(form.endDate!)) return false;

          // For recurring forms, check the current schedule
          if (form.isRecurring && form.recurrenceType != null) {
            if (form.startTime != null && form.endTime != null) {
              final currentTime = TimeOfDay.fromDateTime(now);
              final currentMinutes = currentTime.hour * 60 + currentTime.minute;
              final startMinutes =
                  form.startTime!.hour * 60 + form.startTime!.minute;
              final endMinutes = form.endTime!.hour * 60 + form.endTime!.minute;

              if (currentMinutes < startMinutes ||
                  currentMinutes > endMinutes) {
                return false;
              }
            }
          }

          return true;
        } catch (e) {
          debugPrint('Error filtering form ${form.id}: $e');
          return false; // Exclude forms that cause errors
        }
      }).toList();

      return activeFormsWithSchedule;
    } catch (e) {
      debugPrint('Error getting available forms: $e');
      return [];
    }
  }

  // Search users by email for adding to groups or permissions
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    try {
      // This requires a custom function in Supabase
      final response = await _withRetry(() =>
          _client.rpc('search_users_by_email', params: {'email_query': email}));
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }
}
