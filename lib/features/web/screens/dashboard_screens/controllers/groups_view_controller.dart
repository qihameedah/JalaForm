// lib/features/web/screens/dashboard_screens/controllers/groups_view_controller.dart

import 'package:flutter/material.dart';
import 'package:jala_form/features/groups/models/user_group.dart';
import 'package:jala_form/services/supabase_service.dart';

/// Controller for managing "Groups" view in the dashboard
///
/// Extracted from WebDashboard to follow Single Responsibility Principle
class GroupsViewController extends ChangeNotifier {
  final SupabaseService _supabaseService;

  GroupsViewController(this._supabaseService);

  // State
  List<UserGroup> _myGroups = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _sortBy = 'recent';

  // Getters
  List<UserGroup> get myGroups => _myGroups;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;

  // Filtered and sorted groups
  List<UserGroup> get filteredGroups {
    var groups = List<UserGroup>.from(_myGroups);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      groups = groups.where((group) {
        return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (group.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'recent':
        groups.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        break;
      case 'oldest':
        groups.sort((a, b) => (a.createdAt ?? DateTime(1970))
            .compareTo(b.createdAt ?? DateTime(1970)));
        break;
      case 'name_asc':
        groups.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        groups.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'members':
        // Sort by member count (if available)
        groups.sort((a, b) => (b.memberCount ?? 0).compareTo(a.memberCount ?? 0));
        break;
    }

    return groups;
  }

  // Actions
  Future<void> loadMyGroups() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _myGroups = await _supabaseService.getMyCreatedGroups();
    } catch (e) {
      _errorMessage = 'Failed to load groups: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await _supabaseService.deleteGroup(groupId);
      _myGroups.removeWhere((group) => group.id == groupId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete group: $e';
      debugPrint(_errorMessage);
      rethrow;
    }
  }

  Future<void> refresh() async {
    await loadMyGroups();
  }

  // Get group by ID
  UserGroup? getGroupById(String groupId) {
    try {
      return _myGroups.firstWhere((group) => group.id == groupId);
    } catch (e) {
      return null;
    }
  }

  // Statistics
  int get totalGroups => _myGroups.length;

  int get totalMembers {
    return _myGroups.fold(0, (sum, group) => sum + (group.memberCount ?? 0));
  }

  double get averageMembersPerGroup {
    if (_myGroups.isEmpty) return 0;
    return totalMembers / _myGroups.length;
  }
}
