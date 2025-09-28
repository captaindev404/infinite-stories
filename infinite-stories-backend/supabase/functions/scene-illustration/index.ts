/**
 * Scene Illustration Edge Function
 *
 * This function handles batch generation of scene illustrations for stories,
 * maintaining visual consistency through generation ID chaining. Features:
 * - Batch processing with rate limiting
 * - Visual consistency through generation ID chaining
 * - Async processing with real-time status updates
 * - Retry logic for failed generations
 * - Hero character consistency across scenes
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  withEdgeFunctionWrapper,
  parseAndValidateJSON,
  SceneIllustrationSchema,
  openai,
  MODELS,
  logger,
  LogCategory,
  cache,
  CacheKeyGenerator,
  CACHE_CONFIG,
  contentFilter,
  createSupabaseServiceClient,
  checkBatchRateLimit
} from '../_shared/index.ts';

/**
 * Scene illustration request interface
 */
interface SceneIllustrationRequest {
  story_id: string;
  scenes: Array<{
    scene_number: number;
    text_segment: string;
    illustration_prompt: string;
    timestamp_seconds: number;
    emotion?: string;
    importance?: string;
  }>;
  hero_id: string;
  process_async?: boolean; // If true, process in background
}

/**
 * Scene illustration response interface
 */
interface SceneIllustrationResponse {
  job_id?: string; // For async processing
  illustrations?: Array<{
    scene_number: number;
    image_url: string;
    generation_id: string;
    status: 'completed' | 'failed';
    error_message?: string;
  }>;
  status: 'processing' | 'completed' | 'partial';
  total_scenes: number;
  completed_scenes: number;
  estimated_completion?: string;
}

/**
 * Build scene illustration prompt with hero consistency
 */
function buildScenePrompt(
  scene: any,
  hero: any,
  storyContext: string
): string {
  const baseStyle = `Create a beautiful children's book scene illustration in a warm, whimsical style.
Use soft watercolor or digital painting techniques with gentle lighting and magical atmosphere.
The art style should match modern children's picture books.
Ensure the image is appropriate for children aged 4-10.
Focus on creating wonder, joy, and visual storytelling.`;

  const heroConsistency = `
HERO CHARACTER (MUST APPEAR CONSISTENTLY):
Name: ${hero.name}
Appearance: ${hero.appearance || 'friendly and lovable'}
Traits: ${hero.primary_trait}, ${hero.secondary_trait}
Special ability: ${hero.special_ability || 'kindness and courage'}

CRITICAL: The character ${hero.name} MUST look IDENTICAL to their established appearance.
Same hair color, clothing style, features, and overall design as in previous illustrations.`;

  const sceneDetails = `
SCENE CONTEXT:
Story: ${storyContext}
Scene text: "${scene.text_segment}"
Emotion: ${scene.emotion || 'peaceful'}
Importance: ${scene.importance || 'major'}
Timestamp: ${Math.round(scene.timestamp_seconds)}s into story`;

  const safetyRequirements = `
MANDATORY SAFETY REQUIREMENTS:
- ${hero.name} MUST be shown with friends, companions, or helpful creatures
- NO isolation, loneliness, or characters appearing alone
- Bright, colorful, cheerful atmosphere with warm lighting
- All characters show positive emotions (happy, curious, excited, peaceful)
- Safe, magical environment with no scary or dark elements
- Include magical creatures, animal friends, or other positive characters
- Peaceful interactions and cooperation between characters`;

  const specificPrompt = scene.illustration_prompt;

  return `${baseStyle}

${heroConsistency}

${sceneDetails}

Scene requirements: ${specificPrompt}

${safetyRequirements}

Create a delightful scene that children would love to see, showing ${hero.name} in a bright, magical world with friendly companions.`;
}

/**
 * Generate single scene illustration
 */
