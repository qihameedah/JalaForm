// lib/services/supabase_constants.dart

class SupabaseConstants {
  // Table Names
  static const String formsTable = 'forms';
  static const String userProfilesTable = 'user_profiles';
  static const String formResponsesTable = 'form_responses';
  static const String formDraftsTable = 'form_drafts';
  static const String userGroupsTable = 'user_groups';
  static const String groupMembersTable = 'group_members';
  static const String formPermissionsTable = 'form_permissions';

  // RPC Function Names
  static const String rpcListAllUsers = 'list_all_users';
  static const String rpcGetAvailableForms = 'get_available_forms';
  static const String rpcGetGroupMembers = 'get_group_members';
  static const String rpcSearchUsersByEmail = 'search_users_by_email';

  // SharedPreferences Keys
  static const String prefsAccessToken = 'access_token';
  static const String prefsRefreshToken = 'refresh_token';
  static const String prefsExpiresAt = 'expires_at';
  static const String prefsSavedEmail = 'savedEmail';
  // SECURITY: Never store passwords in SharedPreferences
  // Removed: prefsSavedPassword (security vulnerability)
}
