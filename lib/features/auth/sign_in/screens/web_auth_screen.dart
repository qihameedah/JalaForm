import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:jala_form/services/supabase_service.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/web/screens/dashboard_screens/web_dashboard.dart';

class WebAuthScreen extends StatefulWidget {
  const WebAuthScreen({super.key});

  @override
  State<WebAuthScreen> createState() => _WebAuthScreenState();
}

class _WebAuthScreenState extends State<WebAuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _passwordVisible = false;

  // Animation controller for subtle UI animations
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

// Enhanced initState with optimized animations
  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

// Professional authenticate method with enhanced UX
  Future<void> _authenticate() async {
    if (_formKey.currentState!.saveAndValidate()) {
      setState(() {
        _isLoading = true;
      });

      HapticFeedback.lightImpact();

      try {
        final supabaseService = SupabaseService();

        if (_isLogin) {
          final user = await supabaseService.signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );

          if (user != null && mounted) {
            HapticFeedback.lightImpact();

            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const WebDashboard(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeInOutCubic)),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 600),
              ),
            );
          }
        } else {
          if (_usernameController.text.trim().isEmpty) {
            throw Exception('Username is required');
          }

          final user = await supabaseService.signUp(
            _emailController.text.trim(),
            _passwordController.text,
            _usernameController.text.trim(),
          );

          if (user != null && mounted) {
            HapticFeedback.lightImpact();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Registration successful! Please check your email.',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                duration: Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.successColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: EdgeInsets.all(16),
              ),
            );

            setState(() {
              _isLogin = true;
              _isLoading = false;
            });

            _usernameController.clear();
            _passwordController.clear();
          }
        }
      } catch (e) {
        HapticFeedback.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error: ${e.toString().replaceFirst('Exception: ', '')}',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      HapticFeedback.mediumImpact();
    }
  }

