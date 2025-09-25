// Full updated ProfileScreen with fixes
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:jala_form/services/supabase_service.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  final _usernameFormKey = GlobalKey<FormBuilderState>();
  final _passwordFormKey = GlobalKey<FormBuilderState>();
  final _supabaseService = SupabaseService();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = true;
  bool _isUpdatingUsername = false;
  bool _isUpdatingPassword = false;
  bool _isPasswordVisible = false;
  bool _isChangePasswordVisible = false;
  late AnimationController _animationController;
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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
    _animationController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: ${e.toString()}')),
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

  Future<void> _updateUsername() async {
    if (_usernameFormKey.currentState!.saveAndValidate()) {
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Username updated successfully'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating username: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
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

  Future<void> _updatePassword() async {
    if (_passwordFormKey.currentState!.saveAndValidate()) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated successfully'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );

          setState(() {
            _isChangePasswordVisible = false;
          });
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Error updating password: ${e.toString()}';

          // Provide a more user-friendly error message
          if (e.toString().contains('Invalid login credentials')) {
            errorMessage = 'Current password is incorrect';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated Profile Avatar
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Animated Username
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: Text(
                      _emailController.text,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats cards in a responsive grid
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate how many cards can fit per row based on screen width
                        final cardWidth = constraints.maxWidth > 600
                            ? (constraints.maxWidth - 48) / 4
                            : // 4 cards per row on large screens
                            (constraints.maxWidth - 16) /
                                2; // 2 cards per row on small screens

                        return Wrap(
                          spacing: 16, // horizontal spacing
                          runSpacing: 16, // vertical spacing
                          alignment: WrapAlignment.center,
                          children: [
                            _buildStatCard('Forms', _userStats['forms'] ?? 0,
                                Icons.assignment, cardWidth),
                            _buildStatCard(
                                'Checklists',
                                _userStats['checklists'] ?? 0,
                                Icons.checklist,
                                cardWidth),
                            _buildStatCard('Groups', _userStats['groups'] ?? 0,
                                Icons.group, cardWidth),
                            _buildStatCard(
                                'Responses',
                                _userStats['responses'] ?? 0,
                                Icons.how_to_reg,
                                cardWidth),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Account Settings Card
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 16),

                            // Username update (separate form)
                            FormBuilder(
                              key: _usernameFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Username',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return constraints.maxWidth > 600
                                          ? Row(
                                              children: [
                                                Expanded(
                                                  child: FormBuilderTextField(
                                                    name: 'username',
                                                    controller:
                                                        _usernameController,
                                                    decoration:
                                                        const InputDecoration(
                                                      hintText:
                                                          'Enter username',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                    validator:
                                                        FormBuilderValidators
                                                            .compose([
                                                      FormBuilderValidators
                                                          .required(),
                                                      FormBuilderValidators
                                                          .minLength(3),
                                                    ]),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                _isUpdatingUsername
                                                    ? Container(
                                                        height: 50,
                                                        width: 120,
                                                        alignment:
                                                            Alignment.center,
                                                        child:
                                                            const CircularProgressIndicator(),
                                                      )
                                                    : ElevatedButton(
                                                        onPressed:
                                                            _updateUsername,
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            vertical: 15,
                                                            horizontal: 16,
                                                          ),
                                                        ),
                                                        child: const Text(
                                                            'Update'),
                                                      ),
                                              ],
                                            )
                                          : Column(
                                              children: [
                                                FormBuilderTextField(
                                                  name: 'username',
                                                  controller:
                                                      _usernameController,
                                                  decoration:
                                                      const InputDecoration(
                                                    hintText: 'Enter username',
                                                    border:
                                                        OutlineInputBorder(),
                                                  ),
                                                  validator:
                                                      FormBuilderValidators
                                                          .compose([
                                                    FormBuilderValidators
                                                        .required(),
                                                    FormBuilderValidators
                                                        .minLength(3),
                                                  ]),
                                                ),
                                                const SizedBox(height: 12),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: _isUpdatingUsername
                                                      ? const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        )
                                                      : ElevatedButton(
                                                          onPressed:
                                                              _updateUsername,
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              vertical: 12,
                                                            ),
                                                          ),
                                                          child: const Text(
                                                              'Update Username'),
                                                        ),
                                                ),
                                              ],
                                            );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Email (read-only)
                            const Text('Email',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            FormBuilderTextField(
                              name: 'email',
                              controller: _emailController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              enabled: false,
                            ),

                            const SizedBox(height: 24),

                            // Password change section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextButton.icon(
                                  icon: Icon(
                                    _isChangePasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  label: Text(
                                    _isChangePasswordVisible
                                        ? 'Hide'
                                        : 'Change Password',
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isChangePasswordVisible =
                                          !_isChangePasswordVisible;
                                    });
                                  },
                                ),
                              ],
                            ),

                            if (_isChangePasswordVisible) ...[
                              const SizedBox(height: 16),
                              FormBuilder(
                                key: _passwordFormKey,
                                child: Column(
                                  children: [
                                    FormBuilderTextField(
                                      name: 'current_password',
                                      controller: _oldPasswordController,
                                      decoration: InputDecoration(
                                        labelText: 'Current Password',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                        ),
                                      ),
                                      obscureText: !_isPasswordVisible,
                                      validator: FormBuilderValidators.compose([
                                        FormBuilderValidators.required(),
                                      ]),
                                    ),
                                    const SizedBox(height: 16),
                                    FormBuilderTextField(
                                      name: 'new_password',
                                      controller: _newPasswordController,
                                      decoration: InputDecoration(
                                        labelText: 'New Password',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                        ),
                                      ),
                                      obscureText: !_isPasswordVisible,
                                      validator: FormBuilderValidators.compose([
                                        FormBuilderValidators.required(),
                                        FormBuilderValidators.minLength(6),
                                      ]),
                                    ),
                                    const SizedBox(height: 16),
                                    FormBuilderTextField(
                                      name: 'confirm_password',
                                      controller: _confirmPasswordController,
                                      decoration: InputDecoration(
                                        labelText: 'Confirm New Password',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                        ),
                                      ),
                                      obscureText: !_isPasswordVisible,
                                      validator: FormBuilderValidators.compose([
                                        FormBuilderValidators.required(),
                                        (val) {
                                          if (val !=
                                              _newPasswordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ]),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _isUpdatingPassword
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : ElevatedButton(
                                              onPressed: _updatePassword,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppTheme.primaryColor,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                              ),
                                              child: const Text(
                                                'Update Password',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ),
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
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, double width) {
    return Container(
      width: width,
      constraints:
          BoxConstraints(minHeight: 140), // Fixed height to prevent overflow
      child: Card(
        elevation: 4,
        shadowColor: AppTheme.primaryColor.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
