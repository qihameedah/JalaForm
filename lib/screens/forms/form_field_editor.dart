// lib/screens/forms/form_field_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:uuid/uuid.dart';
import '../../models/form_field.dart';
import '../../theme/app_theme.dart';

class FormFieldEditor extends StatefulWidget {
  final FormFieldModel? initialField;
  final Function(FormFieldModel) onSave;

  const FormFieldEditor({
    super.key,
    this.initialField,
    required this.onSave,
  });

  @override
  State<FormFieldEditor> createState() => _FormFieldEditorState();
}

class _FormFieldEditorState extends State<FormFieldEditor>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  final _labelController = TextEditingController();
  final _placeholderController = TextEditingController();

  FieldType _selectedType = FieldType.text;
  bool _isRequired = false;
  List<TextEditingController> _optionControllers = [];
  List<TextEditingController> _likertQuestionControllers = [];

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  int _likertScale = 5;
  final _likertStartLabelController = TextEditingController();
  final _likertEndLabelController = TextEditingController();
  final _likertMiddleLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    if (widget.initialField != null) {
      _labelController.text = widget.initialField!.label;
      _placeholderController.text = widget.initialField!.placeholder ?? '';
      _selectedType = widget.initialField!.type;
      _isRequired = widget.initialField!.isRequired;

      // Handle existing options
      if (widget.initialField!.options != null &&
          widget.initialField!.options!.isNotEmpty) {
        for (String option in widget.initialField!.options!) {
          final controller = TextEditingController(text: option);
          _optionControllers.add(controller);
        }
      }

      // Handle Likert scale properties
      if (widget.initialField!.type == FieldType.likert) {
        _likertScale = widget.initialField!.likertScale ?? 5;
        _likertStartLabelController.text =
            widget.initialField!.likertStartLabel ?? '';
        _likertEndLabelController.text =
            widget.initialField!.likertEndLabel ?? '';
        _likertMiddleLabelController.text =
            widget.initialField!.likertMiddleLabel ?? '';

        if (widget.initialField!.likertQuestions != null &&
            widget.initialField!.likertQuestions!.isNotEmpty) {
          for (String question in widget.initialField!.likertQuestions!) {
            final controller = TextEditingController(text: question);
            _likertQuestionControllers.add(controller);
          }
        }
      }
    }

    if (_optionControllers.isEmpty &&
        (_selectedType == FieldType.dropdown ||
            _selectedType == FieldType.checkbox ||
            _selectedType == FieldType.radio)) {
      _addOptionField();
    }

    if (_likertQuestionControllers.isEmpty &&
        _selectedType == FieldType.likert) {
      _addLikertQuestionField();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _labelController.dispose();
    _placeholderController.dispose();
    _likertStartLabelController.dispose();
    _likertEndLabelController.dispose();
    _likertMiddleLabelController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    for (var controller in _likertQuestionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addLikertQuestionField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _likertQuestionControllers.add(TextEditingController());
      });
    });
  }

  void _removeLikertQuestionField(int index) {
    if (_likertQuestionControllers.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _likertQuestionControllers[index].dispose();
          _likertQuestionControllers.removeAt(index);
        });
      });
    }
  }

  List<String> _getLikertQuestionsFromControllers() {
    return _likertQuestionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  void _addOptionField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    });
  }

  void _removeOptionField(int index) {
    if (_optionControllers.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _optionControllers[index].dispose();
          _optionControllers.removeAt(index);
        });
      });
    }
  }

  void _onFieldTypeChanged(FieldType? newType) {
    if (newType != null) {
      setState(() {
        _selectedType = newType;

        if (newType != FieldType.dropdown &&
            newType != FieldType.checkbox &&
            newType != FieldType.radio) {
          for (var controller in _optionControllers) {
            controller.dispose();
          }
          _optionControllers.clear();
        } else {
          if (_optionControllers.isEmpty) {
            _addOptionField();
          }
        }

        if (newType != FieldType.likert) {
          for (var controller in _likertQuestionControllers) {
            controller.dispose();
          }
          _likertQuestionControllers.clear();
        } else {
          if (_likertQuestionControllers.isEmpty) {
            _addLikertQuestionField();
          }
        }
      });
    }
  }

  List<String> _getOptionsFromControllers() {
    return _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  void _saveField() {
    if (_formKey.currentState!.saveAndValidate()) {
      List<String> options = _getOptionsFromControllers();
      List<String> likertQuestions = _getLikertQuestionsFromControllers();

      if ((_selectedType == FieldType.dropdown ||
              _selectedType == FieldType.checkbox ||
              _selectedType == FieldType.radio ||
              _selectedType == FieldType.likert) &&
          options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Please add at least one option'),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      if (_selectedType == FieldType.likert && likertQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Please add at least one question for the Likert scale'),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final field = FormFieldModel(
        id: widget.initialField?.id ?? const Uuid().v4(),
        label: _labelController.text.trim(),
        type: _selectedType,
        isRequired: _isRequired,
        placeholder: _placeholderController.text.isEmpty
            ? null
            : _placeholderController.text.trim(),
        options: options.isEmpty ? null : options,
        likertQuestions:
            _selectedType == FieldType.likert && likertQuestions.isNotEmpty
                ? likertQuestions
                : null,
      );

      widget.onSave(field);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * (1 - _slideAnimation.value)),
          child: Opacity(
            opacity: _slideAnimation.value.clamp(0.0, 1.0),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Colors.grey.shade50,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildDragHandle(),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                          child: FormBuilder(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 24),
                                _buildLabelField(),
                                const SizedBox(height: 20),
                                _buildFieldTypeDropdown(),
                                const SizedBox(height: 20),
                                _buildPlaceholderField(),
                                if (_selectedType == FieldType.dropdown ||
                                    _selectedType == FieldType.checkbox ||
                                    _selectedType == FieldType.radio)
                                  _buildOptionsSection(),
                                if (_selectedType == FieldType.likert)
                                  _buildLikertSection(),
                                const SizedBox(height: 20),
                                _buildRequiredSwitch(),
                                const SizedBox(height: 24),
                                _buildActionButtons(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.edit_note,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initialField == null ? 'Create Field' : 'Edit Field',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.initialField == null
                      ? 'Add a new field to your form'
                      : 'Modify field properties',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelField() {
    return _buildInputSection(
      title: 'Field Label',
      child: FormBuilderTextField(
        name: 'label',
        controller: _labelController,
        decoration: _buildInputDecoration(
          labelText: 'Field Label',
          hintText: 'e.g., Full Name, Email',
          prefixIcon: Icons.label_outline,
        ),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
        ]),
      ),
    );
  }

  Widget _buildFieldTypeDropdown() {
    // Define the field types in the exact same order as the items
    final List<FieldType> orderedFieldTypes = [
      FieldType.text,
      FieldType.multiline,
      FieldType.textarea,
      FieldType.number,
      FieldType.email,
      FieldType.dropdown,
      FieldType.checkbox,
      FieldType.radio,
      FieldType.likert, // Add this
      FieldType.date,
      FieldType.time,
      FieldType.image,
    ];

    return _buildInputSection(
      title: 'Field Type',
      child: FormBuilderDropdown<FieldType>(
        name: 'type',
        decoration: _buildInputDecoration(
          labelText: 'Select Type',
          prefixIcon: Icons.tune,
        ),
        initialValue: _selectedType,
        onChanged: _onFieldTypeChanged,
        isExpanded: true,
        menuMaxHeight: 300,
        selectedItemBuilder: (BuildContext context) {
          return orderedFieldTypes.map<Widget>((FieldType fieldType) {
            return Container(
              alignment: Alignment.centerLeft,
              child: Text(
                _getFieldTypeLabel(fieldType),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();
        },
        items: [
          DropdownMenuItem(
            value: FieldType.text,
            child: _buildFieldTypeItem('Short Text', Icons.text_fields),
          ),
          DropdownMenuItem(
            value: FieldType.multiline,
            child: _buildFieldTypeItem('Paragraph', Icons.notes),
          ),
          DropdownMenuItem(
            value: FieldType.textarea,
            child: _buildFieldTypeItem('Text Area', Icons.text_snippet),
          ),
          DropdownMenuItem(
            value: FieldType.number,
            child: _buildFieldTypeItem('Number', Icons.numbers),
          ),
          DropdownMenuItem(
            value: FieldType.email,
            child: _buildFieldTypeItem('Email', Icons.email_outlined),
          ),
          DropdownMenuItem(
            value: FieldType.dropdown,
            child:
                _buildFieldTypeItem('Dropdown', Icons.arrow_drop_down_circle),
          ),
          DropdownMenuItem(
            value: FieldType.checkbox,
            child: _buildFieldTypeItem('Checkbox', Icons.check_box_outlined),
          ),
          DropdownMenuItem(
            value: FieldType.radio,
            child: _buildFieldTypeItem(
                'Radio Button', Icons.radio_button_unchecked),
          ),
          DropdownMenuItem(
            value: FieldType.likert,
            child: _buildFieldTypeItem('Likert Scale', Icons.poll_outlined),
          ),
          DropdownMenuItem(
            value: FieldType.date,
            child: _buildFieldTypeItem('Date', Icons.calendar_today),
          ),
          DropdownMenuItem(
            value: FieldType.time,
            child: _buildFieldTypeItem('Time', Icons.access_time),
          ),
          DropdownMenuItem(
            value: FieldType.image,
            child: _buildFieldTypeItem('Image Upload', Icons.image_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildLikertSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          // Scale Configuration
          _buildInputSection(
            title: 'Likert Scale Configuration',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scale Options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune,
                              color: Colors.purple.shade700, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Scale Options',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addOptionField,
                        icon: const Icon(Icons.add,
                            size: 16, color: Colors.white),
                        label: const Text('Add Option'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Options List (Label|Value pairs)
                  ..._optionControllers.asMap().entries.map((entry) {
                    int index = entry.key;
                    TextEditingController controller = entry.value;

                    // Split existing value into label and value
                    String existingLabel = '';
                    String existingValue = '';
                    if (controller.text.contains('|')) {
                      final parts = controller.text.split('|');
                      existingLabel = parts[0];
                      existingValue = parts.length > 1 ? parts[1] : parts[0];
                    } else {
                      existingLabel = controller.text;
                      existingValue = controller.text;
                    }

                    final labelController =
                        TextEditingController(text: existingLabel);
                    final valueController =
                        TextEditingController(text: existingValue);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade600,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Option ${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _optionControllers.length > 1
                                    ? () => _removeOptionField(index)
                                    : null,
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: _optionControllers.length > 1
                                      ? Colors.red.shade600
                                      : Colors.grey.shade400,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: _optionControllers.length > 1
                                      ? Colors.red.shade50
                                      : Colors.grey.shade100,
                                  padding: const EdgeInsets.all(6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: labelController,
                                  decoration: InputDecoration(
                                    labelText: 'Display Label',
                                    hintText: 'e.g., Strongly Agree',
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.purple.shade300),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    labelStyle: const TextStyle(fontSize: 12),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (value) {
                                    // Update the main controller with label|value format
                                    controller.text =
                                        '$value|${valueController.text}';
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: valueController,
                                  decoration: InputDecoration(
                                    labelText: 'Value',
                                    hintText: 'e.g., 5',
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.purple.shade300),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    labelStyle: const TextStyle(fontSize: 12),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (value) {
                                    // Update the main controller with label|value format
                                    controller.text =
                                        '${labelController.text}|$value';
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Questions Section
          _buildInputSection(
            title: 'Likert Questions',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.quiz_outlined,
                              color: Colors.purple.shade700, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Questions',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addLikertQuestionField,
                        icon: const Icon(Icons.add,
                            size: 16, color: Colors.white),
                        label: const Text('Add Question'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Questions List
                  ..._likertQuestionControllers.asMap().entries.map((entry) {
                    int index = entry.key;
                    TextEditingController controller = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: 'Question ${index + 1}',
                                hintText: 'Enter your question here',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.purple.shade300),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                labelStyle: const TextStyle(fontSize: 12),
                              ),
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: IconButton(
                              onPressed: _likertQuestionControllers.length > 1
                                  ? () => _removeLikertQuestionField(index)
                                  : null,
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: _likertQuestionControllers.length > 1
                                    ? Colors.red.shade600
                                    : Colors.grey.shade400,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    _likertQuestionControllers.length > 1
                                        ? Colors.red.shade50
                                        : Colors.grey.shade100,
                                padding: const EdgeInsets.all(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderField() {
    return _buildInputSection(
      title: 'Placeholder Text',
      child: FormBuilderTextField(
        name: 'placeholder',
        controller: _placeholderController,
        decoration: _buildInputDecoration(
          labelText: 'Placeholder (Optional)',
          hintText: 'e.g., Enter your name',
          prefixIcon: Icons.text_format,
        ),
      ),
    );
  }

  Widget _buildOptionsSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 20),
      child: _buildInputSection(
        title: 'Field Options',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.list_alt,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Options',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _addOptionField,
                    icon: const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Use Column instead of ListView to avoid scrollable conflicts
              ..._optionControllers.asMap().entries.map((entry) {
                int index = entry.key;
                TextEditingController controller = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Option ${index + 1}',
                            hintText: 'Enter option',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.blue.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.blue.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.blue.shade600, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Option cannot be empty';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        child: IconButton(
                          onPressed: _optionControllers.length > 1
                              ? () => _removeOptionField(index)
                              : null,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: _optionControllers.length > 1
                                ? Colors.red.shade600
                                : Colors.grey.shade400,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: _optionControllers.length > 1
                                ? Colors.red.shade50
                                : Colors.grey.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.all(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequiredSwitch() {
    return _buildInputSection(
      title: 'Field Settings',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade50,
              Colors.amber.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: FormBuilderSwitch(
          name: 'isRequired',
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isRequired
                      ? Colors.orange.shade600
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.priority_high,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Required Field',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Users must fill this field',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRequired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          initialValue: _isRequired,
          onChanged: (value) {
            setState(() {
              _isRequired = value ?? false;
            });
          },
          activeColor: Colors.orange.shade600,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _saveField,
            icon: const Icon(Icons.save, color: Colors.white, size: 18),
            label: const Text('Save Field'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              shadowColor: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: AppTheme.primaryColor, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      labelStyle: const TextStyle(fontSize: 13),
    );
  }

  String _getFieldTypeLabel(FieldType fieldType) {
    switch (fieldType) {
      case FieldType.text:
        return 'Short Text';
      case FieldType.multiline:
        return 'Paragraph';
      case FieldType.textarea:
        return 'Text Area';
      case FieldType.number:
        return 'Number';
      case FieldType.email:
        return 'Email';
      case FieldType.dropdown:
        return 'Dropdown';
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.radio:
        return 'Radio Button';
      case FieldType.likert:
        return 'Likert Scale';
      case FieldType.date:
        return 'Date';
      case FieldType.time:
        return 'Time';
      case FieldType.image:
        return 'Image Upload';
      default:
        return 'Select Type';
    }
  }

  Widget _buildFieldTypeItem(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
