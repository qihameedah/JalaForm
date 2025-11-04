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

    // Upload to storage
    await service.uploadImage(
      _bucketName,
      imagePath,
      Uint8List.fromList(imageBytes),
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

  /// Validates if a file is an image based on extension
  ///
  /// Returns true if the file has a valid image extension
  static bool isValidImageExtension(String path) {
    final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final extension = path.split('.').last.toLowerCase();
    return validExtensions.contains(extension);
  }
}
