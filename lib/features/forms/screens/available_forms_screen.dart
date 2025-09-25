// lib/screens/forms/available_forms_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jala_form/services/supabase_service.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/screens/checklist_form_screen.dart';
import 'package:jala_form/features/forms/screens/form_detail_screen.dart';

class AvailableFormsScreen extends StatefulWidget {
  const AvailableFormsScreen({super.key});

  @override
  State<AvailableFormsScreen> createState() => _AvailableFormsScreenState();
}

class CustomAnimatedTabs extends StatefulWidget {
  final List<TabData> tabs;
  final Function(int) onTabChanged;
  final int initialIndex;

  const CustomAnimatedTabs({
    super.key,
    required this.tabs,
    required this.onTabChanged,
    this.initialIndex = 0,
  });

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
      duration: const Duration(milliseconds: 250),
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
    final tabWidth = (screenWidth - (containerPadding * 2) - 8) / 2;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: containerPadding, vertical: 12),
      padding: const EdgeInsets.all(4),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: _selectedIndex * tabWidth,
            child: Container(
              width: tabWidth,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF5C6BC0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
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
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tab.count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.2) : AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tab.count.toString(),
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

class _AvailableFormsScreenState extends State<AvailableFormsScreen> with TickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  List<CustomForm> _availableForms = [];
  List<CustomForm> _checklistForms = [];
  List<CustomForm> _regularForms = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  int _currentTabIndex = 0;
  late TabController _tabController;
  StreamSubscription<List<CustomForm>>? _formsSubscription;

  void _updateAndFilterForms(List<CustomForm> forms) {
    if (mounted) {
      setState(() {
        _availableForms = forms;
        _checklistForms = forms.where((form) => form.isChecklist).toList();
        _regularForms = forms.where((form) => !form.isChecklist).toList();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _tabController = TabController(length: 2, vsync: this);
    _initializeRealTime();
    _loadForms();
  }

  void _initializeRealTime() async {
    try {
      await _supabaseService.initializeRealTimeSubscriptions();
      _formsSubscription = _supabaseService.availableFormsStream.listen(
        (forms) {
          _updateAndFilterForms(forms);
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
    _formsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadForms() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in. Please log in again.')),
          );
        }
        throw Exception('User not logged in');
      }
      final forms = await _supabaseService.getAvailableForms();
      _updateAndFilterForms(forms);
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
        if (_availableForms.isNotEmpty) {
          _animationController.forward();
        }
      }
    }
  }

  Widget _buildFormsList(List<CustomForm> forms, bool isChecklist) {
    if (forms.isEmpty) {
      return _buildEnhancedEmptyState(isChecklist); // Using enhanced empty state
    }
    return ListView.builder(
      itemCount: forms.length,
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        // Defaulting to _buildSmoothAnimatedCard, can be made configurable if needed
        return _buildSmoothAnimatedCard(forms[index], isChecklist, index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
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
                          _buildFormsList(_regularForms, false),
                          _buildFormsList(_checklistForms, true),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmoothAnimatedCard(CustomForm form, bool isChecklist, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation)),
          child: Opacity(
            opacity: animation,
            child: _FormListItemCard(form: form, isChecklist: isChecklist), // Using new Widget
          ),
        );
      },
    );
  }

  Widget _buildIOSStyleAnimatedCard(CustomForm form, bool isChecklist, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 60)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack, 
      builder: (context, animation, child) {
        final safeAnimation = animation.clamp(0.0, 1.0);
        final scaleValue = (0.9 + (0.1 * safeAnimation)).clamp(0.1, 1.1);
        return Transform.scale(
          scale: scaleValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - safeAnimation)),
            child: Opacity(
              opacity: safeAnimation,
              child: _FormListItemCard(form: form, isChecklist: isChecklist), // Using new Widget
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpringAnimatedCard(CustomForm form, bool isChecklist, int index) {
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
              child: _FormListItemCard(form: form, isChecklist: isChecklist), // Using new Widget
            ),
          ),
        );
      },
    );
  }

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
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                            (isChecklist ? Colors.orange : AppTheme.primaryColor).withOpacity(0.1),
                            (isChecklist ? Colors.orange : AppTheme.primaryColor).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        isChecklist ? Icons.checklist_rounded : Icons.description_rounded,
                        size: 60,
                        color: (isChecklist ? Colors.orange : AppTheme.primaryColor).withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isChecklist ? 'No checklists available' : 'No forms available',
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
                      isChecklist ? 'Checklists shared with you will appear here' : 'Forms shared with you will appear here',
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
  
  // _buildCompactEmptyState is removed as _buildEnhancedEmptyState is used now.
  // _buildCompactScheduleRow, _handleSecondaryAction, _getSecondaryButtonText are specific to MyFormsScreen and not used here.
  // _buildEnhancedScheduleRow is moved to _FormListItemCard
}

