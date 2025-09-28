-- Enable Row Level Security (RLS) on all user tables
ALTER TABLE heroes ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_scenes ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_illustrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE generation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE image_generation_chains ENABLE ROW LEVEL SECURITY;

-- Heroes policies - users can only access their own heroes
CREATE POLICY "Users can view their own heroes"
    ON heroes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own heroes"
    ON heroes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own heroes"
    ON heroes FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own heroes"
    ON heroes FOR DELETE
    USING (auth.uid() = user_id);

-- Custom events policies
CREATE POLICY "Users can view their own custom events"
    ON custom_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own custom events"
    ON custom_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own custom events"
    ON custom_events FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own custom events"
    ON custom_events FOR DELETE
    USING (auth.uid() = user_id);

-- Stories policies
CREATE POLICY "Users can view their own stories"
    ON stories FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own stories"
    ON stories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own stories"
    ON stories FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own stories"
    ON stories FOR DELETE
    USING (auth.uid() = user_id);

-- Story scenes policies - access through story ownership
CREATE POLICY "Users can view scenes of their own stories"
    ON story_scenes FOR SELECT
    USING (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_scenes.story_id
    ));

CREATE POLICY "Users can insert scenes for their own stories"
    ON story_scenes FOR INSERT
    WITH CHECK (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_scenes.story_id
    ));

CREATE POLICY "Users can update scenes of their own stories"
    ON story_scenes FOR UPDATE
    USING (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_scenes.story_id
    ))
    WITH CHECK (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_scenes.story_id
    ));

CREATE POLICY "Users can delete scenes of their own stories"
    ON story_scenes FOR DELETE
    USING (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_scenes.story_id
    ));

-- Story illustrations policies - access through story ownership
CREATE POLICY "Users can view illustrations of their own stories"
    ON story_illustrations FOR SELECT
    USING (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_illustrations.story_id
    ));

CREATE POLICY "Users can insert illustrations for their own stories"
    ON story_illustrations FOR INSERT
    WITH CHECK (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_illustrations.story_id
    ));

CREATE POLICY "Users can update illustrations of their own stories"
    ON story_illustrations FOR UPDATE
    USING (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_illustrations.story_id
    ))
    WITH CHECK (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_illustrations.story_id
    ));

CREATE POLICY "Users can delete illustrations of their own stories"
    ON story_illustrations FOR DELETE
    USING (auth.uid() IN (
        SELECT user_id FROM stories WHERE stories.id = story_illustrations.story_id
    ));

-- API usage policies - users can only view their own usage
CREATE POLICY "Users can view their own API usage"
    ON api_usage FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert API usage records"
    ON api_usage FOR INSERT
    WITH CHECK (true); -- Allow system to insert usage records

-- Rate limits policies - users can view their own rate limits
CREATE POLICY "Users can view their own rate limits"
    ON rate_limits FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can manage rate limits"
    ON rate_limits FOR ALL
    USING (true); -- Allow system to manage rate limits

-- Generation queue policies
CREATE POLICY "Users can view their own generation jobs"
    ON generation_queue FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own generation jobs"
    ON generation_queue FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "System can manage generation queue"
    ON generation_queue FOR UPDATE
    USING (true); -- Allow system to update job status

CREATE POLICY "Users can delete their own generation jobs"
    ON generation_queue FOR DELETE
    USING (auth.uid() = user_id);

-- Image generation chains policies - access through hero ownership
CREATE POLICY "Users can view chains for their own heroes"
    ON image_generation_chains FOR SELECT
    USING (auth.uid() IN (
        SELECT user_id FROM heroes WHERE heroes.id = image_generation_chains.hero_id
    ));

CREATE POLICY "Users can insert chains for their own heroes"
    ON image_generation_chains FOR INSERT
    WITH CHECK (auth.uid() IN (
        SELECT user_id FROM heroes WHERE heroes.id = image_generation_chains.hero_id
    ));

CREATE POLICY "System can manage generation chains"
    ON image_generation_chains FOR UPDATE
    USING (true); -- Allow system to update chains

-- Storage bucket policies for file access
CREATE POLICY "Users can view their own story assets"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'story-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can upload their own story assets"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'story-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own story assets"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'story-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own story assets"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'story-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Hero avatars bucket policies
CREATE POLICY "Users can view their own hero avatars"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'hero-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can upload their own hero avatars"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'hero-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own hero avatars"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'hero-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own hero avatars"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'hero-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Story audio bucket policies
CREATE POLICY "Users can view their own story audio"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'story-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can upload their own story audio"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'story-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own story audio"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'story-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own story audio"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'story-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Story illustrations bucket policies
CREATE POLICY "Users can view their own story illustrations"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'story-illustrations' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can upload their own story illustrations"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'story-illustrations' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own story illustrations"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'story-illustrations' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own story illustrations"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'story-illustrations' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Anonymous cache access is allowed for performance (api_cache table doesn't need RLS)
-- This allows caching to work efficiently without user context