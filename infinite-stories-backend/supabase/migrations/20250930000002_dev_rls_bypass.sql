-- Allow anon role to access heroes table for local development
-- This enables the iOS app to sync heroes without full authentication

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own heroes" ON heroes;
DROP POLICY IF EXISTS "Users can insert their own heroes" ON heroes;
DROP POLICY IF EXISTS "Users can update their own heroes" ON heroes;
DROP POLICY IF EXISTS "Users can delete their own heroes" ON heroes;

-- Recreate policies with anon access for development user
-- For SELECT: Allow authenticated users to see their own, and allow anon to see dev user
CREATE POLICY "Users can view their own heroes"
    ON heroes FOR SELECT
    USING (
        (auth.uid() = user_id)  -- Authenticated users see their own
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)  -- Anon can see dev user
    );

-- For INSERT: Allow authenticated users their own, and allow anon for dev user
CREATE POLICY "Users can insert their own heroes"
    ON heroes FOR INSERT
    WITH CHECK (
        (auth.uid() = user_id)  -- Authenticated users insert their own
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)  -- Anon can insert as dev user
    );

-- For UPDATE: Allow authenticated users their own, and allow anon for dev user
CREATE POLICY "Users can update their own heroes"
    ON heroes FOR UPDATE
    USING (
        (auth.uid() = user_id)  -- Authenticated users update their own
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)  -- Anon can update dev user
    )
    WITH CHECK (
        (auth.uid() = user_id)
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)
    );

-- For DELETE: Allow authenticated users their own, and allow anon for dev user
CREATE POLICY "Users can delete their own heroes"
    ON heroes FOR DELETE
    USING (
        (auth.uid() = user_id)  -- Authenticated users delete their own
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)  -- Anon can delete dev user
    );

-- Same for stories table
DROP POLICY IF EXISTS "Users can view their own stories" ON stories;
DROP POLICY IF EXISTS "Users can insert their own stories" ON stories;
DROP POLICY IF EXISTS "Users can update their own stories" ON stories;
DROP POLICY IF EXISTS "Users can delete their own stories" ON stories;

CREATE POLICY "Users can view their own stories"
    ON stories FOR SELECT
    USING (
        (auth.uid() = user_id)
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)
    );

CREATE POLICY "Users can insert their own stories"
    ON stories FOR INSERT
    WITH CHECK (
        (auth.uid() = user_id)
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)
    );

CREATE POLICY "Users can update their own stories"
    ON stories FOR UPDATE
    USING (
        (auth.uid() = user_id)
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)
    )
    WITH CHECK (
        (auth.uid() = user_id)
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)
    );

CREATE POLICY "Users can delete their own stories"
    ON stories FOR DELETE
    USING (
        (auth.uid() = user_id)
        OR (auth.role() = 'anon' AND user_id = '00000000-0000-0000-0000-000000000001'::uuid)
    );