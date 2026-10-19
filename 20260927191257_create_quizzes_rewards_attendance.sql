/*
# ElMeilElThani Core Schema - Part 2

Creates the remaining tables for quizzes, rewards, attendance, and hat akhook system.

## Tables

### quizzes
Quiz entries created by servants. Fields for question type (mcq, truefalse, fillblank),
question text, options (JSON array for MCQ), correct answer, duration timer, and expiry.

### quiz_attempts
Tracks 1-attempt-only policy per member per quiz. Stores score and total.

### rewards
Gift catalog items with title, description, price in stars, and stock status.

### reward_redemptions
Tracks member reward redemption requests for servant delivery board.

### attendance
Member attendance records with GPS coordinates and face capture verification.

### absent_peers
Directory of absent peers uploaded by servants for the Hat Akhook revival system.

### hat_akhook_uploads
Joint selfie uploads from members who brought absent peers back. Pending servant approval.

## Security
RLS enabled on all tables with anon, authenticated policies (custom auth).
*/

-- QUIZZES TABLE
CREATE TABLE IF NOT EXISTS quizzes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  quiz_type text NOT NULL DEFAULT 'moquwte',
  question_type text NOT NULL DEFAULT 'mcq',
  question text NOT NULL,
  options text[] DEFAULT '{}',
  correct_answer text NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 10,
  expiry_date timestamptz DEFAULT (now() + interval '7 days'),
  church_class text DEFAULT '',
  created_by text DEFAULT '',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_quizzes" ON quizzes;
CREATE POLICY "anon_select_quizzes" ON quizzes FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_quizzes" ON quizzes;
CREATE POLICY "anon_insert_quizzes" ON quizzes FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_quizzes" ON quizzes;
CREATE POLICY "anon_update_quizzes" ON quizzes FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_quizzes" ON quizzes;
CREATE POLICY "anon_delete_quizzes" ON quizzes FOR DELETE
  TO anon, authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_quizzes_type ON quizzes(quiz_type);
CREATE INDEX IF NOT EXISTS idx_quizzes_expiry ON quizzes(expiry_date);

-- QUIZ ATTEMPTS TABLE
CREATE TABLE IF NOT EXISTS quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id uuid NOT NULL,
  user_id uuid NOT NULL,
  score integer NOT NULL DEFAULT 0,
  total integer NOT NULL DEFAULT 0,
  answers jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_quiz_attempts" ON quiz_attempts;
CREATE POLICY "anon_select_quiz_attempts" ON quiz_attempts FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_quiz_attempts" ON quiz_attempts;
CREATE POLICY "anon_insert_quiz_attempts" ON quiz_attempts FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_quiz_attempts" ON quiz_attempts;
CREATE POLICY "anon_update_quiz_attempts" ON quiz_attempts FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_quiz_attempts" ON quiz_attempts;
CREATE POLICY "anon_delete_quiz_attempts" ON quiz_attempts FOR DELETE
  TO anon, authenticated USING (true);

CREATE UNIQUE INDEX IF NOT EXISTS idx_quiz_attempts_unique ON quiz_attempts(quiz_id, user_id);

-- REWARDS TABLE
CREATE TABLE IF NOT EXISTS rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text DEFAULT '',
  price_stars integer NOT NULL DEFAULT 0,
  in_stock boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_rewards" ON rewards;
CREATE POLICY "anon_select_rewards" ON rewards FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_rewards" ON rewards;
CREATE POLICY "anon_insert_rewards" ON rewards FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_rewards" ON rewards;
CREATE POLICY "anon_update_rewards" ON rewards FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_rewards" ON rewards;
CREATE POLICY "anon_delete_rewards" ON rewards FOR DELETE
  TO anon, authenticated USING (true);

-- REWARD REDEMPTIONS TABLE
CREATE TABLE IF NOT EXISTS reward_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  user_name text DEFAULT '',
  reward_id uuid NOT NULL,
  reward_title text NOT NULL,
  price_stars integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_redemptions" ON reward_redemptions;
