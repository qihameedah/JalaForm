# Phase 2 Mixins - Migration Guide

## 📋 Overview

This guide shows how to migrate existing screens to use the new Phase 2 mixins and controllers. The mixins provide reusable implementations of common patterns, reducing code duplication and improving maintainability.

## 🎯 When to Use These Mixins

### For New Screens
**Always use these mixins when creating new screens**. They provide battle-tested implementations and consistent behavior across the app.

### For Existing Screens
**Migrate gradually during bug fixes or feature additions**. Don't refactor working code just to use mixins—wait until you need to modify a screen, then apply the appropriate mixins.

## 🔧 Mixin Usage Guide

### 1. ResponsiveValues Mixin

**Use when**: Your screen has responsive breakpoints or needs different values for mobile/tablet/desktop.

**Before**:
```dart
class _MyScreenState extends State<MyScreen> {
  // Repeated in 50+ screens
  bool get isSmallScreen => MediaQuery.of(context).size.width < 600;
  bool get isMediumScreen => MediaQuery.of(context).size.width >= 600 &&
                              MediaQuery.of(context).size.width < 1024;
  bool get isLargeScreen => MediaQuery.of(context).size.width >= 1024;

  double get padding => isSmallScreen ? 10.0 : (isMediumScreen ? 12.0 : 14.0);
  double get fontSize => isSmallScreen ? 14.0 : 16.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Text('Hello', style: TextStyle(fontSize: fontSize)),
    );
  }
}
```

**After**:
```dart
import 'package:jala_form/shared/mixins/responsive_values.dart';

class _MyScreenState extends State<MyScreen> with ResponsiveValues {
  // All responsive properties available automatically!

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(responsivePadding), // Auto-adjusts
      child: Text('Hello', style: TextStyle(fontSize: responsiveFontSize)),
    );
  }
}
```

**Migration Steps**:
1. Add `with ResponsiveValues` to your State class
2. Replace custom breakpoint checks with `isMobile`, `isTablet`, `isDesktop`
3. Replace custom responsive values with mixin properties
4. Remove duplicate code
5. Test on different screen sizes

---

### 2. DataLoadingMixin

**Use when**: Your screen loads data from Supabase or performs async operations with loading states.

**Before**:
```dart
class _MyScreenState extends State<MyScreen> {
  bool _isLoading = false;
  List<CustomForm> _forms = [];

  Future<void> _loadForms() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      _forms = await _supabaseService.getForms();

      if (mounted) {
        setState(() {
          // Update state
        });
      }
    } catch (e) {
      debugPrint('Error loading forms: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load forms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return ListView.builder(...);
  }
}
```

**After**:
```dart
import 'package:jala_form/shared/mixins/data_loading.dart';

class _MyScreenState extends State<MyScreen> with DataLoadingMixin {
  List<CustomForm> _forms = [];

  Future<void> _loadForms() async {
    final forms = await loadDataSafely(
      () => _supabaseService.getForms(),
      errorMessage: 'Failed to load forms',
    );

    setState(() => _forms = forms);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) { // From mixin
      return Center(child: CircularProgressIndicator());
    }

    return ListView.builder(...);
  }
}
```

**Migration Steps**:
1. Add `with DataLoadingMixin` to your State class
2. Replace try-catch-finally blocks with `loadDataSafely()`
3. Replace `_isLoading` with `isLoadingData` (from mixin)
4. Remove duplicate error handling code
5. Test error scenarios

**Advanced Usage - Multiple Operations**:
```dart
// Load multiple data sources in parallel
Future<void> _loadAllData() async {
  final results = await loadMultipleSafely([
    () => _supabaseService.getForms(),
    () => _supabaseService.getGroups(),
    () => _supabaseService.getResponses(),
  ]);

  setState(() {
    _forms = results[0] as List<CustomForm>;
    _groups = results[1] as List<UserGroup>;
    _responses = results[2] as List<FormResponse>;
  });
}
```

---

### 3. BaseFormManagerState Mixin

**Use when**: Your screen manages a list of form fields with add/remove/reorder operations.

