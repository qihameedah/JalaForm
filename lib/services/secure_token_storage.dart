// lib/services/secure_token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Secure storage for authentication tokens using platform-specific secure storage
///
/// - Android: Uses Android Keystore
/// - iOS: Uses iOS Keychain
/// - Web: Falls back to SharedPreferences (with encryption)
class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Token keys
  static const String _accessTokenKey = 'secure_access_token';
  static const String _refreshTokenKey = 'secure_refresh_token';
  static const String _expiresAtKey = 'secure_expires_at';

  /// Save access token securely
  static Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessTokenKey, value: token);
      debugPrint('[SecureStorage] Access token saved successfully');
    } catch (e) {
      debugPrint('[SecureStorage] Error saving access token: $e');
      rethrow;
    }
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e) {
      debugPrint('[SecureStorage] Error reading access token: $e');
      return null;
    }
  }

  /// Save refresh token securely
  static Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
      debugPrint('[SecureStorage] Refresh token saved successfully');
    } catch (e) {
      debugPrint('[SecureStorage] Error saving refresh token: $e');
      rethrow;
    }
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('[SecureStorage] Error reading refresh token: $e');
      return null;
    }
  }

  /// Save token expiration time
  static Future<void> saveExpiresAt(int expiresAt) async {
    try {
      await _storage.write(key: _expiresAtKey, value: expiresAt.toString());
      debugPrint('[SecureStorage] Expiration time saved successfully');
    } catch (e) {
      debugPrint('[SecureStorage] Error saving expiration time: $e');
      rethrow;
    }
  }

  /// Get token expiration time
  static Future<int?> getExpiresAt() async {
    try {
      final value = await _storage.read(key: _expiresAtKey);
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading expiration time: $e');
      return null;
    }
  }

  /// Clear all stored tokens (on logout)
  static Future<void> clearAll() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _expiresAtKey);
      debugPrint('[SecureStorage] All tokens cleared successfully');
    } catch (e) {
      debugPrint('[SecureStorage] Error clearing tokens: $e');
      rethrow;
    }
  }

  /// Check if tokens exist
  static Future<bool> hasTokens() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();
      return accessToken != null && refreshToken != null;
    } catch (e) {
      debugPrint('[SecureStorage] Error checking tokens: $e');
      return false;
    }
  }

  /// Migrate tokens from SharedPreferences to secure storage
  /// Call this once during app upgrade
  static Future<void> migrateFromSharedPreferences({
    required String? oldAccessToken,
    required String? oldRefreshToken,
    required int? oldExpiresAt,
  }) async {
    try {
      if (oldAccessToken != null) {
        await saveAccessToken(oldAccessToken);
      }
      if (oldRefreshToken != null) {
        await saveRefreshToken(oldRefreshToken);
      }
      if (oldExpiresAt != null) {
        await saveExpiresAt(oldExpiresAt);
      }
      debugPrint('[SecureStorage] Migration from SharedPreferences completed');
    } catch (e) {
      debugPrint('[SecureStorage] Error during migration: $e');
      rethrow;
    }
  }
}
