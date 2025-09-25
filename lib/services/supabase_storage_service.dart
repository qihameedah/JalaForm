// lib/services/supabase_storage_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  final SupabaseClient _client;

  SupabaseStorageService(this._client);

  Future<String> uploadImage(
      String bucketName, String path, Uint8List bytes) async {
    try {
      // Use uploadBinary with file options for upsert to overwrite if exists
      await _withRetry(() => _client.storage
          .from(bucketName)
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true)));
      // After successful upload, get the public URL
      return _client.storage.from(bucketName).getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading image to $bucketName/$path: $e');
      rethrow;
    }
  }

  Future<String> getImageUrl(String bucketName, String path) async {
    try {
      return _client.storage.from(bucketName).getPublicUrl(path);
    } catch (e) {
      debugPrint('Error getting image URL for $bucketName/$path: $e');
      rethrow;
    }
  }

  // Helper method for retry logic (duplicated for now, ideally in a shared utility)
  Future<T> _withRetry<T>(Future<T> Function() operation,
      {int maxRetries = 3}) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation().timeout(
          const Duration(seconds: 30), // Consider making timeout configurable
          onTimeout: () {
            throw TimeoutException(
                'Storage operation timed out. Please check your internet connection.');
          },
        );
      } catch (e) {
        if (!_isRetryableError(e) || attempts >= maxRetries) {
          rethrow;
        }
        final delay = Duration(milliseconds: 1000 * attempts);
        debugPrint(
            'Retrying storage operation after $delay (attempt $attempts/$maxRetries)');
        await Future.delayed(delay);
      }
    }
  }

  // Determine if an error should trigger a retry (duplicated for now)
  bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    // Supabase storage might throw StorageException, check for specific codes if needed
    return errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('host lookup') ||
        error is TimeoutException;
  }
}