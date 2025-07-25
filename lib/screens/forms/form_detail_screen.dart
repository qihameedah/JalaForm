// lib/screens/forms/form_detail_screen.dart (Updated)

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:form_builder_image_picker/form_builder_image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../models/custom_form.dart';
import '../../models/form_field.dart';
import '../../models/form_response.dart';
import '../../services/supabase_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import 'dart:math' as math;

class FormDetailScreen extends StatefulWidget {
  final CustomForm form;
  final bool isPreview;

  const FormDetailScreen({
    super.key,
    required this.form,
    this.isPreview = false,
  });

  @override
  State<FormDetailScreen> createState() => _FormDetailScreenState();
}

// Helper class for Likert options
class LikertOption {
  final String label;
  final String value;

  LikertOption({required this.label, required this.value});
}

class _FormDetailScreenState extends State<FormDetailScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _supabaseService = SupabaseService();
  final _pdfService = PdfService();
  bool _isSubmitting = false;
  bool _isPdfGenerating = false;
  final Map<String, dynamic> _responses = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPreview ? 'Preview Form' : widget.form.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 2,
        actions: widget.isPreview
            ? []
            : [
                IconButton(
                  icon: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                  ),
                  onPressed: _submitForm,
                  tooltip: 'Submit Form',
                ),
              ],
      ),
      body: _isSubmitting || _isPdfGenerating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    _isPdfGenerating
                        ? 'Generating PDF...'
                        : 'Submitting form...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              color: AppTheme.backgroundColor,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.form.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.form.description,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Form fields
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: FormBuilder(
                          key: _formKey,
                          initialValue: const {},
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildFormFields(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit button
                    if (!widget.isPreview)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _submitForm,
                            icon: const Icon(
                              Icons.send,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Submit Form',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildFormFields() {
    final List<Widget> fields = [];

    for (var i = 0; i < widget.form.fields.length; i++) {
      final field = widget.form.fields[i];

      fields.add(
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i > 0) const Divider(height: 32),

              // Field label with required indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      field.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                  if (field.isRequired)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Required',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildFormField(field),
            ],
          ),
        ),
      );
    }

    return fields;
  }

  Widget _buildLikertTable(FormFieldModel field) {
    final questions = field.likertQuestions ?? [];

    // Parse scale options from the options field
    // Format: "label|value" for each option
    final scaleOptions = _parseLikertOptions(field);

    if (questions.isEmpty || scaleOptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          'Likert scale not properly configured',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Get saved responses
    Map<String, dynamic> savedResponses = {};
    if (_responses[field.id] is Map) {
      savedResponses = Map<String, dynamic>.from(_responses[field.id]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.poll_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Rate each statement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9C27B0),
                  ),
                ),
              ],
            ),
          ),

          // Table
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;

              if (isSmallScreen) {
                return _buildVerticalLikertLayout(
                    field, questions, scaleOptions, savedResponses);
              } else {
                return _buildHorizontalLikertTable(
                    field, questions, scaleOptions, savedResponses);
              }
            },
          ),

          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.checklist_rtl,
                  size: 16,
                  color: Color(0xFF9C27B0),
                ),
                const SizedBox(width: 8),
                Text(
                  'Progress: ${savedResponses.length}/${questions.length} questions answered',
                  style: const TextStyle(
                    color: Color(0xFF9C27B0),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalLikertTable(
    FormFieldModel field,
    List<String> questions,
    List<LikertOption> scaleOptions,
    Map<String, dynamic> savedResponses,
  ) {
    return Column(
      children: questions.asMap().entries.map((entry) {
        final index = entry.key;
        final question = entry.value;
        final questionKey = index.toString();
        final selectedValue = savedResponses[questionKey];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Options in horizontal layout
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: scaleOptions.map((option) {
                      final isSelected = selectedValue == option.value;

                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.isPreview
                                ? null
                                : () {
                                    Map<String, dynamic> currentResponses = {};
                                    if (_responses[field.id] is Map) {
                                      currentResponses =
                                          Map<String, dynamic>.from(
                                              _responses[field.id]);
                                    }
                                    currentResponses[questionKey] =
                                        option.value;
                                    _responses[field.id] = currentResponses;
                                    setState(() {});
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF9C27B0)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF9C27B0)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF333333),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVerticalLikertLayout(
    FormFieldModel field,
    List<String> questions,
    List<LikertOption> scaleOptions,
    Map<String, dynamic> savedResponses,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final questionKey = index.toString();
          final selectedValue = savedResponses[questionKey];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: scaleOptions.map((option) {
                      final isSelected = selectedValue == option.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.isPreview
                                ? null
                                : () {
                                    Map<String, dynamic> currentResponses = {};
                                    if (_responses[field.id] is Map) {
                                      currentResponses =
                                          Map<String, dynamic>.from(
                                              _responses[field.id]);
                                    }
                                    currentResponses[questionKey] =
                                        option.value;
                                    _responses[field.id] = currentResponses;
                                    setState(() {});
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF9C27B0).withOpacity(0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF9C27B0)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF9C27B0)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF9C27B0)
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF9C27B0)
                                            : const Color(0xFF333333),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<LikertOption> _parseLikertOptions(FormFieldModel field) {
    // If field.options contains likert scale options in format "label|value"
    if (field.options != null && field.options!.isNotEmpty) {
      return field.options!.map((option) {
        if (option.contains('|')) {
          final parts = option.split('|');
          return LikertOption(
            label: parts[0].trim(),
            value: parts.length > 1 ? parts[1].trim() : parts[0].trim(),
          );
        } else {
          return LikertOption(label: option, value: option);
        }
      }).toList();
    }

    // Fallback to default scale if no custom options
    final scale = field.likertScale ?? 5;
    final startLabel = field.likertStartLabel ?? 'Strongly Disagree';
    final endLabel = field.likertEndLabel ?? 'Strongly Agree';
    final middleLabel = field.likertMiddleLabel;

    List<LikertOption> options = [];

    for (int i = 1; i <= scale; i++) {
      String label;
      if (i == 1) {
        label = startLabel;
      } else if (i == scale) {
        label = endLabel;
      } else if (i == ((scale + 1) ~/ 2) &&
          middleLabel != null &&
          middleLabel.isNotEmpty) {
        label = middleLabel;
      } else {
        label = i.toString();
      }
      options.add(LikertOption(label: label, value: 'scale_$i'));
    }

    return options;
  }

  Widget _buildFormField(FormFieldModel field) {
    switch (field.type) {
      case FieldType.text:
        return FormBuilderTextField(
          name: field.id,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          enabled: !widget.isPreview,
          onChanged: (value) {
            if (value != null) {
              _responses[field.id] = value;
            }
          },
        );

      case FieldType.email:
        return FormBuilderTextField(
          name: field.id,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            prefixIcon: const Icon(Icons.email, color: AppTheme.primaryColor),
          ),
          validator: FormBuilderValidators.compose([
            if (field.isRequired) FormBuilderValidators.required(),
            FormBuilderValidators.email(),
          ]),
          keyboardType: TextInputType.emailAddress,
          enabled: !widget.isPreview,
          onChanged: (value) {
            if (value != null) {
              _responses[field.id] = value;
            }
          },
        );

      case FieldType.number:
        return FormBuilderTextField(
          name: field.id,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            prefixIcon: const Icon(Icons.numbers, color: AppTheme.primaryColor),
          ),
          validator: FormBuilderValidators.compose([
            if (field.isRequired) FormBuilderValidators.required(),
            FormBuilderValidators.numeric(),
          ]),
          keyboardType: TextInputType.number,
          enabled: !widget.isPreview,
          onChanged: (value) {
            if (value != null) {
              _responses[field.id] = value;
            }
          },
        );

      case FieldType.multiline:
        return FormBuilderTextField(
          name: field.id,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          maxLines: 5,
          minLines: 3,
          enabled: !widget.isPreview,
          onChanged: (value) {
            if (value != null) {
              _responses[field.id] = value;
            }
          },
        );

      case FieldType.textarea:
        return FormBuilderTextField(
          name: field.id,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            alignLabelWithHint: true,
          ),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          maxLines: 8,
          minLines: 6,
          enabled: !widget.isPreview,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          onChanged: (value) {
            if (value != null) {
              _responses[field.id] = value;
            }
          },
        );

      case FieldType.dropdown:
        return FormBuilderDropdown<String>(
          name: field.id,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          items: field.options!.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          enabled: !widget.isPreview,
          onChanged: (value) {
            if (value != null) {
              _responses[field.id] = value;
            }
          },
        );

      case FieldType.checkbox:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: FormBuilderCheckboxGroup<String>(
            name: field.id,
            orientation: OptionsOrientation.vertical,
            options: field.options!.map((option) {
              return FormBuilderFieldOption(
                value: option,
                child: Text(option),
              );
            }).toList(),
            validator:
                field.isRequired ? FormBuilderValidators.required() : null,
            enabled: !widget.isPreview,
            onChanged: (value) {
              if (value != null) {
                _responses[field.id] = value;
              }
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            activeColor: AppTheme.primaryColor,
          ),
        );

      case FieldType.radio:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: FormBuilderRadioGroup<String>(
            name: field.id,
            orientation: OptionsOrientation.vertical,
            options: field.options!.map((option) {
              return FormBuilderFieldOption(
                value: option,
                child: Text(option),
              );
            }).toList(),
            validator:
                field.isRequired ? FormBuilderValidators.required() : null,
            enabled: !widget.isPreview,
            onChanged: (value) {
              if (value != null) {
                _responses[field.id] = value;
              }
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            activeColor: AppTheme.primaryColor,
          ),
        );

      case FieldType.date:
        return FormBuilderDateTimePicker(
          name: field.id,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            suffixIcon:
                const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
          ),
          inputType: InputType.date,
          format: DateFormat('dd/MM/yyyy'),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          enabled: !widget.isPreview,
          onChanged: (value) {
            if (value != null) {
              _responses[field.id] = value.toString();
            }
          },
        );

      case FieldType.time:
        return FormBuilderDateTimePicker(
          name: field.id,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            fillColor: Colors.white,
            filled: true,
            suffixIcon:
                const Icon(Icons.access_time, color: AppTheme.primaryColor),
          ),
          inputType: InputType.time,
          format: DateFormat('HH:mm'),
          validator: field.isRequired ? FormBuilderValidators.required() : null,
          enabled: !widget.isPreview,
          onChanged: (value) {
            if (value != null) {
              _responses[field.id] = DateFormat('HH:mm').format(value);
            }
          },
        );

      case FieldType.image:
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          padding: const EdgeInsets.all(12),
          child: FormBuilderImagePicker(
            name: field.id,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            maxImages: 1,
            previewWidth: 150,
            previewHeight: 150,
            validator:
                field.isRequired ? FormBuilderValidators.required() : null,
            enabled: !widget.isPreview,
            showDecoration: true,
            fit: BoxFit.cover,
            onChanged: (value) async {
              if (value != null && value.isNotEmpty) {
                if (value[0] is XFile) {
                  XFile imageFile = value[0] as XFile;
                  final imagePath = 'form_images/${const Uuid().v4()}.jpg';

                  try {
                    final imageBytes = await File(imageFile.path).readAsBytes();
                    final imageUrl = await _supabaseService.uploadImage(
                      'form_images',
                      imagePath,
                      imageBytes,
                    );

                    // Get public URL
                    final publicUrl = await _supabaseService.getImageUrl(
                      'form_images',
                      imagePath,
                    );

                    _responses[field.id] = publicUrl;
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Error uploading image: ${e.toString()}')),
                    );
                  }
                }
              }
            },
          ),
        );

      case FieldType.likert:
        return _buildLikertTable(field);

      default:
        return Container();
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.saveAndValidate()) {
      // Check if all required fields are filled
      bool allRequiredFieldsFilled = true;
      for (var field in widget.form.fields) {
        if (field.isRequired &&
            (_responses[field.id] == null || _responses[field.id] == '')) {
          allRequiredFieldsFilled = false;
          break;
        }
      }

      if (!allRequiredFieldsFilled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required fields'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final user = _supabaseService.getCurrentUser();

        final formResponse = FormResponse(
          id: const Uuid().v4(),
          form_id: widget.form.id,
          responses: _responses,
          respondent_id: user?.id,
          submitted_at: DateTime.now(),
        );

        // Submit form response to Supabase
        await _supabaseService.submitFormResponse(formResponse);

        // Generate PDF
        await _generateAndDownloadPdf(formResponse);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Form submitted successfully'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Future<void> _generateAndDownloadPdf(FormResponse response) async {
    setState(() {
      _isPdfGenerating = true;
    });

    try {
      // Generate PDF with full-page images optimized for width
      final pdfFile = await _pdfService
          .generateFormResponsePdfWithFullPageImages(widget.form, response);

      // Share the PDF instead of opening it
      await _pdfService.sharePdf(pdfFile, context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPdfGenerating = false;
        });
      }
    }
  }
}