CREATE POLICY "anon_select_redemptions" ON reward_redemptions FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_redemptions" ON reward_redemptions;
CREATE POLICY "anon_insert_redemptions" ON reward_redemptions FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_redemptions" ON reward_redemptions;
CREATE POLICY "anon_update_redemptions" ON reward_redemptions FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_redemptions" ON reward_redemptions;
CREATE POLICY "anon_delete_redemptions" ON reward_redemptions FOR DELETE
  TO anon, authenticated USING (true);

-- ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  user_name text DEFAULT '',
  church_class text DEFAULT '',
  status text NOT NULL DEFAULT 'present',
  gps_lat double precision,
  gps_lng double precision,
  face_image text DEFAULT '',
  attendance_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_attendance" ON attendance;
CREATE POLICY "anon_select_attendance" ON attendance FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_attendance" ON attendance;
CREATE POLICY "anon_insert_attendance" ON attendance FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_attendance" ON attendance;
CREATE POLICY "anon_update_attendance" ON attendance FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_attendance" ON attendance;
CREATE POLICY "anon_delete_attendance" ON attendance FOR DELETE
  TO anon, authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_attendance_user_date ON attendance(user_id, attendance_date);

-- ABSENT PEERS TABLE
CREATE TABLE IF NOT EXISTS absent_peers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  contact_info text DEFAULT '',
  photo_url text DEFAULT '',
  church_class text DEFAULT '',
  status text NOT NULL DEFAULT 'absent',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE absent_peers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_absent_peers" ON absent_peers;
CREATE POLICY "anon_select_absent_peers" ON absent_peers FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_absent_peers" ON absent_peers;
CREATE POLICY "anon_insert_absent_peers" ON absent_peers FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_absent_peers" ON absent_peers;
CREATE POLICY "anon_update_absent_peers" ON absent_peers FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_absent_peers" ON absent_peers;
CREATE POLICY "anon_delete_absent_peers" ON absent_peers FOR DELETE
  TO anon, authenticated USING (true);

-- HAT AKHOOK UPLOADS TABLE
CREATE TABLE IF NOT EXISTS hat_akhook_uploads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL,
  member_name text DEFAULT '',
  peer_id uuid NOT NULL,
  peer_name text NOT NULL,
  photo_data text DEFAULT '',
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE hat_akhook_uploads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_hat_akhook" ON hat_akhook_uploads;
CREATE POLICY "anon_select_hat_akhook" ON hat_akhook_uploads FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "anon_insert_hat_akhook" ON hat_akhook_uploads;
CREATE POLICY "anon_insert_hat_akhook" ON hat_akhook_uploads FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_hat_akhook" ON hat_akhook_uploads;
CREATE POLICY "anon_update_hat_akhook" ON hat_akhook_uploads FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_hat_akhook" ON hat_akhook_uploads;
CREATE POLICY "anon_delete_hat_akhook" ON hat_akhook_uploads FOR DELETE
  TO anon, authenticated USING (true);

-- Seed some sample rewards
INSERT INTO rewards (title, description, price_stars, in_stock)
SELECT 'Bible Cover', 'Beautiful leather-bound Bible cover with gold embossing', 50, true
WHERE NOT EXISTS (SELECT 1 FROM rewards);

INSERT INTO rewards (title, description, price_stars, in_stock)
SELECT 'Youth Retreat Ticket', 'Full weekend youth retreat admission and meals', 100, true
WHERE NOT EXISTS (SELECT 1 FROM rewards WHERE title = 'Youth Retreat Ticket');

INSERT INTO rewards (title, description, price_stars, in_stock)
SELECT 'Gold Cross Necklace', 'Elegant gold-plated cross necklace', 200, true
WHERE NOT EXISTS (SELECT 1 FROM rewards WHERE title = 'Gold Cross Necklace');