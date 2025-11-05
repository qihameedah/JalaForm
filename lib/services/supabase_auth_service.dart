// lib/services/supabase_auth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:jala_form/services/supabase_constants.dart';
import 'package:jala_form/services/secure_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient _client;

  SupabaseAuthService(this._client);

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
      // User profile creation will be handled by SupabaseService after this call
      return response.user;
    } on AuthException catch (e) {
      debugPrint('Auth Error during sign_up: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error during sign_up: $e');
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
      await _saveSession(response.session);
      return response.user;
    } on AuthException catch (e) {
      debugPrint('Auth Error during sign_in: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error during sign_in: $e');
      if (e is TimeoutException ||
          (e.toString().contains('SocketException') ||
              e.toString().contains('Failed host lookup') ||
              e.toString().contains('connection failed'))) {
        throw Exception(
            'Cannot connect to the server. Please check your internet connection and try again.');
      }
      rethrow;
    }
  }

  Future<void> _saveSession(Session? session) async {
    if (session != null) {
      try {
        // SECURITY: Use secure storage for tokens (Android Keystore / iOS Keychain)
        await SecureTokenStorage.saveAccessToken(session.accessToken);

        if (session.refreshToken != null) {
          await SecureTokenStorage.saveRefreshToken(session.refreshToken!);
        }

        if (session.expiresAt != null) {
          await SecureTokenStorage.saveExpiresAt(session.expiresAt!);
        }

        // Migration: Clean up old tokens from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(SupabaseConstants.prefsAccessToken);
        await prefs.remove(SupabaseConstants.prefsRefreshToken);
        await prefs.remove(SupabaseConstants.prefsExpiresAt);

        debugPrint('[Auth] Session saved securely');
      } catch (e) {
        debugPrint('[Auth] Error saving session: $e');
        rethrow;
      }
    }
  }

  Future<bool> restoreSession() async {
    try {
      // SECURITY: Try to read from secure storage first
      String? accessToken = await SecureTokenStorage.getAccessToken();
      int? expiresAt = await SecureTokenStorage.getExpiresAt();

      // Migration: If not in secure storage, try SharedPreferences (old version)
      if (accessToken == null) {
        final prefs = await SharedPreferences.getInstance();
        final oldAccessToken = prefs.getString(SupabaseConstants.prefsAccessToken);
        final oldRefreshToken = prefs.getString(SupabaseConstants.prefsRefreshToken);
        final oldExpiresAt = prefs.getInt(SupabaseConstants.prefsExpiresAt);

        if (oldAccessToken != null) {
          debugPrint('[Auth] Migrating tokens from SharedPreferences to secure storage');
          await SecureTokenStorage.migrateFromSharedPreferences(
            oldAccessToken: oldAccessToken,
            oldRefreshToken: oldRefreshToken,
            oldExpiresAt: oldExpiresAt,
          );

          // Clean up old storage
          await prefs.remove(SupabaseConstants.prefsAccessToken);
          await prefs.remove(SupabaseConstants.prefsRefreshToken);
          await prefs.remove(SupabaseConstants.prefsExpiresAt);

          accessToken = oldAccessToken;
          expiresAt = oldExpiresAt;
        }
      }

      if (accessToken == null) {
        debugPrint('[Auth] No access token found for session restoration');
        return false;
      }

      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now >= expiresAt) {
          // debugPrint('Access token expired. Attempting to refresh session...');
          try {
            final response = await _client.auth.refreshSession(); // Uses refresh token stored by Supabase
            await _saveSession(response.session);
            // debugPrint('Session refreshed successfully.');
            return response.user != null;
          } catch (e) {
            debugPrint('Error refreshing session: $e');
            await _clearSessionInternal(); // Clear all session details if refresh fails
            return false;
          }
        }
      }

      // If token not expired or no expiry info, try setting current session from stored access token
      try {
        // debugPrint('Attempting to set session from stored access token...');
        final response = await _client.auth.setSession(accessToken);
        if (response.user == null) {
          // debugPrint('setSession resulted in null user. Attempting to recover session...');
          final recoverResponse = await _client.auth.recoverSession(accessToken);
          await _saveSession(recoverResponse.session);
          // debugPrint(recoverResponse.user != null ? 'Session recovered successfully.' : 'Failed to recover session.');
          return recoverResponse.user != null;
        }
        await _saveSession(response.session); // Save potentially updated session details
        // debugPrint('Session set successfully from stored access token.');
        return response.user != null;
      } catch (e) {
        debugPrint('Error setting/recovering session from token: $e. Clearing session.');
        await _clearSessionInternal();
        return false;
      }
    } catch (e) {
      debugPrint('Error in session restoration: $e');
      return false;
    }
  }

  // Clears tokens and expiry, keeps savedEmail for "Remember Me"
  Future<void> clearAuthTokens() async {
    // SECURITY: Clear secure storage
    await SecureTokenStorage.clearAll();

    // Also clear old SharedPreferences (migration cleanup)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SupabaseConstants.prefsAccessToken);
    await prefs.remove(SupabaseConstants.prefsRefreshToken);
    await prefs.remove(SupabaseConstants.prefsExpiresAt);

    debugPrint('[Auth] Auth tokens cleared securely');
  }

  // Clears all session related data including "Remember Me" email
  Future<void> _clearSessionInternal() async {
    // SECURITY: Clear secure storage
    await SecureTokenStorage.clearAll();

    // Clear SharedPreferences (both new and old data)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SupabaseConstants.prefsAccessToken);
    await prefs.remove(SupabaseConstants.prefsRefreshToken);
    await prefs.remove(SupabaseConstants.prefsExpiresAt);
    await prefs.remove(SupabaseConstants.prefsSavedEmail);
    await prefs.remove('savedPassword'); // Clean up old password storage

    debugPrint('[Auth] All session data cleared');
  }

  // Public method that might be called from SupabaseService
  Future<void> clearFullSessionData() async {
    await _clearSessionInternal(); // Changed call
  }


  Future<void> signOut(Future<void> Function()? onBeforeSignOut) async {
    try {
      if (onBeforeSignOut != null) {
        await onBeforeSignOut();
      }
      await _client.auth.signOut();
      await _clearSessionInternal(); // Changed call: Clear all session data on sign out
      // debugPrint('User signed out and all session data cleared.');
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

  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      // debugPrint('Password updated successfully.');
    } on AuthException catch (e) {
      debugPrint('Auth Error updating password: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating password: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      // debugPrint('Password reset email sent to $email.');
    } on AuthException catch (e) {
      debugPrint('Auth Error sending password reset email: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }
}