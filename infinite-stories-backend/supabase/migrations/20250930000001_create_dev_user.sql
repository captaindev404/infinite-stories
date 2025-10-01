-- Create development user in auth.users table
-- This allows the iOS app to sync data without full authentication

-- Insert dev user into auth.users
INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    role,
    aud
) VALUES (
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-000000000000'::uuid,
    'dev@infinitestories.local',
    crypt('devpassword', gen_salt('bf')),  -- Hashed password
    NOW(),
    NOW(),
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Development User"}'::jsonb,
    false,
    'authenticated',
    'authenticated'
) ON CONFLICT (id) DO NOTHING;

-- Also add to public.profiles if that table exists
-- (Some Supabase setups use a profiles table)
-- This is optional and will be ignored if the table doesn't exist
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        INSERT INTO public.profiles (id, created_at, updated_at)
        VALUES (
            '00000000-0000-0000-0000-000000000001'::uuid,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;