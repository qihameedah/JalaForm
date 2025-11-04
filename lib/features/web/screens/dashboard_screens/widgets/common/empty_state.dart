import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';

/// Empty state widget for when no forms exist
class EmptyState extends StatelessWidget {
  final VoidCallback onCreateForm;

  const EmptyState({
    super.key,
    required this.onCreateForm,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade50,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 24 : 40),
          width: isSmallScreen ? double.infinity : 600,
          margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  size: isSmallScreen ? 60 : 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Jala Form Dashboard',
                style: TextStyle(
                  fontSize: isSmallScreen ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Create your first form to get started. You can create regular forms or checklists with time windows and recurrence patterns.',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: isSmallScreen ? double.infinity : null,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Create Your First Form',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 24 : 32,
                      vertical: isSmallScreen ? 16 : 18,
                    ),
                    textStyle: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onCreateForm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
