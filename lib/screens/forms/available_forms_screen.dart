// lib/screens/forms/available_forms_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/custom_form.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'form_detail_screen.dart';
import 'checklist_form_screen.dart';

class AvailableFormsScreen extends StatefulWidget {
  const AvailableFormsScreen({super.key});

  @override
  State<AvailableFormsScreen> createState() => _AvailableFormsScreenState();
}

// Add this class to both screen files (AvailableFormsScreen and MyFormsScreen)

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

// Change this line at the top of AvailableFormsScreen class
class _AvailableFormsScreenState extends State<AvailableFormsScreen>
    with TickerProviderStateMixin {
  // Changed from SingleTickerProviderStateMixin
  final _supabaseService = SupabaseService();
  List<CustomForm> _availableForms = [];
  List<CustomForm> _checklistForms = [];
  List<CustomForm> _regularForms = [];
  bool _isLoading = true;
  late AnimationController _animationController;

// Add these class variables to AvailableFormsScreen (at the top with other variables)
  int _currentTabIndex = 0;
  late TabController _tabController;
  StreamSubscription<List<CustomForm>>? _formsSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _tabController = TabController(length: 2, vsync: this);

    // ADD THESE TWO LINES:
    _initializeRealTime();
    _loadForms();
  }

  void _initializeRealTime() async {
    try {
      // Initialize real-time subscriptions in the service
      await _supabaseService.initializeRealTimeSubscriptions();

      // Listen to available forms stream
      _formsSubscription = _supabaseService.availableFormsStream.listen(
        (forms) {
          if (mounted) {
            setState(() {
              _availableForms = forms;
              _checklistForms =
                  forms.where((form) => form.isChecklist).toList();
              _regularForms = forms.where((form) => !form.isChecklist).toList();
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
    _animationController.dispose();
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

      // Get available forms
      final forms = await _supabaseService.getAvailableForms();

      setState(() {
        _availableForms = forms;
        _checklistForms = forms.where((form) => form.isChecklist).toList();
        _regularForms = forms.where((form) => !form.isChecklist).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading forms: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
      }
    }
  }

// Replace the entire build method in AvailableFormsScreen

// Replace the build method in AvailableFormsScreen
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
                  label: 'Forms',
                  count: _regularForms.length,
                ),
                TabData(
                  icon: Icons.checklist_rounded,
                  label: 'Checklists',
                  count: _checklistForms.length,
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
                          // Regular Forms Tab
                          _regularForms.isEmpty
                              ? _buildCompactEmptyState(false)
                              : ListView.builder(
                                  itemCount: _regularForms.length,
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 20),
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return _buildSmoothAnimatedCard(
                                        _regularForms[index], false, index);
                                  },
                                ),

                          // Checklists Tab
                          _checklistForms.isEmpty
                              ? _buildCompactEmptyState(true)
                              : ListView.builder(
                                  itemCount: _checklistForms.length,
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 20),
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return _buildSmoothAnimatedCard(
                                        _checklistForms[index], true, index);
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
                            (isChecklist ? Colors.orange : Color(0xFF5C6BC0))
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

// Override the helper methods for AvailableFormsScreen specific actions
  void _handleSecondaryAction(CustomForm form, bool isChecklist) {
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
  }

  String _getSecondaryButtonText() {
    return 'Preview';
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

// iOS-style spring animation that's safer
  Widget _buildIOSStyleAnimatedCard(
      CustomForm form, bool isChecklist, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 60)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack, // Similar to iOS spring but safer
      builder: (context, animation, child) {
        // Ensure all values stay within safe ranges
        final safeAnimation = animation.clamp(0.0, 1.0);
        final scaleValue = (0.9 + (0.1 * safeAnimation)).clamp(0.1, 1.1);

        return Transform.scale(
          scale: scaleValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - safeAnimation)),
            child: Opacity(
              opacity: safeAnimation,
              child: _buildFormCard(form, isChecklist),
            ),
          ),
        );
      },
    );
  }

// Add _buildSpringAnimatedCard method to AvailableFormsScreen as well
  Widget _buildSpringAnimatedCard(
      CustomForm form, bool isChecklist, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * animation),
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - animation)),
            child: Opacity(
              opacity: animation,
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

  Widget _buildActionButtons(
      CustomForm form, bool isChecklist, Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () {
          if (isChecklist) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChecklistFormScreen(form: form),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FormDetailScreen(
                  form: form,
                  isPreview: false,
                ),
              ),
            );
          }
        },
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isChecklist ? Icons.play_arrow_rounded : Icons.edit_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        label: Text(
          isChecklist ? 'Start Checklist' : 'Fill Form',
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
    );
  }

// Replace _buildFormCard method in BOTH screens with this updated version

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
        : Color(0xFF5C6BC0); // Use requested purple for regular forms

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
          // Improved Header Section
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

                // Improved Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

                // Action Button - Different for each screen
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
