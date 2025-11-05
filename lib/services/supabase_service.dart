// lib/services/supabase_service.dart
import 'dart:async';
// Added for Uint8List parameter in uploadImage signature
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jala_form/services/supabase_auth_service.dart';
import 'package:jala_form/services/supabase_constants.dart';
import 'package:jala_form/services/supabase_storage_service.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_permission.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:jala_form/features/forms/models/group_member.dart';
import 'package:jala_form/features/forms/models/user_group.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jala_form/shared/utils/cache_manager.dart';


// SupabaseConstants class has been moved to supabase_constants.dart

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient _client;
  late final SupabaseAuthService _authService;
  late final SupabaseStorageService _storageService; // New Storage Service instance
  static bool _initialized = false;

  // Cache for form responses (5 minute TTL)
  final CacheManager<String, List<FormResponse>> _responseCache =
      CacheManager(defaultTtl: const Duration(minutes: 5));

  // Cache for form response batches (5 minute TTL)
  final CacheManager<String, Map<String, List<FormResponse>>> _batchResponseCache =
      CacheManager(defaultTtl: const Duration(minutes: 5));

  RealtimeChannel? _formsChannel;
  RealtimeChannel? _formPermissionsChannel;
  final StreamController<List<CustomForm>> _formsStreamController =
  StreamController<List<CustomForm>>.broadcast();
  final StreamController<List<CustomForm>> _availableFormsStreamController =
  StreamController<List<CustomForm>>.broadcast();

  Stream<List<CustomForm>> get formsStream => _formsStreamController.stream;
  Stream<List<CustomForm>> get availableFormsStream =>
      _availableFormsStreamController.stream;

  factory SupabaseService() {
    if (!_initialized) {
      throw Exception(
          'SupabaseService not initialized. Call initialize() first.');
    }
    return _instance;
  }

  SupabaseService._internal() {
    _client = Supabase.instance.client;
    _authService = SupabaseAuthService(_client);
    _storageService = SupabaseStorageService(_client); // Initialize Storage Service
  }

  SupabaseClient get client => _client;
  SupabaseAuthService get authService => _authService;
  SupabaseStorageService get storageService => _storageService; // Getter for storage service

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      // Load Supabase credentials from environment variables
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception(
          'Missing Supabase credentials in .env file. '
          'Please ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.',
        );
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      _initialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }

  // --- Authentication Methods (Delegated to SupabaseAuthService) ---
  Future<User?> signUp(String email, String password, String username) async {
    final user = await _authService.signUp(email, password, username);
    if (user != null) {
      try {
        await createUserProfile(user.id, username);
      } catch (e) {
        debugPrint('Error creating user profile after sign_up in SupabaseService: $e');
      }
    }
    return user;
  }

  Future<User?> signIn(String email, String password) async {
    return await _authService.signIn(email, password);
  }

  Future<bool> restoreSession() async {
    return await _authService.restoreSession();
  }

  Future<void> signOut() async {
    await disposeRealTime();
    await _authService.signOut(null);
  }

  User? getCurrentUser() {
    return _authService.getCurrentUser();
  }

  Future<void> updatePassword(String newPassword) async {
    await _authService.updatePassword(newPassword);
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }
  // --- End of Authentication Methods ---

  // --- Storage Methods (Delegated to SupabaseStorageService) ---
  Future<String> uploadImage(String bucketName, String path, Uint8List bytes) async {
    return await _storageService.uploadImage(bucketName, path, bytes);
  }

  Future<String> getImageUrl(String bucketName, String path) async {
    return await _storageService.getImageUrl(bucketName, path);
  }
  // --- End of Storage Methods ---

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _withRetry(() => _client.rpc(SupabaseConstants.rpcListAllUsers));
      return _ensureListOfMaps(response);
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  Future<void> initializeRealTimeSubscriptions() async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        debugPrint('Cannot initialize real-time subscriptions: User not logged in.');
        return;
      }
      _formsChannel = _client
          .channel('forms_changes')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: SupabaseConstants.formsTable,
        callback: _handleFormsChange,
      )
          .subscribe();
      _formPermissionsChannel = _client
          .channel('form_permissions_changes')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: SupabaseConstants.formPermissionsTable,
        callback: _handleFormPermissionsChange,
      )
          .subscribe();
      debugPrint('Real-time subscriptions initialized successfully');
    } catch (e) {
      debugPrint('Error initializing real-time subscriptions: $e');
    }
  }

  void _handleFormsChange(PostgresChangePayload payload) async {
    debugPrint('Forms table changed: ${payload.eventType}');
    await _refreshFormsStreams();
  }

  void _handleFormPermissionsChange(PostgresChangePayload payload) async {
    debugPrint('Form permissions changed: ${payload.eventType}');
    await _refreshAvailableFormsStream();
  }

  Future<void> _refreshFormsStreams() async {
    try {
      final allForms = await getForms();
      if (!_formsStreamController.isClosed) _formsStreamController.add(allForms);
      final availableForms = await getAvailableForms();
      if (!_availableFormsStreamController.isClosed) _availableFormsStreamController.add(availableForms);
    } catch (e) {
      debugPrint('Error refreshing forms streams: $e');
    }
  }

  Future<void> _refreshAvailableFormsStream() async {
    try {
      final availableForms = await getAvailableForms();
      if (!_availableFormsStreamController.isClosed) _availableFormsStreamController.add(availableForms);
    } catch (e) {
      debugPrint('Error refreshing available forms stream: $e');
    }
  }

  Future<void> refreshForms() async {
    await _refreshFormsStreams();
  }

  Future<void> disposeRealTime() async {
    try {
      await _formsChannel?.unsubscribe();
      _formsChannel = null;
      await _formPermissionsChannel?.unsubscribe();
      _formPermissionsChannel = null;

      // Close stream controllers to prevent memory leaks
      if (!_formsStreamController.isClosed) {
        await _formsStreamController.close();
      }
      if (!_availableFormsStreamController.isClosed) {
        await _availableFormsStreamController.close();
      }

      debugPrint('Real-time subscriptions unsubscribed and stream controllers closed.');
    } catch (e) {
      debugPrint('Error disposing real-time subscriptions: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.userProfilesTable)
          .select()
          .eq('user_id', userId)
          .single());
      return _ensureMap(response);
    } catch (e) {
      debugPrint('Error getting user profile for $userId: $e');
      return null;
    }
  }

  Map<String, DateTime> _getCurrentRecurrencePeriod(CustomForm form) {
    final now = DateTime.now();
    DateTime periodStart;
    DateTime periodEnd;
    switch (form.recurrenceType) {
      case RecurrenceType.daily:
        periodStart = DateTime(now.year, now.month, now.day);
        periodEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case RecurrenceType.weekly:
        final daysFromMonday = now.weekday - 1; // Assuming Monday is 1
        periodStart = DateTime(now.year, now.month, now.day - daysFromMonday);
        periodEnd = DateTime(
            now.year, now.month, now.day - daysFromMonday + 6, 23, 59, 59, 999);
        break;
      case RecurrenceType.monthly:
        periodStart = DateTime(now.year, now.month, 1);
        periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999); // Day 0 of next month is last day of current
        break;
      case RecurrenceType.yearly:
        periodStart = DateTime(now.year, 1, 1);
        periodEnd = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
      case null: // Explicitly handle null for clarity
      default:
        periodStart = form.startDate ?? DateTime(now.year, now.month, now.day);
        periodEnd = form.endDate ??
            DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
    }
    return {'start': periodStart, 'end': periodEnd};
  }

  Future<bool> hasUserSubmittedInCurrentPeriod(
      String formId, String userId) async {
    try {
      final form = await getFormById(formId);
      final period = _getCurrentRecurrencePeriod(form);
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.formResponsesTable)
          .select()
          .eq('form_id', formId)
          .eq('respondent_id', userId)
          .gte('submitted_at', period['start']!.toIso8601String())
          .lte('submitted_at', period['end']!.toIso8601String())
          .count(CountOption.exact));
      return response.count > 0;
    } catch (e) {
      debugPrint('Error checking user submission in current period: $e');
      return false;
    }
  }

  Future<int> checkUserFormSubmissionInCurrentPeriod(
      String formId, String userId) async {
    try {
      final form = await getFormById(formId);
      final period = _getCurrentRecurrencePeriod(form);
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.formResponsesTable)
          .select()
          .eq('form_id', formId)
          .eq('respondent_id', userId)
          .gte('submitted_at', period['start']!.toIso8601String())
          .lte('submitted_at', period['end']!.toIso8601String())
          .count(CountOption.exact));
      return response.count;
    } catch (e) {
      debugPrint('Error checking user form submission count in current period: $e');
      return 0;
    }
  }

  bool isFormAvailableForCurrentPeriod(CustomForm form) {
    final now = DateTime.now();
    if (form.startDate != null && now.isBefore(form.startDate!)) {
      return false;
    }
    if (form.endDate != null) {
      final endOfDayForEndDate = DateTime(form.endDate!.year, form.endDate!.month, form.endDate!.day, 23, 59, 59, 999);
      if (now.isAfter(endOfDayForEndDate)) {
        return false;
      }
    }
    if (form.isRecurring && form.recurrenceType != null) {
      if (form.recurrenceType == RecurrenceType.daily) {
        if (form.startTime != null && form.endTime != null) {
          final currentTime = TimeOfDay.fromDateTime(now);
          final currentMinutes = currentTime.hour * 60 + currentTime.minute;
          final startMinutes = form.startTime!.hour * 60 + form.startTime!.minute;
          final endMinutes = form.endTime!.hour * 60 + form.endTime!.minute;
          return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
        }
      }
    }
    return true;
  }

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
        if (form.startDate != null && form.endDate != null) {
          return '${_formatDate(form.startDate!)} - ${_formatDate(form.endDate!)}';
        } else if (form.startDate != null) {
          return 'Starts ${_formatDate(form.startDate!)}';
        }
        return 'Current Period';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  Future<void> cleanOldDraftResponses(String formId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;
      final form = await getFormById(formId);
      final period = _getCurrentRecurrencePeriod(form);
      await _withRetry(() => _client
          .from(SupabaseConstants.formDraftsTable)
          .delete()
          .eq('form_id', formId)
          .eq('user_id', user.id)
          .lt('updated_at', period['start']!.toIso8601String()));
    } catch (e) {
      debugPrint('Error cleaning old draft responses: $e');
    }
  }

  Future<Map<String, dynamic>?> getDraftResponseForCurrentPeriod(
      String formId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;
      final form = await getFormById(formId);
      final period = _getCurrentRecurrencePeriod(form);
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.formDraftsTable)
          .select('data')
          .eq('form_id', formId)
          .eq('user_id', user.id)
          .gte('updated_at', period['start']!.toIso8601String())
          .lte('updated_at', period['end']!.toIso8601String())
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle());
      if (response != null && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting draft response for current period: $e');
      return null;
    }
  }

  Future<void> createUserProfile(String userId, String username) async {
    try {
      await _withRetry(() => _client.from(SupabaseConstants.userProfilesTable).insert({
        'user_id': userId,
        'username': username,
        'created_at': DateTime.now().toIso8601String(),
      }));
      debugPrint('User profile created for $userId');
    } catch (e) {
      debugPrint('Error creating user profile for $userId: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      final updateData = {...data, 'updated_at': DateTime.now().toIso8601String()};
      await _withRetry(() => _client
          .from(SupabaseConstants.userProfilesTable)
          .update(updateData)
          .eq('user_id', userId));
    } catch (e) {
      debugPrint('Error updating user profile for $userId: $e');
      rethrow;
    }
  }

  Future<bool> hasUserSubmittedForm(String formId, String userId) async {
    try {
      final form = await getFormById(formId);
      var queryBuilder = _client
          .from(SupabaseConstants.formResponsesTable)
          .select()
          .eq('form_id', formId)
          .eq('respondent_id', userId);

      if (form.startDate != null) {
        queryBuilder = queryBuilder.gte('submitted_at', form.startDate!.toIso8601String());
      }
      if (form.endDate != null) {
        final adjustedEndDate = DateTime(form.endDate!.year, form.endDate!.month, form.endDate!.day, 23, 59, 59, 999);
        queryBuilder = queryBuilder.lte('submitted_at', adjustedEndDate.toIso8601String());
      }
      final response = await _withRetry(() => queryBuilder.count(CountOption.exact));
      return response.count > 0;
    } catch (e) {
      debugPrint('Error checking user form submission: $e');
      return false;
    }
  }

  Future<int> checkUserFormSubmission(String formId, String userId,
      DateTime? startDate, DateTime? endDate) async {
    try {
      var queryBuilder = _client
          .from(SupabaseConstants.formResponsesTable)
          .select()
          .eq('form_id', formId)
          .eq('respondent_id', userId);

      if (startDate != null) {
        queryBuilder = queryBuilder.gte('submitted_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        final adjustedEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
        queryBuilder = queryBuilder.lte('submitted_at', adjustedEndDate.toIso8601String());
      }
      final response = await _withRetry(() => queryBuilder.count(CountOption.exact));
      return response.count;
    } catch (e) {
      debugPrint('Error checking user form submission count: $e');
      return 0;
    }
  }

  Future<String> getUsername(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile != null && profile['username'] != null && profile['username'].toString().isNotEmpty) {
        return profile['username'].toString();
      }
      final currentUser = getCurrentUser();
      if (currentUser != null && currentUser.id == userId) {
        final authUsername = currentUser.userMetadata?['username'];
        if (authUsername != null && authUsername.toString().isNotEmpty) {
          return authUsername.toString();
        }
        if (currentUser.email != null && currentUser.email!.contains('@')) {
          return currentUser.email!.split('@')[0];
        }
      }
      return 'User';
    } catch (e) {
      debugPrint('Error getting username for $userId: $e');
      return 'User';
    }
  }

  Future<String> createForm(CustomForm form) async {
    try {
      final response = await _withRetry(() =>
          _client.from(SupabaseConstants.formsTable).insert(form.toJson()).select('id').single());
      return response['id']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error creating form: $e');
      rethrow;
    }
  }

  Future<List<CustomForm>> getForms() async {
    try {
      final response = await _withRetry(() => _client.from(SupabaseConstants.formsTable).select().order('created_at', ascending: false));
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
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.formsTable)
          .select()
          .eq('id', formId)
          .single());
      final responseMap = _ensureMap(response);
      return CustomForm.fromJson(responseMap);
    } catch (e) {
      debugPrint('Error getting form by ID $formId: $e');
      rethrow;
    }
  }

  Future<void> updateForm(CustomForm form) async {
    try {
      await _withRetry(() => _client
          .from(SupabaseConstants.formsTable)
          .update(form.toJson())
          .eq('id', form.id));
    } catch (e) {
      debugPrint('Error updating form ${form.id}: $e');
      rethrow;
    }
  }

  Future<void> deleteForm(String formId) async {
    try {
      await _withRetry(() => _client.from(SupabaseConstants.formsTable).delete().eq('id', formId));
    } catch (e) {
      debugPrint('Error deleting form $formId: $e');
      rethrow;
    }
  }

  Future<String?> saveDraftResponse(
      String formId, Map<String, dynamic> data) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in, cannot save draft.');
      }
      final now = DateTime.now().toIso8601String();
      final draftData = {
        'form_id': formId,
        'user_id': user.id,
        'data': data,
        'updated_at': now,
      };
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.formDraftsTable)
          .upsert(
        {...draftData, 'created_at': now},
        onConflict: 'form_id, user_id',
      )
          .select('id')
          .single());
      return response['id']?.toString();
    } catch (e) {
      debugPrint('Error saving draft response for form $formId: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDraftResponse(String formId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.formDraftsTable)
          .select('data')
          .eq('form_id', formId)
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle());
      if (response != null && response['data'] != null) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        } else {
          debugPrint('Draft data is not a Map: ${data.runtimeType}');
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting draft response for form $formId: $e');
      return null;
    }
  }

  Future<void> deleteDraftResponse(String formId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;
      await _withRetry(() => _client
          .from(SupabaseConstants.formDraftsTable)
          .delete()
          .eq('form_id', formId)
          .eq('user_id', user.id));
    } catch (e) {
      debugPrint('Error deleting draft response for form $formId: $e');
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await _withRetry(() => _client
          .from(SupabaseConstants.groupMembersTable)
          .delete()
          .eq('group_id', groupId));
      await _withRetry(() => _client
          .from(SupabaseConstants.formPermissionsTable)
          .delete()
          .eq('group_id', groupId));
      await _withRetry(() =>
          _client.from(SupabaseConstants.userGroupsTable).delete().eq('id', groupId));
    } catch (e) {
      debugPrint('Error deleting group $groupId: $e');
      rethrow;
    }
  }

  Future<String> submitFormResponse(FormResponse response) async {
    try {
      final result = await _withRetry(() => _client
          .from(SupabaseConstants.formResponsesTable)
          .insert(response.toJson())
          .select('id')
          .single());
      final responseId = result['id']?.toString() ?? '';
      if (responseId.isNotEmpty && response.respondent_id != null) {
        await deleteDraftResponse(response.form_id);
      }

      // Invalidate cache for this form since a new response was added
      clearFormResponseCache(response.form_id);

      return responseId;
    } catch (e) {
      debugPrint('Error submitting form response for form ${response.form_id}: $e');
      rethrow;
    }
  }

  Future<List<FormResponse>> getFormResponses(String formId, {
    int? limit,
    int? offset,
    bool useCache = true,
  }) async {
    // Create cache key including pagination params
    final cacheKey = limit == null && offset == null ? formId : '$formId:$limit:$offset';

    // Try cache first (only for non-paginated queries)
    if (useCache && limit == null && offset == null) {
      final cached = _responseCache.get(formId);
      if (cached != null) {
        debugPrint('Cache hit for form responses: $formId');
        return cached;
      }
    }

    try {
      var query = _client
          .from(SupabaseConstants.formResponsesTable)
          .select()
          .eq('form_id', formId)
          .order('submitted_at', ascending: false);

      // Apply pagination if provided
      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 1000) - 1);
      }

      final response = await _withRetry(() => query);
      final responseList = _ensureListOfMaps(response);
      final responses = responseList.map<FormResponse>((json) {
        try {
          return FormResponse.fromJson(json);
        } catch (e) {
          debugPrint('Error parsing form response JSON for form $formId: $e, JSON: $json');
          rethrow;
        }
      }).toList();

      // Cache the result (only for non-paginated queries)
      if (useCache && limit == null && offset == null) {
        _responseCache.put(formId, responses);
      }

      return responses;
    } catch (e) {
      debugPrint('Error getting form responses for form $formId: $e');
      return [];
    }
  }

  /// Get total count of responses for a form (useful for pagination)
  Future<int> getFormResponseCount(String formId) async {
    try {
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.formResponsesTable)
          .select('*')
          .eq('form_id', formId)
          .count(CountOption.exact));
      return response.count;
    } catch (e) {
      debugPrint('Error getting form response count for form $formId: $e');
      return 0;
    }
  }

  /// Batch fetch form responses for multiple forms at once
  ///
  /// This eliminates the N+1 query pattern by fetching all responses
  /// in a single database query using the `in` filter.
  ///
  /// Returns a Map where keys are form IDs and values are lists of responses.
  /// If a form has no responses, it will have an empty list.
  Future<Map<String, List<FormResponse>>> getFormResponsesBatch(
      List<String> formIds, {bool useCache = true}) async {
    if (formIds.isEmpty) {
      return {};
    }

    // Create cache key from sorted form IDs
    final sortedIds = [...formIds]..sort();
    final batchCacheKey = sortedIds.join(',');

    // Try cache first
    if (useCache) {
      final cached = _batchResponseCache.get(batchCacheKey);
      if (cached != null) {
        debugPrint('Cache hit for batch responses: ${formIds.length} forms');
        return cached;
      }
    }

    try {
      // Fetch all responses for all forms in a single query
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.formResponsesTable)
          .select()
          .inFilter('form_id', formIds)
          .order('submitted_at', ascending: false));

      final responseList = _ensureListOfMaps(response);

      // Group responses by form_id
      final Map<String, List<FormResponse>> responseMap = {};

      // Initialize all form IDs with empty lists
      for (var formId in formIds) {
        responseMap[formId] = [];
      }

      // Parse and group responses
      for (var json in responseList) {
        try {
          final formResponse = FormResponse.fromJson(json);
          final formId = formResponse.form_id;
          if (responseMap.containsKey(formId)) {
            responseMap[formId]!.add(formResponse);
          }
        } catch (e) {
          debugPrint('Error parsing form response JSON in batch: $e, JSON: $json');
        }
      }

      // Cache the batch result
      if (useCache) {
        _batchResponseCache.put(batchCacheKey, responseMap);

        // Also cache individual form responses
        for (var entry in responseMap.entries) {
          _responseCache.put(entry.key, entry.value);
        }
      }

      return responseMap;
    } catch (e) {
      debugPrint('Error getting form responses batch: $e');
      // Return empty lists for all form IDs on error
      return Map.fromIterable(formIds, value: (_) => <FormResponse>[]);
    }
  }

  /// Clear all response caches
  ///
  /// Useful when data has been updated and cache should be invalidated
  void clearResponseCache() {
    _responseCache.clear();
    _batchResponseCache.clear();
    debugPrint('Response caches cleared');
  }

  /// Clear cache for a specific form
  void clearFormResponseCache(String formId) {
    _responseCache.remove(formId);
    debugPrint('Cache cleared for form: $formId');
  }

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
        if (!_isRetryableError(e) || attempts >= maxRetries) {
          rethrow;
        }
        final delay = Duration(milliseconds: 1000 * attempts);
        debugPrint(
            'Retrying operation after $delay (attempt $attempts/$maxRetries), Error: $e');
        await Future.delayed(delay);
      }
    }
  }

  bool _isRetryableError(dynamic error) {
    if (error is PostgrestException) {
      if (error.code == 'PGRST000' || error.code == 'PGRST100') return true;
    }
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('host lookup') ||
        error is TimeoutException;
  }

  Future<bool> checkConnection() async {
    try {
      await _client
          .from(SupabaseConstants.formsTable)
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

  Future<String> createUserGroup(UserGroup group) async {
    try {
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.userGroupsTable)
          .insert(group.toJson())
          .select('id')
          .single());
      return response['id']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error creating user group ${group.name}: $e');
      rethrow;
    }
  }

  Future<List<UserGroup>> getUserGroups() async {
    final currentUser = getCurrentUser();
    if (currentUser == null) return [];
    try {
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.userGroupsTable)
          .select('*, members: ${SupabaseConstants.groupMembersTable}!inner(user_id)')
          .eq('members.user_id', currentUser.id)
          .order('name', ascending: true));
      final responseList = _ensureListOfMaps(response);
      return responseList
          .map<UserGroup>((json) => UserGroup.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting user groups: $e');
      return [];
    }
  }

  Future<List<UserGroup>> getMyCreatedGroups() async {
    final currentUser = getCurrentUser();
    if (currentUser == null) return [];
    try {
      final response = await _withRetry(() => _client
          .from(SupabaseConstants.userGroupsTable)
          .select()
          .eq('created_by', currentUser.id)
          .order('name', ascending: true));
      final responseList = _ensureListOfMaps(response);
      return responseList
          .map<UserGroup>((json) => UserGroup.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting created groups: $e');
      return [];
    }
  }

  Future<void> addGroupMember(GroupMember member) async {
    try {
      await _withRetry(() => _client
          .from(SupabaseConstants.groupMembersTable)
          .insert(member.toJson()));
    } catch (e) {
      if (e is PostgrestException && e.code == '23505') {
        debugPrint('User ${member.user_id} is already a member of group ${member.group_id}.');
        return;
      }
      debugPrint('Error adding group member ${member.user_id} to group ${member.group_id}: $e');
      rethrow;
    }
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    try {
      await _withRetry(() => _client
          .from(SupabaseConstants.groupMembersTable)
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId));
    } catch (e) {
      debugPrint('Error removing group member $userId from group $groupId: $e');
      rethrow;
    }
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      final response = await _withRetry(() => _client.rpc(
          SupabaseConstants.rpcGetGroupMembers,
          params: {'group_id_param': groupId}));
      final responseList = _ensureListOfMaps(response);
      return responseList.map<GroupMember>((json) {
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
      debugPrint('Error getting group members for group $groupId: $e');
      return [];
    }
  }

  Future<void> addFormPermission(FormPermission permission) async {
    try {
      await _withRetry(() => _client
          .from(SupabaseConstants.formPermissionsTable)
          .insert(permission.toJson()));
    } catch (e) {
      if (e is PostgrestException && e.code == '23505') {
        debugPrint('Permission already exists for form ${permission.form_id} and user/group.');
        return;
      }
      debugPrint('Error adding form permission for form ${permission.form_id}: $e');
      rethrow;
    }
  }

  Future<void> removeFormPermission(String formId,
      {String? userId, String? groupId}) async {
    try {
      var query = _client
          .from(SupabaseConstants.formPermissionsTable)
          .delete()
          .eq('form_id', formId);
      if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      } else if (groupId != null && groupId.isNotEmpty) {
        query = query.eq('group_id', groupId);
      } else {
        debugPrint('Warning: removeFormPermission called without userId or groupId for form $formId. This will remove all permissions.');
      }
      await _withRetry(() => query);
    } catch (e) {
      debugPrint('Error removing form permission for form $formId: $e');
      rethrow;
    }
  }

  Future<List<FormPermission>> getFormPermissions(String formId) async {
    try {
      final permissionsResponse = await _withRetry(() => _client
          .from(SupabaseConstants.formPermissionsTable)
          .select('''
            *,
            user_profiles(username),
            user_groups(name)
          ''')
          .eq('form_id', formId));
      final List<Map<String, dynamic>> responseList = _ensureListOfMaps(permissionsResponse);

      List<FormPermission> permissions = [];
      for (var permData in responseList) {
        String? userEmail;
        String? userName = permData['user_profiles']?['username'];
        String? groupName = permData['user_groups']?['name'];
        permissions.add(FormPermission.fromJson({
          ...permData,
          'user_email': userEmail,
          'user_name': userName,
          'group_name': groupName,
        }));
      }
      return permissions;
    } catch (e) {
      debugPrint('Error getting form permissions for form $formId: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _ensureListOfMaps(dynamic response) {
    if (response == null) return [];
    if (response is List) {
      return response.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else if (item is Map) {
          return Map<String, dynamic>.from(item);
        } else {
          debugPrint('Warning: Unexpected item type in list: ${item.runtimeType}, item: $item. Skipping item.');
          return <String, dynamic>{};
        }
      }).where((map) => map.isNotEmpty).toList();
    }
    debugPrint('Warning: Expected List but got ${response.runtimeType}, value: $response. Returning empty list.');
    return [];
  }

  Map<String, dynamic> _ensureMap(dynamic response) {
    if (response == null) return {};
    if (response is Map<String, dynamic>) {
      return response;
    } else if (response is Map) {
      return Map<String, dynamic>.from(response);
    } else {
      debugPrint('Warning: Expected Map but got ${response.runtimeType}, value: $response. Returning empty map.');
      return {};
    }
  }

  Future<List<CustomForm>> getAvailableForms() async {
    final user = getCurrentUser();
    if (user == null) {
      debugPrint('User not logged in, cannot get available forms.');
      return [];
    }
    try {
      final response = await _withRetry(() => _client.rpc(SupabaseConstants.rpcGetAvailableForms));
      final responseList = _ensureListOfMaps(response);

      final forms = responseList.map<CustomForm>((json) {
        try {
          return CustomForm.fromJson(json);
        } catch (e) {
          debugPrint('Error parsing available form JSON: $e, JSON: $json');
          rethrow;
        }
      }).toList();

      return forms.where((form) => isFormAvailableForCurrentPeriod(form)).toList();

    } catch (e) {
      debugPrint('Error getting available forms: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchUsersByEmail(String emailQuery) async {
    if (emailQuery.isEmpty) return [];
    try {
      final response = await _withRetry(() => _client
          .rpc(SupabaseConstants.rpcSearchUsersByEmail, params: {'email_query': emailQuery}));
      return _ensureListOfMaps(response);
    } catch (e) {
      debugPrint('Error searching users by email "$emailQuery": $e');
      return [];
    }
  }
}