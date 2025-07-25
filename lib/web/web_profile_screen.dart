// lib/screens/web_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebProfileScreen extends StatefulWidget {
  const WebProfileScreen({super.key});

  @override
  State<WebProfileScreen> createState() => _WebProfileScreenState();
}

class _WebProfileScreenState extends State<WebProfileScreen>
    with SingleTickerProviderStateMixin {
  // Colors
  static const primaryColor = Color(0xFF4355B9);
  static const secondaryColor = Color(0xFF3A8EF6);
  static const backgroundColor = Color(0xFFF7F9FC);
  static const cardColor = Colors.white;
  static const textPrimaryColor = Color(0xFF2D3142);
  static const textSecondaryColor = Color(0xFF6E7191);
  static const accentColor = Color(0xFF00C8B8);
  static const dividerColor = Color(0xFFEAECF0);

  // Controllers
  final _formKey = GlobalKey<FormBuilderState>();
  final _passwordFormKey = GlobalKey<FormBuilderState>();
  final _supabaseService = SupabaseService();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late ScrollController _scrollController;

  // Animation controllers
  late AnimationController _pageController;
  late Animation<double> _fadeInAnimation;

  // UI state
  bool _isAccountSectionExpanded = true;
  bool _isPasswordSectionExpanded = true;
  bool _isLoading = true;
  bool _isUpdatingUsername = false;
  bool _isUpdatingPassword = false;
  bool _isPasswordVisible = false;

  // User data
  Map<String, int> _userStats = {
    'forms': 0,
    'checklists': 0,
    'groups': 0,
    'responses': 0,
  };
  String _userName = 'User';

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    // Initialize animation controller
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOut,
    );

    _loadUserProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        _emailController.text = user.email ?? '';

        // Get username
        final username = await _supabaseService.getUsername(user.id);
        _userName = username;
        _usernameController.text = username;

        // Load form statistics
        await _loadUserStats();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error loading profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Start page animations
        _pageController.forward();
      }
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        // Get all forms created by the user
        final forms = await _supabaseService.getForms();
        final myForms =
            forms.where((form) => form.created_by == user.id).toList();

        // Count regular forms and checklists
        final checklistsCount =
            myForms.where((form) => form.isChecklist).length;
        final regularFormsCount =
            myForms.where((form) => !form.isChecklist).length;

        // Get user groups
        final groups = await _supabaseService.getMyCreatedGroups();

        // Count responses
        int responsesCount = 0;
        for (var form in myForms) {
          final responses = await _supabaseService.getFormResponses(form.id);
          responsesCount += responses.length;
        }

        if (mounted) {
          setState(() {
            _userStats = {
              'forms': regularFormsCount,
              'checklists': checklistsCount,
              'groups': groups.length,
              'responses': responsesCount,
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user stats: $e');
      // Continue without stats rather than breaking the whole profile
    }
  }

  // Update username
  Future<void> _updateUsername() async {
    if (_formKey.currentState!.saveAndValidate()) {
      // Add haptic feedback
      HapticFeedback.mediumImpact();

      final user = _supabaseService.getCurrentUser();
      if (user == null) return;

      setState(() {
        _isUpdatingUsername = true;
      });

      try {
        // Get the user profile if it exists
        final profile = await _supabaseService.getUserProfile(user.id);

        if (profile != null) {
          // Update existing profile
          await _supabaseService.updateUserProfile(
              user.id, {'username': _usernameController.text.trim()});
        } else {
          // Create new profile
          await _supabaseService.createUserProfile(
              user.id, _usernameController.text.trim());
        }

        // Also update auth metadata
        await _supabaseService.client.auth.updateUser(
          UserAttributes(
            data: {'username': _usernameController.text.trim()},
          ),
        );

        if (mounted) {
          setState(() {
            _userName = _usernameController.text.trim();
          });

          _showSuccessSnackbar('Profile updated successfully');
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Error updating profile: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingUsername = false;
          });
        }
      }
    }
  }

  // Password update function
  Future<void> _updatePassword() async {
    if (_passwordFormKey.currentState!.saveAndValidate()) {
      // Add haptic feedback
      HapticFeedback.mediumImpact();

      if (_newPasswordController.text != _confirmPasswordController.text) {
        _showErrorSnackbar('Passwords do not match');
        return;
      }

      setState(() {
        _isUpdatingPassword = true;
      });

      try {
        // Verify current password first
        await _supabaseService.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _oldPasswordController.text,
        );

        // Update password
        await _supabaseService.client.auth.updateUser(
          UserAttributes(
            password: _newPasswordController.text,
          ),
        );

        // Clear password fields
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        if (mounted) {
          _showSuccessSnackbar('Password updated successfully');
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Error updating password: ${e.toString()}';

          // Provide a more user-friendly error message
          if (e.toString().contains('Invalid login credentials')) {
            errorMessage = 'Current password is incorrect';
          }

          _showErrorSnackbar(errorMessage);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingPassword = false;
          });
        }
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 16),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF43A047),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFE53935),
        duration: const Duration(seconds: 4),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen info with more precise breakpoints
    final screenSize = MediaQuery.of(context).size;
    final isSmallMobile = screenSize.width < 360;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 960;
    final isDesktop = screenSize.width >= 960;

    // Dynamic app bar font size
    final appBarTitleSize = isSmallMobile ? 16.0 : (isMobile ? 18.0 : 20.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'My Profile',
            style: TextStyle(
              fontSize: appBarTitleSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: isSmallMobile ? 20 : 22),
            splashRadius: 24,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline, size: isSmallMobile ? 20 : 22),
              splashRadius: 24,
              onPressed: () {
                // Show help dialog
              },
              tooltip: 'Help',
            ),
          ],
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        body: _isLoading
            ? _buildLoadingIndicator()
            : SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                child: FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: screenSize.height -
                          (MediaQuery.of(context).padding.top + kToolbarHeight),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal:
                              isSmallMobile ? 12.0 : (isMobile ? 16.0 : 24.0)),
                      child: Column(
                        children: [
                          SizedBox(height: isSmallMobile ? 16.0 : 24.0),

                          // Profile section (responsive layout)
                          isTablet || isDesktop
                              ? _buildDesktopProfileHeader()
                              : _buildMobileProfileHeader(),

                          SizedBox(height: isSmallMobile ? 16.0 : 24.0),

                          // Content sections
                          _buildAccountSection(),
                          SizedBox(height: isSmallMobile ? 12.0 : 16.0),
                          _buildPasswordSection(),
                          SizedBox(height: isSmallMobile ? 24.0 : 36.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: isSmallScreen ? 40.0 : 48.0,
              height: isSmallScreen ? 40.0 : 48.0,
              child: const CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 20.0 : 24.0),
          Text(
            "Loading your profile...",
            style: TextStyle(
              fontSize: isSmallScreen ? 14.0 : 16.0,
              color: textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileProfileHeader() {
    final screenSize = MediaQuery.of(context).size;
    final isVerySmallScreen = screenSize.width < 320;
    final isSmallScreen = screenSize.width < 360;
    final smallScreen = screenSize.width < 400;

    // Adjust sizes based on screen width
    final avatarSize = isVerySmallScreen ? 72.0 : (isSmallScreen ? 82.0 : 92.0);
    final avatarFontSize =
        isVerySmallScreen ? 32.0 : (isSmallScreen ? 36.0 : 40.0);
    final userNameSize =
        isVerySmallScreen ? 18.0 : (isSmallScreen ? 19.0 : 20.0);
    final emailSize = isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 15.0);

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        side: BorderSide(color: dividerColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Avatar and user info
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                0,
                isVerySmallScreen ? 24.0 : (isSmallScreen ? 28.0 : 32.0),
                0,
                isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 24.0)),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4355B9),
                  Color(0xFF3F51B5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    height: avatarSize,
                    width: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4F67ED),
                          Color(0xFF5E77FD),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: avatarFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: userNameSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.15,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                Text(
                  _emailController.text,
                  style: TextStyle(
                    fontSize: emailSize,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                      decoration: BoxDecoration(
                        color: secondaryColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                      ),
                      child: Icon(
                        Icons.insert_chart_outlined,
                        size: isSmallScreen ? 16.0 : 18.0,
                        color: secondaryColor,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    Text(
                      'Activity Statistics',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        color: textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),

                // Adapt grid layout based on screen width
                smallScreen
                    ? // Very small screen - stack cards in columns of two rows
                    Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  label: 'Forms',
                                  value: _userStats['forms'] ?? 0,
                                  icon: Icons.description_outlined,
                                  iconColor: const Color(0xFF4CAF50),
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                              Expanded(
                                child: _buildStatCard(
                                  label: 'Checklists',
                                  value: _userStats['checklists'] ?? 0,
                                  icon: Icons.checklist_rounded,
                                  iconColor: const Color(0xFFFF9800),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  label: 'Groups',
                                  value: _userStats['groups'] ?? 0,
                                  icon: Icons.group_outlined,
                                  iconColor: const Color(0xFF9C27B0),
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                              Expanded(
                                child: _buildStatCard(
                                  label: 'Responses',
                                  value: _userStats['responses'] ?? 0,
                                  icon: Icons.how_to_reg_outlined,
                                  iconColor: const Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : // Standard grid layout for larger screens
                    GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: isSmallScreen ? 8.0 : 12.0,
                        mainAxisSpacing: isSmallScreen ? 8.0 : 12.0,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatCard(
                            label: 'Forms',
                            value: _userStats['forms'] ?? 0,
                            icon: Icons.description_outlined,
                            iconColor: const Color(0xFF4CAF50),
                          ),
                          _buildStatCard(
                            label: 'Checklists',
                            value: _userStats['checklists'] ?? 0,
                            icon: Icons.checklist_rounded,
                            iconColor: const Color(0xFFFF9800),
                          ),
                          _buildStatCard(
                            label: 'Groups',
                            value: _userStats['groups'] ?? 0,
                            icon: Icons.group_outlined,
                            iconColor: const Color(0xFF9C27B0),
                          ),
                          _buildStatCard(
                            label: 'Responses',
                            value: _userStats['responses'] ?? 0,
                            icon: Icons.how_to_reg_outlined,
                            iconColor: const Color(0xFF2196F3),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopProfileHeader() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallDesktop = screenSize.width < 1200;
    final isMediumDesktop = screenSize.width >= 1200 && screenSize.width < 1600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 960;

    // Adapt sizes based on screen width
    final avatarSize = isTablet ? 100.0 : (isSmallDesktop ? 110.0 : 120.0);
    final avatarFontSize = isTablet ? 44.0 : (isSmallDesktop ? 50.0 : 56.0);
    final nameSize = isTablet ? 24.0 : (isSmallDesktop ? 26.0 : 28.0);
    final emailSize = isTablet ? 14.0 : 16.0;
    final iconSize = isTablet ? 14.0 : 16.0;
    final containerPadding = EdgeInsets.fromLTRB(isTablet ? 24.0 : 32.0,
        isTablet ? 24.0 : 32.0, isTablet ? 24.0 : 32.0, isTablet ? 24.0 : 32.0);

    // Need more responsive layout for tablets vs desktops
    final useCompactLayout = screenSize.width < 1100;

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dividerColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: containerPadding,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4355B9),
                  Color(0xFF3F51B5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: useCompactLayout
                ? _buildTabletProfileContent(
                    avatarSize: avatarSize,
                    avatarFontSize: avatarFontSize,
                    nameSize: nameSize,
                    emailSize: emailSize,
                    iconSize: iconSize,
                  )
                : _buildDesktopProfileContent(
                    avatarSize: avatarSize,
                    avatarFontSize: avatarFontSize,
                    nameSize: nameSize,
                    emailSize: emailSize,
                    iconSize: iconSize,
                  ),
          ),
        ],
      ),
    );
  }

// Maintain existing desktop layout but with responsive parameters
  Widget _buildDesktopProfileContent({
    required double avatarSize,
    required double avatarFontSize,
    required double nameSize,
    required double emailSize,
    required double iconSize,
  }) {
    return Row(
      children: [
        // Avatar
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            height: avatarSize,
            width: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4F67ED),
                  Color(0xFF5E77FD),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: avatarFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 32),

        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userName,
                style: TextStyle(
                  fontSize: nameSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: iconSize,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _emailController.text,
                    style: TextStyle(
                      fontSize: emailSize,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Stats
        Row(
          children: [
            _buildDesktopStatCard(
              label: 'Forms',
              value: _userStats['forms'] ?? 0,
              icon: Icons.description_outlined,
            ),
            _buildDesktopStatCard(
              label: 'Checklists',
              value: _userStats['checklists'] ?? 0,
              icon: Icons.checklist_rounded,
            ),
            _buildDesktopStatCard(
              label: 'Groups',
              value: _userStats['groups'] ?? 0,
              icon: Icons.group_outlined,
            ),
            _buildDesktopStatCard(
              label: 'Responses',
              value: _userStats['responses'] ?? 0,
              icon: Icons.how_to_reg_outlined,
            ),
          ],
        ),
      ],
    );
  }

// New helper method for tablet layouts
  Widget _buildTabletProfileContent({
    required double avatarSize,
    required double avatarFontSize,
    required double nameSize,
    required double emailSize,
    required double iconSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            height: avatarSize,
            width: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4F67ED),
                  Color(0xFF5E77FD),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: avatarFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // User details
        Text(
          _userName,
          style: TextStyle(
            fontSize: nameSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.email_outlined,
              size: iconSize,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              _emailController.text,
              style: TextStyle(
                fontSize: emailSize,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Stats in a row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDesktopStatCard(
              label: 'Forms',
              value: _userStats['forms'] ?? 0,
              icon: Icons.description_outlined,
            ),
            _buildDesktopStatCard(
              label: 'Checklists',
              value: _userStats['checklists'] ?? 0,
              icon: Icons.checklist_rounded,
            ),
            _buildDesktopStatCard(
              label: 'Groups',
              value: _userStats['groups'] ?? 0,
              icon: Icons.group_outlined,
            ),
            _buildDesktopStatCard(
              label: 'Responses',
              value: _userStats['responses'] ?? 0,
              icon: Icons.how_to_reg_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required int value,
    required IconData icon,
    required Color iconColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 320;
    final isSmallScreen = screenWidth < 360;

    // Adjust sizes based on screen width
    final iconSize = isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0);
    final valueSize = isVerySmallScreen ? 20.0 : (isSmallScreen ? 22.0 : 24.0);
    final labelSize = isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);
    final containerPadding =
        isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0);
    final iconPadding = isVerySmallScreen ? 8.0 : 10.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(containerPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: value),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                );
              },
            ),
            SizedBox(height: isVerySmallScreen ? 2.0 : 4.0),
            Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                color: textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopStatCard({
    required String label,
    required int value,
    required IconData icon,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width >= 600 && screenSize.width < 960;
    final isSmallDesktop = screenSize.width < 1200;

    // Adjust container size for different screens
    final containerPadding =
        EdgeInsets.all(isTablet ? 12.0 : (isSmallDesktop ? 14.0 : 16.0));
    final marginLeft = isTablet ? 10.0 : (isSmallDesktop ? 12.0 : 16.0);
    final valueSize = isTablet ? 20.0 : (isSmallDesktop ? 22.0 : 24.0);
    final iconSize = isTablet ? 12.0 : 14.0;
    final labelSize = isTablet ? 12.0 : 14.0;

    return Container(
      margin: EdgeInsets.only(left: marginLeft),
      padding: containerPadding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutQuart,
            builder: (context, value, child) {
              return Text(
                value.toString(),
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: iconSize,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 320;
    final isSmallScreen = screenWidth < 360;
    final isMobile = screenWidth < 600;

    // Adjust sizes for different screens
    final headerPadding =
        isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0);
    final contentPadding =
        isVerySmallScreen ? 16.0 : (isSmallScreen ? 20.0 : 24.0);
    final iconSize = isVerySmallScreen ? 18.0 : 20.0;
    final titleSize = isVerySmallScreen ? 14.0 : (isSmallScreen ? 15.0 : 16.0);
    final labelSize = isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 15.0);

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        side: BorderSide(color: dividerColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse button
          InkWell(
            onTap: () {
              setState(() {
                _isAccountSectionExpanded = !_isAccountSectionExpanded;
              });

              // Add haptic feedback
              HapticFeedback.lightImpact();
            },
            child: Padding(
              padding: EdgeInsets.all(headerPadding),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: primaryColor,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                  Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isAccountSectionExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: textSecondaryColor,
                        size: isSmallScreen ? 18.0 : 20.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: dividerColor),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: FormBuilder(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          color: secondaryColor,
                          size: isSmallScreen ? 16.0 : 18.0,
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          'Username',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: labelSize,
                            color: textPrimaryColor,
                          ),
                        ),
                        Container(
                          margin:
                              EdgeInsets.only(left: isSmallScreen ? 6.0 : 8.0),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6.0 : 8.0,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Required',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10.0 : 11.0,
                              color: secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10.0 : 12.0),

                    // Responsive layout for form fields
                    isMobile
                        ? // Stacked layout for mobile
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAnimatedTextField(
                                controller: _usernameController,
                                name: 'username',
                                hintText: 'Enter username',
                                prefixIcon: Icons.person_outline,
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.required(),
                                  FormBuilderValidators.minLength(3),
                                ]),
                              ),
                              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                              _buildAnimatedButton(
                                onPressed: _isUpdatingUsername
                                    ? null
                                    : _updateUsername,
                                isLoading: _isUpdatingUsername,
                                label: 'Update Profile',
                                icon: Icons.check_rounded,
                                isFullWidth: true,
                                gradientColors: const [
                                  Color(0xFF4CAF50),
                                  Color(0xFF388E3C),
                                ],
                              ),
                            ],
                          )
                        : // Side-by-side layout for tablet/desktop
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildAnimatedTextField(
                                  controller: _usernameController,
                                  name: 'username',
                                  hintText: 'Enter username',
                                  prefixIcon: Icons.person_outline,
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    FormBuilderValidators.minLength(3),
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _buildAnimatedButton(
                                  onPressed: _isUpdatingUsername
                                      ? null
                                      : _updateUsername,
                                  isLoading: _isUpdatingUsername,
                                  label: 'Update Profile',
                                  icon: Icons.check_rounded,
                                  gradientColors: const [
                                    Color(0xFF4CAF50),
                                    Color(0xFF388E3C),
                                  ],
                                ),
                              ),
                            ],
                          ),

                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: secondaryColor,
                          size: isSmallScreen ? 16.0 : 18.0,
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: labelSize,
                            color: textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                    _buildAnimatedTextField(
                      controller: _emailController,
                      name: 'email',
                      enabled: false,
                      prefixIcon: Icons.email_outlined,
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: _isAccountSectionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 320;
    final isSmallScreen = screenWidth < 360;

    // Adjust sizes for different screens
    final headerPadding =
        isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0);
    final contentPadding =
        isVerySmallScreen ? 16.0 : (isSmallScreen ? 20.0 : 24.0);
    final iconSize = isVerySmallScreen ? 18.0 : 20.0;
    final titleSize = isVerySmallScreen ? 14.0 : (isSmallScreen ? 15.0 : 16.0);
    final labelSize = isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 15.0);
    final descriptionSize =
        isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);
    final guidelinesTitleSize = isVerySmallScreen ? 13.0 : 14.0;
    final guidelinesContentSize =
        isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        side: BorderSide(color: dividerColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse button
          InkWell(
            onTap: () {
              setState(() {
                _isPasswordSectionExpanded = !_isPasswordSectionExpanded;
              });

              // Add haptic feedback
              HapticFeedback.lightImpact();
            },
            child: Padding(
              padding: EdgeInsets.all(headerPadding),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: secondaryColor,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                  Text(
                    'Security',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isPasswordSectionExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: textSecondaryColor,
                        size: isSmallScreen ? 18.0 : 20.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: dividerColor),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: FormBuilder(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password Management',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 4.0 : 6.0),
                    Text(
                      'Update your password to maintain account security',
                      style: TextStyle(
                        fontSize: descriptionSize,
                        color: textSecondaryColor,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),

                    // Current Password
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: secondaryColor,
                          size: isSmallScreen ? 16.0 : 18.0,
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          'Current Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: labelSize,
                            color: textPrimaryColor,
                          ),
                        ),
                        Container(
                          margin:
                              EdgeInsets.only(left: isSmallScreen ? 6.0 : 8.0),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6.0 : 8.0,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Required',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10.0 : 11.0,
                              color: secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                    _buildAnimatedTextField(
                      controller: _oldPasswordController,
                      name: 'current_password',
                      hintText: 'Enter current password',
                      obscureText: !_isPasswordVisible,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey[600],
                          size: isSmallScreen ? 18.0 : 20.0,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                      ]),
                    ),
                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),

                    // New Password
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: secondaryColor,
                          size: isSmallScreen ? 16.0 : 18.0,
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          'New Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: labelSize,
                            color: textPrimaryColor,
                          ),
                        ),
                        Container(
                          margin:
                              EdgeInsets.only(left: isSmallScreen ? 6.0 : 8.0),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6.0 : 8.0,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Required',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10.0 : 11.0,
                              color: secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                    _buildAnimatedTextField(
                      controller: _newPasswordController,
                      name: 'new_password',
                      hintText: 'Enter new password',
                      obscureText: !_isPasswordVisible,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey[600],
                          size: isSmallScreen ? 18.0 : 20.0,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.minLength(6),
                      ]),
                    ),
                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),

                    // Confirm New Password
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: secondaryColor,
                          size: isSmallScreen ? 16.0 : 18.0,
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          'Confirm New Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: labelSize,
                            color: textPrimaryColor,
                          ),
                        ),
                        Container(
                          margin:
                              EdgeInsets.only(left: isSmallScreen ? 6.0 : 8.0),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6.0 : 8.0,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Required',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10.0 : 11.0,
                              color: secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                    _buildAnimatedTextField(
                      controller: _confirmPasswordController,
                      name: 'confirm_password',
                      hintText: 'Confirm new password',
                      obscureText: !_isPasswordVisible,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey[600],
                          size: isSmallScreen ? 18.0 : 20.0,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        (val) {
                          if (val != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ]),
                    ),
                    SizedBox(height: isSmallScreen ? 24.0 : 32.0),
                    _buildAnimatedButton(
                      onPressed: _isUpdatingPassword ? null : _updatePassword,
                      isLoading: _isUpdatingPassword,
                      label: 'Update Password',
                      icon: Icons.lock,
                      isFullWidth: true,
                      gradientColors: const [
                        Color(0xFF2196F3),
                        Color(0xFF1976D2),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),
                    const Divider(),
                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),

                    // Password Guidelines
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA000).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: const Color(0xFFFFA000),
                            size: isSmallScreen ? 16.0 : 18.0,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password Guidelines',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: guidelinesTitleSize,
                                  color: textPrimaryColor,
                                ),
                              ),
                              SizedBox(height: isVerySmallScreen ? 3.0 : 4.0),
                              Text(
                                '• Minimum of 6 characters\n'
                                '• Include at least one uppercase letter\n'
                                '• Include at least one number\n'
                                '• Include at least one special character',
                                style: TextStyle(
                                  fontSize: guidelinesContentSize,
                                  color: Colors.grey[600],
                                  height: 1.5,
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
            ),
            crossFadeState: _isPasswordSectionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String name,
    String? labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool enabled = true,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Responsive sizes
    final fontSize = isSmallScreen ? 14.0 : 15.0;
    final contentPadding = isSmallScreen
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    final prefixIconSize = isSmallScreen ? 16.0 : 18.0;
    final prefixIconMargin = EdgeInsets.only(
        left: isSmallScreen ? 10.0 : 12.0, right: isSmallScreen ? 6.0 : 8.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.98, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: FormBuilderTextField(
        name: name,
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: fontSize - 1,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            borderSide: const BorderSide(color: secondaryColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            borderSide: BorderSide(color: Colors.red.shade500, width: 1.5),
          ),
          prefixIcon: prefixIcon != null
              ? Container(
                  margin: prefixIconMargin,
                  child: Icon(prefixIcon,
                      size: prefixIconSize,
                      color: enabled ? textSecondaryColor : Colors.grey[400]),
                )
              : null,
          suffixIcon: suffixIcon,
          contentPadding: contentPadding,
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade50,
        ),
        enabled: enabled,
        obscureText: obscureText,
        validator: validator,
        style: TextStyle(
          fontSize: fontSize,
          color: enabled ? textPrimaryColor : Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    bool isLoading = false,
    bool isFullWidth = false,
    List<Color> gradientColors = const [Color(0xFF4355B9), Color(0xFF3F51B5)],
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Responsive sizes
    final buttonHeight = isSmallScreen ? 48.0 : 54.0;
    final labelSize = isSmallScreen ? 14.0 : 15.0;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final borderRadius = isSmallScreen ? 10.0 : 12.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: buttonHeight,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: onPressed == null
                  ? null
                  : LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: onPressed == null ? Colors.grey[300] : null,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: onPressed == null
                  ? null
                  : [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Container(
              alignment: Alignment.center,
              child: isLoading
                  ? SizedBox(
                      height: isSmallScreen ? 20.0 : 24.0,
                      width: isSmallScreen ? 20.0 : 24.0,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: isFullWidth
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFullWidth) const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                                isSmallScreen ? 6.0 : 8.0),
                          ),
                          child:
                              Icon(icon, size: iconSize, color: Colors.white),
                        ),
                        SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: labelSize,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (isFullWidth) const SizedBox(width: 8),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// Animation helper class for integer count animations
class IntTween extends Tween<int> {
  IntTween({required int begin, required int end})
      : super(begin: begin, end: end);

  @override
  int lerp(double t) => (begin! + (end! - begin!) * t).round();
}
