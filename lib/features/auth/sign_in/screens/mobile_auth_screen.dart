// lib/screens/auth/mobile_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_form/features/auth/sign_up/screens/register_screen.dart';
import 'package:jala_form/features/home/screens/mobile_home.dart';
import 'package:jala_form/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Constants for UI layout
const double _kSmallScreenWidth = 360.0;
const double _kDefaultPadding = 24.0;
const double _kSmallPadding = 16.0;
const double _kLogoBottomPadding = 32.0;
const double _kMaxFormWidth = 450.0;
const double _kLargeIconSize = 80.0;
const double _kSmallIconSize = 64.0;
const double _kLargeTitleFontSize = 36.0;
const double _kSmallTitleFontSize = 28.0;
const double _kHeadlineSmallFontSizeSmallScreen = 18.0;
const double _kDefaultFieldSpacing = 16.0;
const double _kSmallFieldSpacing = 12.0;
const double _kSmallVerticalSpacing = 8.0;
const double _kExtraSmallVerticalSpacing = 4.0;
const double _kButtonHeight = 48.0;
const double _kButtonCircularProgressSize = 20.0;
const double _kLinkFontSizeSmallScreen = 13.0;
const double _kLinkFontSizeDefault = 14.0;

class MobileAuthScreen extends StatefulWidget {
  const MobileAuthScreen({super.key});

  @override
  State<MobileAuthScreen> createState() => _MobileAuthScreenState();
}

class _MobileAuthScreenState extends State<MobileAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _passwordVisible = false;

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _checkSavedCredentials();
  }

  Future<void> _checkSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('savedEmail');

    // Only restore email, never store passwords
    if (savedEmail != null) {
      if (mounted) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn({bool autoLogin = false}) async {
    if (!autoLogin && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final User? user = await _supabaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          // Only save email, never store passwords
          await prefs.setString('savedEmail', _emailController.text.trim());
        } else {
          await prefs.remove('savedEmail');
        }
        // Clean up any old saved passwords from previous versions
        await prefs.remove('savedPassword');

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MobileHomeScreen()),
          );
        }
      } else if (!autoLogin) { 
        // Only show generic error for manual login if user is null and no exception was thrown by service
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login failed. Please try again.')),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (e is AuthException) {
          errorMessage = e.message;
        } else if (e.toString().contains("Email not confirmed")) {
           errorMessage = 'Please verify your email before logging in.';
        } else if (e.toString().contains("Invalid login credentials")) {
           errorMessage = 'Invalid email or password. Please try again.';
        } else if (e.toString().contains("Failed host lookup") || e.toString().contains("SocketException")) {
           errorMessage = 'Cannot connect to the server. Please check your internet connection.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
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

  void _showForgotPasswordDialog() {
    final TextEditingController emailDialogController = TextEditingController();
    final formKeyDialog = GlobalKey<FormState>();
    final isSmallScreen = MediaQuery.of(context).size.width < _kSmallScreenWidth;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Form(
            key: formKeyDialog,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: TextStyle(
                    fontSize: isSmallScreen ? _kLinkFontSizeSmallScreen : _kLinkFontSizeDefault,
                  ),
                ),
                const SizedBox(height: _kDefaultFieldSpacing),
                TextFormField(
                  controller: emailDialogController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
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
            onPressed: () async {
              if (formKeyDialog.currentState?.validate() ?? false) {
                final email = emailDialogController.text.trim();
                Navigator.pop(context); // Close dialog first
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sending password reset link to $email...')),
                );
                try {
                  await _supabaseService.resetPassword(email);
                  if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Password reset link sent to $email. Please check your inbox.')),
                  );
                  }
                } catch (e) {
                   if(mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send reset link: ${e.toString()}')),
                    );
                   }
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < _kSmallScreenWidth;
    final double padding = isSmallScreen ? _kSmallPadding : _kDefaultPadding;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AppLogo(isSmallScreen: isSmallScreen),
                  const SizedBox(height: _kLogoBottomPadding / 2), // Adjusted spacing
                  _LoginFormCard(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    isLoading: _isLoading,
                    isSmallScreen: isSmallScreen,
                    rememberMe: _rememberMe,
                    onRememberMeChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      }
                    },
                    passwordVisible: _passwordVisible,
                    onPasswordVisibilityToggle: () {
                       if (mounted) {
                         setState(() {
                           _passwordVisible = !_passwordVisible;
                         });
                       }
                    },
                    onSignIn: () => _signIn(),
                    onForgotPassword: _showForgotPasswordDialog,
                    onRegister: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RegisterScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  final bool isSmallScreen;

  const _AppLogo({required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.assignment,
          size: isSmallScreen ? _kSmallIconSize : _kLargeIconSize,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: _kDefaultFieldSpacing),
        Text(
          'Jala Form',
          style: TextStyle(
            fontSize: isSmallScreen ? _kSmallTitleFontSize : _kLargeTitleFontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansArabic',
          ),
        ),
      ],
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool isSmallScreen;
  final bool rememberMe;
  final ValueChanged<bool?> onRememberMeChanged;
  final bool passwordVisible;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  const _LoginFormCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.isSmallScreen,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.passwordVisible,
    required this.onPasswordVisibilityToggle,
    required this.onSignIn,
    required this.onForgotPassword,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final double padding = isSmallScreen ? _kSmallPadding : _kDefaultPadding;
    final double fieldSpacing = isSmallScreen ? _kSmallFieldSpacing : _kDefaultFieldSpacing;
    final double verticalSpacing = isSmallScreen ? _kExtraSmallVerticalSpacing : _kSmallVerticalSpacing;
     final double linkFontSize = isSmallScreen ? _kLinkFontSizeSmallScreen : _kLinkFontSizeDefault;


    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Login to your account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? _kHeadlineSmallFontSizeSmallScreen : null,
                    ),
              ),
              SizedBox(height: fieldSpacing),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
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
              SizedBox(height: fieldSpacing),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      passwordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: onPasswordVisibilityToggle,
                  ),
                  border: const OutlineInputBorder(),
                ),
                obscureText: !passwordVisible,
                onFieldSubmitted: (_) => onSignIn(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: verticalSpacing),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 24, // Standard checkbox tap target size
                        width: 24,
                        child: Checkbox(
                          value: rememberMe,
                          onChanged: onRememberMeChanged,
                        ),
                      ),
                      const SizedBox(width: _kExtraSmallVerticalSpacing),
                      const Text('Remember me'),
                    ],
                  ),
                  TextButton(
                    onPressed: onForgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: _kSmallVerticalSpacing, vertical: _kExtraSmallVerticalSpacing),
                    ),
                    child: const Text('Forgot Password?'),
                  ),
                ],
              ),
              SizedBox(height: fieldSpacing),
              SizedBox(
                width: double.infinity,
                height: _kButtonHeight,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: _kButtonCircularProgressSize,
                          width: _kButtonCircularProgressSize,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: fieldSpacing),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(fontSize: linkFontSize),
                  ),
                  TextButton(
                    onPressed: onRegister,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: _kSmallVerticalSpacing, vertical: 0),
                    ),
                    child: Text(
                      'Register',
                      style: TextStyle(fontSize: linkFontSize),
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
}
