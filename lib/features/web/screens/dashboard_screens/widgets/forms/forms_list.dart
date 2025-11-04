import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'form_card.dart';

class FormsList extends StatelessWidget {
  final List<CustomForm> forms;
  final Map<String, List<FormResponse>> formResponses;
  final Function(CustomForm) onEditForm;
  final Function(CustomForm) onDeleteForm;
  final Function(CustomForm) onOpenFormSubmission;
  final Function(CustomForm) onViewResponses;

  const FormsList({
    super.key,
    required this.forms,
    required this.formResponses,
    required this.onEditForm,
    required this.onDeleteForm,
    required this.onOpenFormSubmission,
    required this.onViewResponses,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      final isCompactScreen = screenWidth < 500;
      final spacing = isCompactScreen ? 8.0 : 10.0;

      return AnimationLimiter(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: forms.length,
          separatorBuilder: (context, index) => SizedBox(height: spacing),
          itemBuilder: (context, index) {
            if (index >= forms.length) return const SizedBox.shrink();

            final form = forms[index];
            final responses = formResponses[form.id] ?? <FormResponse>[];

            return AnimationConfiguration.staggeredList(
              key: ValueKey(form.id),
              position: index,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                horizontalOffset: 40.0,
                child: FadeInAnimation(
                  child: FormCard(
                    form: form,
                    responses: responses,
                    onEdit: () => onEditForm(form),
                    onDelete: () => onDeleteForm(form),
                    onSubmit: () => onOpenFormSubmission(form),
                    onViewResponses: () => onViewResponses(form),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('Error building forms list: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading forms: ${e.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Trigger a rebuild by notifying parent
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }
}