**Before** (FormBuilderScreen example):
```dart
class _FormBuilderScreenState extends State<FormBuilderScreen> {
  List<FormFieldModel> _fields = [];
  bool _hasUnsavedChanges = false;

  void _addField(FormFieldModel field) {
    if (mounted) {
      setState(() {
        _fields.add(field);
        _hasUnsavedChanges = true;
      });
    }
  }

  void _removeField(int index) {
    if (index < 0 || index >= _fields.length) return;
    if (mounted) {
      setState(() {
        _fields.removeAt(index);
        _hasUnsavedChanges = true;
      });
    }
  }

  void _updateField(int index, FormFieldModel updatedField) {
    if (index < 0 || index >= _fields.length) return;
    if (mounted) {
      setState(() {
        _fields[index] = updatedField;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _reorderFields(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (mounted) {
      setState(() {
        final field = _fields.removeAt(oldIndex);
        _fields.insert(newIndex, field);
        _hasUnsavedChanges = true;
      });
    }
  }

  void _duplicateField(int index) {
    if (index < 0 || index >= _fields.length) return;

    final fieldToDuplicate = _fields[index];
    final duplicatedField = FormFieldModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: '${fieldToDuplicate.label} (Copy)',
      type: fieldToDuplicate.type,
      isRequired: fieldToDuplicate.isRequired,
      options: fieldToDuplicate.options != null
          ? List.from(fieldToDuplicate.options!)
          : null,
      placeholder: fieldToDuplicate.placeholder,
      validation: fieldToDuplicate.validation,
    );

    if (mounted) {
      setState(() {
        _fields.insert(index + 1, duplicatedField);
        _hasUnsavedChanges = true;
      });
    }
  }

  // ... 10+ more methods for field management
}
```

**After**:
```dart
import 'package:jala_form/shared/mixins/form_manager_state.dart';

class _FormBuilderScreenState extends State<FormBuilderScreen>
    with BaseFormManagerState {

  @override
  void initState() {
    super.initState();
    initializeFields([]); // Start with empty fields
  }

  void _addTextField() {
    addField(FormFieldModel( // From mixin!
      id: DateTime.now().toString(),
      label: 'New Field',
      type: FieldType.text,
    ));
  }

  void _onFieldReorder(int oldIndex, int newIndex) {
    reorderFields(oldIndex, newIndex); // From mixin!
  }

  // All field operations available:
  // - addField()
  // - removeField()
  // - updateField()
  // - duplicateField()
  // - moveFieldUp()
  // - moveFieldDown()
  // - reorderFields()
  // - getRequiredFields()
  // - validateFields()
  // And more!
}
```

**Migration Steps**:
1. Add `with BaseFormManagerState` to your State class
2. Replace `_fields` with `fields` (from mixin)
3. Replace `_hasUnsavedChanges` with `hasUnsavedChanges` (from mixin)
4. Call `initializeFields()` in `initState()`
5. Replace field operation methods with mixin methods
6. Remove duplicate code
7. Test all field operations

**Available Methods**:
- `initializeFields(List<FormFieldModel>)` - Initialize with fields
- `addField(FormFieldModel)` - Add new field
- `removeField(int index)` - Remove field by index
- `updateField(int index, FormFieldModel)` - Update existing field
- `reorderFields(int oldIndex, int newIndex)` - Reorder fields
- `duplicateField(int index)` - Duplicate field at index
- `moveFieldUp(int index)` - Move field up one position
- `moveFieldDown(int index)` - Move field down one position
- `getRequiredFields()` - Get list of required fields
- `getOptionalFields()` - Get list of optional fields
- `getFieldsByType(FieldType)` - Filter fields by type
- `findFieldById(String id)` - Find field by ID
- `validateFields()` - Validate all fields

---

### 4. UnsavedChangesHandler Mixin

**Use when**: Your screen has forms or editable content that users might accidentally navigate away from.

**Before**:
```dart
class _FormEditScreenState extends State<FormEditScreen> {
  bool _hasUnsavedChanges = false;

  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Unsaved Changes'),
          ],
        ),
        content: Text('You have unsaved changes. Do you want to leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _showUnsavedChangesDialog();
        if (mounted && shouldPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(...),
    );
  }
}
```

