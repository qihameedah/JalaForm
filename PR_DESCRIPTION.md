# Fix type conversion and null-safety analyzer warnings

## Summary

This PR fixes critical type conversion errors and removes dead null-aware expressions that were causing analyzer warnings in the refactored web dashboard code.

## Changes

### Type Conversion Fixes (web_dashboard.dart:667-673)
- Fixed dynamic map access for Likert field options
- Wrapped `option['label']` and `option['value']` in `toString()` to prevent String-to-int assignment errors
- Ensures proper type handling when constructing `LikertOption` objects from dynamic data

**Before:**
```dart
label: option['label'] ?? option.toString(),
value: option['value'] ?? option.toString(),
```

**After:**
```dart
label: (option['label'] ?? option).toString(),
value: (option['value'] ?? option).toString(),
```

### Dead Null-Aware Expression Fixes

#### pdf_service.dart
- **Line 407**: Removed unnecessary `?? 'نموذج بلا عنوان'` from `form.title`
- **Line 440**: Removed unnecessary `?? DateTime.now()` from `response.submitted_at`
- **Lines 451-453**: Removed unnecessary `?? 'N/A'` from `response.id`

#### web_pdf_service.dart
- **Line 342**: Removed unnecessary `?? 'Form'` from `form.title`
- **Line 342**: Removed unnecessary `?? 'unknown'` from `response.id`

All removed null-aware operators were flagged by the analyzer because the left operands are non-nullable fields, making the right operands unreachable.

## Files Changed
- `lib/features/web/screens/dashboard_screens/web_dashboard.dart` (2 lines)
- `lib/core/services/pdf_service.dart` (5 lines)
- `lib/core/services/web_pdf_service.dart` (1 line)

**Total**: 3 files changed, 7 insertions(+), 8 deletions(-)

## Impact
- ✅ Resolves all compilation errors related to type conversion
- ✅ Eliminates dead null-aware expression warnings in refactored code
- ✅ Improves code correctness and null-safety compliance
- ✅ No functional changes - behavior remains identical

## Testing
- All type conversions now handle dynamic data correctly
- PDF generation continues to work with proper non-nullable field usage
- No breaking changes to existing functionality

## Commit
- Commit: `bf342f7`
- Branch: `claude/refactor-web-dashboard-011CUmbRYutV8u83khXP5CLG`
- Base: `main`

## How to Create PR

Since the GitHub CLI is not available, please create the PR manually:

1. Go to: https://github.com/ma7moudfiras/JalaForm/compare/main...claude/refactor-web-dashboard-011CUmbRYutV8u83khXP5CLG
2. Click "Create pull request"
3. Copy the content above into the PR description
4. Submit the PR

Or use this direct link:
```
https://github.com/ma7moudfiras/JalaForm/compare/main...claude/refactor-web-dashboard-011CUmbRYutV8u83khXP5CLG?quick_pull=1
```
