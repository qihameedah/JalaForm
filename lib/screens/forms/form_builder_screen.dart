// lib/screens/forms/form_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:jala_form/models/form_permission.dart';
import 'package:jala_form/models/form_state_interface.dart';
import 'package:jala_form/models/user_group.dart';
import 'package:uuid/uuid.dart';
import '../../models/custom_form.dart';
import '../../models/form_field.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'form_field_editor.dart';

class FormBuilderScreen extends StatefulWidget {
  // Add these callback parameters
  final VoidCallback? onFormContentChanged;
  final bool Function()? checkUnsavedChanges;
  final VoidCallback? resetFormCallback;

  const FormBuilderScreen({
    super.key,
    this.onFormContentChanged,
    this.checkUnsavedChanges,
    this.resetFormCallback,
  });

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen>
    with SingleTickerProviderStateMixin
    implements FormStateInterface {
  final _formKey = GlobalKey<FormBuilderState>();
  final List<FormFieldModel> _fields = [];
  bool _isLoading = false;
  final _supabaseService = SupabaseService();
  late AnimationController _animationController;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

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

  // Track which section is expanded
  bool _isFieldsExpanded = true;
  bool _isSchedulingExpanded = false;
  bool _isPermissionsExpanded = false;

  // Add these new properties for unsaved changes tracking
  bool _hasUnsavedChanges = false;
  bool _isNavigatingAway = false;

  // Make these methods public (remove the interface completely)
  bool hasUnsavedChanges() {
    return _hasFormContent();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadGroups();

    // Add listeners to text controllers to track changes
    _titleController.addListener(_markAsModified);
    _descriptionController.addListener(_markAsModified);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    if (mounted) {
      setState(() {
        _isLoadingGroups = true;
      });
    }

    try {
      _availableGroups = await _supabaseService.getMyCreatedGroups();
    } catch (e) {
      debugPrint('Error loading groups: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGroups = false;
        });
      }
    }
  }

  // Track changes in form
  void _markAsModified() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
    // Notify parent about content change
    widget.onFormContentChanged?.call();
  }

  // Reset form method
  void resetForm() {
    if (mounted) {
      setState(() {
        _isNavigatingAway = true;
        _hasUnsavedChanges = false;
        _titleController.clear();
        _descriptionController.clear();
        _fields.clear();
        _isChecklist = false;
        _isRecurring = false;
        _recurrenceType = RecurrenceType.once;
        _startTime = null;
        _endTime = null;
        _startDate = null;
        _endDate = null;
        _visibility = FormVisibility.public;
        _permissions.clear();
        _isFieldsExpanded = true;
        _isSchedulingExpanded = false;
        _isPermissionsExpanded = false;
      });
      _formKey.currentState?.reset();
    }
  }

  // Check if form has any content
  bool _hasFormContent() {
    return _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _fields.isNotEmpty ||
        _isChecklist ||
        _visibility != FormVisibility.public ||
        _permissions.isNotEmpty;
  }

  // Show unsaved changes warning (for back button)
  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasFormContent() || _isNavigatingAway) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            const Text('Unsaved Changes'),
          ],
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave? All changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _addField(FormFieldModel field) {
    setState(() {
      _fields.add(field);
      _markAsModified();
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
      _markAsModified();
    });
  }

  void _editField(int index, FormFieldModel updatedField) {
    setState(() {
      _fields[index] = updatedField;
      _markAsModified();
    });
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
      _markAsModified();
    });
  }

  void _addNewField() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: FormFieldEditor(
            onSave: (field) {
              _addField(field);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && mounted) {
          setState(() {
            _isNavigatingAway = true;
          });
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Create Form',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: Material(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _isLoading ? null : _saveForm,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.save_outlined,
                          color:
                              _isLoading ? Colors.grey : AppTheme.primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Save',
                          style: TextStyle(
                            color: _isLoading
                                ? Colors.grey
                                : AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Creating your form...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: FormBuilder(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Form Header Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.5),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: const Interval(0.0, 0.5,
                                  curve: Curves.easeOut),
                            ),
                          ),
                          child: FadeTransition(
                            opacity:
                                Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: const Interval(0.0, 0.5,
                                    curve: Curves.easeIn),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.description_outlined,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Form Details',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          Text(
                                            'Basic information about your form',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                FormBuilderTextField(
                                  name: 'title',
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    labelText: 'Form Title',
                                    hintText: 'Enter a title for your form',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: AppTheme.primaryColor),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.title_outlined,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    FormBuilderValidators.minLength(3),
                                  ]),
                                ),
                                const SizedBox(height: 16),
                                FormBuilderTextField(
                                  name: 'description',
                                  controller: _descriptionController,
                                  decoration: InputDecoration(
                                    labelText: 'Form Description',
                                    hintText:
                                        'Enter a description for your form',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: AppTheme.primaryColor),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.description_outlined,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 3,
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Expandable Sections
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              FadeTransition(
                                opacity:
                                    Tween<double>(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _animationController,
                                    curve: const Interval(0.2, 0.7,
                                        curve: Curves.easeIn),
                                  ),
                                ),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(0.2, 0.7,
                                          curve: Curves.easeOut),
                                    ),
                                  ),
                                  child: _buildFieldsSection(),
                                ),
                              ),

                              FadeTransition(
                                opacity:
                                    Tween<double>(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _animationController,
                                    curve: const Interval(0.3, 0.8,
                                        curve: Curves.easeIn),
                                  ),
                                ),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(0.3, 0.8,
                                          curve: Curves.easeOut),
                                    ),
                                  ),
                                  child: _buildSchedulingSection(),
                                ),
                              ),

                              FadeTransition(
                                opacity:
                                    Tween<double>(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _animationController,
                                    curve: const Interval(0.4, 0.9,
                                        curve: Curves.easeIn),
                                  ),
                                ),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(0.4, 0.9,
                                          curve: Curves.easeOut),
                                    ),
                                  ),
                                  child: _buildPermissionsSection(),
                                ),
                              ),

                              // Save Button
                              FadeTransition(
                                opacity:
                                    Tween<double>(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _animationController,
                                    curve: const Interval(0.6, 1.0,
                                        curve: Curves.easeIn),
                                  ),
                                ),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.5),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(0.6, 1.0,
                                          curve: Curves.easeOut),
                                    ),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(
                                        top: 24, bottom: 16),
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _saveForm,
                                      icon: Icon(
                                        Icons.save_outlined,
                                        size: 18,
                                        color: _isLoading
                                            ? Colors.grey
                                            : Colors.white,
                                      ),
                                      label: Text(
                                        _isLoading
                                            ? 'Creating...'
                                            : 'Create Form',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: _isLoading
                                              ? Colors.grey
                                              : Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isLoading
                                            ? Colors.grey[300]
                                            : AppTheme.primaryColor,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required Widget content,
    required bool isExpanded,
    required Function(bool) onToggle,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onToggle(!isExpanded),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsSection() {
    return _buildExpandableSection(
      title: 'Form Fields',
      icon: Icons.view_list_outlined,
      isExpanded: _isFieldsExpanded,
      onToggle: (value) => setState(() => _isFieldsExpanded = value),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fields.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.note_add_outlined,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No fields added yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add your first field to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _fields.length,
                    onReorder: _reorderFields,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.white,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final field = _fields[index];
                      final color = _getColorForFieldType(field.type);

                      return Container(
                        key: ValueKey(field.id),
                        margin: EdgeInsets.fromLTRB(
                          8,
                          index == 0 ? 8 : 4,
                          8,
                          index == _fields.length - 1 ? 8 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getIconForFieldType(field.type),
                              color: color,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            field.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _formatFieldType(field.type),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (field.isRequired)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Required',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: SizedBox(
                            width: 120,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: Colors.grey[600],
                                      size: 14,
                                    ),
                                    tooltip: 'Edit',
                                    onPressed: () => _editFieldDialog(index),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 14,
                                    ),
                                    tooltip: 'Delete',
                                    onPressed: () =>
                                        _showDeleteFieldConfirmation(index),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _addNewField,
              icon: const Icon(
                Icons.add,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Add Field',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulingSection() {
    return _buildExpandableSection(
      title: 'Form Schedule',
      icon: Icons.schedule_outlined,
      isExpanded: _isSchedulingExpanded,
      onToggle: (value) => setState(() => _isSchedulingExpanded = value),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isChecklist
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.checklist_outlined,
                    color:
                        _isChecklist ? AppTheme.primaryColor : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checklist Form',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enable time windows & recurrence',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isChecklist,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _isChecklist = value;
                      _markAsModified(); // Add this line
                      if (value && _startTime == null) {
                        _startTime = const TimeOfDay(hour: 8, minute: 0);
                      }
                      if (value && _endTime == null) {
                        _endTime = const TimeOfDay(hour: 17, minute: 0);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          // ... rest of your scheduling section code
        ],
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return _buildExpandableSection(
      title: 'Form Access',
      icon: Icons.security_outlined,
      isExpanded: _isPermissionsExpanded,
      onToggle: (value) => setState(() => _isPermissionsExpanded = value),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _visibility == FormVisibility.public
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _visibility == FormVisibility.public
                            ? Icons.public_outlined
                            : Icons.lock_outline,
                        color: _visibility == FormVisibility.public
                            ? AppTheme.primaryColor
                            : Colors.orange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Who can access this form?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FormVisibility>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primaryColor),
                    ),
                    prefixIcon: Icon(
                      _visibility == FormVisibility.public
                          ? Icons.public_outlined
                          : Icons.lock_outline,
                      color: _visibility == FormVisibility.public
                          ? AppTheme.primaryColor
                          : Colors.orange,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: _visibility,
                  items: const [
                    DropdownMenuItem(
                      value: FormVisibility.public,
                      child: Text('All authenticated users',
                          style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: FormVisibility.private,
                      child: Text('Only specific users and groups',
                          style: TextStyle(fontSize: 14)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _visibility = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          if (_visibility == FormVisibility.private) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 400) {
                  return Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add_outlined,
                                color: Colors.white, size: 18),
                            label: const Text('Add User',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _addUserToForm(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.group_add_outlined,
                                color: Colors.white, size: 18),
                            label: const Text('Add Group',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppTheme.secondaryColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isLoadingGroups
                                ? null
                                : () => _addGroupToForm(),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_outlined,
                              color: Colors.white, size: 18),
                          label: const Text('Add User',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _addUserToForm(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.group_add_outlined,
                              color: Colors.white, size: 18),
                          label: const Text('Add Group',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppTheme.secondaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed:
                              _isLoadingGroups ? null : () => _addGroupToForm(),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            if (_permissions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Current Access (${_permissions.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _permissions.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      itemBuilder: (context, index) {
                        final permission = _permissions[index];
                        final isUser = permission.user_id != null;
                        final name = isUser
                            ? permission.user_email ?? 'User'
                            : permission.group_name ?? 'Group';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppTheme.primaryColor.withOpacity(0.1)
                                  : AppTheme.secondaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isUser
                                  ? Icons.person_outline
                                  : Icons.group_outlined,
                              color: isUser
                                  ? AppTheme.primaryColor
                                  : AppTheme.secondaryColor,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            isUser ? 'User' : 'Group',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                                size: 14,
                              ),
                              tooltip: 'Remove',
                              onPressed: () {
                                setState(() {
                                  _permissions.remove(permission);
                                });
                              },
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            if (_permissions.isEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No users or groups added yet. This form will only be visible to you.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
    bool isOptional = false,
  }) {
    final displayText = value != null
        ? '${value.day}/${value.month}/${value.year}'
        : isOptional
            ? 'Optional'
            : 'Select Date';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: value != null
                        ? AppTheme.primaryColor
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontWeight:
                            value != null ? FontWeight.w500 : FontWeight.normal,
                        color: value != null
                            ? const Color(0xFF1A1A1A)
                            : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final displayText = value != null ? value.format(context) : 'Select Time';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: value != null
                        ? AppTheme.primaryColor
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontWeight:
                            value != null ? FontWeight.w500 : FontWeight.normal,
                        color: value != null
                            ? const Color(0xFF1A1A1A)
                            : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for date/time selection
  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ??
          (_startDate?.add(const Duration(days: 30)) ?? DateTime.now()),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        _startTime = time;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        _endTime = time;
      });
    }
  }

  IconData _getIconForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
        return Icons.text_fields;
      case FieldType.number:
        return Icons.numbers;
      case FieldType.email:
        return Icons.email_outlined;
      case FieldType.multiline:
        return Icons.short_text;
      case FieldType.textarea:
        return Icons.notes;
      case FieldType.dropdown:
        return Icons.arrow_drop_down_circle_outlined;
      case FieldType.checkbox:
        return Icons.check_box_outlined;
      case FieldType.radio:
        return Icons.radio_button_checked;
      case FieldType.date:
        return Icons.calendar_today_outlined;
      case FieldType.time:
        return Icons.access_time_outlined;
      case FieldType.image:
        return Icons.image_outlined;
      case FieldType.likert:
        return Icons.poll_outlined;
      default:
        return Icons.input;
    }
  }

  Color _getColorForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
      case FieldType.multiline:
      case FieldType.textarea:
        return const Color(0xFF5C6BC0);
      case FieldType.number:
        return const Color(0xFFFF8A65);
      case FieldType.email:
        return const Color(0xFF42A5F5);
      case FieldType.dropdown:
        return const Color(0xFFAB47BC);
      case FieldType.checkbox:
        return const Color(0xFF66BB6A);
      case FieldType.radio:
        return const Color(0xFF29B6F6);
      case FieldType.date:
        return const Color(0xFFFF7043);
      case FieldType.time:
        return const Color(0xFF26A69A);
      case FieldType.image:
        return const Color(0xFFEC407A);
      case FieldType.likert:
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF78909C);
    }
  }

  String _formatFieldType(FieldType type) {
    String typeStr = type.toString().split('.').last;
    switch (type) {
      case FieldType.likert:
        return 'Likert Scale';
      default:
        typeStr = typeStr[0].toUpperCase() +
            typeStr
                .substring(1)
                .replaceAllMapped(RegExp(r'[A-Z]'), (Match m) => ' ${m[0]}');
        return typeStr;
    }
  }

  void _showDeleteFieldConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Field'),
        content:
            Text('Are you sure you want to delete "${_fields[index].label}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _removeField(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editFieldDialog(int index) {
    final field = _fields[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: FormFieldEditor(
            initialField: field,
            onSave: (updatedField) {
              _editField(index, updatedField);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  // User and group management methods
  Future<void> _addUserToForm() async {
    setState(() {
      _isLoading = true;
    });

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
        setState(() {
          _isLoading = false;
        });

        if (availableUsers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No more users available to add'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        _showUserSelectionDialog(availableUsers);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showUserSelectionDialog(List<Map<String, dynamic>> users) {
    final List<Map<String, dynamic>> selectedUsers = [];
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation1, animation2) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredUsers = users.where((user) {
              final email = user['email'].toString().toLowerCase();
              final username = user['username']?.toString().toLowerCase() ?? '';
              return email.contains(searchQuery) ||
                  username.contains(searchQuery);
            }).toList();

            return SafeArea(
              child: Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Responsive width calculation
                      double dialogWidth;
                      if (constraints.maxWidth > 600) {
                        dialogWidth = 500;
                      } else if (constraints.maxWidth > 400) {
                        dialogWidth = constraints.maxWidth * 0.85;
                      } else {
                        dialogWidth = constraints.maxWidth * 0.95;
                      }

                      // Responsive height calculation
                      double dialogHeight;
                      if (constraints.maxHeight > 700) {
                        dialogHeight = constraints.maxHeight * 0.7;
                      } else if (constraints.maxHeight > 500) {
                        dialogHeight = constraints.maxHeight * 0.8;
                      } else {
                        dialogHeight = constraints.maxHeight * 0.9;
                      }

                      // Responsive padding
                      final horizontalPadding =
                          constraints.maxWidth > 400 ? 20.0 : 12.0;
                      final verticalPadding =
                          constraints.maxHeight > 600 ? 16.0 : 8.0;

                      return Container(
                        width: dialogWidth,
                        height: dialogHeight,
                        margin:
                            EdgeInsets.symmetric(horizontal: horizontalPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              // Header
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      constraints.maxWidth > 400 ? 16 : 12,
                                  vertical:
                                      constraints.maxHeight > 600 ? 16 : 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_add_outlined,
                                      size:
                                          constraints.maxWidth > 400 ? 24 : 20,
                                      color: AppTheme.primaryColor,
                                    ),
                                    SizedBox(
                                        width: constraints.maxWidth > 400
                                            ? 12
                                            : 8),
                                    Expanded(
                                      child: Text(
                                        'Add Users to Form',
                                        style: TextStyle(
                                          fontSize: constraints.maxWidth > 400
                                              ? 18
                                              : 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      icon: Icon(
                                        Icons.close,
                                        size: constraints.maxWidth > 400
                                            ? 24
                                            : 20,
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),

                              // Search bar
                              Padding(
                                padding: EdgeInsets.all(
                                  constraints.maxWidth > 400 ? 16 : 12,
                                ),
                                child: Container(
                                  height: constraints.maxHeight > 600 ? 48 : 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(
                                      constraints.maxWidth > 400 ? 24 : 20,
                                    ),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: TextField(
                                    controller: searchController,
                                    style: TextStyle(
                                      fontSize:
                                          constraints.maxWidth > 400 ? 14 : 12,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search users...',
                                      hintStyle: TextStyle(
                                        fontSize: constraints.maxWidth > 400
                                            ? 14
                                            : 12,
                                      ),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(
                                        Icons.search,
                                        size: constraints.maxWidth > 400
                                            ? 20
                                            : 18,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: constraints.maxHeight > 600
                                            ? 12
                                            : 8,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        searchQuery = value.toLowerCase();
                                      });
                                    },
                                  ),
                                ),
                              ),

                              // User list
                              Expanded(
                                child: filteredUsers.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(
                                            constraints.maxWidth > 400
                                                ? 24
                                                : 16,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.search_off,
                                                size: constraints.maxWidth > 400
                                                    ? 48
                                                    : 36,
                                                color: Colors.grey
                                                    .withOpacity(0.5),
                                              ),
                                              SizedBox(
                                                  height:
                                                      constraints.maxHeight >
                                                              600
                                                          ? 16
                                                          : 12),
                                              Text(
                                                searchQuery.isEmpty
                                                    ? 'No users available'
                                                    : 'No users found',
                                                style: TextStyle(
                                                  fontSize:
                                                      constraints.maxWidth > 400
                                                          ? 16
                                                          : 14,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              if (searchQuery.isNotEmpty) ...[
                                                SizedBox(
                                                    height:
                                                        constraints.maxHeight >
                                                                600
                                                            ? 8
                                                            : 4),
                                                Text(
                                                  'for "$searchQuery"',
                                                  style: TextStyle(
                                                    fontSize:
                                                        constraints.maxWidth >
                                                                400
                                                            ? 14
                                                            : 12,
                                                    color: Colors.grey,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: filteredUsers.length,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: constraints.maxWidth > 400
                                              ? 16
                                              : 12,
                                        ),
                                        itemBuilder: (context, index) {
                                          final user = filteredUsers[index];
                                          final isSelected = selectedUsers.any(
                                              (selected) =>
                                                  selected['id'] == user['id']);

                                          return Padding(
                                            padding: EdgeInsets.only(
                                              bottom:
                                                  constraints.maxHeight > 600
                                                      ? 8
                                                      : 4,
                                            ),
                                            child: Material(
                                              color: isSelected
                                                  ? AppTheme.primaryColor
                                                      .withOpacity(0.1)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                onTap: () {
                                                  setState(() {
                                                    if (isSelected) {
                                                      selectedUsers.removeWhere(
                                                          (selected) =>
                                                              selected['id'] ==
                                                              user['id']);
                                                    } else {
                                                      selectedUsers.add(user);
                                                    }
                                                  });
                                                },
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical:
                                                        constraints.maxHeight >
                                                                600
                                                            ? 12
                                                            : 8,
                                                    horizontal:
                                                        constraints.maxWidth >
                                                                400
                                                            ? 12
                                                            : 8,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Avatar
                                                      CircleAvatar(
                                                        radius: constraints
                                                                    .maxWidth >
                                                                400
                                                            ? 20
                                                            : 16,
                                                        backgroundColor:
                                                            AppTheme
                                                                .primaryColor,
                                                        child: Text(
                                                          (user['username'] ??
                                                                  'U')[0]
                                                              .toUpperCase(),
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: constraints
                                                                        .maxWidth >
                                                                    400
                                                                ? 14
                                                                : 12,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                          width: constraints
                                                                      .maxWidth >
                                                                  400
                                                              ? 12
                                                              : 8),

                                                      // User info
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              user['username'] ??
                                                                  'User',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize:
                                                                    constraints.maxWidth >
                                                                            400
                                                                        ? 14
                                                                        : 12,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            if (constraints
                                                                    .maxHeight >
                                                                500) ...[
                                                              const SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                user['email'] ??
                                                                    '',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      constraints.maxWidth >
                                                                              400
                                                                          ? 12
                                                                          : 10,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),

                                                      // Checkbox
                                                      Transform.scale(
                                                        scale: constraints
                                                                    .maxWidth >
                                                                400
                                                            ? 1.0
                                                            : 0.8,
                                                        child: Checkbox(
                                                          value: isSelected,
                                                          activeColor: AppTheme
                                                              .primaryColor,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              if (value ==
                                                                  true) {
                                                                if (!isSelected) {
                                                                  selectedUsers
                                                                      .add(
                                                                          user);
                                                                }
                                                              } else {
                                                                selectedUsers.removeWhere(
                                                                    (selected) =>
                                                                        selected[
                                                                            'id'] ==
                                                                        user[
                                                                            'id']);
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),

                              // Footer
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      constraints.maxWidth > 400 ? 16 : 12,
                                  vertical:
                                      constraints.maxHeight > 600 ? 16 : 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 1,
                                      offset: const Offset(0, -1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Selection count
                                    if (constraints.maxHeight > 500)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Text(
                                          '${selectedUsers.length} user${selectedUsers.length == 1 ? '' : 's'} selected',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textSecondaryColor,
                                            fontSize: constraints.maxWidth > 400
                                                ? 14
                                                : 12,
                                          ),
                                        ),
                                      ),

                                    // Buttons
                                    if (constraints.maxWidth > 400) ...[
                                      // Row layout for larger screens
                                      Row(
                                        children: [
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                            ),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                fontSize:
                                                    constraints.maxWidth > 400
                                                        ? 14
                                                        : 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: selectedUsers.isEmpty
                                                ? null
                                                : () => Navigator.pop(
                                                    context,
                                                    List<
                                                            Map<String,
                                                                dynamic>>.from(
                                                        selectedUsers)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              'Add Selected',
                                              style: TextStyle(
                                                fontSize:
                                                    constraints.maxWidth > 400
                                                        ? 14
                                                        : 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      // Column layout for smaller screens
                                      Column(
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            height: 40,
                                            child: ElevatedButton(
                                              onPressed: selectedUsers.isEmpty
                                                  ? null
                                                  : () => Navigator.pop(
                                                      context,
                                                      List<
                                                              Map<String,
                                                                  dynamic>>.from(
                                                          selectedUsers)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppTheme.primaryColor,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                'Add Selected (${selectedUsers.length})',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 36,
                                            child: TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              style: TextButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: BorderSide(
                                                      color:
                                                          Colors.grey.shade300),
                                                ),
                                              ),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((dynamic result) {
      if (result != null) {
        try {
          final List<Map<String, dynamic>> selectedUsers =
              List<Map<String, dynamic>>.from(result);

          if (selectedUsers.isNotEmpty) {
            setState(() {
              for (final user in selectedUsers) {
                final permission = FormPermission(
                  id: const Uuid().v4(),
                  form_id: '',
                  user_id: user['id'],
                  created_at: DateTime.now(),
                  user_email: user['email'],
                );
                _permissions.add(permission);
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${selectedUsers.length} user${selectedUsers.length == 1 ? '' : 's'} added successfully'),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error processing selected users: $e');
        }
      }
    });
  }

  Future<void> _addGroupToForm() async {
    if (_availableGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You haven\'t created any groups yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All your groups are already added to this form'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showDialog<UserGroup>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.group_add_outlined,
                color: AppTheme.secondaryColor, size: 24),
            const SizedBox(width: 12),
            const Text('Add Group'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a group to give access to:',
                style:
                    TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableGroups.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    itemBuilder: (context, index) {
                      final group = availableGroups[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.group_outlined,
                            color: AppTheme.secondaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          group.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          group.description,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, group),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _permissions.add(FormPermission(
          id: const Uuid().v4(),
          form_id: '',
          group_id: result.id,
          created_at: DateTime.now(),
          group_name: result.name,
        ));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Added group ${result.name}'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.saveAndValidate()) {
      if (_fields.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Please add at least one field to your form'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final user = _supabaseService.getCurrentUser();
        if (user == null) {
          throw Exception('User not logged in');
        }

        final formId = const Uuid().v4();

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
        );

        await _supabaseService.createForm(newForm);

        if (_visibility == FormVisibility.private && _permissions.isNotEmpty) {
          for (var permission in _permissions) {
            final formPermission = FormPermission(
              id: const Uuid().v4(),
              form_id: formId,
              user_id: permission.user_id,
              group_id: permission.group_id,
              created_at: DateTime.now(),
            );
            await _supabaseService.addFormPermission(formPermission);
          }
        }

        if (mounted) {
          setState(() {
            _isNavigatingAway =
                true; // Mark as navigating away after successful save
            _hasUnsavedChanges = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Form created successfully'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.successColor,
            ),
          );

          _titleController.clear();
          _descriptionController.clear();

          setState(() {
            _fields.clear();
            _isChecklist = false;
            _isRecurring = false;
            _startTime = null;
            _endTime = null;
            _startDate = null;
            _endDate = null;
            _visibility = FormVisibility.public;
            _permissions.clear();
            _isFieldsExpanded = true;
            _isSchedulingExpanded = false;
            _isPermissionsExpanded = false;
          });

          _formKey.currentState?.reset();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
