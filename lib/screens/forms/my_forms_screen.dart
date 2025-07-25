// lib/screens/forms/my_forms_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jala_form/screens/forms/form_edit_screen.dart';
import '../../models/custom_form.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'form_responses_screen.dart';
import 'form_detail_screen.dart';
import 'checklist_form_screen.dart';

class MyFormsScreen extends StatefulWidget {
  const MyFormsScreen({super.key});

  @override
  State<MyFormsScreen> createState() => _MyFormsScreenState();
}

// Replace the CustomAnimatedTabs class with this fixed and compact version

class CustomAnimatedTabs extends StatefulWidget {
  final List<TabData> tabs;
  final Function(int) onTabChanged;
  final int initialIndex;

  const CustomAnimatedTabs({
    Key? key,
    required this.tabs,
    required this.onTabChanged,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<CustomAnimatedTabs> createState() => _CustomAnimatedTabsState();
}

class _CustomAnimatedTabsState extends State<CustomAnimatedTabs>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250), // Faster, smoother
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      _animationController.forward(from: 0.0);
      widget.onTabChanged(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerPadding = screenWidth > 600 ? 20.0 : 16.0;
    final tabWidth = (screenWidth - (containerPadding * 2) - 8) /
        2; // 4px padding in container

    return Container(
      margin: EdgeInsets.symmetric(horizontal: containerPadding, vertical: 12),
      padding: const EdgeInsets.all(4),
      height: 44, // More compact height
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(
            22), // Half of height for perfect rounded sides
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Smooth animated background indicator with rounded sides
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic, // Smooth curve, no vibration
            left: _selectedIndex * tabWidth,
            child: Container(
              width: tabWidth,
              height: 36, // Height - 8 (4px padding on each side)
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF5C6BC0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.circular(18), // Perfect rounded sides
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          // Tab buttons
          Row(
            children: widget.tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final isSelected = index == _selectedIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTapped(index),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          size: 16,
                          color:
                              isSelected ? Colors.white : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tab.count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.2)
                                  : AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tab.count.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class TabData {
  final IconData icon;
  final String label;
  final int count;

  TabData({
    required this.icon,
    required this.label,
    required this.count,
  });
}

// Change this line at the top of MyFormsScreen class
class _MyFormsScreenState extends State<MyFormsScreen>
    with TickerProviderStateMixin {
  // Changed from SingleTickerProviderStateMixin
  final _supabaseService = SupabaseService();
  List<CustomForm> _myForms = [];
  List<CustomForm> _myChecklistForms = [];
  List<CustomForm> _myRegularForms = [];
  bool _isLoading = true;
  late TabController _tabController;
  int _currentTabIndex = 0;
  StreamSubscription<List<CustomForm>>? _formsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // ADD THESE TWO LINES:
    _initializeRealTime();
    _loadForms();
  }

  void _initializeRealTime() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) return;

      // Listen to forms stream and filter for current user's forms
      _formsSubscription = _supabaseService.formsStream.listen(
        (allForms) {
          if (mounted) {
            // Filter forms created by current user
            final myForms =
                allForms.where((form) => form.created_by == user.id).toList();
            final checklistForms =
                myForms.where((form) => form.isChecklist).toList();
            final regularForms =
                myForms.where((form) => !form.isChecklist).toList();

            setState(() {
              _myForms = myForms;
              _myChecklistForms = checklistForms;
              _myRegularForms = regularForms;
            });
          }
        },
        onError: (error) {
          debugPrint('Error in forms stream: $error');
        },
      );
    } catch (e) {
      debugPrint('Error initializing real-time: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _formsSubscription?.cancel(); // ADD THIS LINE
    super.dispose();
  }

// KEEP YOUR EXISTING _loadForms METHOD AS IS:
  Future<void> _loadForms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      final forms = await _supabaseService.getForms();

      // Filter forms created by current user
      final myForms =
          forms.where((form) => form.created_by == user.id).toList();
      final checklistForms = myForms.where((form) => form.isChecklist).toList();
      final regularForms = myForms.where((form) => !form.isChecklist).toList();

      setState(() {
        _myForms = myForms;
        _myChecklistForms = checklistForms;
        _myRegularForms = regularForms;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading forms: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
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

// UPDATE YOUR EXISTING _deleteForm METHOD:
  Future<void> _deleteForm(String formId) async {
    try {
      await _supabaseService.deleteForm(formId);

      // REMOVE THE MANUAL setState - real-time will handle the update
      // The real-time subscription will automatically update the lists

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form deleted successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting form: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _editForm(CustomForm form) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormEditScreen(form: form),
      ),
    ).then((_) {
      // REMOVE THE MANUAL _loadForms() call - real-time will handle it
      // Real-time subscription will automatically detect changes
    });
  }

// Enhanced schedule row helper method (if not already added)
  Widget _buildEnhancedScheduleRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpringAnimatedCard(
      CustomForm form, bool isChecklist, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, animation, child) {
        // Clamp the animation value to ensure it stays within valid ranges
        final clampedAnimation = animation.clamp(0.0, 1.0);
        final scaleAnimation = (0.8 + (0.2 * animation)).clamp(0.0, 2.0);

        return Transform.scale(
          scale: scaleAnimation,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - clampedAnimation)),
            child: Opacity(
              opacity: clampedAnimation, // Use clamped value for opacity
              child: _buildFormCard(form, isChecklist),
            ),
          ),
        );
      },
    );
  }

