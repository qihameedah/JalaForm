import 'package:flutter/material.dart';
import 'package:jala_form/services/supabase_service.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_field.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:jala_form/features/forms/models/user_group.dart';
import 'package:jala_form/features/web/web_form_builder.dart';
import 'package:jala_form/features/web/web_form_editor.dart';
import 'package:jala_form/features/web/screens/web_group_detail_screen.dart';
import 'package:jala_form/features/web/screens/web_profile_screen.dart';
import 'package:jala_form/features/web/screens/web_form_submission_screen.dart';
import 'package:uuid/uuid.dart';

// Import all extracted views
import 'views/dashboard_view.dart';
import 'views/forms_view.dart';
import 'views/responses_view.dart';
import 'views/groups_view.dart';

// Import services
import '../../services/export_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/response_analyzer.dart';

// Import shared models and utilities
import 'package:jala_form/shared/models/likert/likert_option.dart';
import 'package:jala_form/shared/models/likert/likert_display_data.dart';
import 'package:jala_form/shared/utils/likert_parser.dart';
import 'package:jala_form/shared/models/forms/dashboard_stats.dart';

// Import widgets
import 'widgets/header/dashboard_header.dart';
import 'widgets/common/loading_indicator.dart';
import 'widgets/responses/enhanced_response_value.dart';

class WebDashboard extends StatefulWidget {
  const WebDashboard({super.key});

  @override
  State<WebDashboard> createState() => _WebDashboardState();
}

