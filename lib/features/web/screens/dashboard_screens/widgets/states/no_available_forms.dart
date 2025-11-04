import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';

class NoAvailableFormsMessage extends StatelessWidget {
  const NoAvailableFormsMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No forms available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.infoColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'When forms are shared with you, they will appear here for easy access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
