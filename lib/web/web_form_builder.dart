// lib/screens/web_form_builder.dart - Part 1: Main Class & State Management (Optimized)
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:jala_form/models/form_permission.dart';
import 'package:jala_form/models/user_group.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_form.dart';
import '../models/form_field.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'web_form_field_editor.dart';

class WebFormBuilder extends StatefulWidget {
  const WebFormBuilder({super.key});

  @override
  State<WebFormBuilder> createState() => _WebFormBuilderState();
}

class _WebFormBuilderState extends State<WebFormBuilder>
    with TickerProviderStateMixin {
  // Core form state
  final _formKey = GlobalKey<FormBuilderState>();
  final List<FormFieldModel> _fields = [];
  bool _isLoading = false;
  final _supabaseService = SupabaseService();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Animation controllers - simplified
  late AnimationController _pageAnimationController;
  late AnimationController _fieldAnimationController;

  // Form configuration
  bool _isChecklist = false;
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.once;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _startDate;
  DateTime? _endDate;
  FormVisibility _visibility = FormVisibility.public;
  final List<FormPermission> _permissions = [];
  List<UserGroup> _availableGroups = [];
  bool _isLoadingGroups = false;

  // Section expansion state - simplified
  int _expandedSectionIndex = 0; // 0: Fields, 1: Schedule, 2: Permissions

  // Performance optimization
  bool _hasUnsavedChanges = false;

  // Cached responsive values
  late double _screenWidth;
  late double _screenHeight;
  late bool _isMobile;
  late bool _isTablet;
  late bool _isDesktop;

  // Responsive getters - OPTIMIZED FOR COMPACT LAYOUT
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
    _isDesktop = _screenWidth >= 1024;
  }

  // OPTIMIZED responsive dimensions - Much more compact
  double get responsiveSpacing => _isMobile
      ? 6.0 // Reduced from 12.0
      : _isTablet
          ? 8.0 // Reduced from 16.0
          : 10.0; // Reduced from 20.0

  double get responsivePadding => _isMobile
      ? 10.0 // Reduced from 16.0
      : _isTablet
          ? 12.0 // Reduced from 20.0
          : 14.0; // Reduced from 24.0

  double get responsiveBorderRadius => _isMobile ? 8.0 : 10.0; // Reduced
  double get responsiveIconSize => _isMobile ? 18.0 : 20.0; // Reduced
  double get responsiveFontSize => _isMobile ? 13.0 : 14.0; // Reduced
  double get responsiveFontSizeLarge => _isMobile ? 16.0 : 18.0; // Reduced
  double get responsiveFontSizeSmall =>
      _isMobile ? 11.0 : 12.0; // New small size

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
    _setupListeners();
  }

  void _initializeAnimations() {
    _pageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Faster
      vsync: this,
    );

    _fieldAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200), // Faster
      vsync: this,
    );

    // Start animations after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageAnimationController.forward();
    });
  }

  void _setupListeners() {
    _titleController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
  }

  Future<void> _loadInitialData() async {
    await _loadGroups();
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _pageAnimationController.dispose();
    _fieldAnimationController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _loadGroups() async {
    if (!mounted) return;

    setState(() => _isLoadingGroups = true);

    try {
      _availableGroups = await _supabaseService.getMyCreatedGroups();
    } catch (e) {
      debugPrint('Error loading groups: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  // Field management methods
  void _addField(FormFieldModel field) {
    setState(() {
      _fields.add(field);
      _hasUnsavedChanges = true;
    });
    _fieldAnimationController.forward();
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  void _editField(int index, FormFieldModel updatedField) {
    setState(() {
      _fields[index] = updatedField;
      _hasUnsavedChanges = true;
    });
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
      _hasUnsavedChanges = true;
    });
  }

  // Section management
  void _toggleSection(int sectionIndex) {
    setState(() {
      _expandedSectionIndex =
          _expandedSectionIndex == sectionIndex ? -1 : sectionIndex;
    });
  }

  // Navigation and validation
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await _showUnsavedChangesDialog();
    return result ?? false;
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildUnsavedChangesDialog(),
    );
  }

  // lib/screens/web_form_builder.dart - Part 2: UI Components & Dialogs (Compact)

  // OPTIMIZED unsaved changes dialog - More compact
  Widget _buildUnsavedChangesDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: BoxConstraints(
          maxWidth: _isMobile ? _screenWidth * 0.9 : 320, // Reduced width
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(responsivePadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(responsiveBorderRadius),
                  topRight: Radius.circular(responsiveBorderRadius),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: responsiveIconSize,
                  ),
                  SizedBox(width: responsiveSpacing),
                  Text(
                    'Unsaved Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsiveFontSize + 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Compact content
            Padding(
              padding: EdgeInsets.all(responsivePadding),
              child: Column(
                children: [
                  Text(
                    'You have unsaved changes. Are you sure you want to leave?',
                    style: TextStyle(
                      fontSize: responsiveFontSize,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: responsivePadding),

                  // Compact action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(fontSize: responsiveFontSize)),
                        ),
                      ),
                      SizedBox(width: responsiveSpacing),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text('Leave',
                              style: TextStyle(fontSize: responsiveFontSize)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // OPTIMIZED compact form header
  Widget _buildFormHeader() {
    return Container(
      margin: EdgeInsets.all(responsiveSpacing),
      padding: EdgeInsets.all(responsivePadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsiveSpacing * 0.6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(responsiveBorderRadius * 0.6),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: AppTheme.primaryColor,
                  size: responsiveIconSize,
                ),
              ),
              SizedBox(width: responsiveSpacing),
              Text(
                'Form Details',
                style: TextStyle(
                  fontSize: responsiveFontSize + 2,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),

          SizedBox(height: responsiveSpacing), // Reduced spacing

          // Compact form fields
          _buildTextField(
            controller: _titleController,
            name: 'title',
            label: 'Form Title',
            hint: 'Enter a descriptive title for your form',
            icon: Icons.title_rounded,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(3),
            ]),
          ),

          SizedBox(height: responsiveSpacing * 0.8), // Reduced spacing

          _buildTextField(
            controller: _descriptionController,
            name: 'description',
            label: 'Form Description',
            hint: 'Briefly describe the purpose of this form',
            icon: Icons.notes_rounded,
            maxLines: _isMobile ? 2 : 2, // Reduced lines
            validator: FormBuilderValidators.required(),
          ),
        ],
      ),
    );
  }

  // OPTIMIZED compact text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String name,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) {
    return FormBuilderTextField(
      name: name,
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: AppTheme.primaryColor.withOpacity(0.7),
          size: responsiveIconSize,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // Reduced
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(
          horizontal: responsivePadding * 0.8, // Reduced padding
          vertical: responsiveSpacing * 0.8,
        ),
      ),
      style: TextStyle(fontSize: responsiveFontSize),
    );
  }

  // OPTIMIZED compact expandable section
  Widget _buildExpandableSection({
    required int sectionIndex,
    required String title,
    required IconData icon,
    required Widget content,
    String? subtitle,
  }) {
    final isExpanded = _expandedSectionIndex == sectionIndex;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: responsiveSpacing,
        vertical: responsiveSpacing * 0.3, // Reduced margin
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primaryColor.withOpacity(0.3)
              : Colors.grey.shade200,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isExpanded ? 0.06 : 0.03),
            blurRadius: isExpanded ? 4 : 2,
            offset: Offset(0, isExpanded ? 2 : 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Compact header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleSection(sectionIndex),
              borderRadius: BorderRadius.circular(responsiveBorderRadius),
              child: Container(
                padding:
                    EdgeInsets.all(responsivePadding * 0.8), // Reduced padding
                child: Row(
                  children: [
                    // Compact icon
                    Container(
                      padding: EdgeInsets.all(responsiveSpacing * 0.5),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius:
                            BorderRadius.circular(responsiveBorderRadius * 0.6),
                      ),
                      child: Icon(
                        icon,
                        color: isExpanded
                            ? AppTheme.primaryColor
                            : Colors.grey.shade600,
                        size: responsiveIconSize * 0.9,
                      ),
                    ),

                    SizedBox(width: responsiveSpacing * 0.8),

                    // Compact title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: responsiveFontSize + 1,
                              fontWeight: FontWeight.w600,
                              color: isExpanded
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimaryColor,
                            ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: 1),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: responsiveFontSizeSmall,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Compact expand indicator
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey.shade500,
                        size: responsiveIconSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content with smooth animation
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                responsivePadding * 0.8,
                0,
                responsivePadding * 0.8,
                responsivePadding * 0.8,
              ),
              child: content,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 150),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
  // lib/screens/web_form_builder.dart - Part 3: Field Management (Optimized)

  // OPTIMIZED compact fields section
  Widget _buildFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_fields.isEmpty) _buildEmptyFieldsState() else _buildFieldsList(),
        SizedBox(height: responsiveSpacing * 0.8),
        _buildAddFieldButton(),
      ],
    );
  }

  // OPTIMIZED compact empty state
  Widget _buildEmptyFieldsState() {
    return Container(
      padding: EdgeInsets.all(responsivePadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(responsiveSpacing),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.post_add_rounded,
              size: responsiveIconSize * 1.5, // Reduced size
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          SizedBox(height: responsiveSpacing * 0.8),
          Text(
            'No fields added yet',
            style: TextStyle(
              fontSize: responsiveFontSize + 1,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: responsiveSpacing * 0.4),
          Text(
            'Start building your form by adding fields',
            style: TextStyle(
              fontSize: responsiveFontSizeSmall,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // OPTIMIZED compact fields list
  Widget _buildFieldsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _fields.length,
        onReorder: _reorderFields,
        proxyDecorator: _buildReorderProxy,
        itemBuilder: (context, index) {
          final field = _fields[index];
          return _buildFieldItem(field, index, key: ValueKey(field.id));
        },
      ),
    );
  }

  // OPTIMIZED proxy decorator for reordering
  Widget _buildReorderProxy(
      Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Material(
          elevation: 4, // Reduced elevation
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
          child: child,
        );
      },
      child: child,
    );
  }

  // OPTIMIZED compact field item - MAJOR IMPROVEMENT
  Widget _buildFieldItem(FormFieldModel field, int index, {required Key key}) {
    final color = _getColorForFieldType(field.type);

    return Container(
      key: key,
      margin: EdgeInsets.symmetric(
        horizontal: responsiveSpacing * 0.4,
        vertical: responsiveSpacing * 0.2, // Much smaller margins
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.6),
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.6),
        child: InkWell(
          onTap: () => _editFieldDialog(index),
          borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.6),
          child: Padding(
            padding: EdgeInsets.all(responsivePadding * 0.7), // Reduced padding
            child: _buildCompactFieldLayout(field, color, index),
          ),
        ),
      ),
    );
  }

  // NEW: Ultra-compact field layout for all screen sizes
  Widget _buildCompactFieldLayout(
      FormFieldModel field, Color color, int index) {
    return Row(
      children: [
        // Compact field icon
        Container(
          width: responsiveIconSize * 1.4,
          height: responsiveIconSize * 1.4,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.4),
          ),
          child: Icon(
            _getIconForFieldType(field.type),
            color: color,
            size: responsiveIconSize * 0.8,
          ),
        ),

        SizedBox(width: responsiveSpacing * 0.7),

        // Field info - takes most space
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: responsiveFontSize,
                  color: AppTheme.textPrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  _buildCompactFieldTypeBadge(field.type, color),
                  if (field.isRequired) ...[
                    SizedBox(width: responsiveSpacing * 0.4),
                    _buildCompactRequiredBadge(color),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Compact action buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCompactIconButton(
              icon: Icons.edit_rounded,
              color: Colors.blue.shade600,
              onPressed: () => _editFieldDialog(index),
            ),
            SizedBox(width: responsiveSpacing * 0.3),
            _buildCompactIconButton(
              icon: Icons.delete_rounded,
              color: Colors.red.shade600,
              onPressed: () => _showDeleteFieldConfirmation(index),
            ),
            SizedBox(width: responsiveSpacing * 0.3),
            _buildCompactDragHandle(),
          ],
        ),
      ],
    );
  }

  // OPTIMIZED compact field type badge
  Widget _buildCompactFieldTypeBadge(FieldType type, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsiveSpacing * 0.5,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.3),
      ),
      child: Text(
        _formatFieldType(type),
        style: TextStyle(
          fontSize: responsiveFontSizeSmall - 1,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // OPTIMIZED compact required badge
  Widget _buildCompactRequiredBadge(Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsiveSpacing * 0.4,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.3),
      ),
      child: Text(
        'Required',
        style: TextStyle(
          fontSize: responsiveFontSizeSmall - 1,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // OPTIMIZED compact icon button
  Widget _buildCompactIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.all(responsiveSpacing * 0.3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: responsiveIconSize * 0.8,
          color: color,
        ),
      ),
    );
  }

  // OPTIMIZED compact drag handle
  Widget _buildCompactDragHandle() {
    return Container(
      padding: EdgeInsets.all(responsiveSpacing * 0.3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.drag_indicator_rounded,
        color: Colors.grey.shade400,
        size: responsiveIconSize * 0.7,
      ),
    );
  }

  // OPTIMIZED compact add field button
  Widget _buildAddFieldButton() {
    return Container(
      width: double.infinity,
      height: 40, // Reduced height
      child: ElevatedButton.icon(
        onPressed: _addNewField,
        icon: Icon(
          Icons.add_rounded,
          size: responsiveIconSize * 0.9,
          color: Colors.white,
        ),
        label: Text(
          'Add Field',
          style: TextStyle(
            fontSize: responsiveFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: AppTheme.primaryColor.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // Field operations
  void _addNewField() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
        ),
        child: WebFormFieldEditor(
          onSave: (field) {
            _addField(field);
            Navigator.pop(context);
            _showSuccessMessage('Field added successfully');
          },
        ),
      ),
    );
  }

  void _editFieldDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
        ),
        child: WebFormFieldEditor(
          initialField: _fields[index],
          onSave: (updatedField) {
            _editField(index, updatedField);
            Navigator.pop(context);
            _showSuccessMessage('Field updated successfully');
          },
        ),
      ),
    );
  }

  // OPTIMIZED compact delete confirmation dialog
  void _showDeleteFieldConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          constraints: BoxConstraints(
            maxWidth: _isMobile ? _screenWidth * 0.9 : 300, // Reduced width
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(responsivePadding * 0.8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(responsiveBorderRadius),
                    topRight: Radius.circular(responsiveBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade600,
                      size: responsiveIconSize,
                    ),
                    SizedBox(width: responsiveSpacing),
                    Text(
                      'Delete Field',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: responsiveFontSize + 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Compact content
              Padding(
                padding: EdgeInsets.all(responsivePadding * 0.8),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to delete "${_fields[index].label}"?',
                      style: TextStyle(
                        fontSize: responsiveFontSize,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: responsivePadding * 0.8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text('Cancel',
                                style: TextStyle(fontSize: responsiveFontSize)),
                          ),
                        ),
                        SizedBox(width: responsiveSpacing),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _removeField(index);
                              Navigator.pop(context);
                              _showSuccessMessage('Field deleted');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text('Delete',
                                style: TextStyle(fontSize: responsiveFontSize)),
                          ),
                        ),
                      ],
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

  // Helper methods for field types
  IconData _getIconForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
        return Icons.text_fields_rounded;
      case FieldType.number:
        return Icons.numbers_rounded;
      case FieldType.email:
        return Icons.email_rounded;
      case FieldType.multiline:
        return Icons.short_text_rounded;
      case FieldType.textarea:
        return Icons.notes_rounded;
      case FieldType.dropdown:
        return Icons.arrow_drop_down_circle_rounded;
      case FieldType.checkbox:
        return Icons.check_box_rounded;
      case FieldType.radio:
        return Icons.radio_button_checked_rounded;
      case FieldType.date:
        return Icons.calendar_today_rounded;
      case FieldType.time:
        return Icons.access_time_rounded;
      case FieldType.image:
        return Icons.image_rounded;
      case FieldType.likert:
        return Icons.poll_rounded;
      default:
        return Icons.input_rounded;
    }
  }

  Color _getColorForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
      case FieldType.multiline:
      case FieldType.textarea:
        return Colors.blue.shade600;
      case FieldType.number:
        return Colors.orange.shade600;
      case FieldType.email:
        return Colors.indigo.shade600;
      case FieldType.dropdown:
        return Colors.purple.shade600;
      case FieldType.checkbox:
        return Colors.green.shade600;
      case FieldType.radio:
        return Colors.cyan.shade600;
      case FieldType.date:
        return Colors.red.shade600;
      case FieldType.time:
        return Colors.teal.shade600;
      case FieldType.image:
        return Colors.pink.shade600;
      case FieldType.likert:
        return Colors.deepPurple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatFieldType(FieldType type) {
    final typeStr = type.toString().split('.').last;
    // Convert camelCase to Title Case
    return typeStr.replaceAllMapped(
      RegExp(r'^([a-z])|([A-Z])'),
      (Match match) => match.group(1)?.toUpperCase() ?? ' ${match.group(2)}',
    );
  }

  // OPTIMIZED compact success message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: responsiveIconSize * 0.9,
            ),
            SizedBox(width: responsiveSpacing * 0.8),
            Text(
              message,
              style: TextStyle(fontSize: responsiveFontSize),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        margin: EdgeInsets.all(responsiveSpacing),
      ),
    );
  }

  // OPTIMIZED compact error message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_rounded,
              color: Colors.white,
              size: responsiveIconSize * 0.9,
            ),
            SizedBox(width: responsiveSpacing * 0.8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: responsiveFontSize),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        margin: EdgeInsets.all(responsiveSpacing),
      ),
    );
  }
  // lib/screens/web_form_builder.dart - Part 4: Scheduling Section (Compact)

  // OPTIMIZED compact scheduling section
  Widget _buildSchedulingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChecklistToggle(),
        if (_isChecklist) ...[
          SizedBox(height: responsiveSpacing * 0.8),
          _buildTimeWindowCard(),
          SizedBox(height: responsiveSpacing * 0.8),
          _buildRecurrenceCard(),
        ],
      ],
    );
  }

  // OPTIMIZED compact checklist toggle
  Widget _buildChecklistToggle() {
    return Container(
      padding: EdgeInsets.all(responsivePadding * 0.8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        border: Border.all(
          color: _isChecklist ? Colors.blue.shade300 : Colors.grey.shade300,
          width: _isChecklist ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsiveSpacing * 0.5),
            decoration: BoxDecoration(
              color: _isChecklist ? Colors.blue.shade100 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.checklist_rounded,
              color: _isChecklist ? Colors.blue.shade600 : Colors.grey.shade600,
              size: responsiveIconSize * 0.9,
            ),
          ),
          SizedBox(width: responsiveSpacing * 0.8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checklist Form',
                  style: TextStyle(
                    fontSize: responsiveFontSize + 1,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Enable time windows and recurring schedules',
                  style: TextStyle(
                    fontSize: responsiveFontSizeSmall,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8, // Smaller switch
            child: Switch(
              value: _isChecklist,
              activeColor: Colors.blue.shade600,
              onChanged: (value) {
                setState(() {
                  _isChecklist = value;
                  _hasUnsavedChanges = true;
                  // Set default times if enabling checklist
                  if (value) {
                    _startTime ??= const TimeOfDay(hour: 8, minute: 0);
                    _endTime ??= const TimeOfDay(hour: 17, minute: 0);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // OPTIMIZED compact time window card
  Widget _buildTimeWindowCard() {
    return Container(
      padding: EdgeInsets.all(responsivePadding * 0.8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsiveSpacing * 0.5),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius:
                      BorderRadius.circular(responsiveBorderRadius * 0.6),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: Colors.blue.shade600,
                  size: responsiveIconSize * 0.9,
                ),
              ),
              SizedBox(width: responsiveSpacing * 0.8),
              Text(
                'Time Window',
                style: TextStyle(
                  fontSize: responsiveFontSize + 1,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: responsiveSpacing * 0.8),
          _isMobile ? _buildMobileTimeInputs() : _buildDesktopTimeInputs(),
        ],
      ),
    );
  }

  // OPTIMIZED compact mobile time inputs
  Widget _buildMobileTimeInputs() {
    return Column(
      children: [
        _buildTimeInput(
          label: 'Start Time',
          value: _startTime,
          onTap: () => _selectTime(true),
        ),
        SizedBox(height: responsiveSpacing * 0.8),
        _buildTimeInput(
          label: 'End Time',
          value: _endTime,
          onTap: () => _selectTime(false),
        ),
      ],
    );
  }

  // OPTIMIZED compact desktop time inputs
  Widget _buildDesktopTimeInputs() {
    return Row(
      children: [
        Expanded(
          child: _buildTimeInput(
            label: 'Start Time',
            value: _startTime,
            onTap: () => _selectTime(true),
          ),
        ),
        SizedBox(width: responsiveSpacing),
        Expanded(
          child: _buildTimeInput(
            label: 'End Time',
            value: _endTime,
            onTap: () => _selectTime(false),
          ),
        ),
      ],
    );
  }

  // OPTIMIZED compact time input component
  Widget _buildTimeInput({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(responsivePadding * 0.8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(
            color: value != null ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: responsiveFontSizeSmall,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value?.format(context) ?? 'Select time',
                    style: TextStyle(
                      fontSize: responsiveFontSize,
                      fontWeight:
                          value != null ? FontWeight.w600 : FontWeight.normal,
                      color:
                          value != null ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: responsiveIconSize * 0.9,
                  color: value != null
                      ? Colors.blue.shade600
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Time picker method (unchanged but optimized theme)
  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? initialTime = isStartTime ? _startTime : _endTime;
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: AppTheme.primaryColor,
              dayPeriodTextColor: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      setState(() {
        if (isStartTime) {
          _startTime = selectedTime;
        } else {
          _endTime = selectedTime;
        }
        _hasUnsavedChanges = true;
      });
    }
  }

  // OPTIMIZED compact recurrence card
  Widget _buildRecurrenceCard() {
    return Container(
      padding: EdgeInsets.all(responsivePadding * 0.8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        border: Border.all(
          color: _isRecurring ? Colors.green.shade300 : Colors.grey.shade200,
          width: _isRecurring ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsiveSpacing * 0.5),
                decoration: BoxDecoration(
                  color: _isRecurring
                      ? Colors.green.shade100
                      : Colors.grey.shade100,
                  borderRadius:
                      BorderRadius.circular(responsiveBorderRadius * 0.6),
                ),
                child: Icon(
                  Icons.repeat_rounded,
                  color: _isRecurring
                      ? Colors.green.shade600
                      : Colors.grey.shade600,
                  size: responsiveIconSize * 0.9,
                ),
              ),
              SizedBox(width: responsiveSpacing * 0.8),
              Expanded(
                child: Text(
                  'Recurring Schedule',
                  style: TextStyle(
                    fontSize: responsiveFontSize + 1,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isRecurring,
                  activeColor: Colors.green.shade600,
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_isRecurring) ...[
            SizedBox(height: responsiveSpacing * 0.8),
            _buildRecurrenceOptions(),
          ],
        ],
      ),
    );
  }

  // OPTIMIZED compact recurrence options
  Widget _buildRecurrenceOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recurrence Pattern',
          style: TextStyle(
            fontSize: responsiveFontSizeSmall,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: responsiveSpacing * 0.6),
        Wrap(
          spacing: responsiveSpacing * 0.5,
          runSpacing: responsiveSpacing * 0.4,
          children: RecurrenceType.values.map((type) {
            return _buildRecurrenceChip(type);
          }).toList(),
        ),
        SizedBox(height: responsiveSpacing * 0.8),
        _isMobile ? _buildMobileDateInputs() : _buildDesktopDateInputs(),
      ],
    );
  }

  // OPTIMIZED compact recurrence chip
  Widget _buildRecurrenceChip(RecurrenceType type) {
    final isSelected = _recurrenceType == type;
    final (label, icon) = _getRecurrenceInfo(type);

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: responsiveIconSize * 0.7,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
          SizedBox(width: responsiveSpacing * 0.4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _recurrenceType = type;
            _hasUnsavedChanges = true;
          });
        }
      },
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: responsiveFontSizeSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.6),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: responsiveSpacing * 0.6,
        vertical: responsiveSpacing * 0.2,
      ),
    );
  }

  // Helper method for recurrence info (unchanged)
  (String, IconData) _getRecurrenceInfo(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.once:
        return ('Once', Icons.looks_one_rounded);
      case RecurrenceType.daily:
        return ('Daily', Icons.today_rounded);
      case RecurrenceType.weekly:
        return ('Weekly', Icons.view_week_rounded);
      case RecurrenceType.monthly:
        return ('Monthly', Icons.calendar_month_rounded);
      case RecurrenceType.yearly:
        return ('Yearly', Icons.event_rounded);
      case RecurrenceType.custom:
        return ('Custom', Icons.tune_rounded);
    }
  }
  // lib/screens/web_form_builder.dart - Part 5: Date Inputs & Permissions Section (Compact)

  // OPTIMIZED compact mobile date inputs
  Widget _buildMobileDateInputs() {
    return Column(
      children: [
        _buildDateInput(
          label: 'Start Date',
          value: _startDate,
          onTap: () => _selectDate(true),
        ),
        SizedBox(height: responsiveSpacing * 0.8),
        _buildDateInput(
          label: 'End Date',
          value: _endDate,
          onTap: () => _selectDate(false),
        ),
      ],
    );
  }

  // OPTIMIZED compact desktop date inputs
  Widget _buildDesktopDateInputs() {
    return Row(
      children: [
        Expanded(
          child: _buildDateInput(
            label: 'Start Date',
            value: _startDate,
            onTap: () => _selectDate(true),
          ),
        ),
        SizedBox(width: responsiveSpacing),
        Expanded(
          child: _buildDateInput(
            label: 'End Date',
            value: _endDate,
            onTap: () => _selectDate(false),
          ),
        ),
      ],
    );
  }

  // OPTIMIZED compact date input component
  Widget _buildDateInput({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(responsivePadding * 0.8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(
            color: value != null ? Colors.green.shade300 : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: responsiveFontSizeSmall,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: responsiveFontSize,
                      fontWeight:
                          value != null ? FontWeight.w600 : FontWeight.normal,
                      color:
                          value != null ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: responsiveIconSize * 0.9,
                  color: value != null
                      ? Colors.green.shade600
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Date picker method (unchanged)
  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ??
              _startDate?.add(const Duration(days: 30)) ??
              DateTime.now().add(const Duration(days: 30))),
      firstDate: isStartDate ? DateTime.now() : (_startDate ?? DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: AppTheme.primaryColor,
              headerForegroundColor: Colors.white,
              dayForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return Colors.black87;
              }),
              dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppTheme.primaryColor;
                }
                return Colors.transparent;
              }),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;
          // Adjust end date if it's before start date
          if (_endDate != null && _endDate!.isBefore(selectedDate)) {
            _endDate = selectedDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = selectedDate;
        }
        _hasUnsavedChanges = true;
      });
    }
  }

  // OPTIMIZED compact permissions section
  Widget _buildPermissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAccessTypeSelector(),
        if (_visibility == FormVisibility.private) ...[
          SizedBox(height: responsiveSpacing * 0.8),
          _buildPermissionActions(),
          SizedBox(height: responsiveSpacing * 0.8),
          _permissions.isNotEmpty
              ? _buildPermissionsList()
              : _buildEmptyPermissionsState(),
        ],
      ],
    );
  }

  // OPTIMIZED compact access type selector
  Widget _buildAccessTypeSelector() {
    return Container(
      padding: EdgeInsets.all(responsivePadding * 0.8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade50,
            Colors.blue.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who can access this form?',
            style: TextStyle(
              fontSize: responsiveFontSize + 1,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: responsiveSpacing * 0.8),
          _isMobile
              ? _buildMobileAccessOptions()
              : _buildDesktopAccessOptions(),
        ],
      ),
    );
  }

  // OPTIMIZED compact mobile access options
  Widget _buildMobileAccessOptions() {
    return Column(
      children: [
        _buildAccessOption(
          title: 'Public Access',
          subtitle: 'All authenticated users can access',
          icon: Icons.public_rounded,
          isSelected: _visibility == FormVisibility.public,
          color: Colors.green.shade600,
          onTap: () => _setVisibility(FormVisibility.public),
        ),
        SizedBox(height: responsiveSpacing * 0.8),
        _buildAccessOption(
          title: 'Private Access',
          subtitle: 'Only specific users and groups',
          icon: Icons.lock_rounded,
          isSelected: _visibility == FormVisibility.private,
          color: Colors.orange.shade600,
          onTap: () => _setVisibility(FormVisibility.private),
        ),
      ],
    );
  }

  // OPTIMIZED compact desktop access options
  Widget _buildDesktopAccessOptions() {
    return Row(
      children: [
        Expanded(
          child: _buildAccessOption(
            title: 'Public Access',
            subtitle: 'All authenticated users can access',
            icon: Icons.public_rounded,
            isSelected: _visibility == FormVisibility.public,
            color: Colors.green.shade600,
            onTap: () => _setVisibility(FormVisibility.public),
          ),
        ),
        SizedBox(width: responsiveSpacing),
        Expanded(
          child: _buildAccessOption(
            title: 'Private Access',
            subtitle: 'Only specific users and groups',
            icon: Icons.lock_rounded,
            isSelected: _visibility == FormVisibility.private,
            color: Colors.orange.shade600,
            onTap: () => _setVisibility(FormVisibility.private),
          ),
        ),
      ],
    );
  }

  // OPTIMIZED compact access option component
  Widget _buildAccessOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.white,
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
          child: Padding(
            padding: EdgeInsets.all(responsivePadding * 0.8),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(responsiveSpacing * 0.7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.2)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: responsiveIconSize,
                    color: isSelected ? color : Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: responsiveSpacing * 0.7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: responsiveFontSize,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: responsiveFontSizeSmall,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setVisibility(FormVisibility visibility) {
    setState(() {
      _visibility = visibility;
      _hasUnsavedChanges = true;
    });
  }

  // OPTIMIZED compact permission actions
  Widget _buildPermissionActions() {
    return _isMobile
        ? _buildMobilePermissionActions()
        : _buildDesktopPermissionActions();
  }

  Widget _buildMobilePermissionActions() {
    return Column(
      children: [
        _buildPermissionActionButton(
          icon: Icons.person_add_rounded,
          label: 'Add User',
          color: AppTheme.primaryColor,
          onPressed: _isLoadingGroups ? null : _addUserToForm,
        ),
        SizedBox(height: responsiveSpacing * 0.8),
        _buildPermissionActionButton(
          icon: Icons.group_add_rounded,
          label: 'Add Group',
          color: AppTheme.secondaryColor,
          onPressed: _isLoadingGroups ? null : _addGroupToForm,
        ),
      ],
    );
  }

  Widget _buildDesktopPermissionActions() {
    return Row(
      children: [
        Expanded(
          child: _buildPermissionActionButton(
            icon: Icons.person_add_rounded,
            label: 'Add User',
            color: AppTheme.primaryColor,
            onPressed: _isLoadingGroups ? null : _addUserToForm,
          ),
        ),
        SizedBox(width: responsiveSpacing),
        Expanded(
          child: _buildPermissionActionButton(
            icon: Icons.group_add_rounded,
            label: 'Add Group',
            color: AppTheme.secondaryColor,
            onPressed: _isLoadingGroups ? null : _addGroupToForm,
          ),
        ),
      ],
    );
  }

  // OPTIMIZED compact permission action button
  Widget _buildPermissionActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 36, // Reduced height
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: responsiveIconSize * 0.9),
        label: Text(
          label,
          style: TextStyle(
            fontSize: responsiveFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: color.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // OPTIMIZED compact permissions list
  Widget _buildPermissionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Current Access',
              style: TextStyle(
                fontSize: responsiveFontSize + 1,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsiveSpacing * 0.8,
                vertical: responsiveSpacing * 0.3,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(responsiveBorderRadius * 0.6),
              ),
              child: Text(
                '${_permissions.length} ${_permissions.length == 1 ? "item" : "items"}',
                style: TextStyle(
                  fontSize: responsiveFontSizeSmall,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: responsiveSpacing * 0.8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _permissions.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final permission = _permissions[index];
              return _buildPermissionItem(permission, index);
            },
          ),
        ),
      ],
    );
  }

  // OPTIMIZED compact permission item
  Widget _buildPermissionItem(FormPermission permission, int index) {
    final isUser = permission.user_id != null;
    final name = isUser
        ? (permission.user_email ?? 'User')
        : (permission.group_name ?? 'Group');
    final color = isUser ? AppTheme.primaryColor : AppTheme.secondaryColor;

    return ListTile(
      dense: true, // Make it more compact
      contentPadding: EdgeInsets.symmetric(
        horizontal: responsivePadding * 0.8,
        vertical: responsiveSpacing * 0.2,
      ),
      leading: Container(
        padding: EdgeInsets.all(responsiveSpacing * 0.5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isUser ? Icons.person_rounded : Icons.group_rounded,
          color: color,
          size: responsiveIconSize * 0.9,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: responsiveFontSize,
        ),
      ),
      subtitle: Container(
        margin: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsiveSpacing * 0.5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(responsiveBorderRadius * 0.3),
              ),
              child: Text(
                isUser ? 'User' : 'Group',
                style: TextStyle(
                  fontSize: responsiveFontSizeSmall - 1,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.remove_circle_rounded,
          color: Colors.red.shade600,
          size: responsiveIconSize * 0.9,
        ),
        onPressed: () => _removePermission(index),
        tooltip: 'Remove access',
        constraints: BoxConstraints(
          minWidth: responsiveIconSize * 1.5,
          minHeight: responsiveIconSize * 1.5,
        ),
      ),
    );
  }

  void _removePermission(int index) {
    setState(() {
      _permissions.removeAt(index);
      _hasUnsavedChanges = true;
    });
    _showSuccessMessage('Access removed');
  }

  // OPTIMIZED compact empty permissions state
  Widget _buildEmptyPermissionsState() {
    return Container(
      padding: EdgeInsets.all(responsivePadding),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(responsiveSpacing * 0.7),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_rounded,
              color: Colors.blue.shade600,
              size: responsiveIconSize,
            ),
          ),
          SizedBox(height: responsiveSpacing * 0.8),
          Text(
            'No users or groups added yet',
            style: TextStyle(
              fontSize: responsiveFontSize + 1,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: responsiveSpacing * 0.4),
          Text(
            'This form will only be accessible by you.\nAdd users or groups to share it.',
            style: TextStyle(
              fontSize: responsiveFontSizeSmall,
              color: Colors.blue.shade600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  // lib/screens/web_form_builder.dart - Part 6: User Management & Build Methods (Compact)

  // Add user to form method (unchanged but optimized dialogs)
  Future<void> _addUserToForm() async {
    setState(() => _isLoading = true);

    try {
      final allUsers = await _supabaseService.getAllUsers();
      final existingUserIds = _permissions
          .where((p) => p.user_id != null)
          .map((p) => p.user_id)
          .toSet();

      final availableUsers = allUsers
          .where((user) => !existingUserIds.contains(user['id']))
          .toList();

      if (mounted) {
        setState(() => _isLoading = false);

        if (availableUsers.isEmpty) {
          _showErrorMessage('No more users available to add');
          return;
        }

        await _showUserSelectionDialog(availableUsers);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('Error loading users: ${e.toString()}');
      }
    }
  }

  // OPTIMIZED compact user selection dialog
  Future<void> _showUserSelectionDialog(
      List<Map<String, dynamic>> users) async {
    final selectedUsers = <Map<String, dynamic>>[];
    String searchQuery = '';

    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final filteredUsers = users.where((user) {
              final email = user['email'].toString().toLowerCase();
              final username = user['username']?.toString().toLowerCase() ?? '';
              return email.contains(searchQuery.toLowerCase()) ||
                  username.contains(searchQuery.toLowerCase());
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsiveBorderRadius),
              ),
              child: Container(
                width: _isMobile ? _screenWidth * 0.95 : 450, // Reduced width
                height: _screenHeight * 0.65, // Reduced height
                padding: EdgeInsets.all(responsivePadding * 0.8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compact header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(responsiveSpacing * 0.5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add_rounded,
                            color: AppTheme.primaryColor,
                            size: responsiveIconSize,
                          ),
                        ),
                        SizedBox(width: responsiveSpacing * 0.8),
                        Expanded(
                          child: Text(
                            'Add Users',
                            style: TextStyle(
                              fontSize: responsiveFontSize + 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                          constraints: BoxConstraints(
                            minWidth: responsiveIconSize * 1.5,
                            minHeight: responsiveIconSize * 1.5,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: responsiveSpacing * 0.8),

                    // Compact search bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: responsivePadding * 0.8,
                          vertical: responsiveSpacing * 0.8,
                        ),
                      ),
                      style: TextStyle(fontSize: responsiveFontSize),
                      onChanged: (value) {
                        dialogSetState(() => searchQuery = value);
                      },
                    ),

                    SizedBox(height: responsiveSpacing * 0.8),

                    // Compact users count
                    Row(
                      children: [
                        Text(
                          '${filteredUsers.length} users found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: responsiveFontSizeSmall,
                          ),
                        ),
                        const Spacer(),
                        if (selectedUsers.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsiveSpacing * 0.8,
                              vertical: responsiveSpacing * 0.3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                  responsiveBorderRadius * 0.6),
                            ),
                            child: Text(
                              '${selectedUsers.length} selected',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: responsiveFontSizeSmall,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: responsiveSpacing * 0.6),

                    // Compact users list
                    Expanded(
                      child: _buildUserSelectionList(
                          filteredUsers, selectedUsers, dialogSetState),
                    ),

                    SizedBox(height: responsiveSpacing * 0.8),

                    // Compact action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsivePadding,
                              vertical: responsiveSpacing * 0.8,
                            ),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(fontSize: responsiveFontSize)),
                        ),
                        SizedBox(width: responsiveSpacing),
                        ElevatedButton(
                          onPressed: selectedUsers.isEmpty
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  List<Map<String, dynamic>>.from(
                                      selectedUsers)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: responsivePadding,
                              vertical: responsiveSpacing * 0.8,
                            ),
                          ),
                          child: Text(
                            'Add ${selectedUsers.length} User${selectedUsers.length != 1 ? 's' : ''}',
                            style: TextStyle(fontSize: responsiveFontSize),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        for (final user in result) {
          _permissions.add(FormPermission(
            id: const Uuid().v4(),
            form_id: '',
            user_id: user['id'],
            created_at: DateTime.now(),
            user_email: user['email'],
          ));
        }
        _hasUnsavedChanges = true;
      });

      _showSuccessMessage(
          '${result.length} user${result.length == 1 ? '' : 's'} added');
    }
  }

  // OPTIMIZED compact user selection list
  Widget _buildUserSelectionList(
    List<Map<String, dynamic>> users,
    List<Map<String, dynamic>> selectedUsers,
    StateSetter dialogSetState,
  ) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: responsiveIconSize * 1.5,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: responsiveSpacing),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: responsiveFontSize,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelected = selectedUsers.any((u) => u['id'] == user['id']);

        return CheckboxListTile(
          dense: true, // Make it more compact
          value: isSelected,
          onChanged: (value) {
            dialogSetState(() {
              if (value == true) {
                selectedUsers.add(user);
              } else {
                selectedUsers.removeWhere((u) => u['id'] == user['id']);
              }
            });
          },
          title: Text(
            user['username'] ?? 'User',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: responsiveFontSize,
            ),
          ),
          subtitle: Text(
            user['email'] ?? '',
            style: TextStyle(
              fontSize: responsiveFontSizeSmall,
              color: Colors.grey.shade600,
            ),
          ),
          secondary: Container(
            width: responsiveIconSize * 1.2,
            height: responsiveIconSize * 1.2,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (user['username'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: responsiveFontSizeSmall,
                ),
              ),
            ),
          ),
          activeColor: AppTheme.primaryColor,
          contentPadding: EdgeInsets.symmetric(
            horizontal: responsiveSpacing * 0.5,
            vertical: responsiveSpacing * 0.2,
          ),
        );
      },
    );
  }

  // Add group to form method (unchanged)
  Future<void> _addGroupToForm() async {
    if (_availableGroups.isEmpty) {
      _showErrorMessage('You haven\'t created any groups yet');
      return;
    }

    final existingGroupIds = _permissions
        .where((p) => p.group_id != null)
        .map((p) => p.group_id)
        .toSet();

    final availableGroups = _availableGroups
        .where((group) => !existingGroupIds.contains(group.id))
        .toList();

    if (availableGroups.isEmpty) {
      _showErrorMessage('All your groups are already added');
      return;
    }

    final result = await _showGroupSelectionDialog(availableGroups);
    if (result != null) {
      setState(() {
        _permissions.add(FormPermission(
          id: const Uuid().v4(),
          form_id: '',
          group_id: result.id,
          created_at: DateTime.now(),
          group_name: result.name,
        ));
        _hasUnsavedChanges = true;
      });

      _showSuccessMessage('Added group: ${result.name}');
    }
  }

  // OPTIMIZED compact group selection dialog
  Future<UserGroup?> _showGroupSelectionDialog(List<UserGroup> groups) {
    return showDialog<UserGroup>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
        ),
        child: Container(
          width: _isMobile ? _screenWidth * 0.9 : 350, // Reduced width
          padding: EdgeInsets.all(responsivePadding * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(responsiveSpacing * 0.5),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.group_add_rounded,
                      color: AppTheme.secondaryColor,
                      size: responsiveIconSize,
                    ),
                  ),
                  SizedBox(width: responsiveSpacing * 0.8),
                  Expanded(
                    child: Text(
                      'Add Group',
                      style: TextStyle(
                        fontSize: responsiveFontSize + 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    constraints: BoxConstraints(
                      minWidth: responsiveIconSize * 1.5,
                      minHeight: responsiveIconSize * 1.5,
                    ),
                  ),
                ],
              ),

              SizedBox(height: responsiveSpacing * 0.8),

              Text(
                'Select a group to give access to:',
                style: TextStyle(
                  fontSize: responsiveFontSize,
                  color: Colors.grey.shade600,
                ),
              ),

              SizedBox(height: responsiveSpacing * 0.8),

              // Compact groups list
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _screenHeight * 0.35),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: EdgeInsets.all(responsiveSpacing * 0.4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.group_rounded,
                            color: AppTheme.secondaryColor,
                            size: responsiveIconSize * 0.8,
                          ),
                        ),
                        title: Text(
                          group.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: responsiveFontSize,
                          ),
                        ),
                        subtitle: Text(
                          group.description,
                          style: TextStyle(
                            fontSize: responsiveFontSizeSmall,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, group),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: responsivePadding * 0.8,
                          vertical: responsiveSpacing * 0.4,
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
  // lib/screens/web_form_builder.dart - Part 7: Final Build Methods & Save Logic (Compact)

  // Save form method (unchanged logic but optimized dialogs)
  Future<void> _saveForm() async {
    if (!_formKey.currentState!.saveAndValidate()) return;

    // Validation
    if (_fields.isEmpty) {
      _showErrorMessage('Please add at least one field to your form');
      return;
    }

    if (_isChecklist && (_startTime == null || _endTime == null)) {
      _showErrorMessage(
          'Please set both start and end times for your checklist');
      return;
    }

    if (_isChecklist && _isRecurring && _startDate == null) {
      _showErrorMessage('Please set a start date for your recurring checklist');
      return;
    }

    // Confirm if private form with no permissions
    if (_visibility == FormVisibility.private && _permissions.isEmpty) {
      final confirm = await _showPrivateFormConfirmation();
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      final formId = const Uuid().v4();

      // Prepare recurrence config
      Map<String, dynamic>? recurrenceConfig;
      if (_isRecurring) {
        recurrenceConfig = {
          'type': _recurrenceType.toString().split('.').last,
        };
      }

      final newForm = CustomForm(
        id: formId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        fields: _fields,
        created_by: user.id,
        created_at: DateTime.now(),
        visibility: _visibility,
        isRecurring: _isRecurring,
        recurrenceType: _isRecurring ? _recurrenceType : null,
        recurrenceConfig: recurrenceConfig,
        startTime: _startTime,
        endTime: _endTime,
        startDate: _startDate,
        endDate: _endDate,
        isChecklist: _isChecklist,
        timeZone: 'UTC',
      );

      await _supabaseService.createForm(newForm);

      // Add permissions for private forms
      if (_visibility == FormVisibility.private && _permissions.isNotEmpty) {
        for (var permission in _permissions) {
          final formPermission = FormPermission(
            id: const Uuid().v4(),
            form_id: formId,
            user_id: permission.user_id,
            group_id: permission.group_id,
            created_at: DateTime.now(),
            user_email: permission.user_email,
            group_name: permission.group_name,
          );
          await _supabaseService.addFormPermission(formPermission);
        }
      }

      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        _showSuccessMessage('Form created successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Error creating form: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // OPTIMIZED compact private form confirmation dialog
  Future<bool?> _showPrivateFormConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_rounded,
              color: Colors.orange.shade600,
              size: responsiveIconSize,
            ),
            SizedBox(width: responsiveSpacing * 0.8),
            const Text('Private Form'),
          ],
        ),
        titleTextStyle: TextStyle(
          fontSize: responsiveFontSize + 1,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
        content: Text(
          'This form will only be visible to you. Are you sure you want to continue?',
          style: TextStyle(fontSize: responsiveFontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Cancel', style: TextStyle(fontSize: responsiveFontSize)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: responsivePadding,
                vertical: responsiveSpacing * 0.8,
              ),
            ),
            child: Text('Continue',
                style: TextStyle(fontSize: responsiveFontSize)),
          ),
        ],
      ),
    );
  }

  // OPTIMIZED main build method - Compact layout
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: _isLoading ? _buildLoadingState() : _buildFormContent(),
      ),
    );
  }

  // OPTIMIZED compact app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      toolbarHeight: 56, // Standard height
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsiveSpacing * 0.4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.create_rounded,
                size: responsiveIconSize * 0.9, color: Colors.white),
          ),
          SizedBox(width: responsiveSpacing * 0.8),
          Text(
            'Create Form',
            style: TextStyle(
              fontSize: responsiveFontSize + 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () async {
          if (await _onWillPop()) {
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        if (_hasUnsavedChanges)
          Container(
            margin: EdgeInsets.only(right: responsiveSpacing),
            padding: EdgeInsets.symmetric(
              horizontal: responsiveSpacing * 0.8,
              vertical: responsiveSpacing * 0.4,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(responsiveBorderRadius * 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_rounded,
                  size: responsiveIconSize * 0.7,
                ),
                if (!_isMobile) ...[
                  SizedBox(width: responsiveSpacing * 0.4),
                  Text(
                    'Unsaved',
                    style: TextStyle(
                      fontSize: responsiveFontSizeSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // OPTIMIZED compact loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(responsivePadding),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: responsiveSpacing),
          Text(
            'Creating your form...',
            style: TextStyle(
              fontSize: responsiveFontSize,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // OPTIMIZED main form content - Much more compact
  Widget _buildFormContent() {
    return FormBuilder(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
            vertical: responsiveSpacing * 0.5), // Reduced padding
        child: FadeTransition(
          opacity: _pageAnimationController,
          child: Column(
            children: [
              // Form header
              _buildFormHeader(),

              // Fields section
              _buildExpandableSection(
                sectionIndex: 0,
                title: 'Form Fields',
                subtitle:
                    '${_fields.length} field${_fields.length != 1 ? 's' : ''} added',
                icon: Icons.view_list_rounded,
                content: _buildFieldsSection(),
              ),

              // Schedule section
              _buildExpandableSection(
                sectionIndex: 1,
                title: 'Schedule & Timing',
                subtitle:
                    _isChecklist ? 'Checklist enabled' : 'No schedule set',
                icon: Icons.schedule_rounded,
                content: _buildSchedulingSection(),
              ),

              // Permissions section
              _buildExpandableSection(
                sectionIndex: 2,
                title: 'Access & Permissions',
                subtitle: _visibility == FormVisibility.public
                    ? 'Public access'
                    : '${_permissions.length} permission${_permissions.length != 1 ? 's' : ''}',
                icon: Icons.security_rounded,
                content: _buildPermissionsSection(),
              ),

              // Save button
              _buildSaveButton(),

              SizedBox(height: responsivePadding), // Reduced bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // OPTIMIZED compact save button
  Widget _buildSaveButton() {
    return Container(
      margin: EdgeInsets.all(responsiveSpacing),
      width: double.infinity,
      height: 48, // Reduced height
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveForm,
        icon: Icon(Icons.save_rounded,
            size: responsiveIconSize, color: Colors.white),
        label: Text(
          'Create Form',
          style: TextStyle(
            fontSize: responsiveFontSize + 1,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppTheme.primaryColor.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
