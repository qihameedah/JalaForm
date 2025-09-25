import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';

class NoResponsesWidget extends StatefulWidget {
  final CustomForm form;
  final Function(CustomForm) onSubmitForm;

  const NoResponsesWidget({
    super.key,
    required this.form,
    required this.onSubmitForm,
  });

  @override
  State<NoResponsesWidget> createState() => _NoResponsesWidgetState();
}

class _NoResponsesWidgetState extends State<NoResponsesWidget> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 450;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isSmallScreen ? 16 : 24),
                child: Container(
                  width: isSmallScreen ? screenWidth * 0.9 : 500,
                  padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        offset: const Offset(0, 2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Empty state icon with pulse animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.95, end: 1.05),
                        duration: const Duration(milliseconds: 2000),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inbox_rounded,
                                size: isSmallScreen ? 40 : 48,
                                color: Colors.blue.shade300,
                              ),
                            ),
                          );
                        },
                        // Create a continuous pulse animation
                        onEnd: () => setState(() {}),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      Text(
                        'No Responses Yet',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 10 : 12),
                      Text(
                        'Share your form to collect responses',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      SizedBox(
                        width: isSmallScreen ? double.infinity : null,
                        child: ElevatedButton.icon(
                          onPressed: () => widget.onSubmitForm(widget.form),
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white),
                          label: const Text('Submit Form Now',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16 : 20,
                                vertical: isSmallScreen ? 10 : 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}