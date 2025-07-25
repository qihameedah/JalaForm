import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jala_form/models/custom_form.dart';
import 'package:jala_form/models/form_state_interface.dart';
import '../services/supabase_service.dart';
import 'forms/my_forms_screen.dart';
import 'forms/form_builder_screen.dart';
import 'forms/available_forms_screen.dart';
import 'groups/group_list_screen.dart';
import 'profile/profile_screen.dart';
import 'auth/login_screen.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final _supabaseService = SupabaseService();
  String _username = 'User';
  String _firstName = 'User';
  int _myFormsCount = 0;
  int _availableFormsCount = 0;
  int _checklistsCount = 0;
  int _availableChecklistsCount = 0;
  StreamSubscription<List<CustomForm>>? _formsSubscription;
  StreamSubscription<List<CustomForm>>? _availableFormsSubscription;
  // Animation controllers
  late AnimationController _headerAnimationController;
  late AnimationController _bottomNavAnimationController;
  late AnimationController _badgeAnimationController;
  late AnimationController _tabSelectionAnimationController;
  late AnimationController _floatingActionController;
  late AnimationController _slidingIndicatorController;

  late Animation<double> _headerAnimation;
  late Animation<double> _bottomNavAnimation;
  late Animation<double> _badgeAnimation;
  late Animation<double> _tabSelectionAnimation;
  late Animation<double> _floatingActionAnimation;
  late Animation<double> _slidingIndicatorAnimation;

  // Page controller
  late PageController _pageController;

  // Screen instances
  late MyFormsScreen _myFormsScreen;
  late FormBuilderScreen _formBuilderScreen;
  late AvailableFormsScreen _availableFormsScreen;

  // Form state tracking
  bool _formHasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();

    _myFormsScreen = const MyFormsScreen();
    _formBuilderScreen = _createFormBuilderScreen();
    _availableFormsScreen = const AvailableFormsScreen();
    _pageController = PageController();

    _initializeAnimations();
    _loadUserInfo();
    _loadFormCounts();

    // ADD THIS LINE:
    _initializeRealTimeFormCounts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimations();
    });
  }

  // ADD THIS NEW METHOD:
  void _initializeRealTimeFormCounts() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) return;

      // Listen to forms stream for "My Forms" counts
      _formsSubscription = _supabaseService.formsStream.listen(
        (allForms) {
          if (mounted) {
            final myForms =
                allForms.where((form) => form.created_by == user.id).toList();
            final myRegularForms =
                myForms.where((form) => !form.isChecklist).toList();
            final myChecklists =
                myForms.where((form) => form.isChecklist).toList();

            setState(() {
              _myFormsCount = myRegularForms.length;
              _checklistsCount = myChecklists.length;
            });
          }
        },
        onError: (error) {
          debugPrint('Error in forms stream (HomeScreen): $error');
        },
      );

      // Listen to available forms stream for "Available Forms" counts
      _availableFormsSubscription =
          _supabaseService.availableFormsStream.listen(
        (availableForms) {
          if (mounted) {
            final availableRegularForms =
                availableForms.where((form) => !form.isChecklist).toList();
            final availableChecklists =
                availableForms.where((form) => form.isChecklist).toList();

            setState(() {
              _availableFormsCount = availableRegularForms.length;
              _availableChecklistsCount = availableChecklists.length;
            });
          }
        },
        onError: (error) {
          debugPrint('Error in available forms stream (HomeScreen): $error');
        },
      );
    } catch (e) {
      debugPrint('Error initializing real-time form counts: $e');
    }
  }

  void _initializeAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _bottomNavAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _badgeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _tabSelectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _floatingActionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slidingIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _headerAnimationController, curve: Curves.easeOut),
    );

    _bottomNavAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _bottomNavAnimationController, curve: Curves.easeOut),
    );

    _badgeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _badgeAnimationController, curve: Curves.easeOut),
    );

    _tabSelectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _tabSelectionAnimationController, curve: Curves.easeOut),
    );

    _floatingActionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _floatingActionController, curve: Curves.easeOut),
    );

    _slidingIndicatorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _slidingIndicatorController, curve: Curves.easeOut),
    );
  }

  void _startAnimations() {
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      _bottomNavAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      _badgeAnimationController.forward();
      _slidingIndicatorController.forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      _floatingActionController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _bottomNavAnimationController.dispose();
    _badgeAnimationController.dispose();
    _tabSelectionAnimationController.dispose();
    _floatingActionController.dispose();
    _slidingIndicatorController.dispose();
    _pageController.dispose();

    // ADD THESE LINES:
    _formsSubscription?.cancel();
    _availableFormsSubscription?.cancel();

    super.dispose();
  }

  FormBuilderScreen _createFormBuilderScreen() {
    return FormBuilderScreen(
      onFormContentChanged: () => _formHasUnsavedChanges = true,
      checkUnsavedChanges: () => _formHasUnsavedChanges,
      resetFormCallback: () => _formHasUnsavedChanges = false,
    );
  }

  List<Widget> get _widgetOptions => [
        _myFormsScreen,
        _formBuilderScreen,
        _availableFormsScreen,
      ];

  bool _hasUnsavedChanges() => _selectedIndex == 1 && _formHasUnsavedChanges;

  void _resetForm() => _formHasUnsavedChanges = false;

  String _extractFirstName(String fullName) {
    if (fullName.isEmpty) return 'User';
    final names = fullName.trim().split(' ');
    return names.first.isNotEmpty ? names.first : 'User';
  }

  Future<bool> _showNavigationWarning() async {
    HapticFeedback.lightImpact();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Unsaved Changes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Stay',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Leave',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        final username = await _supabaseService.getUsername(user.id);
        if (mounted) {
          setState(() {
            _username = username;
            _firstName = _extractFirstName(username);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  Future<void> _loadFormCounts() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        final forms = await _supabaseService.getForms();
        final myForms =
            forms.where((form) => form.created_by == user.id).toList();
        final myRegularForms =
            myForms.where((form) => !form.isChecklist).toList();
        final myChecklists = myForms.where((form) => form.isChecklist).toList();

        final availableForms = await _supabaseService.getAvailableForms();
        final availableRegularForms =
            availableForms.where((form) => !form.isChecklist).toList();
        final availableChecklists =
            availableForms.where((form) => form.isChecklist).toList();

        if (mounted) {
          setState(() {
            _myFormsCount = myRegularForms.length;
            _checklistsCount = myChecklists.length;
            _availableFormsCount = availableRegularForms.length;
            _availableChecklistsCount = availableChecklists.length;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading form counts: $e');
    }
  }

  Future<void> _onItemTapped(int index) async {
    if (_selectedIndex == 1 && index != 1) {
      if (_hasUnsavedChanges()) {
        final shouldLeave = await _showNavigationWarning();
        if (!shouldLeave) return;
        _resetForm();
      }
    }

    if (index == 1 && _selectedIndex != 1) {
      _formBuilderScreen = _createFormBuilderScreen();
      _formHasUnsavedChanges = false;
    }

    HapticFeedback.mediumImpact();

    // Animate sliding indicator
    _slidingIndicatorController.reset();
    _slidingIndicatorController.forward();

    // Animate tab selection
    _tabSelectionAnimationController.reset();
    _tabSelectionAnimationController.forward();

    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Sign Out',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      // ADD THIS LINE BEFORE SIGN OUT:
      await _supabaseService.disposeRealTime();

      await _supabaseService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('savedEmail');
      await prefs.remove('savedPassword');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _navigateToGroups() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroupListScreen()),
    ).then((_) => _loadFormCounts());
  }

  void _navigateToProfile() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    ).then((_) {
      _loadUserInfo();
      _loadFormCounts();
    });
  }

  double _calculateIndicatorPosition(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        isTablet ? 40 : 24; // Total horizontal padding (left + right)
    final availableWidth = screenWidth -
        horizontalPadding -
        (isTablet ? 40 : 24); // Subtract container margins
    final itemWidth = availableWidth / 3;
    return itemWidth * _selectedIndex;
  }

  double _calculateIndicatorWidth(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = isTablet ? 40 : 24;
    final availableWidth =
        screenWidth - horizontalPadding - (isTablet ? 40 : 24);
    return availableWidth / 3;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safeAreaTop = mediaQuery.padding.top;
    final safeAreaBottom = mediaQuery.padding.bottom;

    // Responsive calculations
    final isTablet = screenWidth > 600;
    final headerHeight = isTablet ? 80.0 : 70.0;
    final bottomNavHeight = isTablet ? 66.0 : 56.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Enhanced Professional Header
          AnimatedBuilder(
            animation: _headerAnimation,
            builder: (context, child) {
              final animationValue = _headerAnimation.value.clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(0, -50 * (1 - animationValue)),
                child: Opacity(
                  opacity: animationValue,
                  child: Container(
                    height: headerHeight + safeAreaTop,
                    decoration: const BoxDecoration(color: Colors.white),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24 : 16,
                          vertical: isTablet ? 16 : 12,
                        ),
                        child: Row(
                          children: [
                            // Enhanced Logo
                            Container(
                              width: isTablet ? 48 : 40,
                              height: isTablet ? 48 : 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.description_rounded,
                                color: Colors.white,
                                size: isTablet ? 24 : 20,
                              ),
                            ),

                            SizedBox(width: isTablet ? 16 : 12),

                            // Enhanced Title Section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Jala Form',
                                    style: TextStyle(
                                      fontSize: isTablet ? 22 : 20,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1F2937),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: isTablet ? 4 : 2),
                                  Flexible(
                                    child: Text(
                                      'Welcome back, $_firstName',
                                      style: TextStyle(
                                        fontSize: isTablet ? 14 : 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF6B7280),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Enhanced Action Buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildActionButton(
                                  Icons.groups_rounded,
                                  _navigateToGroups,
                                  isTablet: isTablet,
                                ),
                                SizedBox(width: isTablet ? 10 : 8),
                                _buildActionButton(
                                  Icons.person_rounded,
                                  _navigateToProfile,
                                  isTablet: isTablet,
                                ),
                                SizedBox(width: isTablet ? 10 : 8),
                                _buildActionButton(
                                  Icons.logout_rounded,
                                  () => _showSignOutConfirmation(context),
                                  isDestructive: true,
                                  isTablet: isTablet,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Content Area
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (mounted) {
                  setState(() => _selectedIndex = index);
                }
              },
              children: _widgetOptions,
            ),
          ),
        ],
      ),

      // Enhanced Bottom Navigation with Modern Design
      bottomNavigationBar: AnimatedBuilder(
        animation: _bottomNavAnimation,
        builder: (context, child) {
          final animationValue = _bottomNavAnimation.value.clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, 100 * (1 - animationValue)),
            child: Container(
              margin: EdgeInsets.only(
                left: isTablet ? 20 : 12,
                right: isTablet ? 20 : 12,
                bottom: isTablet ? 16 : 12,
              ),
              child: SafeArea(
                child: Container(
                  height: bottomNavHeight,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Color(0xFFFAFBFF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 12,
                      vertical: isTablet ? 8 : 6,
                    ),
                    child: Stack(
                      children: [
                        // Sliding indicator background
                        AnimatedBuilder(
                          animation: _slidingIndicatorAnimation,
                          builder: (context, child) {
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                              left: _calculateIndicatorPosition(isTablet),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: _calculateIndicatorWidth(isTablet),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius:
                                      BorderRadius.circular(isTablet ? 16 : 14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Navigation items
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildEnhancedNavItem(
                              icon: Icons.folder_copy_rounded,
                              activeIcon: Icons.folder_copy_rounded,
                              label: 'My Forms',
                              index: 0,
                              count: _myFormsCount + _checklistsCount,
                              isTablet: isTablet,
                            ),
                            _buildEnhancedNavItem(
                              icon: Icons.add_circle_outline_rounded,
                              activeIcon: Icons.add_circle_rounded,
                              label: 'Create',
                              index: 1,
                              isTablet: isTablet,
                              isFloating: true,
                            ),
                            _buildEnhancedNavItem(
                              icon: Icons.assignment_outlined,
                              activeIcon: Icons.assignment_rounded,
                              label: 'Available',
                              index: 2,
                              count: _availableFormsCount +
                                  _availableChecklistsCount,
                              isTablet: isTablet,
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildActionButton(
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
    bool isTablet = false,
  }) {
    final size = isTablet ? 40.0 : 36.0;
    final iconSize = isTablet ? 20.0 : 18.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? Colors.red.withOpacity(0.2)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isDestructive
                ? const Color(0xFFEF4444)
                : const Color(0xFF6B7280),
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    int count = 0,
    bool isTablet = false,
    bool isFloating = false,
  }) {
    final isSelected = _selectedIndex == index;
    final iconSize = isTablet ? 24.0 : 22.0;

    Widget navContent = Container(
      constraints: BoxConstraints(
        minHeight: isTablet ? 56 : 52,
        maxHeight: isTablet ? 62 : 58,
      ),
      padding: EdgeInsets.symmetric(
        vertical: isTablet ? 6 : 4,
        horizontal: isTablet ? 8 : 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    key: ValueKey(isSelected),
                    color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                    size: iconSize,
                  ),
                ),
                if (count > 0)
                  AnimatedBuilder(
                    animation: _badgeAnimation,
                    builder: (context, child) {
                      final badgeValue = _badgeAnimation.value.clamp(0.0, 1.0);
                      return Positioned(
                        right: -4,
                        top: -2,
                        child: Transform.scale(
                          scale: badgeValue,
                          child: Container(
                            padding: EdgeInsets.all(isTablet ? 3 : 2.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFEF4444).withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(
                              minWidth: isTablet ? 16 : 14,
                              minHeight: isTablet ? 16 : 14,
                            ),
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 9 : 8,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          SizedBox(height: isTablet ? 14 : 12), // Much more spacing
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isTablet ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                height: 1.1,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );

    if (isFloating && isSelected) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onItemTapped(index),
            borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
            child: Transform.scale(
              scale: 1.02,
              child: navContent,
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
          child: navContent,
        ),
      ),
    );
  }
}
