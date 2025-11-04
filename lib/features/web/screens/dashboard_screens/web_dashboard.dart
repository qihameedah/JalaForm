import 'package:flutter/material.dart';
import 'package:jala_form/features/web/screens/dashboard_screens/widgets/no_responses_widget.dart';
import 'package:jala_form/features/web/web_form_builder.dart';
import 'package:jala_form/features/web/web_form_editor.dart';
import 'package:jala_form/services/supabase_service.dart';
import 'package:jala_form/core/services/web_pdf_service.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_field.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:jala_form/features/forms/models/user_group.dart';
import 'package:jala_form/features/web/screens/web_group_detail_screen.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import '../web_profile_screen.dart';
import 'package:excel/excel.dart' hide Border;
import '../web_form_submission_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

// Import shared Likert models
import 'package:jala_form/shared/models/likert/likert_option.dart';
import 'package:jala_form/shared/models/likert/likert_display_data.dart';
import 'package:jala_form/shared/utils/likert_parser.dart';


class WebDashboard extends StatefulWidget {
  const WebDashboard({super.key});

  @override
  State<WebDashboard> createState() => _WebDashboardState();
}

class _WebDashboardState extends State<WebDashboard>
    with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  List<CustomForm> _myForms = <CustomForm>[];
  List<CustomForm> _availableForms = <CustomForm>[];
  List<CustomForm> _availableRegularForms = <CustomForm>[];
  List<CustomForm> _availableChecklistForms = <CustomForm>[];
  final Map<String, List<FormResponse>> _formResponses =
      <String, List<FormResponse>>{};
  List<UserGroup> _userGroups = <UserGroup>[];
  List<UserGroup> _filteredGroups = <UserGroup>[];
  bool _isLoading = true;
  bool _isExporting = false;
  String _username = 'User';
  int _selectedFormIndex = -1;
  late AnimationController _animationController;
  String _selectedFormType = 'all'; // 'all', 'forms', 'checklists'
  String _currentView = 'dashboard'; // dashboard, forms, responses, groups
  bool _isCreatingForm = false;

  // Responsive breakpoints
  bool get isSmallScreen => MediaQuery.of(context).size.width < 600;
  bool get isMediumScreen =>
      MediaQuery.of(context).size.width < 1024 &&
      MediaQuery.of(context).size.width >= 600;
  bool get isLargeScreen => MediaQuery.of(context).size.width >= 1024;

  // New controller for search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // New variables for sorting and filtering
  String _sortBy = 'newest'; // Options: newest, oldest, alphabetical

// Update the _onSearchChanged method:
  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        final username = await _supabaseService.getUsername(user.id);
        if (mounted) {
          setState(() {
            _username = username;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

// Update the _loadData() method to add better error handling:
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load user's forms with better error handling
      final forms = await _supabaseService.getForms();
      final user = _supabaseService.getCurrentUser();

      if (user != null && mounted) {
        final myForms =
            forms.where((form) => form.created_by == user.id).toList();

        // Batch fetch responses for all forms at once (eliminates N+1 query pattern)
        final formIds = myForms.map((form) => form.id).toList();
        final responseMap = await _supabaseService.getFormResponsesBatch(formIds);

        if (mounted) {
          setState(() {
            _myForms = myForms;
            _formResponses.clear();
            _formResponses.addAll(responseMap);
          });
        }

        // Load available forms with error handling
        try {
          final availableForms = await _supabaseService.getAvailableForms();
          if (mounted) {
            setState(() {
              _availableForms = List<CustomForm>.from(availableForms);
              _availableRegularForms =
                  availableForms.where((form) => !form.isChecklist).toList();
              _availableChecklistForms =
                  availableForms.where((form) => form.isChecklist).toList();
            });
          }
        } catch (e) {
          debugPrint('Error loading available forms: $e');
          if (mounted) {
            setState(() {
              _availableForms = <CustomForm>[];
              _availableRegularForms = <CustomForm>[];
              _availableChecklistForms = <CustomForm>[];
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _loadData: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        try {
          if (_animationController.status != AnimationStatus.completed) {
            _animationController.forward();
          }
        } catch (e) {
          debugPrint('Error starting animation: $e');
        }
      }
    }
  }

// Add this to your build method to debug the Forms view specifically:
  @override
  Widget build(BuildContext context) {
    // Add debugging for Forms view
    if (_currentView == 'forms') {
      debugPrint(
          'Building Forms view - Loading: $_isLoading, Forms: ${_myForms.length}');
    }

    return Scaffold(
      body: Column(
        children: [
          // Enhanced Responsive Header
          _buildResponsiveHeader(),

          // Main Content Area
          Expanded(
            child: _isLoading ? _buildLoadingIndicator() : _buildCurrentView(),
          ),
        ],
      ),
      // Add bottom navbar for tiny screens
      bottomNavigationBar:
          MediaQuery.of(context).size.width < 360 && !_isLoading
              ? Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMobileNavItem(
                          'Dashboard',
                          Icons.dashboard_rounded,
                          _currentView == 'dashboard',
                          () => _navigateToView('dashboard')),
                      _buildMobileNavItem(
                          'Forms',
                          Icons.article_rounded,
                          _currentView == 'forms',
                          () => _navigateToView('forms')),
                      _buildMobileNavItem(
                          'Responses',
                          Icons.analytics_rounded,
                          _currentView == 'responses',
                          () => _navigateToView('responses')),
                      _buildMobileNavItem(
                          'Groups',
                          Icons.group_rounded,
                          _currentView == 'groups',
                          () => _navigateToView('groups')),
                    ],
                  ),
                )
              : null,
    );
  }

// Mobile nav item
  Widget _buildMobileNavItem(
      String label, IconData icon, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.primaryColor : Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppTheme.primaryColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Add this improved loading indicator:
  Widget _buildLoadingIndicator() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Loading your forms...",
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveHeader() {
    final screenWidth = MediaQuery.of(context).size.width;

    // Define breakpoints more precisely for the in-between sizes
    final isTabletSize = screenWidth >= 600 && screenWidth < 1024;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row with logo and user profile
          Row(
            children: [
              // Logo - make it more compact on tablet
              Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.assignment_rounded,
                  color: AppTheme.primaryColor,
                  size: isTabletSize ? 20 : 22,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Jala Form',
                style: TextStyle(
                  fontSize: isTabletSize ? 15 : 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),

              // On large screens, place tabs in the top row
              if (screenWidth >= 1024)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNavButton(
                        'Dashboard',
                        Icons.dashboard_outlined,
                        _currentView == 'dashboard',
                        () => setState(() => _currentView = 'dashboard'),
                        isCompact: false,
                      ),
                      _buildNavButton(
                        'Forms',
                        Icons.article_outlined,
                        _currentView == 'forms',
                        () => setState(() => _currentView = 'forms'),
                        isCompact: false,
                      ),
                      _buildNavButton(
                        'Responses',
                        Icons.analytics_outlined,
                        _currentView == 'responses',
                        () => setState(() => _currentView = 'responses'),
                        isCompact: false,
                      ),
                      _buildNavButton(
                        'Groups',
                        Icons.group_outlined,
                        _currentView == 'groups',
                        () => setState(() => _currentView = 'groups'),
                        isCompact: false,
                      ),
                    ],
                  ),
                )
              else
                // We need this to push items to the right on tablet sizes
                const Spacer(),

              // Create Form button - adjust size for tablet
              if (screenWidth >= 600)
                Padding(
                  padding: EdgeInsets.only(right: isTabletSize ? 8 : 12),
                  child: ElevatedButton.icon(
                    onPressed: _createNewForm,
                    icon: Icon(Icons.add,
                        color: Colors.white, size: isTabletSize ? 14 : 16),
                    label: Text(
                      isTabletSize ? 'Create' : 'Create Form',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: isTabletSize ? 13 : 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: EdgeInsets.symmetric(
                          horizontal: isTabletSize ? 12 : 16,
                          vertical: isTabletSize ? 8 : 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    onPressed: _createNewForm,
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),

              // User profile - make it more compact on tablet
              _buildUserProfileButton(isTabletSize: isTabletSize),
            ],
          ),

          // Second row with tabs for medium and small screens
          if (screenWidth < 1024)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment
                      .start, // Align to start to avoid overflow
                  children: [
                    _buildNavButton(
                      'Dashboard',
                      Icons.dashboard_outlined,
                      _currentView == 'dashboard',
                      () => setState(() => _currentView = 'dashboard'),
                      isCompact: isTabletSize,
                    ),
                    _buildNavButton(
                      'Forms',
                      Icons.article_outlined,
                      _currentView == 'forms',
                      () => setState(() => _currentView = 'forms'),
                      isCompact: isTabletSize,
                    ),
                    _buildNavButton(
                      'Responses',
                      Icons.analytics_outlined,
                      _currentView == 'responses',
                      () => setState(() => _currentView = 'responses'),
                      isCompact: isTabletSize,
                    ),
                    _buildNavButton(
                      'Groups',
                      Icons.group_outlined,
                      _currentView == 'groups',
                      () => setState(() => _currentView = 'groups'),
                      isCompact: isTabletSize,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

// Updated user profile button with tablet mode
  Widget _buildUserProfileButton({bool isTabletSize = false}) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            radius: isTabletSize ? 14 : 16,
            child: Text(
              _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isTabletSize ? 12 : 14,
              ),
            ),
          ),
          if (screenWidth >= 600 && !isTabletSize) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                _username,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          // For tablet size, just show the icon menu without username
          PopupMenuButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: isTabletSize ? 16 : 18,
              color: Colors.grey.shade600,
            ),
            padding: EdgeInsets.zero,
            offset: const Offset(0, 40),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.account_circle,
                        color: AppTheme.primaryColor,
                        size: isTabletSize ? 16 : 18),
                    const SizedBox(width: 8),
                    const Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout,
                        color: AppTheme.errorColor,
                        size: isTabletSize ? 16 : 18),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'profile') {
                _openProfile();
              } else if (value == 'logout') {
                _signOut();
              }
            },
          ),
        ],
      ),
    );
  }

