import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:jala_form/services/supabase_service.dart';

/// Helper utility for image upload operations
///
/// Provides consistent image upload logic across the application
/// with proper error handling and path generation.
class ImageUploadHelper {
  ImageUploadHelper._(); // Private constructor to prevent instantiation

  static const String _bucketName = 'form_images';
  static const Uuid _uuid = Uuid();

  /// Uploads an XFile image to Supabase storage
  ///
  /// [imageFile] - The XFile to upload
  /// [supabaseService] - The Supabase service instance (defaults to singleton)
  ///
  /// Returns the public URL of the uploaded image
  /// Throws an exception if upload fails
  static Future<String> uploadXFile(
    XFile imageFile, {
    SupabaseService? supabaseService,
  }) async {
    final service = supabaseService ?? SupabaseService();
    final imagePath = generateImagePath();

    // Read image bytes
    final imageBytes = await File(imageFile.path).readAsBytes();

    // SECURITY: Validate image using magic bytes
    if (!isValidImageFile(imageBytes)) {
      throw Exception('Invalid image file. Only PNG, JPEG, GIF, WebP, and BMP are allowed.');
    }

    // SECURITY: Validate file size
    if (!isValidFileSize(imageBytes)) {
      throw Exception('File size exceeds maximum limit of ${maxFileSizeBytes ~/ (1024 * 1024)}MB');
    }

    // Upload to storage
    await service.uploadImage(
      _bucketName,
      imagePath,
      imageBytes,
    );

    // Get public URL
    final publicUrl = await service.getImageUrl(
      _bucketName,
      imagePath,
    );

    return publicUrl;
  }

  /// Uploads raw image bytes to Supabase storage
  ///
  /// [imageBytes] - The image data as bytes
  /// [supabaseService] - The Supabase service instance (defaults to singleton)
  ///
  /// Returns the public URL of the uploaded image
  /// Throws an exception if upload fails
  static Future<String> uploadBytes(
    List<int> imageBytes, {
    SupabaseService? supabaseService,
  }) async {
    final service = supabaseService ?? SupabaseService();
    final imagePath = generateImagePath();

    final bytes = Uint8List.fromList(imageBytes);

    // SECURITY: Validate image using magic bytes
    if (!isValidImageFile(bytes)) {
      throw Exception('Invalid image file. Only PNG, JPEG, GIF, WebP, and BMP are allowed.');
    }

    // SECURITY: Validate file size
    if (!isValidFileSize(bytes)) {
      throw Exception('File size exceeds maximum limit of ${maxFileSizeBytes ~/ (1024 * 1024)}MB');
    }

    // Upload to storage
    await service.uploadImage(
      _bucketName,
      imagePath,
      bytes,
    );

    // Get public URL
    final publicUrl = await service.getImageUrl(
      _bucketName,
      imagePath,
    );

    return publicUrl;
  }

  /// Generates a unique image path using UUID
  ///
  /// Returns a path in the format: form_images/{uuid}.jpg
  static String generateImagePath() {
    return 'form_images/${_uuid.v4()}.jpg';
  }

  /// Extracts filename from an image URL
  ///
  /// Removes query parameters and path segments to get the bare filename
  static String getFileNameFromUrl(String imageUrl) {
    return imageUrl.split('/').last.split('?').first;
  }

  /// Validates if a file is a valid image using magic bytes (file signature)
  ///
  /// This is more secure than extension-only validation
  /// Returns true if the file has a valid image signature
  static bool isValidImageFile(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return true;
    }

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }

    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return true;
    }

    // WebP: 52 49 46 46 (RIFF)
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
      // Check for WEBP signature at offset 8
      if (bytes.length > 11 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
        return true;
      }
    }

    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true;
    }

    return false;
  }

  /// Validates file size
  ///
  /// Returns true if file size is within acceptable limits (5MB)
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  static bool isValidFileSize(Uint8List bytes) {
    return bytes.length <= maxFileSizeBytes;
  }

  /// Validates if a file is an image based on extension (fallback)
  ///
  /// Returns true if the file has a valid image extension
  /// NOTE: This is less secure than magic byte validation
  static bool isValidImageExtension(String path) {
    final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final extension = path.split('.').last.toLowerCase();
    return validExtensions.contains(extension);
  }
}
