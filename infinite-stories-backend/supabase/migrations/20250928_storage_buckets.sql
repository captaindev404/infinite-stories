-- Storage Buckets Setup Migration
-- This migration ensures all required storage buckets exist for the Edge Functions

-- =============================================================================
-- 1. CREATE STORAGE BUCKETS
-- =============================================================================

-- Create story-audio bucket for audio files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'story-audio',
  'story-audio',
  true,
  52428800, -- 50MB limit
  ARRAY['audio/mpeg', 'audio/mp3', 'audio/mp4', 'audio/m4a']
) ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800,
  allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp3', 'audio/mp4', 'audio/m4a'];

-- Create hero-avatars bucket for avatar images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'hero-avatars',
  'hero-avatars',
  true,
  10485760, -- 10MB limit
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
) ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];

-- Create story-illustrations bucket for scene illustrations
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'story-illustrations',
  'story-illustrations',
  true,
  10485760, -- 10MB limit
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
) ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];

-- Create story-assets bucket for general story assets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'story-assets',
  'story-assets',
  true,
  52428800, -- 50MB limit
  NULL -- Allow all mime types
) ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800;

-- =============================================================================
-- 2. SET UP STORAGE POLICIES
-- =============================================================================

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can upload their own audio files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own audio files" ON storage.objects;
DROP POLICY IF EXISTS "Public can view audio files" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own avatars" ON storage.objects;
DROP POLICY IF EXISTS "Public can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own illustrations" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own illustrations" ON storage.objects;
DROP POLICY IF EXISTS "Public can view illustrations" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own assets" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own assets" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own assets" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own assets" ON storage.objects;

-- Policy for story-audio bucket: Users can upload/read their own audio files
CREATE POLICY "Users can upload their own audio files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'story-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own audio files"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'story-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Public can view audio files"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'story-audio');

-- Policy for hero-avatars bucket: Users can upload/read their own avatars
CREATE POLICY "Users can upload their own avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'hero-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own avatars"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'hero-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Public can view avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'hero-avatars');

-- Policy for story-illustrations bucket: Users can upload/read their own illustrations
CREATE POLICY "Users can upload their own illustrations"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'story-illustrations' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own illustrations"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'story-illustrations' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Public can view illustrations"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'story-illustrations');

-- Policy for story-assets bucket: Users can manage their own assets
CREATE POLICY "Users can upload their own assets"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'story-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own assets"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'story-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own assets"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'story-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own assets"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'story-assets' AND auth.uid()::text = (storage.foldername(name))[1]);