// Update the _buildNavButton method to use the new navigation:
  Widget _buildNavButton(
      String label, IconData icon, bool isActive, VoidCallback onTap,
      {bool isCompact = false}) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Adjust spacing based on screen width
    final spacing = screenWidth < 400 ? 2.0 : (isCompact ? 3.0 : 6.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing),
      child: InkWell(
        onTap: () {
          debugPrint('Nav button tapped: $label');
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 6 : (screenWidth < 400 ? 8 : 12),
              vertical: isCompact ? 6 : (screenWidth < 400 ? 6 : 8)),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isCompact ? 16 : (screenWidth < 400 ? 16 : 18),
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
              ),
              SizedBox(width: isCompact ? 4 : 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: isCompact ? 12 : (screenWidth < 400 ? 12 : 14),
                  color: isActive
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Update your _buildCurrentView method with better debugging:
  Widget _buildCurrentView() {
    debugPrint(
        'Building current view: $_currentView, forms count: ${_myForms.length}, loading: $_isLoading');

    try {
      switch (_currentView) {
        case 'dashboard':
          return _buildDashboardView();
        case 'forms':
          debugPrint('Building forms view with ${_myForms.length} forms');
          return _buildFormsView();
        case 'responses':
          return _buildResponsesView();
        case 'groups':
          return _buildGroupsView();
        default:
          debugPrint('Unknown view: $_currentView, defaulting to dashboard');
          return _buildDashboardView();
      }
    } catch (e) {
      debugPrint('Error building current view: $e');
      return _buildErrorView('Error loading view: ${e.toString()}');
    }
  }

// Add this method to debug form state:
  void _debugFormState() {
    debugPrint('=== FORM DEBUG INFO ===');
    debugPrint('Current view: $_currentView');
    debugPrint('Is loading: $_isLoading');
    debugPrint('My forms count: ${_myForms.length}');
    debugPrint('Available forms count: ${_availableForms.length}');
    debugPrint('Search query: "$_searchQuery"');
    debugPrint('Sort by: $_sortBy');

    if (_myForms.isNotEmpty) {
      debugPrint('First form: ${_myForms.first.title}');
    }

    debugPrint('======================');
  }

// Update the navigation method to include debugging:
  void _navigateToView(String view) {
    debugPrint('Navigating to view: $view');
    setState(() {
      _currentView = view;
    });
    _debugFormState();
  }

// Add this helper method for better debugging:
  Widget _buildErrorView(String message) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentView = 'dashboard';
                  });
                  _loadData();
                },
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    if (_myForms.isEmpty && _availableForms.isEmpty) {
      return _buildEmptyState();
    }

    // Count forms by type
    final regularFormsCount =
        _myForms.where((form) => !form.isChecklist).length;
    final checklistsCount = _myForms.where((form) => form.isChecklist).length;

    // Count total responses
    int totalResponses = 0;
    _formResponses.forEach((_, responses) {
      totalResponses += responses.length;
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard header with animated greeting
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve:
                Curves.easeOutCubic, // Changed from elasticOut to easeOutCubic
            builder: (context, value, child) {
              return Opacity(
                opacity: clampOpacity(value), // Add clamping
                child: Transform.translate(
                  offset: Offset(-30 * (1 - value), 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $_username!',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome to your form dashboard',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSmallScreen)
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: clampOpacity(value),
                              child: Transform.translate(
                                offset: Offset(30 * (1 - value), 0),
                                child: DropdownButton<String>(
                                  value: _sortBy,
                                  icon: const Icon(Icons.sort),
                                  underline: Container(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'newest',
                                      child: Text('Newest First'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'oldest',
                                      child: Text('Oldest First'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'alphabetical',
                                      child: Text('Alphabetical'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _sortBy = value!;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Stats cards with animations and responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              final useVerticalLayout = constraints.maxWidth < 800;

              if (useVerticalLayout) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.assignment_rounded,
                            iconColor: AppTheme.primaryColor,
                            backgroundColor:
                                AppTheme.primaryColor.withOpacity(0.1),
                            title: "Total Forms",
                            valueText: "${_myForms.length}",
                            delay: 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.article_rounded,
                            iconColor: Colors.blue,
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            title: "Regular Forms",
                            valueText: "$regularFormsCount",
                            delay: 100,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.checklist_rounded,
                            iconColor: Colors.orange,
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            title: "Checklists",
                            valueText: "$checklistsCount",
                            delay: 200,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.analytics_rounded,
                            iconColor: Colors.green,
                            backgroundColor: Colors.green.withOpacity(0.1),
                            title: "Total Responses",
                            valueText: "$totalResponses",
                            delay: 300,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: _buildAnimatedStatCard(
                        icon: Icons.assignment_rounded,
                        iconColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        title: "Total Forms",
                        valueText: "${_myForms.length}",
                        delay: 0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        icon: Icons.article_rounded,
                        iconColor: Colors.blue,
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        title: "Regular Forms",
                        valueText: "$regularFormsCount",
                        delay: 100,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        icon: Icons.checklist_rounded,
                        iconColor: Colors.orange,
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        title: "Checklists",
                        valueText: "$checklistsCount",
                        delay: 200,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        icon: Icons.analytics_rounded,
                        iconColor: Colors.green,
                        backgroundColor: Colors.green.withOpacity(0.1),
                        title: "Total Responses",
                        valueText: "$totalResponses",
                        delay: 300,
                      ),
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 32),

          // Available Forms section with animated header
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: clampOpacity(value),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available Forms',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Forms that have been shared with you',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSmallScreen && _availableForms.isNotEmpty)
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: TextButton.icon(
                                onPressed: () =>
                                    setState(() => _currentView = 'forms'),
                                icon: const Icon(Icons.arrow_forward, size: 16),
                                label: const Text('View All'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Filter chips with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: clampOpacity(value),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Forms', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Regular Forms', 'forms'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Checklists', 'checklists'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Available forms list with staggered animations
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: clampOpacity(value),
                child: _availableForms.isEmpty
                    ? _buildNoAvailableFormsMessage()
                    : _buildAvailableFormsList(),
              );
            },
          ),

          // Create a new form button (floating)
          if (_availableForms.isEmpty && !isSmallScreen)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.white),
                        label: const Text('Create Your First Form',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _createNewForm,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAvailableFormsList() {
    // Filter forms based on selected type
    List<CustomForm> formsToShow = [];
    switch (_selectedFormType) {
      case 'forms':
        formsToShow = _availableRegularForms;
        break;
      case 'checklists':
        formsToShow = _availableChecklistForms;
        break;
      case 'all':
      default:
        formsToShow = _availableForms;
        break;
    }

    // Filter forms based on search query
    if (_searchQuery.isNotEmpty) {
      formsToShow = formsToShow
          .where((form) => form.title.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // If no forms to show
    if (formsToShow.isEmpty) {
      return _buildNoItemsFound();
    }

    // Display forms in a stylish list with animations
    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: formsToShow.length,
        itemBuilder: (context, index) {
          final form = formsToShow[index];
          final isChecklist = form.isChecklist;

          // Get color theme based on form type
          final Color accentColor = isChecklist ? Colors.orange : Colors.blue;

          // This is the enhanced card with animation
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 450),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _openFormSubmission(form),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Form type icon with colored background
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(
                                  isChecklist
                                      ? Icons.checklist_rounded
                                      : Icons.description_rounded,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Form name and creation date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Form title
                                  Text(
                                    form.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  const SizedBox(height: 4),

                                  // Creation date with icon
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Created: ${_formatDate(form.created_at)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Fill button with animation
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.8, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: ElevatedButton(
                                    onPressed: () => _openFormSubmission(form),
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: accentColor,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isChecklist
                                              ? Icons.play_arrow_rounded
                                              : Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isChecklist ? "Start" : "Fill",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsesCompactCard(CustomForm form) {
    final responses = _formResponses[form.id] ?? [];
    final responseCount = responses.length;
    final isChecklist = form.isChecklist;
    final accentColor = isChecklist ? Colors.orange : Colors.blue;

    return Container(
      height: 48, // Extremely reduced height to fit many more cards
      margin: const EdgeInsets.only(bottom: 4), // Minimum margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFormIndex = _myForms.indexOf(form);
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4), // Minimal padding
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon indicator (tiny)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Icon(
                      isChecklist
                          ? Icons.checklist_rounded
                          : Icons.article_rounded,
                      color: accentColor,
                      size: 14,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Title
                Expanded(
                  child: Text(
                    form.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Simple metadata
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isChecklist
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isChecklist ? "Checklist" : "Form",
                    style: TextStyle(
                      fontSize: 10,
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Response count
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: responseCount > 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.analytics_rounded,
                        size: 8,
                        color: responseCount > 0
                            ? Colors.green
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "$responseCount",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: responseCount > 0
                              ? Colors.green
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // Tiny arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Add this improved _buildIconButton method:
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    double iconSize = 20,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final paddingValue = screenWidth < 400 ? 4.0 : 6.0;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: EdgeInsets.all(paddingValue),
            child: Icon(
              icon,
              size: iconSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

// Add this improved _buildMetadataPill method:
  Widget _buildMetadataPill(String label, IconData icon,
      {Color? color, double fontSize = 11, double iconSize = 12}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 400 ? 4.0 : 6.0;
    final verticalPadding = screenWidth < 400 ? 2.0 : 2.0;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: color ?? Colors.grey.shade700,
          ),
          SizedBox(width: screenWidth < 400 ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color ?? Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFormType == value;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedFormType = value;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondaryColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedStatCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String valueText,
    required int delay,
  }) {
    // Get screen width to determine responsive sizes
    final screenWidth = MediaQuery.of(context).size.width;

    // Adjust sizes based on screen width
    final isVerySmallScreen = screenWidth < 360;
    final isSmallScreen = screenWidth < 600;
    final isMobileView = screenWidth < 450;

    // Significantly reduced values for mobile
    final containerPadding = isVerySmallScreen
        ? 8.0
        : (isMobileView ? 10.0 : (isSmallScreen ? 12.0 : 16.0));

    // Use smaller vertical padding specifically on mobile to reduce height
    final containerVerticalPadding = isVerySmallScreen
        ? 6.0
        : (isMobileView ? 8.0 : (isSmallScreen ? 10.0 : 16.0));

    // Smaller icon container for mobile
    final iconPadding = isVerySmallScreen
        ? 5.0
        : (isMobileView ? 6.0 : (isSmallScreen ? 8.0 : 12.0));

    // Smaller icon size for mobile
    final iconSize = isVerySmallScreen
        ? 14.0
        : (isMobileView ? 16.0 : (isSmallScreen ? 18.0 : 22.0));

    // Smaller text sizes for mobile
    final valueFontSize = isVerySmallScreen
        ? 14.0
        : (isMobileView ? 15.0 : (isSmallScreen ? 16.0 : 18.0));

    final titleFontSize = isVerySmallScreen
        ? 9.0
        : (isMobileView ? 10.0 : (isSmallScreen ? 11.0 : 13.0));

    // Reduced spacing
    final horizontalSpacing = isVerySmallScreen
        ? 6.0
        : (isMobileView ? 8.0 : (isSmallScreen ? 10.0 : 16.0));

    final verticalSpacing = isVerySmallScreen
        ? 1.0
        : (isMobileView ? 2.0 : (isSmallScreen ? 3.0 : 4.0));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(
                0, 20 * (1 - animValue)), // Reduced offset animation on mobile
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: containerPadding,
                vertical:
                containerVerticalPadding, // Different value for vertical to reduce height
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(width: horizontalSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:
                      MainAxisSize.min, // Important to minimize height
                      children: [
                        Text(
                          valueText,
                          style: TextStyle(
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            height: isMobileView
                                ? 1.0
                                : 1.2, // Tighter line height on mobile
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: verticalSpacing),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            color: Colors.grey.shade600,
                            height: isMobileView
                                ? 1.0
                                : 1.2, // Tighter line height on mobile
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Replace the _buildNoItemsFound() method with this:
  Widget _buildNoItemsFound() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 400 ? 48.0 : 64.0;
    final titleFontSize = screenWidth < 400 ? 16.0 : 18.0;
    final messageFontSize = screenWidth < 400 ? 13.0 : 14.0;
    final padding = screenWidth < 400 ? 24.0 : 40.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: iconSize,
                color: Colors.grey.withOpacity(0.5),
              ),
              SizedBox(height: screenWidth < 400 ? 12 : 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No forms matching "$_searchQuery"'
                    : 'No forms available',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenWidth < 400 ? 6 : 8),
              if (_searchQuery.isNotEmpty)
                Container(
                  width: screenWidth < 600 ? screenWidth * 0.8 : 300,
                  padding: EdgeInsets.all(screenWidth < 400 ? 12 : 16),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.infoColor,
                        size: screenWidth < 400 ? 20 : 24,
                      ),
                      SizedBox(height: screenWidth < 400 ? 6 : 8),
                      Text(
                        'Try adjusting your search terms or create a new form.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: messageFontSize,
                        ),
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

// No available forms message
  Widget _buildNoAvailableFormsMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No forms available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.infoColor,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When forms are shared with you, they will appear here for easy access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Replace the _buildFormsView() method with this:
  Widget _buildFormsView() {
    try {
      // Show loading state
      if (_isLoading) {
        return _buildLoadingIndicator();
      }

      // Show empty state
      if (_myForms.isEmpty) {
        return _buildEmptyState();
      }

      // Filter forms based on search query with null safety
      List<CustomForm> filteredForms = List<CustomForm>.from(_myForms);
      if (_searchQuery.isNotEmpty) {
        filteredForms = _myForms.where((form) {
          final title = form.title.toLowerCase();
          final description = form.description.toLowerCase();
          return title.contains(_searchQuery) ||
              description.contains(_searchQuery);
        }).toList();
      }

      // Sort forms according to selected sort option
      _sortFormsList(filteredForms);

      final screenWidth = MediaQuery.of(context).size.width;
      final horizontalPadding =
          screenWidth < 400 ? 12.0 : (screenWidth < 600 ? 16.0 : 24.0);
      final verticalPadding =
          screenWidth < 400 ? 10.0 : (screenWidth < 600 ? 12.0 : 16.0);

      return Container(
        color: Colors.grey.shade50, // Add background color
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and actions
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: verticalPadding),
              child: _buildResponsiveFormsHeader(filteredForms),
            ),

            // Search field
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                margin:
                    EdgeInsets.symmetric(vertical: screenWidth < 400 ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search forms...',
                    prefixIcon: Icon(Icons.search,
                        color: Colors.grey.shade500,
                        size: screenWidth < 400 ? 16 : 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: screenWidth < 400 ? 10 : 12,
                      horizontal: screenWidth < 400 ? 8 : 12,
                    ),
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: screenWidth < 400 ? 13 : 14),
                  ),
                  style: TextStyle(fontSize: screenWidth < 400 ? 13 : 14),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ),

            // Forms list
            Expanded(
              child: filteredForms.isEmpty
                  ? _buildNoItemsFound()
                  : Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: _buildFormsList(filteredForms),
                    ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error in _buildFormsView: $e');
      return _buildErrorView('Error loading forms view');
    }
  }

// Update the _sortFormsList method:
  void _sortFormsList(List<CustomForm> forms) {
    try {
      switch (_sortBy) {
        case 'newest':
          forms.sort((a, b) => b.created_at.compareTo(a.created_at));
          break;
        case 'oldest':
          forms.sort((a, b) => a.created_at.compareTo(b.created_at));
          break;
        case 'alphabetical':
          forms.sort((a, b) => a.title.compareTo(b.title));
          break;
      }
    } catch (e) {
      debugPrint('Error sorting forms: $e');
    }
  }

// Replace the _buildResponsiveFormsHeader() method with this:
  Widget _buildResponsiveFormsHeader(List<CustomForm> filteredForms) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 480;
    final isTablet = screenWidth >= 480 && screenWidth < 800;

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Forms',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : (isTablet ? 20 : 24),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage all your forms and checklists',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : (isTablet ? 13 : 14),
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                // Sort dropdown
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 6 : 8, vertical: 0),
                  margin: EdgeInsets.only(right: isTablet ? 8 : 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: Icon(Icons.keyboard_arrow_down,
                          color: Colors.grey.shade700,
                          size: isTablet ? 16 : 18),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: isTablet ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                      isDense: isTablet,
                      items: const [
                        DropdownMenuItem(
                            value: 'newest', child: Text('Newest First')),
                        DropdownMenuItem(
                            value: 'oldest', child: Text('Oldest First')),
                        DropdownMenuItem(
                            value: 'alphabetical', child: Text('Alphabetical')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value!;
                        });
                      },
                    ),
                  ),
                ),

                // Create form button
                ElevatedButton.icon(
                  icon: Icon(Icons.add,
                      color: Colors.white, size: isTablet ? 14 : 16),
                  label: Text(
                    isTablet ? 'Create' : 'Create Form',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: isTablet ? 12 : 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 16,
                      vertical: isTablet ? 8 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _createNewForm,
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            SizedBox(height: 12),
            Row(
              children: [
                // Sort dropdown for mobile
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: Colors.grey.shade700, size: 16),
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        isExpanded: true,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'newest', child: Text('Newest First')),
                          DropdownMenuItem(
                              value: 'oldest', child: Text('Oldest First')),
                          DropdownMenuItem(
                              value: 'alphabetical',
                              child: Text('Alphabetical')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Create form button for mobile
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white, size: 14),
                  label: const Text(
                    'Create',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _createNewForm,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

// Replace the _buildFormsList() method with this:
  Widget _buildFormsList(List<CustomForm> forms) {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      final isCompactScreen = screenWidth < 500;
      final spacing = isCompactScreen ? 8.0 : 10.0;

      return AnimationLimiter(
        child: ListView.separated(
          padding: EdgeInsets.symmetric(vertical: 16),
          itemCount: forms.length,
          separatorBuilder: (context, index) => SizedBox(height: spacing),
          itemBuilder: (context, index) {
            if (index >= forms.length) return const SizedBox.shrink();

            final form = forms[index];
            final responses = _formResponses[form.id] ?? <FormResponse>[];

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                horizontalOffset: 40.0,
                child: FadeInAnimation(
                  child: _buildResponsiveFormCard(form, responses, index),
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
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text('Error loading forms: ${e.toString()}'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadData(),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

// Replace the _buildResponsiveFormCard() method with this:
  Widget _buildResponsiveFormCard(
      CustomForm form, List<FormResponse> responses, int index) {
    final bool isChecklist = form.isChecklist;
    final Color accentColor = isChecklist ? Colors.orange : Colors.blue;
    final IconData formIcon =
        isChecklist ? Icons.checklist_rounded : Icons.article_rounded;

    final screenWidth = MediaQuery.of(context).size.width;
    final isXsScreen = screenWidth < 380; // Extra small screens
    final isSmScreen = screenWidth < 500; // Small screens

    // Adjust padding based on screen size
    final cardPadding = isXsScreen ? 8.0 : (isSmScreen ? 10.0 : 12.0);
    final iconSize = isXsScreen ? 16.0 : (isSmScreen ? 18.0 : 20.0);
    final actionIconSize = isXsScreen ? 16.0 : (isSmScreen ? 18.0 : 20.0);
    final iconContainerSize = isXsScreen ? 32.0 : (isSmScreen ? 36.0 : 40.0);
    final titleFontSize = isXsScreen ? 13.0 : (isSmScreen ? 14.0 : 15.0);
    final metadataFontSize = isXsScreen ? 10.0 : (isSmScreen ? 11.0 : 13.0);

    return Container(
      width: double.infinity, // Ensure full width
      constraints: BoxConstraints(
        minHeight: 80, // Minimum height
        maxWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _editForm(form),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Form header with icon and title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form type icon
                    Container(
                      width: iconContainerSize,
                      height: iconContainerSize,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          formIcon,
                          color: accentColor,
                          size: iconSize,
                        ),
                      ),
                    ),

                    SizedBox(width: isXsScreen ? 8 : 12),

                    // Form info (title, description, metadata)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            form.title,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2D3748),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (form.description.isNotEmpty && !isXsScreen) ...[
                            const SizedBox(height: 3),
                            // Description (hide on very small screens)
                            Text(
                              form.description,
                              style: TextStyle(
                                fontSize: metadataFontSize,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: 6),

                          // Metadata pills in a row - use Wrap for flexibility
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildMetadataPill(
                                "${form.fields.length} ${form.fields.length == 1 ? 'field' : 'fields'}",
                                Icons.list_alt_rounded,
                                fontSize: metadataFontSize,
                                iconSize: metadataFontSize + 1,
                              ),
                              _buildMetadataPill(
                                "${responses.length} ${responses.length == 1 ? 'response' : 'responses'}",
                                Icons.analytics_rounded,
                                fontSize: metadataFontSize,
                                iconSize: metadataFontSize + 1,
                                color: responses.isNotEmpty
                                    ? Colors.green.shade700
                                    : null,
                              ),
                              if (!isXsScreen)
                                _buildMetadataPill(
                                  _formatDate(form.created_at),
                                  Icons.calendar_today_rounded,
                                  fontSize: metadataFontSize,
                                  iconSize: metadataFontSize + 1,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    if (!isXsScreen)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildIconButton(
                            icon: Icons.edit_outlined,
                            color: Colors.blue,
                            tooltip: 'Edit',
                            onPressed: () => _editForm(form),
                            iconSize: actionIconSize,
                          ),
                          _buildIconButton(
                            icon: Icons.send_outlined,
                            color: Colors.green,
                            tooltip: 'Submit',
                            onPressed: () => _openFormSubmission(form),
                            iconSize: actionIconSize,
                          ),
                          _buildIconButton(
                            icon: Icons.analytics_outlined,
                            color: Colors.orange,
                            tooltip: 'Responses',
                            onPressed: () {
                              setState(() {
                                _selectedFormIndex = _myForms.indexOf(form);
                                _currentView = 'responses';
                              });
                            },
                            iconSize: actionIconSize,
                          ),
                          _buildIconButton(
                            icon: Icons.delete_outline,
                            color: Colors.red,
                            tooltip: 'Delete',
                            onPressed: () => _deleteForm(form),
                            iconSize: actionIconSize,
                          ),
                        ],
                      ),
                  ],
                ),

                // Action buttons for small screens
                if (isXsScreen) ...[
                  const SizedBox(height: 8),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  // Action buttons in a separate row for small screens
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildIconButton(
                          icon: Icons.edit_outlined,
                          color: Colors.blue,
                          tooltip: 'Edit',
                          onPressed: () => _editForm(form),
                          iconSize: actionIconSize,
                        ),
                        _buildIconButton(
                          icon: Icons.send_outlined,
                          color: Colors.green,
                          tooltip: 'Submit',
                          onPressed: () => _openFormSubmission(form),
                          iconSize: actionIconSize,
                        ),
                        _buildIconButton(
                          icon: Icons.analytics_outlined,
                          color: Colors.orange,
                          tooltip: 'Responses',
                          onPressed: () {
                            setState(() {
                              _selectedFormIndex = _myForms.indexOf(form);
                              _currentView = 'responses';
                            });
                          },
                          iconSize: actionIconSize,
                        ),
                        _buildIconButton(
                          icon: Icons.delete_outline,
                          color: Colors.red,
                          tooltip: 'Delete',
                          onPressed: () => _deleteForm(form),
                          iconSize: actionIconSize,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

// Responses view with form selection and detailed response viewing
  Widget _buildResponsesView() {
    if (_myForms.isEmpty) {
      return _buildEmptyState();
    }

    // If no form is selected, show the form selection screen
    if (_selectedFormIndex == -1) {
      return _buildFormSelectionForResponses();
    }

    // Show the responses for the selected form
    return _buildFormResponsesView();
  }

// Update the method signature to accept forms as a parameter
  Widget _buildEnhancedFormResponsesList(List<CustomForm> forms) {
    return AnimationLimiter(
      child: ListView.builder(
        itemCount: forms.length,
        itemBuilder: (context, index) {
          final form = forms[index];
          final responses = _formResponses[form.id] ?? [];
          final isChecklist = form.isChecklist;
          final accentColor = isChecklist ? Colors.orange : Colors.blue;

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.08),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: accentColor.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _selectedFormIndex = _myForms.indexOf(form);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Form type icon with animated container
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.8, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isChecklist
                                          ? Icons.checklist_rounded
                                          : Icons.article_rounded,
                                      color: accentColor,
                                      size: 20,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(width: 16),

                            // Form details with text animations
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    form.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created: ${_formatDate(form.created_at)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Response count badge with pulsing animation
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.9, end: 1.05),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeInOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: responses.isNotEmpty
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.analytics_rounded,
                                          size: 14,
                                          color: responses.isNotEmpty
                                              ? Colors.green
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${responses.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: responses.isNotEmpty
                                                ? Colors.green
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              onEnd: () =>
                                  setState(() {}), // Loop the animation
                            ),

                            const SizedBox(width: 12),

                            // Right arrow with micro-animations
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey.shade400,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedResponsesHeader() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.indigo.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon with container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Form Responses',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a form below to view detailed submission data and analytics',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Updated _buildSearchAndFilterBar method with better responsiveness
  Widget _buildSearchAndFilterBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 380;
    final isSmallScreen = screenWidth < 600;

    // Adjust paddings based on screen size
    final horizontalPadding =
        isVerySmallScreen ? 8.0 : (isSmallScreen ? 12.0 : 16.0);
    final verticalPadding =
        isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 8.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: verticalPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isVerySmallScreen
                  // Vertical layout for very small screens
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search field
                        Container(
                          height: 40,
                          margin: EdgeInsets.only(bottom: 8),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search forms...',
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey.shade500, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 12),
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 13),
                            ),
                            style: TextStyle(fontSize: 13),
                          ),
                        ),

                        // Action row with filter and sort
                        Row(
                          children: [
                            // Filter button
                            Expanded(
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      // Show filter options
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.filter_list,
                                              size: 16,
                                              color: Colors.grey.shade700),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Filter',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Sort dropdown
                            Expanded(
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _sortBy,
                                      icon: Icon(Icons.keyboard_arrow_down,
                                          color: Colors.blue.shade800,
                                          size: 16),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'newest',
                                            child: Text('Newest')),
                                        DropdownMenuItem(
                                            value: 'oldest',
                                            child: Text('Oldest')),
                                        DropdownMenuItem(
                                            value: 'alphabetical',
                                            child: Text('A to Z')),
                                        DropdownMenuItem(
                                            value: 'most_responses',
                                            child: Text('Responses ↓')),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _sortBy = value!;
                                        });
                                      },
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  // Horizontal layout for larger screens
                  : Row(
                      children: [
                        // Search field
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search forms...',
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey.shade500,
                                  size: isSmallScreen ? 18 : 20),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 12 : 16),
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: isSmallScreen ? 13 : 14,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                            ),
                          ),
                        ),

                        SizedBox(width: isSmallScreen ? 6 : 8),

                        // Filter button
                        if (!isSmallScreen ||
                            screenWidth >= 480) // Hide on extra small screens
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  // Show filter options
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 8 : 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.filter_list,
                                          size: isSmallScreen ? 16 : 18,
                                          color: Colors.grey.shade700),
                                      SizedBox(width: isSmallScreen ? 4 : 4),
                                      Text(
                                        'Filter',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                          fontSize: isSmallScreen ? 12 : 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        SizedBox(width: isSmallScreen ? 6 : 8),

                        // Sort dropdown
                        Container(
                          height: 36,
                          padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 8 : 12, vertical: 0),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              icon: Icon(Icons.keyboard_arrow_down,
                                  color: Colors.blue.shade800,
                                  size: isSmallScreen ? 16 : 18),
                              items: [
                                DropdownMenuItem(
                                    value: 'newest',
                                    child: Text(isSmallScreen
                                        ? 'Newest'
                                        : 'Newest First')),
                                DropdownMenuItem(
                                    value: 'oldest',
                                    child: Text(isSmallScreen
                                        ? 'Oldest'
                                        : 'Oldest First')),
                                DropdownMenuItem(
                                    value: 'alphabetical',
                                    child: Text(isSmallScreen
                                        ? 'A to Z'
                                        : 'Alphabetical')),
                                DropdownMenuItem(
                                    value: 'most_responses',
                                    child: Text(isSmallScreen
                                        ? 'Responses ↓'
                                        : 'Most Responses')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _sortBy = value!;
                                });
                              },
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyStateWithAnimation() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Container(
                padding: const EdgeInsets.all(32),
                width: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated icon
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.95, end: 1.05),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.analytics_rounded,
                              size: 56,
                              color: Colors.blue.shade300,
                            ),
                          ),
                        );
                      },
                      onEnd: () => setState(() {}), // Restart animation
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'No Forms Found',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Try adjusting your search or create a new form to start collecting responses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _createNewForm,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Create New Form',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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

  Widget _buildFormSelectionForResponses() {
    // Filter and sort forms based on search query and sort option
    List<CustomForm> filteredForms = _myForms;
    if (_searchQuery.isNotEmpty) {
      filteredForms = _myForms
          .where((form) =>
              form.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              form.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort forms according to selected sort option
    if (_sortBy == 'newest') {
      filteredForms.sort((a, b) => b.created_at.compareTo(a.created_at));
    } else if (_sortBy == 'oldest') {
      filteredForms.sort((a, b) => a.created_at.compareTo(b.created_at));
    } else if (_sortBy == 'alphabetical') {
      filteredForms.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortBy == 'most_responses') {
      filteredForms.sort((a, b) {
        final aResponses = _formResponses[a.id]?.length ?? 0;
        final bResponses = _formResponses[b.id]?.length ?? 0;
        return bResponses.compareTo(aResponses);
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated header
          _buildAnimatedResponsesHeader(),

          // Search and filter bar
          _buildSearchAndFilterBar(),

          // Form list or empty state
          Expanded(
            child: filteredForms.isEmpty
                ? _buildEmptyStateWithAnimation()
                : _buildEnhancedFormResponsesList(
                    filteredForms), // Pass the filtered forms here
          ),
        ],
      ),
    );
  }

  Widget _buildFormResponsesView() {
    if (_selectedFormIndex < 0 || _selectedFormIndex >= _myForms.length) {
      return const Center(child: Text('No form selected'));
    }

    final form = _myForms[_selectedFormIndex];
    final responses = _formResponses[form.id] ?? [];
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed Header Bar with better responsive layout
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back button
                  Material(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFormIndex = -1;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.arrow_back, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Form title with limited width
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          form.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (form.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            form.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Export button with responsive sizing
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isExporting ? null : () => _exportToExcel(form),
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white, size: 16),
                      label: Text(
                        MediaQuery.of(context).size.width < 400
                            ? "Export"
                            : "Export to Excel",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width < 400
                                ? 10
                                : 12,
                            vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats cards with improved responsive layout
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: screenWidth < 450
                    ? 0
                    : 8.0, // Less vertical padding on mobile
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive layout based on available width

                  if (screenWidth < 450) {
                    // Stack cards vertically on very small screens with minimal spacing
                    return Column(
                      children: [
                        _buildAnimatedStatCard(
                          icon: Icons.analytics_rounded,
                          iconColor: Colors.blue,
                          backgroundColor: Colors.blue.shade50,
                          title: "Total Responses",
                          valueText: "${responses.length}",
                          delay: 0,
                        ),
                        const SizedBox(
                            height: 6), // Reduced spacing between cards
                        _buildAnimatedStatCard(
                          icon: Icons.calendar_today_rounded,
                          iconColor: Colors.green.shade600,
                          backgroundColor: Colors.green.shade50,
                          title: "Last Response",
                          valueText: responses.isNotEmpty
                              ? _formatDateTime(responses
                                  .reduce((a, b) =>
                                      a.submitted_at.isAfter(b.submitted_at)
                                          ? a
                                          : b)
                                  .submitted_at)
                              : "No responses",
                          delay: 100,
                        ),
                        const SizedBox(
                            height: 6), // Reduced spacing between cards
                        _buildAnimatedStatCard(
                          icon: Icons.schedule_rounded,
                          iconColor: Colors.orange,
                          backgroundColor: Colors.orange.shade50,
                          title: "Most Active Time",
                          valueText: _getMostActiveTime(responses),
                          delay: 200,
                        ),
                      ],
                    );
                  } else if (screenWidth < 700) {
                    // Two cards in first row, one in second for medium screens
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildAnimatedStatCard(
                                icon: Icons.analytics_rounded,
                                iconColor: Colors.blue,
                                backgroundColor: Colors.blue.shade50,
                                title: "Total Responses",
                                valueText: "${responses.length}",
                                delay: 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildAnimatedStatCard(
                                icon: Icons.calendar_today_rounded,
                                iconColor: Colors.green.shade600,
                                backgroundColor: Colors.green.shade50,
                                title: "Last Response",
                                valueText: responses.isNotEmpty
                                    ? _formatDateTime(responses
                                        .reduce((a, b) => a.submitted_at
                                                .isAfter(b.submitted_at)
                                            ? a
                                            : b)
                                        .submitted_at)
                                    : "No responses",
                                delay: 100,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildAnimatedStatCard(
                          icon: Icons.schedule_rounded,
                          iconColor: Colors.orange,
                          backgroundColor: Colors.orange.shade50,
                          title: "Most Active Time",
                          valueText: _getMostActiveTime(responses),
                          delay: 200,
                        ),
                      ],
                    );
                  } else {
                    // Three cards in a row for large screens
                    return Row(
                      children: [
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.analytics_rounded,
                            iconColor: Colors.blue,
                            backgroundColor: Colors.blue.shade50,
                            title: "Total Responses",
                            valueText: "${responses.length}",
                            delay: 0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.calendar_today_rounded,
                            iconColor: Colors.green.shade600,
                            backgroundColor: Colors.green.shade50,
                            title: "Last Response",
                            valueText: responses.isNotEmpty
                                ? _formatDateTime(responses
                                    .reduce((a, b) =>
                                        a.submitted_at.isAfter(b.submitted_at)
                                            ? a
                                            : b)
                                    .submitted_at)
                                : "No responses",
                            delay: 100,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.schedule_rounded,
                            iconColor: Colors.orange,
                            backgroundColor: Colors.orange.shade50,
                            title: "Most Active Time",
                            valueText: _getMostActiveTime(responses),
                            delay: 200,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),

            // Reduced spacing between stats and button on mobile
            SizedBox(height: screenWidth < 450 ? 8 : 16),

            // Submit button with entrance animation and responsive height
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Opacity(
                        opacity: value,
                        child: SizedBox(
                          // Smaller height on mobile
                          height: screenWidth < 450 ? 40 : 46,
                          // Full width on smaller screens
                          width: screenWidth < 500 ? double.infinity : null,
                          child: ElevatedButton.icon(
                            onPressed: () => _openFormSubmission(form),
                            icon: Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: screenWidth < 450 ? 16 : 18,
                            ),
                            label: Text(
                              screenWidth < 400
                                  ? "Submit Form"
                                  : "Submit This Form",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: screenWidth < 450 ? 14 : 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              elevation: 0,
                              // Reduced padding on mobile
                              padding: EdgeInsets.symmetric(
                                vertical: screenWidth < 450 ? 0 : 8,
                                horizontal: screenWidth < 450 ? 12 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
            ),

            // Reduced spacing after submit button on mobile
            SizedBox(height: screenWidth < 450 ? 12 : 20),

            // Responses heading
            if (responses.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Row(
                          children: [
                            Text(
                              "Responses",
                              style: TextStyle(
                                fontSize: screenWidth < 450 ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth < 450 ? 8 : 10,
                                  vertical: screenWidth < 450 ? 3 : 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${responses.length}",
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: screenWidth < 450 ? 12 : 14,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Hide bulk actions on very small screens
                            if (screenWidth >= 450)
                              OutlinedButton.icon(
                                onPressed: () {
                                  // Bulk actions functionality
                                },
                                icon: Icon(
                                  Icons.more_horiz,
                                  size: screenWidth < 500 ? 16 : 18,
                                  color: Colors.grey.shade700,
                                ),
                                label: Text(
                                  screenWidth < 500
                                      ? "Actions"
                                      : "Bulk Actions",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: screenWidth < 500 ? 13 : 14,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth < 500 ? 10 : 12,
                                      vertical: screenWidth < 500 ? 6 : 8),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Reduced space between heading and table on mobile
              SizedBox(height: screenWidth < 450 ? 8 : 16),
            ],

            // Responses table or empty state - expanded to fill remaining space
            Expanded(
              child: _isExporting
                  ? _buildExportingIndicator()
                  : responses.isEmpty
                      ? _buildNoResponsesMessage(form)
                      : _buildResponsiveResponsesTable(form, responses),
            ),
          ],
        ),
      ),
    );
  }

// Responsive responses table with animation
  Widget _buildResponsiveResponsesTable(
      CustomForm form, List<FormResponse> responses) {
    // Get form fields for display
    final fields = form.fields;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Checkbox column
                  SizedBox(
                    width: 40,
                    child: Theme(
                      data: ThemeData(
                        checkboxTheme: CheckboxThemeData(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      child: Checkbox(
                        value: false,
                        onChanged: (value) {
                          // Select all functionality
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),

                  // # Column
                  SizedBox(
                    width: 40,
                    child: Text(
                      "#",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),

                  // Date Column
                  LayoutBuilder(builder: (context, constraints) {
                    return SizedBox(
                      width: 120,
                      child: Text(
                        "Date",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    );
                  }),

                  // Dynamic field columns - adjust based on screen size
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Determine how many fields we can show based on width
                        final availableWidth = constraints.maxWidth;
                        int fieldsToShow = 1; // Show at least one field

                        if (availableWidth > 300) fieldsToShow = 2;
                        if (availableWidth > 600) fieldsToShow = fields.length;

                        return Row(
                          children: fields.take(fieldsToShow).map((field) {
                            return Expanded(
                              child: Text(
                                field.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),

                  // Actions Column
                  SizedBox(
                    width: 80,
                    child: Text(
                      "Actions",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Table body
            Expanded(
              child: responses.isEmpty
                  ? Center(child: Text('No responses yet'))
                  : ListView.builder(
                      itemCount: responses.length,
                      itemBuilder: (context, index) {
                        final response = responses[index];
                        final isEven = index % 2 == 0;

                        // Add animation to each row
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isEven
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () =>
                                        _showResponseDetails(form, response),
                                    highlightColor:
                                        Colors.blue.withOpacity(0.05),
                                    splashColor: Colors.blue.withOpacity(0.05),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          // Checkbox column
                                          SizedBox(
                                            width: 40,
                                            child: Theme(
                                              data: ThemeData(
                                                checkboxTheme:
                                                    CheckboxThemeData(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                ),
                                              ),
                                              child: Checkbox(
                                                value:
                                                    false, // Row selection state
                                                onChanged: (value) {
                                                  // Row selection functionality
                                                },
                                                activeColor:
                                                    AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),

                                          // # Column
                                          SizedBox(
                                            width: 40,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                "${index + 1}",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Date Column
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              _formatDateTime(
                                                  response.submitted_at),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontFamily: 'Roboto Mono',
                                                color: Colors.grey.shade700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          // Dynamic field columns
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                // Determine how many fields we can show based on width
                                                final availableWidth =
                                                    constraints.maxWidth;
                                                int fieldsToShow =
                                                    1; // Show at least one field

                                                if (availableWidth > 300) {
                                                  fieldsToShow = 2;
                                                }
                                                if (availableWidth > 600) {
                                                  fieldsToShow = fields.length;
                                                }

                                                return Row(
                                                  children: fields
                                                      .take(fieldsToShow)
                                                      .map((field) {
                                                    final value = response
                                                        .responses[field.id];
                                                    return Expanded(
                                                      child: Text(
                                                        _getDisplayValue(
                                                            field, value),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors
                                                              .grey.shade800,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ),

                                          // Actions Column with eye-catching hover effects
                                          SizedBox(
                                            width: 80,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _buildAnimatedActionButton(
                                                  icon:
                                                      Icons.visibility_outlined,
                                                  color: Colors.blue,
                                                  tooltip: 'View Details',
                                                  onPressed: () =>
                                                      _showResponseDetails(
                                                          form, response),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildAnimatedActionButton(
                                                  icon: Icons.download_outlined,
                                                  color: Colors.red,
                                                  tooltip: 'Download PDF',
                                                  onPressed: () => _exportToPdf(
                                                      form, response),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

// Animated action button for tables
  Widget _buildAnimatedActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return StatefulBuilder(builder: (context, setState) {
      bool isHovered = false;

      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:
                isHovered ? color.withOpacity(0.15) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Tooltip(
            message: tooltip,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(6),
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

// Helper method to get most active time
  String _getMostActiveTime(List<FormResponse> responses) {
    if (responses.isEmpty) return "N/A";

    Map<String, int> periods = {
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
    };

    for (var response in responses) {
      final hour = response.submitted_at.hour;
      if (hour >= 5 && hour < 12) {
        periods['Morning'] = (periods['Morning'] ?? 0) + 1;
      } else if (hour >= 12 && hour < 18) {
        periods['Afternoon'] = (periods['Afternoon'] ?? 0) + 1;
      } else {
        periods['Evening'] = (periods['Evening'] ?? 0) + 1;
      }
    }

    periods.removeWhere((key, value) => value == 0);
    if (periods.isEmpty) return "N/A";

    return periods.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double clampOpacity(double value) {
    return value.clamp(0.0, 1.0);
  }

// Exporting indicator with loading animation
  Widget _buildExportingIndicator() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Container(
                padding: const EdgeInsets.all(32),
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Spinning loading indicator with custom animation
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1500),
                      builder: (context, value, child) {
                        return SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade600),
                            strokeWidth: 3,
                            value:
                                null, // Makes it indeterminate (continuous spinning)
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Generating Export File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait while we process your data',
                      style: TextStyle(
                        color: Colors.grey.shade600,
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

// Improved empty state message for no responses with better responsiveness
  Widget _buildNoResponsesMessage(CustomForm form) {
    return NoResponsesWidget(
      form: form,
      onSubmitForm: _openFormSubmission,
    );
  }


// Update the _getDisplayValue method in your WebDashboard class
  String _getDisplayValue(FormFieldModel field, dynamic value) {
    if (value == null) {
      return 'Not provided';
    }

    if (field.type == FieldType.image && value.toString().isNotEmpty) {
      return '[Image]';
    }

    if (field.type == FieldType.checkbox && value is List) {
      return value.join(', ');
    }

    // Add Likert handling
    if (field.type == FieldType.likert && value is Map) {
      final likertData = _parseLikertDisplayData(field, value);
      final answeredCount = likertData.responses.length;
      final totalCount = likertData.questions.length;
      return 'Likert Scale ($answeredCount/$totalCount answered)';
    }

    return value.toString();
  }

  LikertDisplayData _parseLikertDisplayData(
      FormFieldModel field, Map<dynamic, dynamic> responseMap) {
    // Use shared utility for parsing Likert display data
    return LikertParser.parseLikertDisplayData(field, responseMap);
  }

// Improved response details dialog with better responsiveness
  void _showResponseDetails(CustomForm form, FormResponse response) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 500;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // Make dialog more responsive
        insetPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
          vertical: isSmallScreen ? 24 : 40,
        ),
        child: Container(
          width: screenWidth * (isSmallScreen ? 0.95 : 0.85),
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.85,
            maxWidth: isSmallScreen ? screenWidth * 0.95 : 800,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog header with subtle animation
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - value)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              color: Colors.blue.shade700,
                              size: isSmallScreen ? 18 : 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Response Details',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Submitted on ${_formatDateTime(response.submitted_at)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.close_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Responses list with staggered animations
              Expanded(
                child: ListView.builder(
                  itemCount: form.fields.length,
                  itemBuilder: (context, index) {
                    final field = form.fields[index];
                    final value = response.responses[field.id];

                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Container(
                            margin: EdgeInsets.only(
                                bottom: isSmallScreen ? 12 : 16),
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question
                                Row(
                                  children: [
                                    Container(
                                      width: isSmallScreen ? 24 : 28,
                                      height: isSmallScreen ? 24 : 28,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "${index + 1}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                          fontSize: isSmallScreen ? 12 : 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        field.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: isSmallScreen ? 14 : 16,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 6 : 8,
                                          vertical: isSmallScreen ? 3 : 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        field.type.toString().split('.').last,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: isSmallScreen ? 12 : 16),

                                // Answer - with response-specific styling
                                _buildEnhancedResponseValue(field, value),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Actions footer
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Row(
                          mainAxisAlignment: isSmallScreen
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.end,
                          children: [
                            if (!isSmallScreen)
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Close'),
                              ),
                            if (!isSmallScreen) const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _exportToPdf(form, response);
                              },
                              icon: Icon(Icons.download_rounded,
                                  color: Colors.white,
                                  size: isSmallScreen ? 16 : 18),
                              label: Text(
                                isSmallScreen ? 'Export PDF' : 'Export as PDF',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 16 : 20,
                                    vertical: isSmallScreen ? 10 : 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

// Update the _buildEnhancedResponseValue method
  Widget _buildEnhancedResponseValue(FormFieldModel field, dynamic value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 500;

    if (value == null) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'No response',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade500,
            fontSize: isSmallScreen ? 13 : 14,
          ),
        ),
      );
    }

    if (field.type == FieldType.image && value.toString().isNotEmpty) {
      return LayoutBuilder(builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double imageSize =
            maxWidth < 280 ? maxWidth : (isSmallScreen ? 240 : 280);

        return Container(
          width: imageSize,
          height: imageSize,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              value.toString(),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Image not available',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      });
    }

    if (field.type == FieldType.checkbox && value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.map<Widget>((item) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Container(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: isSmallScreen ? 16 : 18,
                        color: Colors.green.shade600,
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      Flexible(
                        child: Text(
                          item.toString(),
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      );
    }

    // Add Likert handling
    if (field.type == FieldType.likert && value is Map) {
      return _buildLikertResponseDisplay(field, value, isSmallScreen);
    }

    // For text, number, email, etc.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        value.toString(),
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildLikertResponseDisplay(
      FormFieldModel field, Map<dynamic, dynamic> value, bool isSmallScreen) {
    final likertData = _parseLikertDisplayData(field, value);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.08),
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
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9C27B0).withOpacity(0.08),
                  const Color(0xFF9C27B0).withOpacity(0.12),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.poll_outlined,
                    color: Colors.white,
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Text(
                    'Likert Scale Response',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9C27B0),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 10,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${likertData.responses.length}/${likertData.questions.length}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9C27B0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Questions and responses
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...likertData.questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  final questionKey = index.toString();
                  final responseValue = likertData.responses[questionKey];

                  // Find the option label for this response
                  String responseLabel = 'Not answered';
                  if (responseValue != null) {
                    final option = likertData.options.firstWhere(
                      (opt) => opt.value == responseValue,
                      orElse: () => LikertOption(
                          label: responseValue, value: responseValue),
                    );
                    responseLabel = option.label;
                  }

                  final isAnswered = responseValue != null;

                  return Container(
                    margin: EdgeInsets.only(
                      bottom: index < likertData.questions.length - 1
                          ? (isSmallScreen ? 16 : 20)
                          : 0,
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                    decoration: BoxDecoration(
                      color: isAnswered
                          ? const Color(0xFF9C27B0).withOpacity(0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAnswered
                            ? const Color(0xFF9C27B0).withOpacity(0.2)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: isSmallScreen ? 24 : 28,
                              height: isSmallScreen ? 24 : 28,
                              decoration: BoxDecoration(
                                color: isAnswered
                                    ? const Color(0xFF9C27B0)
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 12 : 16),
                            Expanded(
                              child: Text(
                                question,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: isSmallScreen ? 12 : 16),

                        // Response
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          decoration: BoxDecoration(
                            color: isAnswered
                                ? Colors.white
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAnswered
                                  ? const Color(0xFF9C27B0).withOpacity(0.3)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isAnswered
                                    ? Icons.check_circle
                                    : Icons.help_outline,
                                color: isAnswered
                                    ? const Color(0xFF9C27B0)
                                    : Colors.grey.shade500,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 10 : 12),
                              Expanded(
                                child: Text(
                                  responseLabel,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: isAnswered
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isAnswered
                                        ? const Color(0xFF9C27B0)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Summary footer
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: isSmallScreen ? 16 : 18,
                  color: const Color(0xFF9C27B0),
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                Text(
                  'Completion: ${likertData.responses.length}/${likertData.questions.length} questions answered',
                  style: TextStyle(
                    color: const Color(0xFF9C27B0),
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikertTableCell(FormFieldModel field, dynamic value) {
    if (value == null || value is! Map) {
      return Text(
        'No response',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    final likertData = _parseLikertDisplayData(field, value);
    final answeredCount = likertData.responses.length;
    final totalCount = likertData.questions.length;

    // Show a summary in table view
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Likert ($answeredCount/$totalCount)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9C27B0),
            ),
          ),
        ),
        if (answeredCount > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${((answeredCount / totalCount) * 100).round()}% completed',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget buildFieldCell(FormFieldModel field, dynamic value) {
    if (field.type == FieldType.likert) {
      return _buildLikertTableCell(field, value);
    }

    return Text(
      _getDisplayValue(field, value),
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade800,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }







  Widget _buildGroupsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated header section
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: _buildGroupsHeader(),
              ),
            );
          },
        ),

        // Group management content without search/filter
        Expanded(
          child: _isLoading ? _buildLoadingIndicator() : _buildGroupsContent(),
        ),
      ],
    );
  }

  Widget _buildGroupsHeader() {
    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;

    // Adjust padding based on screen size
    final horizontalPadding =
        isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final verticalPadding =
        isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);

    // Adjust icon size
    final iconSize = isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 28.0);

    // Adjust text size
    final titleSize = isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);
    final subtitleSize = isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0);

    return Container(
      padding: EdgeInsets.all(verticalPadding),
      margin: EdgeInsets.fromLTRB(horizontalPadding, verticalPadding,
          horizontalPadding, horizontalPadding / 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.05),
            AppTheme.primaryColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isSmallScreen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated icon with pulse effect
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.95, end: 1.05),
                  duration: const Duration(milliseconds: 2000),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.group_rounded,
                          color: AppTheme.primaryColor,
                          size: iconSize,
                        ),
                      ),
                    );
                  },
                  onEnd: () => setState(() {}), // Restart animation
                ),

                const SizedBox(height: 16),

                // Text content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Group Management',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage your groups to easily share forms with multiple users at once',
                      style: TextStyle(
                        fontSize: subtitleSize,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Create group button with elastic animation - full width on small screens
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Create Group',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _createNewGroup,
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          : Row(
              children: [
                // Animated icon with pulse effect
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.95, end: 1.05),
                  duration: const Duration(milliseconds: 2000),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: EdgeInsets.all(isMediumScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.group_rounded,
                          color: AppTheme.primaryColor,
                          size: iconSize,
                        ),
                      ),
                    );
                  },
                  onEnd: () => setState(() {}), // Restart animation
                ),
                const SizedBox(width: 20),

                // Text content with fade in and slide up effect
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Management',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your groups to easily share forms with multiple users at once',
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Create group button with elastic animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(isMediumScreen ? 'Create' : 'Create Group',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMediumScreen ? 14 : 18,
                            vertical: isMediumScreen ? 12 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _createNewGroup,
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildGroupsContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 600 ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Groups list with staggered appearance - directly show the list without search/filter
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: _userGroups.isEmpty
                      ? _buildEmptyGroupsState()
                      : _buildGroupsGrid(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsGrid() {
    // Dynamic grid columns based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (screenWidth >= 600 && screenWidth < 900) {
      crossAxisCount = 2;
    } else if (screenWidth >= 900 && screenWidth < 1200) {
      crossAxisCount = 3;
    } else if (screenWidth >= 1200) {
      crossAxisCount = 4;
    }

    // Dynamic aspect ratio based on screen size
    double childAspectRatio = 1.6;
    if (screenWidth >= 400 && screenWidth < 500) {
      childAspectRatio = 1.4; // Slightly taller cards for medium-small screens
    } else if (screenWidth < 400) {
      childAspectRatio = 1.2; // Taller cards for very small screens
    }

    // Adjust spacing based on screen size
    final gridSpacing = screenWidth < 600 ? 12.0 : 20.0;

    return AnimationLimiter(
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
        ),
        itemCount: _userGroups.length,
        itemBuilder: (context, index) {
          final group = _userGroups[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 500),
            columnCount: crossAxisCount,
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                curve: Curves.easeOutQuint,
                child: _buildGroupCard(group),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(UserGroup group) {
    return StatefulBuilder(builder: (context, setState) {
      bool isHovered = false;

      // Get screen size for responsive adjustments
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 600;
      final isVerySmallScreen = screenWidth < 400;

      // Adjust text sizes based on screen width
      final titleSize =
          isVerySmallScreen ? 16.0 : (isSmallScreen ? 17.0 : 18.0);
      final descriptionSize =
          isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);
      final metadataSize =
          isVerySmallScreen ? 11.0 : (isSmallScreen ? 12.0 : 13.0);

      // Adjust container padding
      final containerPadding =
          isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 20.0);

      // Adjust icon size
      final iconSize = isVerySmallScreen ? 20.0 : (isSmallScreen ? 22.0 : 24.0);

      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
            boxShadow: [
              BoxShadow(
                color: isHovered
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.06),
                blurRadius: isHovered ? 15 : 8,
                spreadRadius: isHovered ? 1 : 0,
                offset: isHovered ? const Offset(0, 6) : const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: isHovered
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : Colors.grey.shade200,
              width: isHovered ? 1.5 : 1,
            ),
          ),
          transform: isHovered
              ? (Matrix4.identity()..scale(1.02))
              : Matrix4.identity(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openGroupDetails(group),
              borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
              splashColor: AppTheme.primaryColor.withOpacity(0.1),
              highlightColor: AppTheme.primaryColor.withOpacity(0.05),
              child: Padding(
                padding: EdgeInsets.all(containerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group header
                    Row(
                      children: [
                        // Animated group icon
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.95, end: 1.05),
                          duration:
                              Duration(milliseconds: isHovered ? 800 : 1800),
                          curve: Curves.easeInOut,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale:
                                  isHovered ? 1.0 + (scale - 1.0) * 0.5 : 1.0,
                              child: Container(
                                padding:
                                    EdgeInsets.all(isSmallScreen ? 10 : 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withOpacity(isHovered ? 0.2 : 0.1),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.group,
                                  size: iconSize,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            );
                          },
                          onEnd: () => setState(() {}), // Restart animation
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: isSmallScreen ? 10 : 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatDate(group.created_at),
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 10 : 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Action menu with animated entry
                        AnimatedOpacity(
                          opacity: isHovered ? 1.0 : 0.7,
                          duration: const Duration(milliseconds: 200),
                          child: PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              size: isSmallScreen ? 20 : 24,
                              color: isHovered
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade600,
                            ),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            offset: const Offset(0, 40),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openGroupDetails(group);
                              } else if (value == 'delete') {
                                _deleteGroup(group);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        color: AppTheme.primaryColor, size: 18),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_rounded,
                                        color: Colors.red, size: 18),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Delete',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Group description with optimized visibility
                    Expanded(
                      child: Text(
                        group.description,
                        style: TextStyle(
                          fontSize: descriptionSize,
                          color: AppTheme.textSecondaryColor,
                          height: 1.4,
                        ),
                        maxLines: isVerySmallScreen ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Group members count with animated badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? AppTheme.primaryColor.withOpacity(0.15)
                            : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(isSmallScreen ? 16 : 20),
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: isHovered ? 1.0 + (value * 0.2) : 1.0,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: isSmallScreen ? 12 : 14,
                                  color: AppTheme.primaryColor,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          Text(
                            group.memberCount == null
                                ? 'Loading...'
                                : '${group.memberCount} ${group.memberCount == 1 ? "member" : "members"}',
                            style: TextStyle(
                              fontSize: metadataSize,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  final String _groupSortBy = 'newest';
  final TextEditingController _groupSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Add debugging
    debugPrint('WebDashboard initState called');

    // Load initial data
    _loadUserInfo();
    _loadInitialData();
    _loadGroups();

    // Listen for search query changes
    _searchController.addListener(_onSearchChanged);

    // Add debugging for current view
    debugPrint('Initial current view: $_currentView');
  }

  Future<void> _loadInitialData() async {
    debugPrint('Starting initial data load...');

    try {
      await _loadData();
      debugPrint(
          'Initial data load completed. Forms count: ${_myForms.length}');
    } catch (e) {
      debugPrint('Error in initial data load: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }




  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _groupSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }






  void _sortGroups() {
    setState(() {
      if (_groupSortBy == 'newest') {
        _filteredGroups.sort((a, b) => b.created_at.compareTo(a.created_at));
      } else if (_groupSortBy == 'oldest') {
        _filteredGroups.sort((a, b) => a.created_at.compareTo(b.created_at));
      } else if (_groupSortBy == 'alphabetical') {
        _filteredGroups.sort((a, b) => a.name.compareTo(b.name));
      }
    });
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _supabaseService.getMyCreatedGroups();

      // Load member counts for each group
      for (var group in groups) {
        try {
          final members = await _supabaseService.getGroupMembers(group.id);
          group.memberCount = members.length;
        } catch (e) {
          debugPrint('Error loading member count for group ${group.id}: $e');
          group.memberCount = 0;
        }
      }

      if (mounted) {
        setState(() {
          _userGroups = List<UserGroup>.from(groups);
          _filteredGroups = List<UserGroup>.from(groups);
          _sortGroups();
        });
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading groups: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _createNewGroup() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.group_add, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('Create New Group'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Enter a name for your group',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon:
                        const Icon(Icons.group, color: AppTheme.primaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a group name';
                    }
                    if (value.length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter a description for your group',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.description,
                        color: AppTheme.primaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  {
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                  },
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = _supabaseService.getCurrentUser();
        if (user == null) {
          throw Exception('User not logged in');
        }

        final groupId = const Uuid().v4();

        final newGroup = UserGroup(
          id: groupId,
          name: result['name']!,
          description: result['description']!,
          created_by: user.id,
          created_at: DateTime.now(),
          memberCount: 0,
        );

        await _supabaseService.createUserGroup(newGroup);

        // Reload groups
        await _loadGroups();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group created successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating group: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteGroup(UserGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
            'Are you sure you want to delete "${group.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _supabaseService.deleteGroup(group.id);

        // Reload groups
        await _loadGroups();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group deleted successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting group: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.errorColor,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _openGroupDetails(UserGroup group) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebGroupDetailScreen(
          group: group,
        ),
      ),
    );

    // If the group was deleted, refresh the list
    if (result == true) {
      _loadGroups();
    }
  }

  Widget _buildEmptyGroupsState() {
    // Get screen dimensions for better responsiveness
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Determine responsive sizing
    final isVerySmallScreen = screenWidth < 400;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;

    // Card width - responsive to screen size
    final double cardWidth = isVerySmallScreen
        ? screenWidth * 0.9
        : (isSmallScreen
            ? screenWidth * 0.85
            : (isMediumScreen ? 500.0 : 600.0));

    // Adjust paddings and sizes based on screen
    final contentPadding =
        isVerySmallScreen ? 20.0 : (isSmallScreen ? 24.0 : 32.0);
    final iconSize = isVerySmallScreen ? 40.0 : (isSmallScreen ? 50.0 : 64.0);
    final titleSize = isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 24.0);
    final descriptionSize =
        isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 16.0);
    final buttonPadding = isVerySmallScreen
        ? EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : (isSmallScreen
            ? EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : EdgeInsets.symmetric(horizontal: 24, vertical: 16));

    return Center(
      child: SingleChildScrollView(
        // Add scrolling to prevent overflow
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  width: cardWidth,
                  padding: EdgeInsets.all(contentPadding),
                  constraints: BoxConstraints(
                    maxHeight: screenHeight *
                        0.7, // Limit max height to prevent overflow
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(isSmallScreen ? 16 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min, // Use min size to prevent expansion
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon with responsive sizing
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.95, end: 1.05),
                        duration: const Duration(milliseconds: 2000),
                        curve: Curves.easeInOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: EdgeInsets.all(isVerySmallScreen
                                  ? 16
                                  : (isSmallScreen ? 24 : 32)),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.groups_outlined,
                                size: iconSize,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          );
                        },
                        onEnd: () => setState(() {}), // Restart animation
                      ),

                      SizedBox(
                          height: isVerySmallScreen
                              ? 16
                              : (isSmallScreen ? 20 : 30)),

                      // Title with reveal animation - responsive text size
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutQuad,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Text(
                                'No Groups Created Yet',
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isVerySmallScreen ? 12 : 16),

                      // Description with delayed reveal animation
                      FutureBuilder(
                          future:
                              Future.delayed(const Duration(milliseconds: 200)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return SizedBox(
                                  height: isVerySmallScreen ? 12 : 16);
                            }

                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutQuad,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: SizedBox(
                                      width: isVerySmallScreen
                                          ? screenWidth * 0.7
                                          : (isSmallScreen
                                              ? screenWidth * 0.6
                                              : 320.0),
                                      child: Text(
                                        'Groups help you organize users for easy form sharing and collaboration',
                                        style: TextStyle(
                                          fontSize: descriptionSize,
                                          color: AppTheme.textSecondaryColor,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                        // Prevent text overflow
                                        overflow: TextOverflow.visible,
                                        softWrap: true,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),

                      SizedBox(
                          height: isVerySmallScreen
                              ? 20
                              : (isSmallScreen ? 30 : 40)),

                      // Button with bounce animation
                      FutureBuilder(
                          future:
                              Future.delayed(const Duration(milliseconds: 400)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return SizedBox(
                                  height: isVerySmallScreen ? 36 : 46);
                            }

                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: SizedBox(
                                    // Set a constrained size for the button on small screens
                                    width: isVerySmallScreen || isSmallScreen
                                        ? double.infinity
                                        : null,
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.add_circle_outline,
                                          color: Colors.white,
                                          size: isVerySmallScreen ? 16 : 18),
                                      label: Text(
                                        isVerySmallScreen
                                            ? 'Create'
                                            : (isSmallScreen
                                                ? 'Create Group'
                                                : 'Create Your First Group'),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isVerySmallScreen
                                              ? 13
                                              : (isSmallScreen ? 14 : 16),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: buttonPadding,
                                        elevation: 4,
                                        shadowColor: AppTheme.primaryColor
                                            .withOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              isSmallScreen ? 8 : 12),
                                        ),
                                      ),
                                      onPressed: _createNewGroup,
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }







// Add this improved empty state:
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade50,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 24 : 40),
          width: isSmallScreen ? double.infinity : 600,
          margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  size: isSmallScreen ? 60 : 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Jala Form Dashboard',
                style: TextStyle(
                  fontSize: isSmallScreen ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Create your first form to get started. You can create regular forms or checklists with time windows and recurrence patterns.',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: isSmallScreen ? double.infinity : null,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Create Your First Form',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 24 : 32,
                      vertical: isSmallScreen ? 16 : 18,
                    ),
                    textStyle: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _createNewForm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Utility method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

// Utility method to format date and time
  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} $hour:$minute';
  }

// Method to create a new form
  void _createNewForm() {
    setState(() {
      _isCreatingForm = true;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebFormBuilder(),
      ),
    ).then((_) {
      // When returning from the form builder, reload data
      setState(() {
        _isCreatingForm = false;
      });
      _loadData();
    });
  }

// Method to edit a form
  void _editForm(CustomForm form) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebFormEditor(form: form),
      ),
    ).then((_) {
      // When returning from the form editor, reload data
      _loadData();
    });
  }

// Method to delete a form with confirmation
  void _deleteForm(CustomForm form) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${form.title}?'),
        content: const Text(
          'This action cannot be undone. All responses will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });
              try {
                await _supabaseService.deleteForm(form.id);
                _loadData(); // Reload data after deletion
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Form deleted successfully'),
                      backgroundColor: AppTheme.successColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting form: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

// Method to sign out
  Future<void> _signOut() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _supabaseService.signOut();

      if (mounted) {
        // Using Navigator.pushNamedAndRemoveUntil to clear the navigation stack
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false, // This removes all previous routes
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

// Method to open profile screen
  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WebProfileScreen()),
    ).then((_) {
      _loadUserInfo();
    });
  }

// Method to open form submission screen
  void _openFormSubmission(CustomForm form) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebFormSubmissionScreen(form: form),
      ),
    ).then((_) {
      // Refresh data when returning from submission
      _loadData();
    });
  }

// Add this as a class variable at the top of your widget class
   final List<Map<String, dynamic>> _imageReferences = [];

// Enhanced Excel export with clickable image hyperlinks
  Future<void> _exportToExcel(CustomForm form) async {
    final responses = _formResponses[form.id] ?? [];

    if (responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('No responses to export'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.amber.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: EdgeInsets.all(12),
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _imageReferences.clear();
    });

    try {
      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[sheetName];

      // Build headers
      final List<String> headers = ['#', 'Submission Date', 'Respondent ID'];
      final List<FormFieldModel> expandedFields = [];

      for (var field in form.fields) {
        if (field.type == FieldType.likert && field.likertQuestions != null) {
          for (int i = 0; i < field.likertQuestions!.length; i++) {
            headers.add(
                '${field.label} - Q${i + 1}: ${field.likertQuestions![i]}');
            expandedFields.add(field);
          }
        } else {
          headers.add(field.label);
          expandedFields.add(field);
        }
      }

      // Add headers with styling
      for (var i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: ExcelColor.fromHexString('#9C27B0'),
            fontColorHex:      ExcelColor.fromHexString('#FFFFFF'),
          );
      }


      // Create option labels map for Likert fields
      final Map<String, Map<String, String>> likertOptionLabels = {};
      for (var field in form.fields) {
        if (field.type == FieldType.likert && field.options != null) {
          final Map<String, String> optionLabels = {};
          for (String option in field.options!) {
            if (option.contains('|')) {
              final parts = option.split('|');
              final label = parts[0];
              final value = parts.length > 1 ? parts[1] : parts[0];
              optionLabels[value] = label;
            } else {
              optionLabels[option] = option;
            }
          }
          likertOptionLabels[field.id] = optionLabels;
        }
      }

// Add data rows
      for (var rowIndex = 0; rowIndex < responses.length; rowIndex++) {
        final response = responses[rowIndex];
        final rowStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#F5F7FA'),
        );

        // Basic columns
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex + 1))
          ..value = TextCellValue((rowIndex + 1).toString())
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex + 1))
          ..value = TextCellValue(_formatDateTime(response.submitted_at))
          ..cellStyle = rowStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex + 1))
          ..value = TextCellValue(response.respondent_id ?? 'Anonymous')
          ..cellStyle = rowStyle;

        // Field values
        var columnIndex = 3;

        for (var field in form.fields) {
          final value = response.responses[field.id];

          if (field.type == FieldType.likert && field.likertQuestions != null) {
            // Handle Likert fields
            final likertResponses = value is Map
                ? Map<String, dynamic>.from(value)
                : <String, dynamic>{};
            final optionLabels = likertOptionLabels[field.id] ?? <String, String>{};

            for (int questionIndex = 0;
            questionIndex < field.likertQuestions!.length;
            questionIndex++) {
              final questionKey = questionIndex.toString();
              final selectedValue = likertResponses[questionKey];

              String displayValue;
              CellStyle cellStyle;

              if (selectedValue != null) {
                displayValue =
                    optionLabels[selectedValue] ?? selectedValue.toString();
                cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString(
                      rowIndex % 2 == 0 ? '#F3E5F5' : '#FCE4EC'),
                  fontColorHex: ExcelColor.fromHexString('#4A148C'),
                );
              } else {
                displayValue = 'No answer';
                cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString(
                      rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
                  fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
                  italic: true,
                );
              }

              sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: columnIndex, rowIndex: rowIndex + 1))
                ..value = TextCellValue(displayValue)
                ..cellStyle = cellStyle;

              columnIndex++;
            }
          } else if (field.type == FieldType.image) {
            // Handle Image field with enhanced URL display
            if (value != null && value.toString().isNotEmpty) {
              final imageUrl = value.toString();
              // … filename extraction …

              final cell = sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: columnIndex, rowIndex: rowIndex + 1));

              cell
                ..value = TextCellValue(imageUrl)
                ..cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString(
                      rowIndex % 2 == 0 ? '#E3F2FD' : '#F1F8FF'),
                  fontColorHex: ExcelColor.fromHexString('#1565C0'),
                  underline: Underline.Single,
                );

              _imageReferences.add({
                // … reference data …
              });
            } else {
              sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: columnIndex, rowIndex: rowIndex + 1))
                ..value = TextCellValue('No image')
                ..cellStyle = CellStyle(
                  backgroundColorHex: ExcelColor.fromHexString(
                      rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
                  fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
                  italic: true,
                );
            }
            columnIndex++;
          } else {
            // Handle other fields
            String displayValue;
            if (value != null) {
              if (value is List) {
                displayValue = value.join(', ');
              } else if (value is Map) {
                displayValue = value.toString();
              } else {
                displayValue = value.toString();
              }
            } else {
              displayValue = 'No answer';
            }

            final cellStyle = displayValue == 'No answer'
                ? CellStyle(
              backgroundColorHex: ExcelColor.fromHexString(
                  rowIndex % 2 == 0 ? '#F5F5F5' : '#FAFAFA'),
              fontColorHex: ExcelColor.fromHexString('#9E9E9E'),
              italic: true,
            )
                : rowStyle;

            sheet.cell(CellIndex.indexByColumnRow(
                columnIndex: columnIndex, rowIndex: rowIndex + 1))
              ..value = TextCellValue(displayValue)
              ..cellStyle = cellStyle;

            columnIndex++;
          }
        }
      }


      // Auto-fit columns
      for (var i = 0; i < headers.length; i++) {
        if (i < 3) {
          sheet.setColumnWidth(i, 15.0);
        } else {
          final headerLength = headers[i].length;
          final width = (headerLength > 30)
              ? 35.0
              : (headerLength > 20)
                  ? 25.0
                  : 20.0;
          sheet.setColumnWidth(i, width);
        }
      }
// Add Likert summary sheet if needed
      if (form.fields.any((field) => field.type == FieldType.likert)) {
        await _addLikertSummarySheet(
            excel, form, responses, likertOptionLabels);
      }

      // Add enhanced images summary sheet
      if (_imageReferences.isNotEmpty) {
        await _addEnhancedImagesSummarySheet(excel, form, responses);
      }

      // Generate and download Excel file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${form.title}_responses_$timestamp.xlsx';
      final bytes = excel.encode();

      if (bytes != null) {
        final blob = html.Blob([
          Uint8List.fromList(bytes)
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        // Enhanced success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Excel export successful'),
                  ],
                ),
                if (_imageReferences.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    '• Click blue URLs in Excel to view images',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    '• Check "Images_Reference" sheet for all URLs',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: EdgeInsets.all(12),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting to Excel: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  // Enhanced images summary sheet with better organization
  Future<void> _addEnhancedImagesSummarySheet(
      Excel excel, CustomForm form, List<FormResponse> responses) async {
    const String imagesSheetName = 'Images_Reference';
    final imagesSheet = excel[imagesSheetName];

    // Headers with enhanced info
    final imageHeaders = [
      'Main Sheet Row',
      'Respondent ID',
      'Field Name',
      'Image Filename',
      'Image URL (Copy & Paste to Browser)',
      'Submission Date'
    ];

    // Add styled headers
    for (var i = 0; i < imageHeaders.length; i++) {
      imagesSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = imageHeaders[i] as CellValue?
        ..cellStyle = CellStyle(
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
            fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
            backgroundColorHex: ExcelColor.fromHexString('#2196F3')
        );
    }

    // Add image data with enhanced formatting
    int imageRowIndex = 1;
    for (var imgRef in _imageReferences) {
      final imageUrl = imgRef['imageUrl'];
      final fileName = imgRef['fileName'];

      // Main sheet row reference
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: imageRowIndex))
        ..value = 'Row ${imgRef['row']}' as CellValue?
        ..cellStyle = CellStyle(
            fontColorHex: ExcelColor.fromHexString('#1565C0'), bold: true);

      // Respondent ID
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: imageRowIndex))
          .value = imgRef['respondentId'];

      // Field name
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: imageRowIndex))
          .value = imgRef['fieldLabel'];

      // Clean filename
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: imageRowIndex))
          .value = fileName;

      // Full URL - styled as link for easy copying
      final urlCell = imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: imageRowIndex));
      urlCell.value = imageUrl;
      urlCell.cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#1565C0'),
        underline: Underline.Single,
      );

      // Submission date
      imagesSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: imageRowIndex))
          .value = _formatDateTime(imgRef['submissionDate']) as CellValue?;

      imageRowIndex++;
    }

    // Note: setColumnWidth may not be available in your Excel package
    // You can try these lines, but remove them if they cause errors:
    /*
    final columnWidths = [15.0, 20.0, 25.0, 30.0, 50.0, 20.0];
    for (var i = 0; i < columnWidths.length; i++) {
      imagesSheet.setColumnWidth(i, columnWidths[i]);
    }
    */

    // Add instructions at the bottom
    final instructionRow = imageRowIndex + 2;
    imagesSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: instructionRow))
      ..value = TextCellValue('How to View Images:')
      ..cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#9C27B0'),
      );

    imagesSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: instructionRow))
      ..value = TextCellValue('1. In main sheet: Click blue URLs to open images')
      ..cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#666666'),
      );

    imagesSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: instructionRow + 1))
      ..value = TextCellValue('2. Or copy URLs from this sheet and paste in browser')
      ..cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#666666'),
      );

    imagesSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: instructionRow + 2))
      ..value = TextCellValue('3. Right-click URLs to copy link address')
      ..cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('#666666'),
      );
  }

  // Add this new method for Likert summary analysis
  Future<void> _addLikertSummarySheet(
      Excel excel,
      CustomForm form,
      List<FormResponse> responses,
      Map<String, Map<String, String>> likertOptionLabels,
      ) async {
    // Create summary sheet
    excel.sheets['Likert Summary'] = excel['Likert Summary'];
    final summarySheet = excel.sheets['Likert Summary']!;

    var currentRow = 0;

    // Title
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
      ..value = 'Likert Scale Analysis Summary' as CellValue?
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        backgroundColorHex: ExcelColor.fromHexString('#9C27B0'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    currentRow += 2;

    // Process each Likert field
    for (var field in form.fields) {
      if (field.type == FieldType.likert && field.likertQuestions != null) {
        // Field title
        summarySheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
          ..value = field.label as CellValue?
          ..cellStyle = CellStyle(
            bold: true,
            fontSize: 14,
            backgroundColorHex: ExcelColor.fromHexString('#E1BEE7'),
            fontColorHex: ExcelColor.fromHexString('#4A148C'),
          );
        currentRow += 1;

        final optionLabels = likertOptionLabels[field.id] ?? <String, String>{};

        // Process each question in the Likert scale
        for (int questionIndex = 0;
        questionIndex < field.likertQuestions!.length;
        questionIndex++) {
          final question = field.likertQuestions![questionIndex];

          // Question header
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
            ..value = 'Q${questionIndex + 1}: $question' as CellValue?
            ..cellStyle = CellStyle(bold: true, fontSize: 12);
          currentRow += 1;

          // Count responses for this question
          final Map<String, int> responseCounts = {};
          final String questionKey = questionIndex.toString();

          for (var response in responses) {
            final likertData = response.responses[field.id];
            if (likertData is Map) {
              final likertResponses = Map<String, dynamic>.from(likertData);
              final selectedValue = likertResponses[questionKey];
              if (selectedValue != null) {
                final label =
                    optionLabels[selectedValue] ?? selectedValue.toString();
                responseCounts[label] = (responseCounts[label] ?? 0) + 1;
              }
            }
          }

          // Add response counts headers
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
            ..value = 'Response' as CellValue?
            ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'));
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
            ..value = 'Count' as CellValue?
            ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'));
          summarySheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
            ..value = 'Percentage' as CellValue?
            ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'));
          currentRow += 1;

          final totalResponses =
          responseCounts.values.fold(0, (sum, count) => sum + count);

          for (var entry in responseCounts.entries) {
            final percentage = totalResponses > 0
                ? (entry.value / totalResponses * 100).toStringAsFixed(1)
                : '0.0';

            summarySheet
                .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: currentRow))
                .value = entry.key as CellValue?;
            summarySheet
                .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: currentRow))
                .value = entry.value as CellValue?;
            summarySheet
                .cell(CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: currentRow))
                .value = '$percentage%' as CellValue?;
            currentRow += 1;
          }

          currentRow += 1; // Add space between questions
        }

        currentRow += 2; // Add space between different Likert fields
      }
    }

    // Note: setColumnWidth may not be available in your Excel package
    // You can try these lines, but remove them if they cause errors:

    summarySheet.setColumnWidth(1, 300); // Question/Response column (column A)
    summarySheet.setColumnWidth(2, 80);  // Count column (column B)
    summarySheet.setColumnWidth(3, 100); // Percentage column (column C)

  }
  Future<void> _exportToPdf(CustomForm form, FormResponse response) async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Use the enhanced WebPdfService instead of the old method
      final webPdfService = WebPdfService();
      await webPdfService.generateAndDownloadPdf(form, response);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('PDF export successful'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: EdgeInsets.all(12),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting to PDF: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }
}
