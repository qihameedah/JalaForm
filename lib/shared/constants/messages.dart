/// Centralized app message constants
///
/// Contains all user-facing messages used throughout the app
/// to ensure consistency and ease of localization.
class AppMessages {
  AppMessages._(); // Private constructor to prevent instantiation

  // Form validation messages
  static const String fillRequiredFields = 'Please fill all required fields';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidNumber = 'Please enter a valid number';

  // Success messages
  static const String formSubmittedSuccess = 'Form submitted successfully';
  static const String formCreatedSuccess = 'Form created successfully';
  static const String formUpdatedSuccess = 'Form updated successfully';
  static const String formDeletedSuccess = 'Form deleted successfully';
  static const String changesSaved = 'All changes saved';

  // Error messages
  static const String errorUploadingImage = 'Error uploading image';
  static const String errorLoadingForm = 'Error loading form';
  static const String errorSubmittingForm = 'Error submitting form';
  static const String errorCreatingForm = 'Error creating form';
  static const String errorUpdatingForm = 'Error updating form';
  static const String errorDeletingForm = 'Error deleting form';
  static const String errorLoadingData = 'Error loading data';
  static const String errorSavingData = 'Error saving data';

  // Loading messages
  static const String loading = 'Loading...';
  static const String savingChanges = 'Saving changes...';
  static const String submitting = 'Submitting...';
  static const String uploading = 'Uploading...';
  static const String deleting = 'Deleting...';

  // Dialog messages
  static const String unsavedChangesTitle = 'Unsaved Changes';
  static const String unsavedChangesMessage =
      'You have unsaved changes. Are you sure you want to leave?';
  static const String deleteConfirmationTitle = 'Delete Confirmation';
  static const String deleteConfirmationMessage =
      'Are you sure you want to delete this item?';

  // Button labels
  static const String buttonStay = 'Stay';
  static const String buttonLeave = 'Leave';
  static const String buttonCancel = 'Cancel';
  static const String buttonDelete = 'Delete';
  static const String buttonSave = 'Save';
  static const String buttonSubmit = 'Submit';
  static const String buttonClose = 'Close';

  // Empty state messages
  static const String noFormsAvailable = 'No forms available';
  static const String noResponsesYet = 'No responses yet';
  static const String noGroupsAvailable = 'No groups available';

  // Session messages
  static const String sessionStarted = 'Session started';
  static const String sessionEnded = 'Session ended';
  static const String sessionExpired = 'Session expired';
}