**After**:
```dart
import 'package:jala_form/shared/mixins/unsaved_changes_handler.dart';

class _FormEditScreenState extends State<FormEditScreen>
    with UnsavedChangesHandler {

  bool _formModified = false;

  @override
  bool get hasUnsavedChanges => _formModified; // Required override

  @override
  Widget build(BuildContext context) {
    return wrapWithUnsavedChangesHandler( // From mixin!
      child: Scaffold(...),
    );
  }
}
```

**Migration Steps**:
1. Add `with UnsavedChangesHandler` to your State class
2. Implement `bool get hasUnsavedChanges` (return your modification state)
3. Replace PopScope logic with `wrapWithUnsavedChangesHandler(child: ...)`
4. Remove duplicate dialog code
5. Test navigation scenarios (back button, system back gesture, etc.)

**Advanced Usage - Save Before Leaving**:
```dart
// Show save/discard/cancel dialog
Future<void> _handleBackButton() async {
  final shouldSave = await promptSaveBeforeLeaving(
    onSave: () => _saveForm(), // Your save logic
  );

  if (shouldSave && mounted) {
    Navigator.of(context).pop();
  }
}
```

---

### 5. Combining Multiple Mixins

You can combine multiple mixins on a single screen:

```dart
import 'package:jala_form/shared/mixins/responsive_values.dart';
import 'package:jala_form/shared/mixins/data_loading.dart';
import 'package:jala_form/shared/mixins/form_manager_state.dart';
import 'package:jala_form/shared/mixins/unsaved_changes_handler.dart';

class _FormBuilderScreenState extends State<FormBuilderScreen>
    with
      ResponsiveValues,           // Responsive breakpoints
      DataLoadingMixin,            // Safe data loading
      BaseFormManagerState,        // Field management
      UnsavedChangesHandler {      // Unsaved changes dialog

  @override
  bool get hasUnsavedChanges => hasUnsavedChanges; // From BaseFormManagerState

  @override
  void initState() {
    super.initState();
    initializeFields([]);
    _loadData();
  }

  Future<void> _loadData() async {
    final forms = await loadDataSafely(
      () => _supabaseService.getForms(),
      errorMessage: 'Failed to load forms',
    );
    // Use forms...
  }

  @override
  Widget build(BuildContext context) {
    return wrapWithUnsavedChangesHandler(
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(responsivePadding), // Responsive!
          child: isLoadingData
              ? Center(child: CircularProgressIndicator())
              : ReorderableListView(
                  children: fields.map((field) => ...).toList(),
                  onReorder: reorderFields, // From BaseFormManagerState!
                ),
        ),
      ),
    );
  }
}
```

---

## 🎯 Migration Priority

### High Priority (Immediate Value)
Screens with lots of duplicate code that would benefit most:

1. **FormBuilderScreen** - Use `BaseFormManagerState` + `UnsavedChangesHandler`
2. **FormEditScreen** - Use `BaseFormManagerState` + `UnsavedChangesHandler`
3. **WebFormBuilder** - Use `ResponsiveValues` + `BaseFormManagerState`
4. **WebFormEditor** - Use `ResponsiveValues` + `BaseFormManagerState`

### Medium Priority
Screens with data loading and responsive logic:

5. **FormListScreen** - Use `DataLoadingMixin` + `ResponsiveValues`
6. **GroupDetailScreen** - Use `DataLoadingMixin`
7. **ResponsesScreen** - Use `DataLoadingMixin` + `ResponsiveValues`

### Low Priority
Simple screens with less duplication:

8. **ProfileScreen** - Use `ResponsiveValues`
9. **LoginScreen** - Use `ResponsiveValues`

---

## 🚀 Controllers Usage Guide

The new controllers are designed for the WebDashboard refactoring, but can be used in other complex screens.

### Using Controllers with Provider

**Example: Using FormsViewController**:

```dart
import 'package:provider/provider.dart';
import 'package:jala_form/features/web/screens/dashboard_screens/controllers/forms_view_controller.dart';

// In your app setup:
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => FormsViewController(_supabaseService),
    ),
  ],
  child: MyApp(),
);

// In your widget:
class MyFormsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FormsViewController>();

    return Column(
      children: [
        TextField(
          onChanged: controller.setSearchQuery,
          decoration: InputDecoration(hintText: 'Search forms...'),
        ),

        if (controller.isLoading)
          CircularProgressIndicator()
        else
          ListView.builder(
            itemCount: controller.filteredForms.length,
            itemBuilder: (context, index) {
              final form = controller.filteredForms[index];
              return ListTile(
                title: Text(form.title),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => controller.deleteForm(form.id),
                ),
              );
            },
          ),
      ],
    );
  }
}
```