// Add responsive utility methods
  double _getCardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) return 32.0;
    if (screenWidth > 600) return 24.0;
    return 16.0;
  }

  double _getCardMaxWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 800;
    if (screenWidth > 800) return 600;
    return double.infinity;
  }

// Enhanced empty state that works for both screens
  Widget _buildEnhancedEmptyState(bool isChecklist) {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.elasticOut,
        builder: (context, animation, child) {
          return Transform.scale(
            scale: animation,
            child: Opacity(
              opacity: animation,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: _getCardMaxWidth(context),
                ),
                padding: EdgeInsets.all(_getCardPadding(context)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (isChecklist
                                    ? Colors.orange
                                    : AppTheme.primaryColor)
                                .withOpacity(0.1),
                            (isChecklist
                                    ? Colors.orange
                                    : AppTheme.primaryColor)
                                .withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        isChecklist
                            ? Icons.checklist_rounded
                            : Icons.description_rounded,
                        size: 60,
                        color: (isChecklist
                                ? Colors.orange
                                : AppTheme.primaryColor)
                            .withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isChecklist
                          ? 'No checklists available'
                          : 'No forms available',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3748),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isChecklist
                          ? 'Checklists shared with you will appear here'
                          : 'Forms shared with you will appear here',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

// Replace _buildFormCard method in MyFormsScreen ONLY with this version (includes menu in header)

  Widget _buildFormCard(CustomForm form, bool isChecklist) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth > 600 ? 20.0 : 14.0;

    // Time window information for checklist forms
    String? timeWindow;
    if (isChecklist && form.startTime != null && form.endTime != null) {
      timeWindow =
          '${form.startTime!.format(context)} - ${form.endTime!.format(context)}';
    }

    // Recurrence pattern for checklist forms
    String? recurrencePattern;
    if (isChecklist && form.isRecurring && form.recurrenceType != null) {
      recurrencePattern = form.recurrenceType.toString().split('.').last;
      recurrencePattern =
          recurrencePattern[0].toUpperCase() + recurrencePattern.substring(1);
    }

    // Updated colors - Regular forms use Color(0xFF3F51B5), Checklists keep warm orange
    final Color primaryColor = isChecklist
        ? const Color(0xFFFF8A50) // Keep warm orange for checklists
        : const Color(0xFF5C6BC0); // Use requested purple for regular forms

    final Color lightColor = isChecklist
        ? const Color(0xFFFFF4F0) // Very light warm background for checklists
        : const Color(0xFFF3F4FF); // Very light purple background for forms

    final Color darkColor = isChecklist
        ? const Color(0xFFE17055) // Darker warm orange for checklists
        : AppTheme.primaryColor; // Darker purple for forms

    final Color borderColor = isChecklist
        ? const Color(0xFFFFE0D6) // Subtle orange border for checklists
        : const Color(0xFFE8EAFF); // Subtle purple border for forms

    return Container(
      margin: EdgeInsets.fromLTRB(cardPadding, 6, cardPadding, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Improved shadows for better visibility
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        // Enhanced border for better shape definition
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section with Menu Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Improved Icon with better contrast
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, darkColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isChecklist
                        ? Icons.task_alt_rounded
                        : Icons.description_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),

                // Title and Info with better typography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '${form.fields.length} fields',
                              style: TextStyle(
                                fontSize: 11,
                                color: darkColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (form.description.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                form.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Badge and Menu Button Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Improved Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, darkColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isChecklist ? 'Checklist' : 'Form',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Menu Button
                    GestureDetector(
                      onTap: () => _showSimpleBottomSheet(
                          form, isChecklist, primaryColor),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Schedule info for checklists with improved styling
                if (isChecklist &&
                    (timeWindow != null ||
                        recurrencePattern != null ||
                        form.startDate != null)) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (timeWindow != null)
                          _buildImprovedScheduleRow(
                            Icons.access_time_rounded,
                            timeWindow,
                            primaryColor,
                          ),
                        if (recurrencePattern != null)
                          _buildImprovedScheduleRow(
                            Icons.repeat_rounded,
                            recurrencePattern,
                            primaryColor,
                          ),
                        if (form.startDate != null)
                          _buildImprovedScheduleRow(
                            Icons.calendar_today_rounded,
                            'Valid from ${_formatDate(form.startDate!)}${form.endDate != null ? ' to ${_formatDate(form.endDate!)}' : ''}',
                            primaryColor,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action Button - Full width View Responses only
                _buildActionButtons(form, isChecklist, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Improved schedule row with better styling
  Widget _buildImprovedScheduleRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFF4A5568),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Replace _buildActionButtons method in MyFormsScreen

  Widget _buildActionButtons(
      CustomForm form, bool isChecklist, Color primaryColor) {
    return Row(
      children: [
        // View Responses Button - Full Width
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FormResponsesScreen(
                      form_id: form.id,
                      formTitle: form.title,
                    ),
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              label: Text(
                'View Responses',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 2,
                shadowColor: primaryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  void _showSimpleBottomSheet(
      CustomForm form, bool isChecklist, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header with form info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    form.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${form.fields.length} fields',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Menu options - Only Edit, Preview, Delete
            _buildSimpleMenuOption(
              icon: Icons.edit_rounded,
              title: 'Edit Form',
              subtitle: 'Modify form fields and settings',
              color: primaryColor,
              onTap: () {
                Navigator.pop(context);
                _editForm(form);
              },
            ),
            _buildSimpleMenuOption(
              icon: Icons.visibility_rounded,
              title: 'Preview Form',
              subtitle: 'See how users will view this form',
              color: const Color(0xFF4A90E2),
              onTap: () {
                Navigator.pop(context);
                if (isChecklist) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChecklistFormScreen(
                        form: form,
                        isPreview: true,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormDetailScreen(
                        form: form,
                        isPreview: true,
                      ),
                    ),
                  );
                }
              },
            ),
            _buildSimpleMenuOption(
              icon: Icons.delete_rounded,
              title: 'Delete Form',
              subtitle: 'Permanently remove this form',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(form);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          color: Colors.white, // Changed from grey.shade25 to white
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon,
                  color: color, size: 22), // Using the actual color, not grey
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: title == 'Delete Form'
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _showImprovedBottomSheet(
      CustomForm form, bool isChecklist, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header with form info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    form.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${form.fields.length} fields',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Menu options
            _buildImprovedMenuOption(
              icon: Icons.visibility_rounded,
              title: 'Preview Form',
              subtitle: 'See how users will view this form',
              color: const Color(0xFF4A90E2),
              onTap: () {
                Navigator.pop(context);
                if (isChecklist) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChecklistFormScreen(
                        form: form,
                        isPreview: true,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormDetailScreen(
                        form: form,
                        isPreview: true,
                      ),
                    ),
                  );
                }
              },
            ),
            _buildImprovedMenuOption(
              icon: Icons.share_rounded,
              title: 'Share Form',
              subtitle: 'Send form link to others',
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.pop(context);
                // Add share functionality here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Share functionality coming soon!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _buildImprovedMenuOption(
              icon: Icons.file_copy_rounded,
              title: 'Duplicate Form',
              subtitle: 'Create a copy of this form',
              color: const Color(0xFFFF8A50),
              onTap: () {
                Navigator.pop(context);
                // Add duplicate functionality here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Duplicate functionality coming soon!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _buildImprovedMenuOption(
              icon: Icons.delete_rounded,
              title: 'Delete Form',
              subtitle: 'Permanently remove this form',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(form);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovedMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          color: Colors.grey,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: title == 'Delete Form'
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

// Compact bottom sheet for MyFormsScreen (Add this only to MyFormsScreen)
  void _showCompactBottomSheet(
      CustomForm form, bool isChecklist, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              form.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildCompactMenuOption(
              icon: Icons.edit_rounded,
              title: 'Edit Form',
              color: primaryColor,
              onTap: () {
                Navigator.pop(context);
                _editForm(form);
              },
            ),
            _buildCompactMenuOption(
              icon: Icons.visibility_rounded,
              title: 'Preview',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                if (isChecklist) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChecklistFormScreen(
                        form: form,
                        isPreview: true,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormDetailScreen(
                        form: form,
                        isPreview: true,
                      ),
                    ),
                  );
                }
              },
            ),
            _buildCompactMenuOption(
              icon: Icons.delete_rounded,
              title: 'Delete Form',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(form);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

// Compact menu option for MyFormsScreen (Add this only to MyFormsScreen)
  Widget _buildCompactMenuOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: title == 'Delete Form'
                      ? Colors.red
                      : const Color(0xFF1A202C),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _handleSecondaryAction(CustomForm form, bool isChecklist) {
    _editForm(form);
  }

  String _getSecondaryButtonText() {
    return 'Edit';
  }

// Enhanced bottom sheet method
  void _showEnhancedBottomSheet(
      CustomForm form, bool isChecklist, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              form.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A202C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildEnhancedMenuOption(
              icon: Icons.edit_rounded,
              title: 'Edit Form',
              subtitle: 'Modify form fields and settings',
              color: primaryColor,
              onTap: () {
                Navigator.pop(context);
                _editForm(form);
              },
            ),
            _buildEnhancedMenuOption(
              icon: Icons.visibility_rounded,
              title: 'Preview',
              subtitle: 'See how the form looks to users',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                if (isChecklist) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChecklistFormScreen(
                        form: form,
                        isPreview: true,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormDetailScreen(
                        form: form,
                        isPreview: true,
                      ),
                    ),
                  );
                }
              },
            ),
            _buildEnhancedMenuOption(
              icon: Icons.delete_rounded,
              title: 'Delete Form',
              subtitle: 'Permanently remove this form',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(form);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

// Enhanced menu option method
  Widget _buildEnhancedMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: title == 'Delete Form'
                          ? Colors.red
                          : const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

// Helper method for menu options
  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: title == 'Delete' ? Colors.red : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper method for schedule rows
  Widget _buildScheduleRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(CustomForm form) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Form'),
        content: Text(
          'Are you sure you want to delete "${form.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteForm(form.id);
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

// Replace the build method in MyFormsScreen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom animated tabs
            CustomAnimatedTabs(
              tabs: [
                TabData(
                  icon: Icons.description_rounded,
                  label: 'My Forms',
                  count: _myRegularForms.length,
                ),
                TabData(
                  icon: Icons.checklist_rounded,
                  label: 'My Checklists',
                  count: _myChecklistForms.length,
                ),
              ],
              onTabChanged: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
                _tabController.animateTo(index);
              },
              initialIndex: _currentTabIndex,
            ),

            // Content area
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadForms,
                color: AppTheme.primaryColor,
                backgroundColor: Colors.white,
                strokeWidth: 2,
                child: _isLoading
                    ? _buildCompactLoadingIndicator()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // My Regular Forms Tab
                          _myRegularForms.isEmpty
                              ? _buildCompactEmptyState(false)
                              : ListView.builder(
                                  itemCount: _myRegularForms.length,
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 20),
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return _buildSmoothAnimatedCard(
                                        _myRegularForms[index], false, index);
                                  },
                                ),

                          // My Checklists Tab
                          _myChecklistForms.isEmpty
                              ? _buildCompactEmptyState(true)
                              : ListView.builder(
                                  itemCount: _myChecklistForms.length,
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 20),
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return _buildSmoothAnimatedCard(
                                        _myChecklistForms[index], true, index);
                                  },
                                ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Compact empty state
  Widget _buildCompactEmptyState(bool isChecklist) {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, animation, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - animation)),
            child: Opacity(
              opacity: animation,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (isChecklist
                                    ? Colors.orange
                                    : AppTheme.primaryColor)
                                .withOpacity(0.1),
                            (isChecklist
                                    ? Colors.orange
                                    : AppTheme.primaryColor)
                                .withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isChecklist
                            ? Icons.checklist_rounded
                            : Icons.description_rounded,
                        size: 40,
                        color: (isChecklist
                                ? Colors.orange
                                : AppTheme.primaryColor)
                            .withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isChecklist
                          ? 'No checklists available'
                          : 'No forms available',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isChecklist
                          ? 'Checklists will appear here'
                          : 'Forms will appear here',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

// Compact schedule row helper method
  Widget _buildCompactScheduleRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Compact loading indicator
  Widget _buildCompactLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading forms...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Smooth animation without vibration
  Widget _buildSmoothAnimatedCard(
      CustomForm form, bool isChecklist, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic, // Smooth curve without bounce
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation)),
          child: Opacity(
            opacity: animation,
            child: _buildFormCard(form, isChecklist),
          ),
        );
      },
    );
  }

// ADD this method to MyFormsScreen class
  Widget _buildCleanMyFormsTab({
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyFormsTab({
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Color(0xFF4051B5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isChecklist) {
    final Color primaryColor =
        isChecklist ? Colors.orange : const Color(0xFF4051B5);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isChecklist ? Icons.checklist : Icons.description,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isChecklist
                  ? 'You haven\'t created any checklists yet'
                  : 'You haven\'t created any forms yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isChecklist
                  ? 'Checklists are forms with time windows that can recur'
                  : 'Tap the "Create Form" button in the bottom navigation to get started',
              style: const TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