class _WebDashboardState extends State<WebDashboard>
    with SingleTickerProviderStateMixin {
  // Services
  final _supabaseService = SupabaseService();

  // State variables - Forms
  List<CustomForm> _myForms = <CustomForm>[];
  List<CustomForm> _availableForms = <CustomForm>[];
  List<CustomForm> _availableRegularForms = <CustomForm>[];
  List<CustomForm> _availableChecklistForms = <CustomForm>[];
  final Map<String, List<FormResponse>> _formResponses = <String, List<FormResponse>>{};

  // Memoized dashboard statistics
  DashboardStats _dashboardStats = const DashboardStats.empty();

  // State variables - Groups
  List<UserGroup> _userGroups = <UserGroup>[];
  List<UserGroup> _filteredGroups = <UserGroup>[];

  // UI State
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isCreatingForm = false;
  String _username = 'User';
  int _selectedFormIndex = -1;
  late AnimationController _animationController;
  String _selectedFormType = 'all'; // 'all', 'forms', 'checklists'
  String _currentView = 'dashboard'; // dashboard, forms, responses, groups

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupSearchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'newest'; // Options: newest, oldest, alphabetical
  final String _groupSortBy = 'newest';

  // Responsive breakpoints
  bool get isSmallScreen => MediaQuery.of(context).size.width < 600;
  bool get isMediumScreen =>
      MediaQuery.of(context).size.width < 1024 &&
      MediaQuery.of(context).size.width >= 600;
  bool get isLargeScreen => MediaQuery.of(context).size.width >= 1024;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    debugPrint('WebDashboard initState called');

    // Load initial data
    _loadUserInfo();
    _loadInitialData();
    _loadGroups();

    // Listen for search query changes
    _searchController.addListener(_onSearchChanged);

    debugPrint('Initial current view: $_currentView');
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _groupSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ========== DATA LOADING METHODS ==========

  Future<void> _loadInitialData() async {
    debugPrint('Starting initial data load...');

    try {
      await _loadData();
      debugPrint('Initial data load completed. Forms count: ${_myForms.length}');
    } catch (e) {
      debugPrint('Error in initial data load: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final forms = await _supabaseService.getForms();
      final user = _supabaseService.getCurrentUser();

      if (user != null && mounted) {
        final myForms = forms.where((form) => form.created_by == user.id).toList();

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

        try {
          final availableForms = await _supabaseService.getAvailableForms();
          if (mounted) {
            // Compute dashboard stats once (memoization)
            final stats = DashboardStats.compute(
              myForms: myForms,
              availableForms: availableForms,
              formResponses: responseMap,
            );

            setState(() {
              _availableForms = List<CustomForm>.from(availableForms);
              _availableRegularForms = availableForms.where((form) => !form.isChecklist).toList();
              _availableChecklistForms = availableForms.where((form) => form.isChecklist).toList();
              _dashboardStats = stats; // Store computed stats
            });
          }
        } catch (e) {
          debugPrint('Error loading available forms: $e');
          if (mounted) {
            setState(() {
              _availableForms = <CustomForm>[];
              _availableRegularForms = <CustomForm>[];
              _availableChecklistForms = <CustomForm>[];
              _dashboardStats = const DashboardStats.empty();
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

  Future<void> _loadGroups() async {
    try {
      final groups = await _supabaseService.getMyCreatedGroups();

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

  // ========== FORM CRUD METHODS ==========

  void _createNewForm() {
    setState(() {
      _isCreatingForm = true;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WebFormBuilder()),
    ).then((_) {
      setState(() {
        _isCreatingForm = false;
      });
      _loadData();
    });
  }

  void _editForm(CustomForm form) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WebFormEditor(form: form)),
    ).then((_) {
      _loadData();
    });
  }

  void _deleteForm(CustomForm form) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${form.title}?'),
        content: const Text('This action cannot be undone. All responses will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
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
                _loadData();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _openFormSubmission(CustomForm form) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebFormSubmissionScreen(form: form),
      ),
    ).then((_) => _loadData());
  }

  // ========== GROUP CRUD METHODS ==========

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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.group, color: AppTheme.primaryColor),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.description, color: AppTheme.primaryColor),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'name': nameController.text,
                  'description': descriptionController.text,
                });
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
        content: Text('Are you sure you want to delete "${group.name}"? This action cannot be undone.'),
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
      MaterialPageRoute(builder: (context) => WebGroupDetailScreen(group: group)),
    );

    if (result == true) {
      _loadGroups();
    }
  }

  // ========== EXPORT METHODS ==========

  Future<void> _exportToExcel(CustomForm form) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final exportService = ExportService();
      final responses = _formResponses[form.id] ?? [];
      await exportService.exportToExcel(form, responses);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  // ========== AUTH METHODS ==========

  Future<void> _signOut() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _supabaseService.signOut();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
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
          ),
        );
      }
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WebProfileScreen()),
    );
  }

  // ========== HELPER METHODS ==========

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    }
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

  void _navigateToView(String view) {
    debugPrint('Navigating to view: $view');
    setState(() {
      _currentView = view;
    });
  }

  LikertDisplayData _parseLikertDisplayData(
      FormFieldModel field, Map<dynamic, dynamic> responseMap) {
    // Use shared utility for parsing Likert display data
    return LikertParser.parseLikertDisplayData(field, responseMap);
  }

  Widget buildFieldCell(dynamic field, dynamic value) {
    return EnhancedResponseValue(
      field: field as FormFieldModel,
      value: value,
      parseLikertData: _parseLikertDisplayData,
    );
  }

  void _showResponseDetails(CustomForm form, FormResponse response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Response from ${DateFormatter.formatDateTime(response.submitted_at)}'),
        content: SizedBox(
          width: 600,
          child: ListView(
            shrinkWrap: true,
            children: form.fields.map((field) {
              final value = response.responses[field.id];
              return ListTile(
                title: Text(field.label),
                subtitle: EnhancedResponseValue(
                  field: field,
                  value: value,
                  parseLikertData: _parseLikertDisplayData,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ========== BUILD METHOD ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          DashboardHeader(
            username: _username,
            currentView: _currentView,
            onDashboardPressed: () => _navigateToView('dashboard'),
            onFormsPressed: () => _navigateToView('forms'),
            onResponsesPressed: () => _navigateToView('responses'),
            onGroupsPressed: () => _navigateToView('groups'),
            onCreateForm: _createNewForm,
            onProfilePressed: _openProfile,
            onLogoutPressed: _signOut,
          ),
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _buildCurrentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'dashboard':
        return DashboardView(
          myForms: _myForms,
          availableForms: _availableForms,
          availableRegularForms: _availableRegularForms,
          availableChecklistForms: _availableChecklistForms,
          formResponses: _formResponses,
          selectedFormType: _selectedFormType,
          sortBy: _sortBy,
          searchQuery: _searchQuery,
          username: _username,
          onFormTypeChanged: (type) => setState(() => _selectedFormType = type),
          onSortByChanged: (sort) => setState(() => _sortBy = sort ?? 'newest'),
          onCreateForm: _createNewForm,
          onOpenFormSubmission: _openFormSubmission,
          onViewAllForms: () => setState(() => _currentView = 'forms'),
        );

      case 'forms':
        return FormsView(
          myForms: _myForms,
          formResponses: _formResponses,
          searchQuery: _searchQuery,
          sortBy: _sortBy,
          isLoading: _isLoading,
          searchController: _searchController,
          onSortChanged: (sort) => setState(() => _sortBy = sort ?? 'newest'),
          onCreateForm: _createNewForm,
          onEditForm: _editForm,
          onDeleteForm: _deleteForm,
          onOpenFormSubmission: _openFormSubmission,
          onViewResponses: (form) {
            setState(() {
              _selectedFormIndex = _myForms.indexOf(form);
              _currentView = 'responses';
            });
          },
        );

      case 'responses':
        return ResponsesView(
          myForms: _myForms,
          formResponses: _formResponses,
          selectedFormIndex: _selectedFormIndex,
          isExporting: _isExporting,
          searchQuery: _searchQuery,
          sortBy: _sortBy,
          searchController: _searchController,
          onSelectForm: (index) => setState(() => _selectedFormIndex = index),
          onExportToExcel: _exportToExcel,
          onOpenFormSubmission: _openFormSubmission,
          onShowResponseDetails: _showResponseDetails,
          onBack: () => setState(() => _selectedFormIndex = -1),
          formatDate: DateFormatter.formatDate,
          formatDateTime: DateFormatter.formatDateTime,
          buildFieldCell: buildFieldCell,
        );

      case 'groups':
        return GroupsView(
          userGroups: _userGroups,
          isLoading: _isLoading,
          onCreateGroup: _createNewGroup,
          onDeleteGroup: _deleteGroup,
          onOpenGroupDetails: _openGroupDetails,
          formatDate: DateFormatter.formatDate,
        );

      default:
        return DashboardView(
          myForms: _myForms,
          availableForms: _availableForms,
          availableRegularForms: _availableRegularForms,
          availableChecklistForms: _availableChecklistForms,
          formResponses: _formResponses,
          selectedFormType: _selectedFormType,
          sortBy: _sortBy,
          searchQuery: _searchQuery,
          username: _username,
          onFormTypeChanged: (type) => setState(() => _selectedFormType = type),
          onSortByChanged: (sort) => setState(() => _sortBy = sort ?? 'newest'),
          onCreateForm: _createNewForm,
          onOpenFormSubmission: _openFormSubmission,
          onViewAllForms: () => setState(() => _currentView = 'forms'),
        );
    }
  }
}