// NEW STATELESS WIDGET for displaying a single form card
class _FormListItemCard extends StatelessWidget {
  final CustomForm form;
  final bool isChecklist;

  const _FormListItemCard({
    required this.form,
    required this.isChecklist,
  });

  // Helper method for schedule rows (moved from _AvailableFormsScreenState)
  Widget _buildImprovedScheduleRow(BuildContext context, IconData icon, String text, Color color) {
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

  // Helper method to format date (moved from _AvailableFormsScreenState)
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  // Action Buttons specific to AvailableFormsScreen (Fill Form / Start Checklist)
  Widget _buildActionButtons(BuildContext context, Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () {
          if (isChecklist) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChecklistFormScreen(form: form), // Not a preview
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FormDetailScreen(
                  form: form,
                  isPreview: false, // Not a preview
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth > 600 ? 20.0 : 14.0;

    String? timeWindow;
    if (isChecklist && form.startTime != null && form.endTime != null) {
      timeWindow = '${form.startTime!.format(context)} - ${form.endTime!.format(context)}';
    }

    String? recurrencePattern;
    if (isChecklist && form.isRecurring && form.recurrenceType != null) {
      recurrencePattern = form.recurrenceType.toString().split('.').last;
      recurrencePattern = recurrencePattern[0].toUpperCase() + recurrencePattern.substring(1);
    }

    final Color primaryColor = isChecklist ? const Color(0xFFFF8A50) : Color(0xFF5C6BC0);
    final Color lightColor = isChecklist ? const Color(0xFFFFF4F0) : const Color(0xFFF3F4FF);
    final Color darkColor = isChecklist ? const Color(0xFFE17055) : AppTheme.primaryColor;
    final Color borderColor = isChecklist ? const Color(0xFFFFE0D6) : const Color(0xFFE8EAFF);

    return Container(
      margin: EdgeInsets.fromLTRB(cardPadding, 6, cardPadding, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
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
                    boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Icon(
                    isChecklist ? Icons.task_alt_rounded : Icons.description_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3748), letterSpacing: -0.3, height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: primaryColor.withOpacity(0.2), width: 0.5),
                            ),
                            child: Text(
                              '${form.fields.length} fields',
                              style: TextStyle(fontSize: 11, color: darkColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (form.description.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                form.description,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w400),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primaryColor, darkColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    isChecklist ? 'Checklist' : 'Form',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isChecklist && (timeWindow != null || recurrencePattern != null || form.startDate != null)) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        if (timeWindow != null) _buildImprovedScheduleRow(context, Icons.access_time_rounded, timeWindow, primaryColor),
                        if (recurrencePattern != null) _buildImprovedScheduleRow(context, Icons.repeat_rounded, recurrencePattern, primaryColor),
                        if (form.startDate != null) _buildImprovedScheduleRow(context, Icons.calendar_today_rounded, 'Valid from ${_formatDate(form.startDate!)}${form.endDate != null ? ' to ${_formatDate(form.endDate!)}' : ''}', primaryColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _buildActionButtons(context, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
