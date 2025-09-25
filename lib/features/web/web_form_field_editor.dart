// lib/screens/web_form_field_editor.dart - Responsive & Compact Version
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/form_field.dart';
import 'package:uuid/uuid.dart';


class WebFormFieldEditor extends StatefulWidget {
  final FormFieldModel? initialField;
  final Function(FormFieldModel) onSave;

  const WebFormFieldEditor({
    super.key,
    this.initialField,
    required this.onSave,
  });

  @override
  State<WebFormFieldEditor> createState() => _WebFormFieldEditorState();
}

class _WebFormFieldEditorState extends State<WebFormFieldEditor>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  final _labelController = TextEditingController();
  final _placeholderController = TextEditingController();

  FieldType _selectedType = FieldType.text;
  bool _isRequired = false;
  final List<TextEditingController> _optionControllers = [];
  final List<TextEditingController> _likertQuestionControllers = [];

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  int _likertScale = 5;
  final _likertStartLabelController = TextEditingController();
  final _likertEndLabelController = TextEditingController();
  final _likertMiddleLabelController = TextEditingController();

  // Responsive properties
  late double _screenWidth;
  late double _screenHeight;
  late bool _isMobile;
  late bool _isTablet;

  // Responsive getters - Much more compact
  double get responsiveSpacing => _isMobile ? 6.0 : 8.0;
  double get responsivePadding => _isMobile ? 10.0 : 12.0;
  double get responsiveBorderRadius => _isMobile ? 8.0 : 10.0;
  double get responsiveIconSize => _isMobile ? 16.0 : 18.0;
  double get responsiveFontSize => _isMobile ? 12.0 : 13.0;
  double get responsiveFontSizeLarge => _isMobile ? 14.0 : 16.0;
  double get responsiveFontSizeSmall => _isMobile ? 10.0 : 11.0;

  // Dynamic dialog sizing
  double get dialogWidth => _isMobile
      ? _screenWidth * 0.95
      : _isTablet
          ? _screenWidth * 0.8
          : 520;

  double get dialogHeight => _isMobile
      ? _screenHeight * 0.9
      : _isTablet
          ? _screenHeight * 0.85
          : 600;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateResponsiveValues();
  }

  void _updateResponsiveValues() {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _isMobile = _screenWidth < 600;
    _isTablet = _screenWidth >= 600 && _screenWidth < 1024;
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250), // Faster animation
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
              _selectedType == FieldType.radio) &&
          options.isEmpty) {
        _showErrorSnackBar('Please add at least one option');
        return;
      }

      if (_selectedType == FieldType.likert) {
        if (options.isEmpty) {
          _showErrorSnackBar('Please add at least one scale option');
          return;
        }

        if (likertQuestions.isEmpty) {
          _showErrorSnackBar(
              'Please add at least one question for the Likert scale');
          return;
        }
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
        likertScale: _selectedType == FieldType.likert ? _likertScale : null,
        likertStartLabel: _selectedType == FieldType.likert &&
                _likertStartLabelController.text.isNotEmpty
            ? _likertStartLabelController.text.trim()
            : null,
        likertEndLabel: _selectedType == FieldType.likert &&
                _likertEndLabelController.text.isNotEmpty
            ? _likertEndLabelController.text.trim()
            : null,
        likertMiddleLabel: _selectedType == FieldType.likert &&
                _likertMiddleLabelController.text.isNotEmpty
            ? _likertMiddleLabelController.text.trim()
            : null,
      );

      widget.onSave(field);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: responsiveIconSize),
            SizedBox(width: responsiveSpacing),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: responsiveFontSize),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
        ),
        margin: EdgeInsets.all(responsiveSpacing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _slideAnimation.value)), // Reduced offset
          child: Opacity(
            opacity: _slideAnimation.value.clamp(0.0, 1.0),
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(responsiveBorderRadius + 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Compact Fixed Header
                  _buildHeader(),

                  // Scrollable Content
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: !_isMobile,
                      thickness: _isMobile ? 4 : 6,
                      radius: Radius.circular(responsiveBorderRadius * 0.3),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          responsivePadding + 4,
                          responsiveSpacing,
                          responsivePadding + 4,
                          responsivePadding,
                        ),
                        child: FormBuilder(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabelField(),
                              SizedBox(height: responsiveSpacing * 1.5),
                              _buildFieldTypeDropdown(),
                              SizedBox(height: responsiveSpacing * 1.5),
                              _buildPlaceholderField(),
                              if (_selectedType == FieldType.dropdown ||
                                  _selectedType == FieldType.checkbox ||
                                  _selectedType == FieldType.radio)
                                _buildOptionsSection(),
                              if (_selectedType == FieldType.likert)
                                _buildLikertSection(),
                              SizedBox(height: responsiveSpacing * 1.5),
                              _buildRequiredSwitch(),
                              SizedBox(height: responsivePadding),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Compact Fixed Action Buttons
                  Container(
                    padding: EdgeInsets.all(responsivePadding + 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(responsiveBorderRadius + 4),
                        bottomRight:
                            Radius.circular(responsiveBorderRadius + 4),
                      ),
                      border: Border(
                        top:
                            BorderSide(color: Colors.grey.shade200, width: 0.5),
                      ),
                    ),
                    child: _buildActionButtons(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(responsivePadding + 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(responsiveBorderRadius + 4),
          topRight: Radius.circular(responsiveBorderRadius + 4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsiveSpacing),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(responsiveBorderRadius),
            ),
            child: Icon(
              Icons.edit_note,
              color: Colors.white,
              size: responsiveIconSize + 2,
            ),
          ),
          SizedBox(width: responsiveSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initialField == null
                      ? 'Create New Field'
                      : 'Edit Field',
                  style: TextStyle(
                    fontSize: responsiveFontSizeLarge,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  widget.initialField == null
                      ? 'Add a new field to your form'
                      : 'Modify field properties and settings',
                  style: TextStyle(
                    fontSize: responsiveFontSizeSmall,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: responsiveIconSize + 2),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(responsiveBorderRadius * 0.6),
              ),
              padding: EdgeInsets.all(responsiveSpacing * 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelField() {
    return _buildInputSection(
      title: 'Field Label',
      subtitle: 'What should this field be called?',
      child: FormBuilderTextField(
        name: 'label',
        controller: _labelController,
        decoration: _buildInputDecoration(
          labelText: 'Field Label',
          hintText: 'e.g., Full Name, Email Address',
          prefixIcon: Icons.label_outline,
        ),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
        ]),
      ),
    );
  }

  Widget _buildFieldTypeDropdown() {
    final List<FieldType> orderedFieldTypes = [
      FieldType.text,
      FieldType.multiline,
      FieldType.textarea,
      FieldType.number,
      FieldType.email,
      FieldType.dropdown,
      FieldType.checkbox,
      FieldType.radio,
      FieldType.likert,
      FieldType.date,
      FieldType.time,
      FieldType.image,
    ];

    return _buildInputSection(
      title: 'Field Type',
      subtitle: 'Choose the type of input for this field',
      child: FormBuilderDropdown<FieldType>(
        name: 'type',
        decoration: _buildInputDecoration(
          labelText: 'Select Field Type',
          prefixIcon: Icons.tune,
        ),
        initialValue: _selectedType,
        onChanged: _onFieldTypeChanged,
        isExpanded: true,
        menuMaxHeight: _isMobile ? 250 : 350,
        selectedItemBuilder: (BuildContext context) {
          return orderedFieldTypes.map<Widget>((FieldType fieldType) {
            return Container(
              alignment: Alignment.centerLeft,
              child: Text(
                _getFieldTypeLabel(fieldType),
                style: TextStyle(
                  fontSize: responsiveFontSize + 1,
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
            child: _buildSimpleFieldTypeItem('Short Text', Icons.text_fields),
          ),
          DropdownMenuItem(
            value: FieldType.multiline,
            child: _buildSimpleFieldTypeItem('Paragraph', Icons.notes),
          ),
          DropdownMenuItem(
            value: FieldType.textarea,
            child: _buildSimpleFieldTypeItem('Text Area', Icons.text_snippet),
          ),
          DropdownMenuItem(
            value: FieldType.number,
            child: _buildSimpleFieldTypeItem('Number', Icons.numbers),
          ),
          DropdownMenuItem(
            value: FieldType.email,
            child: _buildSimpleFieldTypeItem('Email', Icons.email_outlined),
          ),
          DropdownMenuItem(
            value: FieldType.dropdown,
            child: _buildSimpleFieldTypeItem(
                'Dropdown', Icons.arrow_drop_down_circle),
          ),
          DropdownMenuItem(
            value: FieldType.checkbox,
            child:
                _buildSimpleFieldTypeItem('Checkbox', Icons.check_box_outlined),
          ),
          DropdownMenuItem(
            value: FieldType.radio,
            child: _buildSimpleFieldTypeItem(
                'Radio Button', Icons.radio_button_unchecked),
          ),
          DropdownMenuItem(
            value: FieldType.likert,
            child:
                _buildSimpleFieldTypeItem('Likert Scale', Icons.poll_outlined),
          ),
          DropdownMenuItem(
            value: FieldType.date,
            child: _buildSimpleFieldTypeItem('Date', Icons.calendar_today),
          ),
          DropdownMenuItem(
            value: FieldType.time,
            child: _buildSimpleFieldTypeItem('Time', Icons.access_time),
          ),
          DropdownMenuItem(
            value: FieldType.image,
            child:
                _buildSimpleFieldTypeItem('Image Upload', Icons.image_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderField() {
    return _buildInputSection(
      title: 'Placeholder Text',
      subtitle: 'Optional hint text shown in the field',
      child: FormBuilderTextField(
        name: 'placeholder',
        controller: _placeholderController,
        decoration: _buildInputDecoration(
          labelText: 'Placeholder (Optional)',
          hintText: 'e.g., Enter your full name here',
          prefixIcon: Icons.text_format,
        ),
      ),
    );
  }

// Part 2: Compact Likert and Options Sections

  Widget _buildLikertSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(top: responsiveSpacing * 1.5),
      child: Column(
        children: [
          // Compact Scale Configuration
          _buildInputSection(
            title: 'Likert Scale Configuration',
            subtitle: 'Configure scale options and questions',
            child: Container(
              padding: EdgeInsets.all(responsivePadding),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(responsiveBorderRadius),
                border: Border.all(color: Colors.purple.shade200, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Scale Options Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune,
                              color: Colors.purple.shade700,
                              size: responsiveIconSize),
                          SizedBox(width: responsiveSpacing * 0.8),
                          Text(
                            'Scale Options',
                            style: TextStyle(
                              fontSize: responsiveFontSize + 1,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addOptionField,
                        icon: Icon(Icons.add,
                            size: responsiveIconSize * 0.9,
                            color: Colors.white),
                        label: Text('Add Option',
                            style:
                                TextStyle(fontSize: responsiveFontSizeSmall)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: responsivePadding * 0.8,
                              vertical: responsiveSpacing * 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(responsiveBorderRadius),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsiveSpacing),

                  // Compact Options List
                  Container(
                    constraints:
                        BoxConstraints(maxHeight: _isMobile ? 150 : 180),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(responsiveBorderRadius * 0.8),
                      border:
                          Border.all(color: Colors.purple.shade100, width: 0.8),
                    ),
                    child: Scrollbar(
                      thumbVisibility: !_isMobile,
                      thickness: _isMobile ? 3 : 4,
                      radius: Radius.circular(responsiveBorderRadius * 0.3),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _optionControllers.length,
                        padding: EdgeInsets.all(responsiveSpacing),
                        itemBuilder: (context, index) {
                          // Split existing value into label and value
                          String existingLabel = '';
                          String existingValue = '';
                          if (_optionControllers[index].text.contains('|')) {
                            final parts =
                                _optionControllers[index].text.split('|');
                            existingLabel = parts[0];
                            existingValue =
                                parts.length > 1 ? parts[1] : parts[0];
                          } else {
                            existingLabel = _optionControllers[index].text;
                            existingValue = _optionControllers[index].text;
                          }

                          final labelController =
                              TextEditingController(text: existingLabel);
                          final valueController =
                              TextEditingController(text: existingValue);

                          return Container(
                            margin: EdgeInsets.only(bottom: responsiveSpacing),
                            padding: EdgeInsets.all(responsivePadding * 0.8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  responsiveBorderRadius * 0.8),
                              border: Border.all(
                                  color: Colors.purple.shade200, width: 0.8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: responsiveIconSize + 8,
                                      height: responsiveIconSize + 8,
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade600,
                                        borderRadius: BorderRadius.circular(
                                            responsiveBorderRadius * 0.6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: responsiveFontSizeSmall,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: responsiveSpacing),
                                    Expanded(
                                      child: Text(
                                        'Option ${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple.shade700,
                                          fontSize: responsiveFontSize,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _optionControllers.length > 1
                                          ? () => _removeOptionField(index)
                                          : null,
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: _optionControllers.length > 1
                                            ? Colors.red.shade600
                                            : Colors.grey.shade400,
                                        size: responsiveIconSize,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            _optionControllers.length > 1
                                                ? Colors.red.shade50
                                                : Colors.grey.shade100,
                                        padding: EdgeInsets.all(
                                            responsiveSpacing * 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: responsiveSpacing),
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
                                            borderRadius: BorderRadius.circular(
                                                responsiveBorderRadius),
                                            borderSide: BorderSide(
                                                color: Colors.purple.shade300,
                                                width: 0.8),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal:
                                                  responsivePadding * 0.8,
                                              vertical: responsiveSpacing),
                                          labelStyle: TextStyle(
                                              fontSize:
                                                  responsiveFontSizeSmall),
                                          hintStyle: TextStyle(
                                              fontSize:
                                                  responsiveFontSizeSmall),
                                        ),
                                        style: TextStyle(
                                            fontSize: responsiveFontSize),
                                        onChanged: (value) {
                                          _optionControllers[index].text =
                                              '${labelController.text}|$value';
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: responsiveSpacing),

          // Compact Questions Section
          _buildInputSection(
            title: 'Likert Questions',
            subtitle: 'Add questions that will use this scale',
            child: Container(
              padding: EdgeInsets.all(responsivePadding),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(responsiveBorderRadius),
                border: Border.all(color: Colors.purple.shade200, width: 0.8),
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
                              color: Colors.purple.shade700,
                              size: responsiveIconSize),
                          SizedBox(width: responsiveSpacing * 0.8),
                          Text(
                            'Questions List',
                            style: TextStyle(
                              fontSize: responsiveFontSize + 1,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addLikertQuestionField,
                        icon: Icon(Icons.add,
                            size: responsiveIconSize * 0.9,
                            color: Colors.white),
                        label: Text('Add Question',
                            style:
                                TextStyle(fontSize: responsiveFontSizeSmall)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: responsivePadding * 0.8,
                              vertical: responsiveSpacing * 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(responsiveBorderRadius),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsiveSpacing),

                  // Compact Questions List
                  Container(
                    constraints:
                        BoxConstraints(maxHeight: _isMobile ? 150 : 180),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(responsiveBorderRadius * 0.8),
                      border:
                          Border.all(color: Colors.purple.shade100, width: 0.8),
                    ),
                    child: Scrollbar(
                      thumbVisibility: !_isMobile,
                      thickness: _isMobile ? 3 : 4,
                      radius: Radius.circular(responsiveBorderRadius * 0.3),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _likertQuestionControllers.length,
                        padding: EdgeInsets.all(responsiveSpacing),
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.only(bottom: responsiveSpacing),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: responsiveIconSize + 8,
                                  height: responsiveIconSize + 8,
                                  margin:
                                      EdgeInsets.only(top: responsiveSpacing),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade600,
                                    borderRadius: BorderRadius.circular(
                                        responsiveBorderRadius * 0.6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: responsiveFontSizeSmall,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: responsiveSpacing),
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        _likertQuestionControllers[index],
                                    decoration: InputDecoration(
                                      labelText: 'Question ${index + 1}',
                                      hintText: 'Enter your question here',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            responsiveBorderRadius),
                                        borderSide: BorderSide(
                                            color: Colors.purple.shade300,
                                            width: 0.8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            responsiveBorderRadius),
                                        borderSide: BorderSide(
                                            color: Colors.purple.shade300,
                                            width: 0.8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            responsiveBorderRadius),
                                        borderSide: BorderSide(
                                            color: Colors.purple.shade600,
                                            width: 1.5),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: responsivePadding * 0.8,
                                          vertical: responsiveSpacing),
                                      labelStyle: TextStyle(
                                          fontSize: responsiveFontSizeSmall),
                                      hintStyle: TextStyle(
                                          fontSize: responsiveFontSizeSmall),
                                    ),
                                    style:
                                        TextStyle(fontSize: responsiveFontSize),
                                    maxLines: _isMobile ? 1 : 2,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Question cannot be empty';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(width: responsiveSpacing * 0.6),
                                Container(
                                  margin:
                                      EdgeInsets.only(top: responsiveSpacing),
                                  child: IconButton(
                                    onPressed: _likertQuestionControllers
                                                .length >
                                            1
                                        ? () =>
                                            _removeLikertQuestionField(index)
                                        : null,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color:
                                          _likertQuestionControllers.length > 1
                                              ? Colors.red.shade600
                                              : Colors.grey.shade400,
                                      size: responsiveIconSize,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          _likertQuestionControllers.length > 1
                                              ? Colors.red.shade50
                                              : Colors.grey.shade100,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            responsiveBorderRadius * 0.6),
                                      ),
                                      padding: EdgeInsets.all(
                                          responsiveSpacing * 0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(top: responsiveSpacing * 1.5),
      child: _buildInputSection(
        title: 'Field Options',
        subtitle: 'Add choices for users to select from',
        child: Container(
          padding: EdgeInsets.all(responsivePadding),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
            border: Border.all(color: Colors.blue.shade200, width: 0.8),
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
                          color: Colors.blue.shade700,
                          size: responsiveIconSize),
                      SizedBox(width: responsiveSpacing * 0.8),
                      Text(
                        'Options List',
                        style: TextStyle(
                          fontSize: responsiveFontSize + 1,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _addOptionField,
                    icon: Icon(Icons.add,
                        size: responsiveIconSize * 0.9, color: Colors.white),
                    label: Text('Add Option',
                        style: TextStyle(fontSize: responsiveFontSizeSmall)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: responsivePadding * 0.8,
                          vertical: responsiveSpacing * 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(responsiveBorderRadius),
                      ),
                      elevation: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsiveSpacing),
              Container(
                constraints: BoxConstraints(maxHeight: _isMobile ? 200 : 250),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(responsiveBorderRadius * 0.6),
                  border: Border.all(color: Colors.blue.shade100, width: 0.8),
                ),
                child: Scrollbar(
                  thumbVisibility: !_isMobile,
                  thickness: _isMobile ? 3 : 4,
                  radius: Radius.circular(responsiveBorderRadius * 0.3),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _optionControllers.length,
                    padding: EdgeInsets.all(responsiveSpacing),
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(bottom: responsiveSpacing),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: responsiveIconSize + 8,
                              height: responsiveIconSize + 8,
                              margin: EdgeInsets.only(top: responsiveSpacing),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                borderRadius: BorderRadius.circular(
                                    responsiveBorderRadius * 0.6),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: responsiveFontSizeSmall,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: responsiveSpacing),
                            Expanded(
                              child: TextFormField(
                                controller: _optionControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'Option ${index + 1}',
                                  hintText: 'Enter option text',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        responsiveBorderRadius),
                                    borderSide: BorderSide(
                                        color: Colors.blue.shade300,
                                        width: 0.8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        responsiveBorderRadius),
                                    borderSide: BorderSide(
                                        color: Colors.blue.shade300,
                                        width: 0.8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        responsiveBorderRadius),
                                    borderSide: BorderSide(
                                        color: Colors.blue.shade600,
                                        width: 1.5),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: responsivePadding * 0.8,
                                      vertical: responsiveSpacing),
                                  labelStyle: TextStyle(
                                      fontSize: responsiveFontSizeSmall),
                                  hintStyle: TextStyle(
                                      fontSize: responsiveFontSizeSmall),
                                ),
                                style: TextStyle(fontSize: responsiveFontSize),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Option cannot be empty';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: responsiveSpacing * 0.6),
                            Container(
                              margin: EdgeInsets.only(top: responsiveSpacing),
                              child: IconButton(
                                onPressed: _optionControllers.length > 1
                                    ? () => _removeOptionField(index)
                                    : null,
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: _optionControllers.length > 1
                                      ? Colors.red.shade600
                                      : Colors.grey.shade400,
                                  size: responsiveIconSize,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: _optionControllers.length > 1
                                      ? Colors.red.shade50
                                      : Colors.grey.shade100,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        responsiveBorderRadius * 0.6),
                                  ),
                                  padding:
                                      EdgeInsets.all(responsiveSpacing * 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Part 3: Final Components - Required Switch, Actions & Utilities

  Widget _buildRequiredSwitch() {
    return _buildInputSection(
      title: 'Field Settings',
      subtitle: 'Configure field requirements',
      child: Container(
        padding: EdgeInsets.all(responsivePadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade50,
              Colors.amber.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
          border: Border.all(color: Colors.orange.shade200, width: 0.8),
        ),
        child: FormBuilderSwitch(
          name: 'isRequired',
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsiveSpacing * 0.6),
                decoration: BoxDecoration(
                  color: _isRequired
                      ? Colors.orange.shade600
                      : Colors.grey.shade400,
                  borderRadius:
                      BorderRadius.circular(responsiveBorderRadius * 0.6),
                ),
                child: Icon(
                  Icons.priority_high,
                  size: responsiveIconSize * 0.9,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: responsiveSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Required Field',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: responsiveFontSize + 1,
                      ),
                    ),
                    Text(
                      'Users must fill this field before submitting',
                      style: TextStyle(
                        fontSize: responsiveFontSizeSmall,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRequired)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: responsiveSpacing,
                      vertical: responsiveSpacing * 0.3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(responsiveBorderRadius),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: TextStyle(
                      fontSize: responsiveFontSizeSmall - 1,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
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
    return _isMobile
        ? _buildMobileActionButtons()
        : _buildDesktopActionButtons();
  }

  Widget _buildMobileActionButtons() {
    return Column(
      children: [
        // Cancel button
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.cancel_outlined, size: responsiveIconSize),
            label:
                Text('Cancel', style: TextStyle(fontSize: responsiveFontSize)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400, width: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsiveBorderRadius),
              ),
            ),
          ),
        ),
        SizedBox(height: responsiveSpacing),
        // Save button
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _saveField,
            icon:
                Icon(Icons.save, color: Colors.white, size: responsiveIconSize),
            label: Text('Save Field',
                style: TextStyle(fontSize: responsiveFontSize)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsiveBorderRadius),
              ),
              elevation: 2,
              shadowColor: AppTheme.primaryColor.withOpacity(0.25),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.cancel_outlined, size: responsiveIconSize),
          label: Text('Cancel', style: TextStyle(fontSize: responsiveFontSize)),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
                horizontal: responsivePadding + 4,
                vertical: responsiveSpacing + 2),
            side: BorderSide(color: Colors.grey.shade400, width: 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(responsiveBorderRadius),
            ),
          ),
        ),
        SizedBox(width: responsiveSpacing),
        ElevatedButton.icon(
          onPressed: _saveField,
          icon: Icon(Icons.save, color: Colors.white, size: responsiveIconSize),
          label: Text('Save Field',
              style: TextStyle(fontSize: responsiveFontSize)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: responsivePadding + 4,
                vertical: responsiveSpacing + 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(responsiveBorderRadius),
            ),
            elevation: 2,
            shadowColor: AppTheme.primaryColor.withOpacity(0.25),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: responsiveFontSize + 1,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: responsiveFontSizeSmall,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: responsiveSpacing),
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
      prefixIcon: Icon(prefixIcon,
          color: AppTheme.primaryColor, size: responsiveIconSize),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        borderSide: BorderSide(color: Colors.red.shade400, width: 0.8),
      ),
      contentPadding: EdgeInsets.symmetric(
          horizontal: responsivePadding, vertical: responsiveSpacing + 2),
      labelStyle: TextStyle(fontSize: responsiveFontSizeSmall),
      hintStyle: TextStyle(fontSize: responsiveFontSizeSmall),
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
        return 'Select Field Type';
    }
  }

  Widget _buildSimpleFieldTypeItem(String label, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: responsiveSpacing, horizontal: responsiveSpacing * 0.6),
      child: Row(
        children: [
          Icon(icon, size: responsiveIconSize, color: AppTheme.primaryColor),
          SizedBox(width: responsiveSpacing),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: responsiveFontSize,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTypeItem(String label, IconData icon, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsiveSpacing * 0.6),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsiveSpacing * 0.6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.6),
            ),
            child: Icon(icon,
                size: responsiveIconSize, color: AppTheme.primaryColor),
          ),
          SizedBox(width: responsiveSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: responsiveFontSize,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: responsiveFontSizeSmall,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
