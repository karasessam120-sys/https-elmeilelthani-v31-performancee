/*
# ElMeilElThani Core Schema - Part 1

Creates the foundational tables for the ElMeilElThani church youth app:
- users: All registered users (members, servants, super admin) with role-based fields
- church_config: Global church settings (GPS coordinates, attendance windows)
- verse_of_day: Daily verse updated by servants
- feedback: Member feedback/suggestions to servants/admin
- password_resets: Password reset requests forwarded to admin
- ai_chats: Rafik ElNoor AI assistant chat history per member

## Tables

### users
Stores all user accounts. Custom auth (username + password) since the app requires
password retrieval for the "Forgot Password" feature. Roles: member, servant, admin.
Status: active or pending (for servant approval).

### church_config
Single-row table for global settings: GPS lat/lng, attendance day/time window.

### verse_of_day
Single active verse, updated by servants.

### feedback
Messages from members to servants/admin.

### password_resets
Reset requests forwarded to admin for approval.

### ai_chats
Chat messages between members and the Rafik ElNoor AI assistant.

## Security
RLS enabled on all tables. Policies use TO anon, authenticated since the app
uses custom auth (not Supabase auth) — role enforcement happens in the frontend.
*/

-- USERS TABLE
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text UNIQUE NOT NULL,
  password text NOT NULL,
  full_name text NOT NULL,
  role text NOT NULL DEFAULT 'member',
  status text NOT NULL DEFAULT 'active',
  education_stage text DEFAULT '',
  church_class text DEFAULT '',
  parent_phone text DEFAULT '',
  home_address text DEFAULT '',
  date_of_birth date,
  stars integer NOT NULL DEFAULT 0,
  avatar_url text DEFAULT '',
  attendance_present integer NOT NULL DEFAULT 0,
  attendance_total integer NOT NULL DEFAULT 0,
  brought_back_count integer NOT NULL DEFAULT 0,
  last_quiz_score integer NOT NULL DEFAULT 0,
  last_quiz_total integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_users" ON users;
CREATE POLICY "anon_select_users" ON users FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_users" ON users;
CREATE POLICY "anon_insert_users" ON users FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_users" ON users;
CREATE POLICY "anon_update_users" ON users FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_users" ON users;
CREATE POLICY "anon_delete_users" ON users FOR DELETE
  TO anon, authenticated USING (true);

-- CHURCH CONFIG TABLE
CREATE TABLE IF NOT EXISTS church_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gps_lat double precision NOT NULL DEFAULT 30.0444,
  gps_lng double precision NOT NULL DEFAULT 31.2357,
  gps_radius_meters integer NOT NULL DEFAULT 200,
  attendance_day text NOT NULL DEFAULT 'Sunday',
  attendance_start_time text NOT NULL DEFAULT '08:00',
  attendance_end_time text NOT NULL DEFAULT '12:00',
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE church_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_church_config" ON church_config;
CREATE POLICY "anon_select_church_config" ON church_config FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_update_church_config" ON church_config;
CREATE POLICY "anon_update_church_config" ON church_config FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_insert_church_config" ON church_config;
CREATE POLICY "anon_insert_church_config" ON church_config FOR INSERT
  TO anon, authenticated WITH CHECK (true);

-- Seed default config
INSERT INTO church_config (gps_lat, gps_lng, gps_radius_meters, attendance_day, attendance_start_time, attendance_end_time)
SELECT 30.0444, 31.2357, 200, 'Sunday', '08:00', '12:00'
WHERE NOT EXISTS (SELECT 1 FROM church_config);

-- VERSE OF THE DAY TABLE
CREATE TABLE IF NOT EXISTS verse_of_day (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verse_text text NOT NULL,
  verse_reference text NOT NULL,
  updated_by text DEFAULT '',
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE verse_of_day ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_verse" ON verse_of_day;
CREATE POLICY "anon_select_verse" ON verse_of_day FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_verse" ON verse_of_day;
CREATE POLICY "anon_insert_verse" ON verse_of_day FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_verse" ON verse_of_day;
CREATE POLICY "anon_update_verse" ON verse_of_day FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_verse" ON verse_of_day;
CREATE POLICY "anon_delete_verse" ON verse_of_day FOR DELETE
  TO anon, authenticated USING (true);

-- Seed default verse
INSERT INTO verse_of_day (verse_text, verse_reference, updated_by)
SELECT 'I can do all things through Christ who strengthens me.', 'Philippians 4:13', 'System'
WHERE NOT EXISTS (SELECT 1 FROM verse_of_day);

-- FEEDBACK TABLE
CREATE TABLE IF NOT EXISTS feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  user_name text DEFAULT '',
  user_role text DEFAULT 'member',
  church_class text DEFAULT '',
  message text NOT NULL,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_feedback" ON feedback;
CREATE POLICY "anon_select_feedback" ON feedback FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_feedback" ON feedback;
CREATE POLICY "anon_insert_feedback" ON feedback FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_feedback" ON feedback;
CREATE POLICY "anon_update_feedback" ON feedback FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_feedback" ON feedback;
CREATE POLICY "anon_delete_feedback" ON feedback FOR DELETE
  TO anon, authenticated USING (true);

-- PASSWORD RESETS TABLE
CREATE TABLE IF NOT EXISTS password_resets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  resolved_password text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz
);

ALTER TABLE password_resets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_password_resets" ON password_resets;
CREATE POLICY "anon_select_password_resets" ON password_resets FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_password_resets" ON password_resets;
CREATE POLICY "anon_insert_password_resets" ON password_resets FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_password_resets" ON password_resets;
CREATE POLICY "anon_update_password_resets" ON password_resets FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_password_resets" ON password_resets;
CREATE POLICY "anon_delete_password_resets" ON password_resets FOR DELETE
  TO anon, authenticated USING (true);

-- AI CHATS TABLE
CREATE TABLE IF NOT EXISTS ai_chats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  user_message text NOT NULL,
  ai_response text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE ai_chats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_ai_chats" ON ai_chats;
CREATE POLICY "anon_select_ai_chats" ON ai_chats FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_ai_chats" ON ai_chats;
CREATE POLICY "anon_insert_ai_chats" ON ai_chats FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_ai_chats" ON ai_chats;
CREATE POLICY "anon_delete_ai_chats" ON ai_chats FOR DELETE
  TO anon, authenticated USING (true);

-- SEED SUPER ADMIN
INSERT INTO users (username, password, full_name, role, status, education_stage, church_class)
SELECT 'كاراس عصام', 'karas', 'Super Admin', 'admin', 'active', '', 'All'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE role = 'admin');

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_feedback_created ON feedback(created_at DESC);