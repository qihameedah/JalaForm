// lib/screens/web_group_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:ui';
import '../models/user_group.dart';
import '../models/group_member.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class WebGroupDetailScreen extends StatefulWidget {
  final UserGroup group;

  const WebGroupDetailScreen({
    super.key,
    required this.group,
  });

  @override
  State<WebGroupDetailScreen> createState() => _WebGroupDetailScreenState();
}

class _WebGroupDetailScreenState extends State<WebGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  List<GroupMember> _members = [];
  bool _isInitialLoading = true;
  bool _isProcessing = false; // New state for overlay operations

  bool _isAddingMembers = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<GroupMember> _filteredMembers = [];

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // For member count animation
  int _oldMemberCount = 0;
  late Animation<int> _memberCountAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuint),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _memberCountAnimation = IntTween(begin: 0, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );

    _searchController.addListener(_onSearchChanged);
    _loadMembers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterMembers();
    });
  }

  void _filterMembers() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredMembers = List.from(_members);
      });
    } else {
      setState(() {
        _filteredMembers = _members.where((member) {
          final name = member.user_name?.toLowerCase() ?? '';
          final email = member.user_email?.toLowerCase() ?? '';
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();
      });
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isInitialLoading = true; // Use this instead of _isLoading
    });

    try {
      final members = await _supabaseService.getGroupMembers(widget.group.id);

      setState(() {
        _oldMemberCount = _members.length;
        _members = members;
        _filteredMembers = List.from(members);
        _isInitialLoading = false; // Use this instead of _isLoading

        // Update member count animation
        _memberCountAnimation =
            IntTween(begin: _oldMemberCount, end: members.length).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
          ),
        );

        // Play animation
        _animationController.forward(from: 0.0);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading members: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(8),
          ),
        );
        setState(() {
          _isInitialLoading = false; // Change this from _isLoading
          _animationController.forward(from: 0.0);
        });
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScaleTransition(
        scale: CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeOutCubic,
        ),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
              SizedBox(width: 12),
              Text(
                'Delete Group',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${widget.group.name}"?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'This action cannot be undone, and all members will be removed from this group.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade100.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.red.shade700, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All sharing settings for forms associated with this group will be lost.',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          contentPadding: EdgeInsets.fromLTRB(24, 8, 24, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.delete_forever, color: Colors.white, size: 20),
              label: Text(
                'Delete Group',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
          actionsPadding: EdgeInsets.fromLTRB(16, 0, 24, 16),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isProcessing = true; // Changed from _isLoading
      });

      try {
        await _supabaseService.deleteGroup(widget.group.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 12),
                  Text(
                    'Group deleted successfully',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.successColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.all(12),
              duration: Duration(seconds: 3),
              elevation: 4,
            ),
          );

          // Navigate back and return true to indicate the group was deleted
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting group: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.all(12),
            ),
          );
          setState(() {
            _isProcessing = false; // Changed from _isLoading
          });
        }
      }
    }
  }

  Future<void> _addMembers() async {
    setState(() {
      _isAddingMembers = true;
    });

    try {
      // Fetch all available users that aren't already members
      final allUsers = await _supabaseService.getAllUsers();

      // Filter out existing members
      final existingMemberIds = _members.map((m) => m.user_id).toSet();
      final availableUsers = allUsers
          .where((user) => !existingMemberIds.contains(user['id']))
          .toList();

      if (mounted) {
        setState(() {
          _isAddingMembers = false;
        });

        if (availableUsers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 18),
                  SizedBox(width: 12),
                  Text(
                    'No more users available to add',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.all(12),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        final result = await _showUserSelectionDialog(availableUsers);

        if (result != null && result.isNotEmpty) {
          await _processSelectedUsers(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAddingMembers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(12),
          ),
        );
      }
    }
  }

// Updated to be responsive
  Widget _buildEmptyUserSearchState(
      String searchQuery,
      TextEditingController controller,
      ValueNotifier<String> searchQueryNotifier,
      bool isSmallScreen) {
    return Center(
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: Duration(milliseconds: 300),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off,
                size: isSmallScreen ? 48 : 64,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            Text(
              searchQuery.isEmpty
                  ? 'No users available'
                  : 'No users found for "$searchQuery"',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            if (searchQuery.isNotEmpty)
              TextButton.icon(
                icon: Icon(Icons.clear, size: isSmallScreen ? 18 : 20),
                label: Text(
                  'Clear Search',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  controller.clear();
                  searchQueryNotifier.value = '';
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 20,
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>?> _showUserSelectionDialog(
      List<Map<String, dynamic>> users) async {
    final TextEditingController dialogSearchController =
        TextEditingController();
    final ValueNotifier<String> searchQueryNotifier = ValueNotifier('');
    final ValueNotifier<List<Map<String, dynamic>>> selectedUsersNotifier =
        ValueNotifier<List<Map<String, dynamic>>>([]);

    // Get the screen size to make adaptive adjustments
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 600;
    final double screenWidth = screenSize.width;
    final double dialogWidth = isSmallScreen
        ? screenWidth * 0.95 // Almost full width on small screens
        : screenWidth < 1024
            ? screenWidth * 0.7
            : screenWidth * 0.5;

    final double dialogHeight =
        isSmallScreen ? screenSize.height * 0.8 : screenSize.height * 0.7;

    final double fontSize = isSmallScreen ? 0.9 : 1.0;

    return await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) {
        return Center(
          child: SingleChildScrollView(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: Curves.easeOutCubic,
              ),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                insetPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16.0 : 40.0,
                  vertical: isSmallScreen ? 20.0 : 24.0,
                ),
                child: Container(
                  width: dialogWidth,
                  constraints: BoxConstraints(
                    maxHeight: dialogHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title section
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            24, 24, 24, isSmallScreen ? 8 : 12),
                        child: Row(
                          children: [
                            Icon(Icons.group_add,
                                color: AppTheme.primaryColor,
                                size: isSmallScreen ? 22 : 26),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Add Members to Group',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 20 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Search bar with enhanced styling
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24, vertical: isSmallScreen ? 8 : 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: dialogSearchController,
                            decoration: InputDecoration(
                              hintText: 'Search users...',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey.shade600,
                                size: isSmallScreen ? 20 : 22,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 16 : 18),
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: Colors.grey.shade800,
                            ),
                            onChanged: (value) {
                              searchQueryNotifier.value = value.toLowerCase();
                            },
                          ),
                        ),
                      ),

                      // User list with improved styling
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            // Ensure a minimum height so the dialog doesn't collapse
                            minHeight: isSmallScreen
                                ? screenSize.height * 0.2
                                : screenSize.height * 0.3,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: isSmallScreen ? 8 : 12),
                            child: ValueListenableBuilder<String>(
                              valueListenable: searchQueryNotifier,
                              builder: (context, searchQuery, _) {
                                final filteredUsers = users.where((user) {
                                  final email =
                                      user['email'].toString().toLowerCase();
                                  final username = user['username']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  return email.contains(searchQuery) ||
                                      username.contains(searchQuery);
                                }).toList();

                                if (filteredUsers.isEmpty) {
                                  return _buildEmptyUserSearchState(
                                      searchQuery,
                                      dialogSearchController,
                                      searchQueryNotifier,
                                      isSmallScreen);
                                }

                                return ValueListenableBuilder<
                                    List<Map<String, dynamic>>>(
                                  valueListenable: selectedUsersNotifier,
                                  builder: (context, selectedUsers, _) {
                                    return AnimationLimiter(
                                      child: ListView.builder(
                                        itemCount: filteredUsers.length,
                                        shrinkWrap: true,
                                        itemBuilder: (context, index) {
                                          final user = filteredUsers[index];
                                          final isSelected = selectedUsers.any(
                                              (selected) =>
                                                  selected['id'] == user['id']);

                                          return AnimationConfiguration
                                              .staggeredList(
                                            position: index,
                                            duration:
                                                Duration(milliseconds: 400),
                                            child: SlideAnimation(
                                              verticalOffset: 40.0,
                                              child: FadeInAnimation(
                                                child: _buildUserSelectionItem(
                                                  user,
                                                  isSelected,
                                                  selectedUsers,
                                                  selectedUsersNotifier,
                                                  isSmallScreen,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Divider
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Divider(
                          height: 32,
                          thickness: 1,
                          color: Colors.grey.shade200,
                        ),
                      ),

                      // Selection counter and action buttons with enhanced styling
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            24, 0, 24, isSmallScreen ? 16 : 24),
                        child:
                            ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: selectedUsersNotifier,
                          builder: (context, selectedUsers, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Selection counter with improved animation
                                AnimatedSwitcher(
                                  duration: Duration(milliseconds: 400),
                                  transitionBuilder: (Widget child,
                                      Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: Offset(0.0, 0.2),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    key: ValueKey<int>(selectedUsers.length),
                                    margin: EdgeInsets.only(bottom: 20),
                                    padding: EdgeInsets.symmetric(
                                      vertical: isSmallScreen ? 10 : 12,
                                      horizontal: isSmallScreen ? 16 : 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedUsers.isEmpty
                                          ? Colors.grey.shade100
                                          : AppTheme.primaryColor
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: selectedUsers.isEmpty
                                            ? Colors.grey.shade300
                                            : AppTheme.primaryColor
                                                .withOpacity(0.4),
                                        width: 1.5,
                                      ),
                                      boxShadow: selectedUsers.isEmpty
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: AppTheme.primaryColor
                                                    .withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          selectedUsers.isEmpty
                                              ? Icons.person_outline
                                              : Icons.people_alt,
                                          size: isSmallScreen ? 18 : 20,
                                          color: selectedUsers.isEmpty
                                              ? Colors.grey.shade600
                                              : AppTheme.primaryColor,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          selectedUsers.isEmpty
                                              ? 'No users selected'
                                              : '${selectedUsers.length} user${selectedUsers.length == 1 ? '' : 's'} selected',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isSmallScreen ? 14 : 16,
                                            color: selectedUsers.isEmpty
                                                ? Colors.grey.shade600
                                                : AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Action buttons with improved styling
                                isSmallScreen
                                    // Stacked buttons for small screens
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: Icon(
                                              Icons.person_add,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            label: Text(
                                              'Add ${selectedUsers.length > 0 ? selectedUsers.length : ""} User${selectedUsers.length == 1 ? "" : "s"}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            onPressed: selectedUsers.isEmpty
                                                ? null
                                                : () => Navigator.pop(
                                                    context, selectedUsers),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              disabledBackgroundColor:
                                                  Colors.grey.shade300,
                                              shadowColor: AppTheme.primaryColor
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          SizedBox(height: 12),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  Colors.grey.shade700,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    // Side-by-side buttons for larger screens
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  Colors.grey.shade700,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          ElevatedButton.icon(
                                            icon: Icon(
                                              Icons.person_add,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            label: Text(
                                              'Add ${selectedUsers.length > 0 ? selectedUsers.length : ""} User${selectedUsers.length == 1 ? "" : "s"}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            onPressed: selectedUsers.isEmpty
                                                ? null
                                                : () => Navigator.pop(
                                                    context, selectedUsers),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              disabledBackgroundColor:
                                                  Colors.grey.shade300,
                                              shadowColor: AppTheme.primaryColor
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

// Updated to be responsive
  Widget _buildUserSelectionItem(
      Map<String, dynamic> user,
      bool isSelected,
      List<Map<String, dynamic>> selectedUsers,
      ValueNotifier<List<Map<String, dynamic>>> selectedUsersNotifier,
      bool isSmallScreen) {
    final double avatarRadius = isSmallScreen ? 20 : 24;
    final double fontSize = isSmallScreen ? 0.9 : 1.0;

    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      elevation: isSelected ? 3 : 1,
      shadowColor: isSelected
          ? AppTheme.primaryColor.withOpacity(0.4)
          : Colors.black.withOpacity(0.1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.white,
          child: InkWell(
            onTap: () {
              final updatedUsers =
                  List<Map<String, dynamic>>.from(selectedUsers);
              if (isSelected) {
                updatedUsers
                    .removeWhere((selected) => selected['id'] == user['id']);
              } else {
                updatedUsers.add(user);
              }
              selectedUsersNotifier.value = updatedUsers;
            },
            splashColor: AppTheme.primaryColor.withOpacity(0.15),
            highlightColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                children: [
                  // Avatar with checkmark overlay for selected state
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.blue.shade200)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Hero(
                          tag: 'user-avatar-${user['id']}',
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: isSelected
                                ? AppTheme.primaryColor
                                : Colors.blue.shade100,
                            child: Text(
                              (user['username'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 16 : 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(isSmallScreen ? 1 : 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: isSmallScreen ? 1.5 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: isSmallScreen ? 10 : 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),

                  // User details with improved typography
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['username'] ?? 'User',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.black87,
                            fontSize: isSmallScreen ? 15 : 17,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: isSmallScreen ? 12 : 14,
                              color: Colors.grey.shade500,
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Expanded(
                              child: Text(
                                user['email'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Enhanced checkbox - sized appropriately for mobile
                  Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.4)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Transform.scale(
                      scale: isSmallScreen ? 1.0 : 1.2,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: BorderSide(
                          color: Colors.grey.shade400,
                          width: 1.5,
                        ),
                        onChanged: (value) {
                          final updatedUsers =
                              List<Map<String, dynamic>>.from(selectedUsers);
                          if (value == true) {
                            if (!isSelected) {
                              updatedUsers.add(user);
                            }
                          } else {
                            updatedUsers.removeWhere(
                                (selected) => selected['id'] == user['id']);
                          }
                          selectedUsersNotifier.value = updatedUsers;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processSelectedUsers(
      List<Map<String, dynamic>> selectedUsers) async {
    setState(() {
      _isProcessing = true; // Use this instead of _isLoading
    });

    try {
      final currentUser = _supabaseService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Add all selected users to the group
      for (final user in selectedUsers) {
        final member = GroupMember(
          group_id: widget.group.id,
          user_id: user['id'],
          added_by: currentUser.id,
          added_at: DateTime.now(),
          user_email: user['email'],
          user_name: user['username'],
        );

        await _supabaseService.addGroupMember(member);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text(
                  '${selectedUsers.length} member${selectedUsers.length == 1 ? '' : 's'} added successfully',
                  style: TextStyle(fontSize: 15),
                ),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(12),
            duration: Duration(seconds: 3),
            elevation: 4,
          ),
        );

        // Reload members with animation
        _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding members: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(12),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false; // Use this when done
        });
      }
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => ScaleTransition(
        scale: CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeOutCubic,
        ),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.person_remove, color: Colors.red.shade600, size: 24),
              SizedBox(width: 12),
              Text(
                'Remove Member',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to remove this member?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: 'member-avatar-remove-${member.user_id}',
                      child: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        radius: 24,
                        child: Text(
                          (member.user_name?.isNotEmpty ?? false)
                              ? member.user_name![0].toUpperCase()
                              : (member.user_email?.isNotEmpty ?? false)
                                  ? member.user_email![0].toUpperCase()
                                  : 'U',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.user_name ?? 'User',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  member.user_email ?? 'No email',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          contentPadding: EdgeInsets.fromLTRB(24, 8, 24, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.person_remove, color: Colors.white, size: 20),
              label: Text(
                'Remove',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                shadowColor: Colors.red.shade300.withOpacity(0.3),
              ),
            ),
          ],
          actionsPadding: EdgeInsets.fromLTRB(16, 0, 24, 16),
        ),
      ),
    );

    if (confirm == true) {
      setState(() {
        _isProcessing = true; // Changed from _isLoading
      });

      try {
        await _supabaseService.removeGroupMember(
            widget.group.id, member.user_id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 12),
                  Text(
                    'Member removed successfully',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.all(12),
              duration: Duration(seconds: 3),
              elevation: 4,
            ),
          );

          // Reload members
          _loadMembers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing member: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.all(12),
            ),
          );
          setState(() {
            _isProcessing = false; // Changed from _isLoading
          });
        }
      }
    }
  }

  PreferredSizeWidget _buildResponsiveAppBar(Size screenSize) {
    final double appBarHeight = screenSize.height * 0.08; // Adaptive height
    final double titleFontSize = screenSize.width < 600 ? 18 : 22;
    final double iconSize = screenSize.width < 600 ? 22 : 26;
    final double cornerRadius = screenSize.width < 600 ? 20 : 30;

    return AppBar(
      title: Text(
        widget.group.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: titleFontSize,
          letterSpacing: 0.3,
        ),
      ),
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: appBarHeight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(cornerRadius),
          bottomRight: Radius.circular(cornerRadius),
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              Color.fromARGB(255, 70, 115, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(cornerRadius),
            bottomRight: Radius.circular(cornerRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
      ),
      leadingWidth: screenSize.width * 0.12,
      actions: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: _isAddingMembers
              ? Container(
                  key: ValueKey<bool>(true),
                  margin: EdgeInsets.only(right: 16),
                  width: iconSize - 2,
                  height: iconSize - 2,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : IconButton(
                  key: ValueKey<bool>(false),
                  icon: Icon(Icons.person_add_alt_1_rounded, size: iconSize),
                  tooltip: 'Add Members',
                  onPressed: _addMembers,
                ),
        ),
        IconButton(
          icon: Icon(Icons.delete, size: iconSize),
          tooltip: 'Delete Group',
          onPressed: _deleteGroup,
        ),
        SizedBox(width: screenSize.width * 0.03),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    final isMediumScreen = screenSize.width >= 768 && screenSize.width < 1024;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    // Calculate adaptive padding based on screen width
    final horizontalPadding = screenSize.width * 0.05; // 5% of screen width
    final verticalPadding = screenSize.height * 0.02; // 2% of screen height

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildResponsiveAppBar(screenSize),
      body: Stack(
        children: [
          // Enhanced background with subtle pattern
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              image: DecorationImage(
                image: NetworkImage(
                    'https://www.transparenttextures.com/patterns/cubes.png'),
                repeat: ImageRepeat.repeat,
                opacity: 0.03,
              ),
            ),
          ),

          _isInitialLoading
              ? _buildLoadingState()
              : AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      top: verticalPadding +
                          (AppBar().preferredSize.height * 1.2),
                      bottom: verticalPadding,
                    ),
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Group Info Card
                          _buildEnhancedGroupInfoCard(
                              isSmallScreen, constraints),

                          SizedBox(height: screenSize.height * 0.03),

                          // Members Section with improved header
                          _buildMembersHeader(isSmallScreen, screenSize),

                          SizedBox(height: screenSize.height * 0.02),

                          // Members list or empty state with improved styling
                          Expanded(
                            child: _members.isEmpty
                                ? _buildEmptyMembersState()
                                : _buildMembersTable(screenSize),
                          ),
                        ],
                      );
                    }),
                  ),
                ),

          // Enhanced loading overlay
          if (_isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildMembersHeader(bool isSmallScreen, Size screenSize) {
    final double iconSize = screenSize.width < 600 ? 20 : 24;
    final double fontSize = screenSize.width < 600 ? 18 : 22;
    final double searchWidth = isSmallScreen
        ? screenSize.width * 0.4
        : screenSize.width < 1024
            ? screenSize.width * 0.25
            : screenSize.width * 0.2;

    return ResponsiveLayoutBuilder(
      small: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and count
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people,
                  color: AppTheme.primaryColor,
                  size: iconSize,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Members',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 14),
              if (_members.isNotEmpty) _buildMemberCountBadge(),
            ],
          ),
          SizedBox(height: 16),
          // Search and add button
          Row(
            children: [
              Expanded(
                child: _buildSearchField(isSmallScreen),
              ),
              SizedBox(width: 12),
              _buildAddMemberButton(isSmallScreen),
            ],
          ),
        ],
      ),
      medium: (context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people,
                  color: AppTheme.primaryColor,
                  size: iconSize,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Members',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 14),
              if (_members.isNotEmpty) _buildMemberCountBadge(),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: searchWidth,
                child: _buildSearchField(isSmallScreen),
              ),
              SizedBox(width: 16),
              _buildAddMemberButton(isSmallScreen),
            ],
          ),
        ],
      ),
      large: (context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people,
                  color: AppTheme.primaryColor,
                  size: iconSize,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Members',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 14),
              if (_members.isNotEmpty) _buildMemberCountBadge(),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: searchWidth,
                child: _buildSearchField(isSmallScreen),
              ),
              SizedBox(width: 16),
              _buildAddMemberButton(isSmallScreen),
            ],
          ),
        ],
      ),
    );
  }

// Helper for member count badge animation
  Widget _buildMemberCountBadge() {
    return AnimatedBuilder(
      animation: _memberCountAnimation,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${_memberCountAnimation.value}',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

// Helper for search field
  Widget _buildSearchField(bool isSmallScreen) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: Icon(
                    Icons.search,
                    size: isSmallScreen ? 18 : 20,
                    color: Colors.grey.shade500,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: isSmallScreen ? 16 : 18,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                  isDense: true,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: isSmallScreen ? 13 : 15,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 15,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

// Helper for add member button
  Widget _buildAddMemberButton(bool isSmallScreen) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: ElevatedButton.icon(
            icon: Icon(
              Icons.person_add,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
            label: Text(
              isSmallScreen ? 'Add' : 'Add Members',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 13 : 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 20,
                vertical: isSmallScreen ? 12 : 14,
              ),
              elevation: 2,
              shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _addMembers,
          ),
        );
      },
    );
  }

  Widget _buildEnhancedGroupInfoCard(
      bool isSmallScreen, BoxConstraints constraints) {
    final cardWidth = constraints.maxWidth;
    final cardHeight = isSmallScreen
        ? null // Auto height for small screens
        : constraints.maxHeight * 0.3; // Percentage of available height
    final fontSize =
        MediaQuery.of(context).size.width < 600 ? 0.8 : 1.0; // Scale factor

    return Card(
      elevation: 6,
      shadowColor: AppTheme.primaryColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.blue.shade50.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 20.0 : 28.0),
          child: LayoutBuilder(builder: (context, cardConstraints) {
            if (isSmallScreen) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildGroupIcon(isSmallScreen),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.group.name,
                              style: TextStyle(
                                fontSize: 22 * fontSize,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 8),
                            _buildCreationDateChip(fontSize),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: AppTheme.primaryColor,
                              size: 18 * fontSize,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 15 * fontSize,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.group.description,
                          style: TextStyle(
                            fontSize: 15 * fontSize,
                            color: AppTheme.textSecondaryColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Add Members',
                          icon: Icons.person_add,
                          color: AppTheme.primaryColor,
                          onPressed: _addMembers,
                          fontSize: fontSize,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Delete',
                          icon: Icons.delete,
                          color: Colors.red.shade600,
                          onPressed: _deleteGroup,
                          fontSize: fontSize,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else {
              // Medium to large screen layout
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGroupIcon(isSmallScreen),
                  SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                widget.group.name,
                                style: TextStyle(
                                  fontSize: 28 * fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildCreationDateChip(fontSize),
                          ],
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      color: AppTheme.primaryColor,
                                      size: 18 * fontSize,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Description',
                                      style: TextStyle(
                                        fontSize: 15 * fontSize,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      widget.group.description,
                                      style: TextStyle(
                                        fontSize: 16 * fontSize,
                                        color: AppTheme.textSecondaryColor,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildActionButton(
                                label: 'Add Members',
                                icon: Icons.person_add,
                                color: AppTheme.primaryColor,
                                onPressed: _addMembers,
                                fontSize: fontSize,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _buildActionButton(
                                label: 'Delete Group',
                                icon: Icons.delete,
                                color: Colors.red.shade600,
                                onPressed: _deleteGroup,
                                fontSize: fontSize,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: SizedBox(), // Spacer for better balance
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          }),
        ),
      ),
    );
  }

  Widget _buildGroupIcon(bool isSmallScreen) {
    final double iconSize = isSmallScreen ? 36 : 42;
    final double padding = isSmallScreen ? 16 : 20;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 2,
        ),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            Colors.white.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.group_rounded,
        size: iconSize,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildCreationDateChip(double fontSizeScale) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            Colors.blue.shade100.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 14 * fontSizeScale,
            color: AppTheme.primaryColor,
          ),
          SizedBox(width: 6),
          Text(
            'Created on ${_formatDate(widget.group.created_at)}',
            style: TextStyle(
              fontSize: 13 * fontSizeScale,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required double fontSize,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 20 * fontSize),
      label: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15 * fontSize,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: 16 * fontSize,
          vertical: 14 * fontSize,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shadowColor: color.withOpacity(0.3),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildEmptyMembersState() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1000),
      curve: Curves.easeOutQuint,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child!,
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 4,
                ),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 40),
            Text(
              'No members in this group yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryColor,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Start adding members to collaborate',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 1200),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon:
                          Icon(Icons.person_add, color: Colors.white, size: 24),
                      label: Text(
                        'Add First Member',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 18,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _addMembers,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTable(Size screenSize) {
    final isSmallScreen = screenSize.width < 768;
    final isMediumScreen = screenSize.width >= 768 && screenSize.width < 1024;
    final fontSize = screenSize.width < 600 ? 0.8 : 1.0; // Scale factor

    if (_filteredMembers.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoSearchResults();
    }

    if (isSmallScreen) {
      // Enhanced list view for small screens
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AnimationLimiter(
            child: ListView.separated(
              padding: EdgeInsets.all(12),
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade200,
              ),
              itemCount: _filteredMembers.length,
              itemBuilder: (context, index) {
                final member = _filteredMembers[index];
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: Duration(milliseconds: 450),
                  child: SlideAnimation(
                    verticalOffset: 40.0,
                    child: FadeInAnimation(
                      child: _buildMemberListItem(member, fontSize),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else {
      // IMPROVED: Enhanced full-width data table for larger screens
      return Column(
        children: [
          // Table header with improved styling
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: 16 * fontSize,
              horizontal: 24 * fontSize,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildExpandedColumnHeader(
                  'Name',
                  Icons.person,
                  isMediumScreen ? 0.35 : 0.3,
                  fontSize,
                ),
                _buildExpandedColumnHeader(
                  'Email',
                  Icons.email,
                  isMediumScreen ? 0.35 : 0.3,
                  fontSize,
                ),
                _buildExpandedColumnHeader(
                  'Added On',
                  Icons.calendar_today,
                  isMediumScreen ? 0.15 : 0.2,
                  fontSize,
                ),
                _buildExpandedColumnHeader(
                  'Actions',
                  Icons.settings,
                  isMediumScreen ? 0.15 : 0.2,
                  fontSize,
                ),
              ],
            ),
          ),

          // Table content with improved styling
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: AnimationLimiter(
                  child: ListView.separated(
                    padding: EdgeInsets.all(0),
                    itemCount: _filteredMembers.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: Duration(milliseconds: 450),
                        child: SlideAnimation(
                          verticalOffset: 40.0,
                          child: FadeInAnimation(
                            child: _buildTableRow(
                              member,
                              index,
                              isMediumScreen,
                              fontSize,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

// New helper method for expanded column headers
  Widget _buildExpandedColumnHeader(
      String text, IconData icon, double flex, double fontSize) {
    return Expanded(
      flex: (flex * 100).toInt(), // Convert to integer for flex factor
      child: Row(
        children: [
          Icon(
            icon,
            size: 18 * fontSize,
            color: AppTheme.primaryColor,
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
              fontSize: 16 * fontSize,
            ),
          ),
        ],
      ),
    );
  }

// New method for table rows with proper width allocation
  Widget _buildTableRow(
      GroupMember member, int index, bool isMediumScreen, double fontSize) {
    final isEvenRow = index % 2 == 0;

    return InkWell(
      onTap: () {}, // Could show detailed info modal in the future
      hoverColor: AppTheme.primaryColor.withOpacity(0.05),
      splashColor: AppTheme.primaryColor.withOpacity(0.1),
      child: Container(
        color: isEvenRow ? Colors.grey.shade50 : Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: 16 * fontSize,
          horizontal: 24 * fontSize,
        ),
        child: Row(
          children: [
            // Name column - 30%
            Expanded(
              flex: isMediumScreen ? 35 : 30,
              child: _buildMemberNameCell(member, fontSize),
            ),

            // Email column - 30%
            Expanded(
              flex: isMediumScreen ? 35 : 30,
              child: _buildMemberEmailCell(member, fontSize),
            ),

            // Date column - 20%
            Expanded(
              flex: isMediumScreen ? 15 : 20,
              child: _buildMemberDateCell(member, fontSize),
            ),

            // Actions column - 20%
            Expanded(
              flex: isMediumScreen ? 15 : 20,
              child: _buildMemberActionsCell(member, fontSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeader(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.primaryColor,
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberListItem(GroupMember member, double fontSize) {
    return InkWell(
      onTap: () {}, // Could show detailed info modal in the future
      splashColor: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 16 * fontSize,
          horizontal: 8 * fontSize,
        ),
        child: Row(
          children: [
            // Avatar with enhanced styling
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Hero(
                tag: 'member-avatar-${member.user_id}',
                child: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  radius: 26 * fontSize,
                  child: Text(
                    (member.user_name?.isNotEmpty ?? false)
                        ? member.user_name![0].toUpperCase()
                        : (member.user_email?.isNotEmpty ?? false)
                            ? member.user_email![0].toUpperCase()
                            : 'U',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18 * fontSize,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16 * fontSize),

            // Details with enhanced styling
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.user_name ?? 'User',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17 * fontSize,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 6 * fontSize),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14 * fontSize,
                        color: Colors.grey.shade500,
                      ),
                      SizedBox(width: 6 * fontSize),
                      Expanded(
                        child: Text(
                          member.user_email ?? 'No email',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14 * fontSize,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6 * fontSize),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * fontSize,
                      vertical: 4 * fontSize,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12 * fontSize),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12 * fontSize,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 4 * fontSize),
                        Text(
                          'Added: ${_formatDate(member.added_at)}',
                          style: TextStyle(
                            fontSize: 12 * fontSize,
                            color: Colors.grey.shade600,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Enhanced remove button
            Material(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12 * fontSize),
              child: InkWell(
                onTap: () => _removeMember(member),
                borderRadius: BorderRadius.circular(12 * fontSize),
                splashColor: Colors.red.withOpacity(0.1),
                highlightColor: Colors.red.withOpacity(0.05),
                child: Padding(
                  padding: EdgeInsets.all(10 * fontSize),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_remove,
                        color: Colors.red.shade600,
                        size: 20 * fontSize,
                      ),
                      SizedBox(width: 6 * fontSize),
                      Text(
                        'Remove',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 14 * fontSize,
                        ),
                      ),
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

  Widget _buildMemberNameCell(GroupMember member, double fontSize) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.15),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Hero(
            tag: 'member-avatar-table-${member.user_id}',
            child: CircleAvatar(
              radius: 20 * fontSize,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                (member.user_name?.isNotEmpty ?? false)
                    ? member.user_name![0].toUpperCase()
                    : (member.user_email?.isNotEmpty ?? false)
                        ? member.user_email![0].toUpperCase()
                        : 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * fontSize,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 14 * fontSize),
        Expanded(
          child: Text(
            member.user_name ?? 'User',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16 * fontSize,
              color: Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberEmailCell(GroupMember member, double fontSize) {
    return Row(
      children: [
        Icon(
          Icons.email_outlined,
          size: 16 * fontSize,
          color: Colors.grey.shade500,
        ),
        SizedBox(width: 8 * fontSize),
        Expanded(
          child: Text(
            member.user_email ?? 'No email',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15 * fontSize,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberDateCell(GroupMember member, double fontSize) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * fontSize,
        vertical: 6 * fontSize,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12 * fontSize),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 14 * fontSize,
            color: Colors.grey.shade600,
          ),
          SizedBox(width: 6 * fontSize),
          Flexible(
            child: Text(
              _formatDate(member.added_at),
              style: TextStyle(
                fontSize: 14 * fontSize,
                fontFamily: 'Roboto Mono',
                color: Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberActionsCell(GroupMember member, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12 * fontSize),
            border: Border.all(
              color: Colors.red.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: TextButton.icon(
            icon: Icon(
              Icons.person_remove,
              color: Colors.red.shade600,
              size: 18 * fontSize,
            ),
            label: Text(
              'Remove',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 15 * fontSize,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12 * fontSize),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 16 * fontSize,
                vertical: 12 * fontSize,
              ),
            ),
            onPressed: () => _removeMember(member),
          ),
        ),
      ],
    );
  }

  Widget _buildNoSearchResults() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.search_off_rounded,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'No members found matching "$_searchQuery"',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Try a different search term or clear the search',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(Icons.clear, size: 20),
                    label: Text(
                      'Clear Search',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      shadowColor: AppTheme.primaryColor.withOpacity(0.3),
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

  Widget _buildLoadingState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Loading Group Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Please wait...",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 16),
                    LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
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

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value * 0.7, // Semi-transparent overlay
            child: BackdropFilter(
              filter: value < 0.1
                  ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                  : ImageFilter.blur(
                      sigmaX: 5 * value,
                      sigmaY: 5 * value,
                    ),
              child: Container(
                color: Colors.black.withOpacity(0.2),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Processing...",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.grey.shade800,
                          ),
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }
}

class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext) small;
  final Widget Function(BuildContext) medium;
  final Widget Function(BuildContext) large;

  const ResponsiveLayoutBuilder({
    required this.small,
    required this.medium,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 768) {
      return small(context);
    } else if (screenWidth >= 768 && screenWidth < 1024) {
      return medium(context);
    } else {
      return large(context);
    }
  }
}