// Clean, professional, responsive build method
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final textScaleFactor = (mediaQuery.textScaleFactor ?? 1.0).clamp(0.8, 1.3);

    // Simplified device classification
    final screenWidth = size.width;
    final isPhone = screenWidth < 600;
    final isSmallPhone = screenWidth < 400;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    // Clean spacing system
    final padding = isSmallPhone
        ? 16.0
        : isPhone
            ? 20.0
            : isTablet
                ? 24.0
                : 32.0;
    final cardPadding = isSmallPhone
        ? 20.0
        : isPhone
            ? 24.0
            : 32.0;

    // Responsive card width
    final cardWidth = isPhone
        ? screenWidth * (isSmallPhone ? 0.92 : 0.88)
        : isTablet
            ? 420.0
            : 440.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.grey[50] ?? Colors.grey.shade50,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50] ?? Colors.grey.shade50,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate safe positioning
              final logoHeight = 60.0;
              final footerHeight = 40.0;
              final availableHeight =
                  constraints.maxHeight - logoHeight - footerHeight;

              return Stack(
                children: [
                  // Simple gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.03),
                          Colors.grey[50] ?? Colors.grey.shade50,
                        ],
                      ),
                    ),
                  ),

                  // Compact top logo
                  Positioned(
                    top: padding,
                    left: padding,
                    child: FadeTransition(
                      opacity: _fadeInAnimation,
                      child: SizedBox(
                        height: logoHeight,
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.assignment_outlined,
                                size: _getResponsiveSize(
                                    20, 22, 24, textScaleFactor),
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Jala Form',
                              style: TextStyle(
                                fontSize: _getResponsiveSize(
                                    18, 20, 22, textScaleFactor),
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Main authentication card - properly positioned
                  Positioned.fill(
                    top: logoHeight + padding * 2,
                    bottom: footerHeight + padding,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: padding),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(_fadeInAnimation),
                          child: FadeTransition(
                            opacity: _fadeInAnimation,
                            child: Container(
                              width: cardWidth,
                              constraints: BoxConstraints(
                                maxWidth: cardWidth,
                                minHeight: isPhone ? 0 : 500,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(cardPadding),
                                child: FormBuilder(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Compact logo
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.assignment_outlined,
                                          size: _getResponsiveSize(
                                              28, 32, 36, textScaleFactor),
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),

                                      SizedBox(height: 20),

                                      // Title
                                      Text(
                                        'Jala Form',
                                        style: TextStyle(
                                          fontSize: _getResponsiveSize(
                                              22, 24, 26, textScaleFactor),
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                      ),

                                      SizedBox(height: 8),

                                      // Subtitle
                                      AnimatedSwitcher(
                                        duration: Duration(milliseconds: 300),
                                        child: Text(
                                          _isLogin
                                              ? 'Sign in to your account'
                                              : 'Create your account',
                                          key: ValueKey<bool>(_isLogin),
                                          style: TextStyle(
                                            fontSize: _getResponsiveSize(
                                                14, 15, 16, textScaleFactor),
                                            color: AppTheme.textSecondaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),

                                      SizedBox(height: 28),

                                      // Form fields
                                      Column(
                                        children: [
                                          // Username field (registration only)
                                          if (!_isLogin) ...[
                                            _buildTextField(
                                              name: 'username',
                                              controller: _usernameController,
                                              labelText: 'Username',
                                              prefixIcon: Icons.person_outline,
                                              validator: FormBuilderValidators
                                                  .compose([
                                                FormBuilderValidators
                                                    .required(),
                                                FormBuilderValidators.minLength(
                                                    3),
                                              ]),
                                            ),
                                            SizedBox(height: 16),
                                          ],

                                          // Email field
                                          _buildTextField(
                                            name: 'email',
                                            controller: _emailController,
                                            labelText: 'Email',
                                            prefixIcon: Icons.email_outlined,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            validator:
                                                FormBuilderValidators.compose([
                                              FormBuilderValidators.required(),
                                              FormBuilderValidators.email(),
                                            ]),
                                          ),

                                          SizedBox(height: 16),

                                          // Password field
                                          _buildTextField(
                                            name: 'password',
                                            controller: _passwordController,
                                            labelText: 'Password',
                                            prefixIcon: Icons.lock_outline,
                                            onFieldSubmitted: (_) => _authenticate(),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _passwordVisible
                                                    ? Icons
                                                        .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                size: 18,
                                                color: AppTheme.primaryColor
                                                    .withOpacity(0.7),
                                              ),
                                              onPressed: () {
                                                HapticFeedback.selectionClick();
                                                setState(() {
                                                  _passwordVisible =
                                                      !_passwordVisible;
                                                });
                                              },
                                            ),
                                            obscureText: !_passwordVisible,
                                            validator:
                                                FormBuilderValidators.compose([
                                              FormBuilderValidators.required(),
                                              FormBuilderValidators.minLength(
                                                  6),
                                            ]),
                                          ),
                                        ],
                                      ),

                                      // Forgot password (login only)
                                      if (_isLogin) ...[
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            padding: EdgeInsets.only(top: 12),
                                            child: TextButton(
                                              onPressed: () =>
                                                  _showForgotPasswordDialog(),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                              ),
                                              child: Text(
                                                'Forgot Password?',
                                                style: TextStyle(
                                                  fontSize: _getResponsiveSize(
                                                      12,
                                                      13,
                                                      14,
                                                      textScaleFactor),
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        SizedBox(height: 16),
                                      ],

                                      SizedBox(height: 24),

                                      // Submit button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton(
                                          onPressed:
                                              _isLoading ? null : _authenticate,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: AppTheme
                                                .primaryColor
                                                .withOpacity(0.6),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      _isLogin
                                                          ? Icons.login
                                                          : Icons.person_add,
                                                      size: 18,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      _isLogin
                                                          ? 'Sign In'
                                                          : 'Create Account',
                                                      style: TextStyle(
                                                        fontSize:
                                                            _getResponsiveSize(
                                                                14,
                                                                15,
                                                                16,
                                                                textScaleFactor),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),

                                      SizedBox(height: 20),

                                      // Toggle section
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50] ??
                                              Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey[200] ??
                                                  Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _isLogin
                                                  ? 'Don\'t have an account?'
                                                  : 'Already have an account?',
                                              style: TextStyle(
                                                color:
                                                    AppTheme.textSecondaryColor,
                                                fontSize: _getResponsiveSize(13,
                                                    14, 15, textScaleFactor),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(() {
                                                  _isLogin = !_isLogin;
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _isLogin
                                                          ? Icons.person_add
                                                          : Icons.login,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      _isLogin
                                                          ? 'Sign Up'
                                                          : 'Sign In',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize:
                                                            _getResponsiveSize(
                                                                13,
                                                                14,
                                                                15,
                                                                textScaleFactor),
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
                        ),
                      ),
                    ),
                  ),

                  // Compact footer
                  Positioned(
                    bottom: padding,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Center(
                        child: Container(
                          height: footerHeight,
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    Colors.grey[200] ?? Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copyright,
                                size: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '2025 Jala Form',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: _getResponsiveSize(
                                      10, 11, 12, textScaleFactor),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

// Clean, compact text field
  Widget _buildTextField({
    required String name,
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    FormFieldValidator<String>? validator,
    ValueChanged<String?>? onFieldSubmitted,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = (mediaQuery.textScaleFactor ?? 1.0).clamp(0.8, 1.3);

    return FormBuilderTextField(
      name: name,
      controller: controller,
      onSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          fontSize: _getResponsiveSize(13, 14, 15, textScaleFactor),
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondaryColor,
        ),
        prefixIcon: Icon(
          prefixIcon,
          size: _getResponsiveSize(18, 19, 20, textScaleFactor),
          color: AppTheme.primaryColor.withOpacity(0.7),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[50] ?? Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.grey[300] ?? Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.grey[300] ?? Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.errorColor),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: TextStyle(
        fontSize: _getResponsiveSize(14, 15, 16, textScaleFactor),
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimaryColor,
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onTap: () => HapticFeedback.selectionClick(),
    );
  }

// Clean forgot password dialog
  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final textScaleFactor = (mediaQuery.textScaleFactor ?? 1.0).clamp(0.8, 1.3);
    final isPhone = size.width < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(24),
            width: isPhone ? size.width * 0.9 : 400,
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_reset,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),

                SizedBox(height: 16),

                Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(18, 20, 22, textScaleFactor),
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'Enter your email to receive a reset link',
                  style: TextStyle(
                    fontSize: _getResponsiveSize(13, 14, 15, textScaleFactor),
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 20),

                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppTheme.primaryColor.withOpacity(0.7),
                        size: 18,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50] ?? Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey[300] ?? Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey[300] ?? Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: TextStyle(
                      fontSize: _getResponsiveSize(14, 15, 16, textScaleFactor),
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),

                SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize:
                                _getResponsiveSize(14, 15, 16, textScaleFactor),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setDialogState(() => isSubmitting = true);
                                  HapticFeedback.lightImpact();

                                  try {
                                    final supabaseService = SupabaseService();
                                    await supabaseService.resetPassword(
                                        emailController.text.trim());

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle,
                                                  color: Colors.white,
                                                  size: 18),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Reset link sent! Check your email.',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                          duration: Duration(seconds: 4),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor:
                                              AppTheme.successColor,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          margin: EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      HapticFeedback.heavyImpact();
                                      setDialogState(
                                          () => isSubmitting = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.error,
                                                  color: Colors.white,
                                                  size: 18),
                                              SizedBox(width: 12),
                                              Text('Error: ${e.toString()}',
                                                  style:
                                                      TextStyle(fontSize: 14)),
                                            ],
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: AppTheme.errorColor,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          margin: EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isSubmitting
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Send Link',
                                    style: TextStyle(
                                      fontSize: _getResponsiveSize(
                                          14, 15, 16, textScaleFactor),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Simplified responsive sizing helper
  double _getResponsiveSize(
      double small, double medium, double large, double textScaleFactor) {
    final screenWidth = MediaQuery.of(context).size.width;

    double baseSize;
    if (screenWidth < 400) {
      baseSize = small;
    } else if (screenWidth < 600) {
      baseSize = medium;
    } else {
      baseSize = large;
    }

    // Ensure textScaleFactor is never zero or null
    final safeFactor = textScaleFactor > 0 ? textScaleFactor : 1.0;
    return baseSize / safeFactor;
  }
}