### Available Controllers

1. **FormsViewController** - Manages user's forms with search/filter/sort
2. **ResponsesViewController** - Manages form responses with batch loading
3. **GroupsViewController** - Manages user groups
4. **DashboardStatsController** - Aggregates statistics
5. **AvailableFormsViewController** - Manages forms shared with user

---

## 📚 Best Practices

### 1. Don't Over-Refactor
- ✅ Apply mixins when creating new screens
- ✅ Apply mixins when fixing bugs in existing screens
- ❌ Don't refactor working code just to use mixins

### 2. Test Thoroughly
After applying mixins:
- Test all functionality on the screen
- Test on different screen sizes (if using ResponsiveValues)
- Test error scenarios (if using DataLoadingMixin)
- Test navigation with unsaved changes (if using UnsavedChangesHandler)

### 3. Gradual Migration
- Migrate one screen at a time
- Start with simple screens
- Test each migration before moving to the next

### 4. Keep It Simple
If a mixin adds complexity rather than reducing it, don't use it. Mixins are tools, not requirements.

---

## 🐛 Common Pitfalls

### 1. Mixin Conflicts
**Problem**: Multiple mixins define the same method name

**Solution**: Use method prefixes or override explicitly:
```dart
class _MyScreenState extends State<MyScreen>
    with MixinA, MixinB {

  @override
  void dispose() {
    // Call both mixin dispose methods if needed
    super.dispose();
  }
}
```

### 2. Forgetting to Call initializeFields()
**Problem**: `BaseFormManagerState` requires initialization

**Solution**: Always call `initializeFields()` in `initState()`:
```dart
@override
void initState() {
  super.initState();
  initializeFields([]); // or initializeFields(existingFields)
}
```

### 3. Not Implementing hasUnsavedChanges
**Problem**: `UnsavedChangesHandler` requires you to implement the getter

**Solution**: Always implement it:
```dart
class _MyScreenState extends State<MyScreen> with UnsavedChangesHandler {
  bool _modified = false;

  @override
  bool get hasUnsavedChanges => _modified; // Required!
}
```

---

## 📝 Checklist for Migration

For each screen you migrate:

- [ ] Identified which mixins apply to this screen
- [ ] Added mixin imports
- [ ] Added `with MixinName` to State class
- [ ] Replaced duplicate code with mixin methods
- [ ] Removed now-unused code
- [ ] Tested all functionality
- [ ] Tested on different screen sizes (if applicable)
- [ ] Tested error scenarios (if applicable)
- [ ] Tested navigation (if applicable)
- [ ] Updated any tests
- [ ] Committed changes with clear message

---

## 🎓 Learning Resources

### Mixin Documentation
- [ResponsiveValues](../lib/shared/mixins/responsive_values.dart) - Full source code with doc comments
- [DataLoadingMixin](../lib/shared/mixins/data_loading.dart) - Full source code with doc comments
- [BaseFormManagerState](../lib/shared/mixins/form_manager_state.dart) - Full source code with doc comments
- [UnsavedChangesHandler](../lib/shared/mixins/unsaved_changes_handler.dart) - Full source code with doc comments

### Flutter Mixins
- [Flutter Mixins Official Docs](https://dart.dev/guides/language/language-tour#adding-features-to-a-class-mixins)

---

## 📞 Need Help?

If you encounter issues or have questions about using these mixins:
1. Check the mixin source code - it has comprehensive doc comments
2. Review the examples in this guide
3. Check if similar patterns exist elsewhere in the codebase

---

## ✅ Success Metrics

After applying mixins, you should see:
- [ ] Less duplicate code
- [ ] More consistent behavior across screens
- [ ] Easier to add new screens
- [ ] Easier to maintain existing screens
- [ ] Better test coverage (controllers are easier to test)
