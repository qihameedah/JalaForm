-- Row Level Security (RLS) Setup for JalaForm
-- Execute these commands in your Supabase SQL Editor

-- =====================================================
-- FORMS TABLE SECURITY
-- =====================================================

-- Enable RLS on forms table
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own forms
CREATE POLICY "Users can view their own forms"
  ON forms FOR SELECT
  USING (created_by = auth.uid());

-- Policy: Users can create their own forms
CREATE POLICY "Users can create forms"
  ON forms FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- Policy: Users can update their own forms
CREATE POLICY "Users can update their own forms"
  ON forms FOR UPDATE
  USING (created_by = auth.uid());

-- Policy: Users can delete their own forms
CREATE POLICY "Users can delete their own forms"
  ON forms FOR DELETE
  USING (created_by = auth.uid());

-- =====================================================
-- FORM_RESPONSES TABLE SECURITY
-- =====================================================

-- Enable RLS on form_responses table
ALTER TABLE form_responses ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view responses for forms they own
CREATE POLICY "Users can view responses for their forms"
  ON form_responses FOR SELECT
  USING (
    form_id IN (
      SELECT id FROM forms WHERE created_by = auth.uid()
    )
  );

-- Policy: Anyone can submit form responses (public forms)
CREATE POLICY "Anyone can submit form responses"
  ON form_responses FOR INSERT
  WITH CHECK (true);

-- Policy: Form owners can delete responses
CREATE POLICY "Form owners can delete responses"
  ON form_responses FOR DELETE
  USING (
    form_id IN (
      SELECT id FROM forms WHERE created_by = auth.uid()
    )
  );

-- =====================================================
-- USER_GROUPS TABLE SECURITY
-- =====================================================

-- Enable RLS on user_groups table
ALTER TABLE user_groups ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own groups
CREATE POLICY "Users can view their own groups"
  ON user_groups FOR SELECT
  USING (created_by = auth.uid());

-- Policy: Users can create groups
CREATE POLICY "Users can create groups"
  ON user_groups FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- Policy: Users can update their own groups
CREATE POLICY "Users can update their own groups"
  ON user_groups FOR UPDATE
  USING (created_by = auth.uid());

-- Policy: Users can delete their own groups
CREATE POLICY "Users can delete their own groups"
  ON user_groups FOR DELETE
  USING (created_by = auth.uid());

-- =====================================================
-- GROUP_MEMBERS TABLE SECURITY
-- =====================================================

-- Enable RLS on group_members table
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- Policy: Group owners can view members
CREATE POLICY "Group owners can view members"
  ON group_members FOR SELECT
  USING (
    group_id IN (
      SELECT id FROM user_groups WHERE created_by = auth.uid()
    )
  );

-- Policy: Group members can view other members
CREATE POLICY "Group members can view other members"
  ON group_members FOR SELECT
  USING (user_id = auth.uid());

-- Policy: Group owners can add members
CREATE POLICY "Group owners can add members"
  ON group_members FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT id FROM user_groups WHERE created_by = auth.uid()
    )
  );

-- Policy: Group owners can remove members
CREATE POLICY "Group owners can remove members"
  ON group_members FOR DELETE
  USING (
    group_id IN (
      SELECT id FROM user_groups WHERE created_by = auth.uid()
    )
  );

-- =====================================================
-- FORM_PERMISSIONS TABLE SECURITY
-- =====================================================

-- Enable RLS on form_permissions table
ALTER TABLE form_permissions ENABLE ROW LEVEL SECURITY;

-- Policy: Form owners can view permissions
CREATE POLICY "Form owners can view permissions"
  ON form_permissions FOR SELECT
  USING (
    form_id IN (
      SELECT id FROM forms WHERE created_by = auth.uid()
    )
  );

-- Policy: Form owners can grant permissions
CREATE POLICY "Form owners can grant permissions"
  ON form_permissions FOR INSERT
  WITH CHECK (
    form_id IN (
      SELECT id FROM forms WHERE created_by = auth.uid()
    )
  );

-- Policy: Form owners can update permissions
CREATE POLICY "Form owners can update permissions"
  ON form_permissions FOR UPDATE
  USING (
    form_id IN (
      SELECT id FROM forms WHERE created_by = auth.uid()
    )
  );

-- Policy: Form owners can revoke permissions
CREATE POLICY "Form owners can revoke permissions"
  ON form_permissions FOR DELETE
  USING (
    form_id IN (
      SELECT id FROM forms WHERE created_by = auth.uid()
    )
  );

-- =====================================================
-- USER_PROFILES TABLE SECURITY
-- =====================================================

-- Enable RLS on user_profiles table
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own profile
CREATE POLICY "Users can view their own profile"
  ON user_profiles FOR SELECT
  USING (id = auth.uid());

-- Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  USING (id = auth.uid());

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Run these queries to verify RLS is enabled:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
-- SELECT * FROM pg_policies WHERE schemaname = 'public';