async function generateSceneIllustration(
  scene: any,
  hero: any,
  storyTitle: string,
  previousGenerationId: string | null,
  requestId: string
): Promise<{
  success: boolean;
  imageUrl?: string;
  generationId?: string;
  error?: string;
}> {
  try {
    // Build prompt
    const fullPrompt = buildScenePrompt(scene, hero, storyTitle);

    // Filter for safety
    const filteredPrompt = await contentFilter.filterImagePrompt(fullPrompt, requestId);

    logger.logImageGeneration('scene_generation_start', requestId, {
      scene_number: scene.scene_number,
      prompt_length: filteredPrompt.length,
      has_previous_gen_id: !!previousGenerationId
    });

    // Prepare image request
    const imageRequest: any = {
      model: MODELS.IMAGE,
      prompt: filteredPrompt,
      n: 1,
      size: '1024x1024',
      quality: 'high',
      background: 'auto',
      output_format: 'png',
      moderation: 'auto'
    };

    // Add previous generation ID for consistency
    if (previousGenerationId) {
      imageRequest.previous_generation_id = previousGenerationId;
    }

    // Generate image
    const response = await openai.createImage(imageRequest, requestId);

    const imageResult = response.data[0];
    if (!imageResult.b64_json) {
      throw new Error('No image data received');
    }

    // Convert base64 to binary
    const imageData = new Uint8Array(
      atob(imageResult.b64_json)
        .split('')
        .map(char => char.charCodeAt(0))
    ).buffer;

    // Upload to storage
    const { url: imageUrl } = await uploadSceneImage(
      imageData,
      scene.scene_number,
      hero.id,
      requestId
    );

    const generationId = imageResult.generation_id || `gen_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    logger.logImageGeneration('scene_generation_success', requestId, {
      scene_number: scene.scene_number,
      generation_id: generationId,
      image_url: imageUrl
    });

    return {
      success: true,
      imageUrl,
      generationId
    };
  } catch (error) {
    logger.error(
      `Scene ${scene.scene_number} generation failed`,
      LogCategory.IMAGE,
      requestId,
      error as Error
    );

    return {
      success: false,
      error: (error as Error).message
    };
  }
}

/**
 * Upload scene image to storage
 */
async function uploadSceneImage(
  imageData: ArrayBuffer,
  sceneNumber: number,
  heroId: string,
  requestId: string
): Promise<{ url: string; size: number }> {
  const supabase = createSupabaseServiceClient();

  const timestamp = Date.now();
  const fileName = `scenes/${heroId}_scene${sceneNumber}_${timestamp}.png`;

  const { data, error } = await supabase.storage
    .from('story-illustrations')
    .upload(fileName, imageData, {
      contentType: 'image/png',
      cacheControl: '86400'
    });

  if (error) {
    throw new Error(`Failed to upload scene image: ${error.message}`);
  }

  const { data: { publicUrl } } = supabase.storage
    .from('story-illustrations')
    .getPublicUrl(fileName);

  return {
    url: publicUrl,
    size: imageData.byteLength
  };
}

/**
 * Process illustrations synchronously
 */
async function processSyncIllustrations(
  request: SceneIllustrationRequest,
  hero: any,
  story: any,
  userId: string,
  requestId: string
): Promise<SceneIllustrationResponse> {
  const supabase = createSupabaseServiceClient();

  // Check batch rate limits
  await checkBatchRateLimit(
    userId,
    [{ functionName: 'illustration_generation', count: request.scenes.length }],
    requestId
  );

  const results: Array<{
    scene_number: number;
    image_url?: string;
    generation_id?: string;
    status: 'completed' | 'failed';
    error_message?: string;
  }> = [];

  let lastGenerationId = hero.avatar_generation_id || null;

  // Sort scenes by scene number
  const sortedScenes = [...request.scenes].sort((a, b) => a.scene_number - b.scene_number);

  for (const [index, scene] of sortedScenes.entries()) {
    logger.info(
      `Processing scene ${scene.scene_number} (${index + 1}/${sortedScenes.length})`,
      LogCategory.IMAGE,
      requestId
    );

    // Generate illustration
    const result = await generateSceneIllustration(
      scene,
      hero,
      story.title,
      lastGenerationId,
      requestId
    );

    if (result.success) {
      // Update database
      await supabase
        .from('story_illustrations')
        .upsert({
          story_id: request.story_id,
          scene_id: null, // Will be populated if scenes table is linked
          image_url: result.imageUrl,
          generation_id: result.generationId,
          previous_generation_id: lastGenerationId,
          status: 'completed',
          retry_count: 0,
          generation_metadata: {
            scene_number: scene.scene_number,
            timestamp_seconds: scene.timestamp_seconds,
            emotion: scene.emotion,
            importance: scene.importance
          }
        });

      results.push({
        scene_number: scene.scene_number,
        image_url: result.imageUrl!,
        generation_id: result.generationId!,
        status: 'completed'
      });

      // Update generation ID for next scene
      lastGenerationId = result.generationId!;
    } else {
      // Record failure
      await supabase
        .from('story_illustrations')
        .upsert({
          story_id: request.story_id,
          scene_id: null,
          status: 'failed',
          error_message: result.error,
          retry_count: 1,
          generation_metadata: {
            scene_number: scene.scene_number,
            error: result.error
          }
        });

      results.push({
        scene_number: scene.scene_number,
        status: 'failed',
        error_message: result.error
      });
    }

    // Add delay between requests to avoid rate limits
    if (index < sortedScenes.length - 1) {
      await new Promise(resolve => setTimeout(resolve, 1500));
    }
  }

  const completedCount = results.filter(r => r.status === 'completed').length;
  const status = completedCount === results.length ? 'completed' : 'partial';

  return {
    illustrations: results,
    status,
    total_scenes: sortedScenes.length,
    completed_scenes: completedCount
  };
}

/**
 * Queue illustrations for async processing
 */
async function queueAsyncIllustrations(
  request: SceneIllustrationRequest,
  userId: string,
  requestId: string
): Promise<SceneIllustrationResponse> {
  const supabase = createSupabaseServiceClient();

  // Create job in queue
  const { data: job, error } = await supabase
    .from('generation_queue')
    .insert({
      user_id: userId,
      story_id: request.story_id,
      job_type: 'illustration',
      job_data: request,
      status: 'pending',
      priority: 5,
      max_attempts: 3
    })
    .select()
    .single();

  if (error || !job) {
    throw new Error('Failed to queue illustration job');
  }

  // Estimate completion time (1.5 minutes per scene + queue time)
  const estimatedMinutes = (request.scenes.length * 1.5) + 2;
  const estimatedCompletion = new Date(Date.now() + estimatedMinutes * 60 * 1000).toISOString();

  logger.info(
    'Queued async illustration job',
    LogCategory.IMAGE,
    requestId,
    {
      job_id: job.id,
      scene_count: request.scenes.length,
      estimated_completion: estimatedCompletion
    }
  );

  return {
    job_id: job.id,
    status: 'processing',
    total_scenes: request.scenes.length,
    completed_scenes: 0,
    estimated_completion: estimatedCompletion
  };
}

/**
 * Main scene illustration handler
 */
serve(async (req) => {
  return withEdgeFunctionWrapper(req, 'illustration_generation', async ({ userId, supabase, requestId }) => {
    const request = await parseAndValidateJSON<SceneIllustrationRequest>(req, SceneIllustrationSchema);

    logger.logImageGeneration('batch_request_received', requestId, {
      story_id: request.story_id,
      scene_count: request.scenes.length,
      process_async: request.process_async || false
    });

    // Verify access to story and hero
    const { data: story, error: storyError } = await supabase
      .from('stories')
      .select('id, title, hero_id')
      .eq('id', request.story_id)
      .eq('user_id', userId)
      .single();

    if (storyError || !story) {
      throw new Error('Story not found or access denied');
    }

    const { data: hero, error: heroError } = await supabase
      .from('heroes')
      .select('*')
      .eq('id', request.hero_id)
      .eq('user_id', userId)
      .single();

    if (heroError || !hero) {
      throw new Error('Hero not found or access denied');
    }

    // Validate scenes
    if (request.scenes.length === 0) {
      throw new Error('No scenes provided');
    }

    if (request.scenes.length > 10) {
      throw new Error('Too many scenes (maximum 10)');
    }

    // Process based on sync/async preference
    if (request.process_async && request.scenes.length > 3) {
      // Queue for async processing if more than 3 scenes
      return await queueAsyncIllustrations(request, userId, requestId);
    } else {
      // Process synchronously
      return await processSyncIllustrations(request, hero, story, userId, requestId);
    }
  });
});