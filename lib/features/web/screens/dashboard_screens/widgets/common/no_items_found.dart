import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';

/// No items found widget
class NoItemsFound extends StatelessWidget {
  final String searchQuery;

  const NoItemsFound({
    super.key,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 400 ? 48.0 : 64.0;
    final titleFontSize = screenWidth < 400 ? 16.0 : 18.0;
    final messageFontSize = screenWidth < 400 ? 13.0 : 14.0;
    final padding = screenWidth < 400 ? 24.0 : 40.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: iconSize,
                color: Colors.grey.withOpacity(0.5),
              ),
              SizedBox(height: screenWidth < 400 ? 12 : 16),
              Text(
                searchQuery.isNotEmpty
                    ? 'No forms matching "$searchQuery"'
                    : 'No forms available',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth < 400 ? 6 : 8),
              if (searchQuery.isNotEmpty)
                Container(
                  width: screenWidth < 600 ? screenWidth * 0.8 : 300,
                  padding: EdgeInsets.all(screenWidth < 400 ? 12 : 16),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.infoColor,
                        size: screenWidth < 400 ? 20 : 24,
                      ),
                      SizedBox(height: screenWidth < 400 ? 6 : 8),
                      Text(
                        'Try adjusting your search terms or create a new form.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: messageFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
