/**
 * Avatar Generation Edge Function
 *
 * This function handles hero avatar generation using GPT-Image-1, providing
 * visual consistency through generation ID tracking. Features:
 * - Child-safe image generation with content filtering
 * - Visual consistency through generation ID chaining
 * - Multiple size and quality options
 * - File storage in Supabase Storage
 * - Automatic hero profile updates
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  withEdgeFunctionWrapper,
  parseAndValidateJSON,
  AvatarGenerationSchema,
  openai,
  MODELS,
  logger,
  LogCategory,
  cache,
  CacheKeyGenerator,
  CACHE_CONFIG,
  contentFilter,
  createSupabaseServiceClient
} from '../_shared/index.ts';

/**
 * Avatar generation request interface
 */
interface AvatarGenerationRequest {
  hero_id: string;
  prompt: string;
  size?: string;
  quality?: string;
  previous_generation_id?: string;
}

/**
 * Avatar generation response interface
 */
interface AvatarGenerationResponse {
  avatar_url: string;
  generation_id: string;
  revised_prompt?: string;
  file_size_bytes: number;
  image_size: string;
  quality: string;
}

/**
 * Build comprehensive avatar prompt
 */
function buildAvatarPrompt(hero: any, userPrompt: string): string {
  // Base style and safety requirements
  const baseStyle = `Create a beautiful children's book character illustration in a warm, whimsical style.
Use soft colors, gentle lighting, and a magical atmosphere.
The art style should be similar to modern children's picture books with watercolor or soft digital painting techniques.
Ensure the image is appropriate for children aged 4-10.
Focus on creating a sense of wonder and joy.`;

  // Hero characteristics
  const heroDescription = `
Character name: ${hero.name}
Primary trait: ${hero.primary_trait} (should be reflected in expression and posture)
Secondary trait: ${hero.secondary_trait} (subtle personality indicator)
Appearance: ${hero.appearance || 'friendly and approachable'}
Special ability: ${hero.special_ability || 'kindness and courage'}`;

  // Safety and companionship requirements
  const safetyRequirements = `
CRITICAL SAFETY REQUIREMENTS:
- The character MUST be shown with friendly companions (magical creatures, animal friends, or other characters)
- NO isolation or loneliness - always include friendly elements in the scene
- Bright, colorful, cheerful atmosphere with warm lighting
- Peaceful, happy expression showing confidence and kindness
- Safe, magical environment (enchanted garden, cozy cottage, magical library, etc.)
- All elements must be child-friendly and positive`;

  // Combine all elements
  return `${baseStyle}

${heroDescription}

User requirements: ${userPrompt}

${safetyRequirements}

The final image should be a delightful character portrait that children would love to see as their story hero, surrounded by a magical, friendly world.`;
}

/**
 * Upload avatar image to Supabase Storage
 */
async function uploadAvatarImage(
  imageData: ArrayBuffer,
  heroId: string,
  userId: string,
  requestId: string
): Promise<{ url: string; size: number }> {
  const supabase = createSupabaseServiceClient();

  // Create filename
  const timestamp = Date.now();
  const fileName = `${userId}/${heroId}_avatar_${timestamp}.png`;

  logger.debug(
    'Uploading avatar image to storage',
    LogCategory.STORAGE,
    requestId,
    {
      file_name: fileName,
      size_bytes: imageData.byteLength,
      hero_id: heroId
    }
  );

  // Upload to storage
  const { data, error } = await supabase.storage
    .from('hero-avatars')
    .upload(fileName, imageData, {
      contentType: 'image/png',
      cacheControl: '86400' // 24 hours
    });

  if (error) {
    logger.error(
      'Failed to upload avatar image',
      LogCategory.STORAGE,
      requestId,
      error as Error,
      { file_name: fileName }
    );
    throw new Error(`Failed to upload avatar image: ${error.message}`);
  }

  // Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from('hero-avatars')
    .getPublicUrl(fileName);

  logger.info(
    'Avatar image uploaded successfully',
    LogCategory.STORAGE,
    requestId,
    {
      file_name: fileName,
      size_bytes: imageData.byteLength,
      url: publicUrl
    }
  );

  return {
    url: publicUrl,
    size: imageData.byteLength
  };
}

/**
 * Update hero with avatar information
 */
async function updateHeroWithAvatar(
  heroId: string,
  avatarUrl: string,
  avatarPrompt: string,
  generationId: string,
  userId: string,
  requestId: string
): Promise<void> {
  const supabase = createSupabaseServiceClient();

  const { error } = await supabase
    .from('heroes')
    .update({
      avatar_url: avatarUrl,
      avatar_prompt: avatarPrompt,
      avatar_generation_id: generationId,
      updated_at: new Date().toISOString()
    })
    .eq('id', heroId)
    .eq('user_id', userId);

  if (error) {
    logger.warn(
      'Failed to update hero with avatar info',
      LogCategory.DATABASE,
      requestId,
      error as Error,
      { hero_id: heroId }
    );
  }
}

/**
 * Store generation ID for consistency tracking
 */
async function storeGenerationChain(
  heroId: string,
  generationId: string,
  prompt: string,
  requestId: string
): Promise<void> {
  const supabase = createSupabaseServiceClient();

  const { error } = await supabase
    .from('image_generation_chains')
    .upsert({
      hero_id: heroId,
      chain_type: 'avatar',
      sequence_number: 0, // Avatar is always sequence 0
      generation_id: generationId,
      prompt: prompt
    });

  if (error) {
    logger.warn(
      'Failed to store generation chain',
      LogCategory.DATABASE,
      requestId,
      error as Error,
      { hero_id: heroId, generation_id: generationId }
    );
  }
}

/**
 * Main avatar generation handler
 */
serve(async (req) => {
  return withEdgeFunctionWrapper(req, 'avatar_generation', async ({ userId, supabase, requestId }) => {
    const request = await parseAndValidateJSON<AvatarGenerationRequest>(req, AvatarGenerationSchema);

    logger.logImageGeneration('avatar_request_received', requestId, {
      hero_id: request.hero_id,
      prompt_length: request.prompt.length,
      size: request.size || '1024x1024',
      quality: request.quality || 'high'
    });

    // Get hero data
    const { data: hero, error: heroError } = await supabase
      .from('heroes')
      .select('*')
      .eq('id', request.hero_id)
      .eq('user_id', userId)
      .single();

    if (heroError || !hero) {
      throw new Error('Hero not found or access denied');
    }

    // Set defaults
    const size = request.size || '1024x1024';
    const quality = request.quality || 'high';

    // Check cache
    const cacheKey = CacheKeyGenerator.avatarGeneration(
      request.hero_id,
      request.prompt,
      size,
      quality
    );

    const cached = await cache.get<AvatarGenerationResponse>(cacheKey, requestId);
    if (cached) {
      logger.logImageGeneration('cache_hit', requestId, { hero_id: request.hero_id });
      return { ...cached, cached: true };
    }

    // Build comprehensive prompt
    const fullPrompt = buildAvatarPrompt(hero, request.prompt);

    // Filter prompt for safety
    const filteredPrompt = await contentFilter.filterImagePrompt(fullPrompt, requestId);

    logger.logImageGeneration('prompt_built', requestId, {
      original_length: fullPrompt.length,
      filtered_length: filteredPrompt.length
    });

    // Generate image using GPT-Image-1 with official client
    logger.logOpenAIRequest(MODELS.IMAGE, 'avatar_generation', requestId, filteredPrompt.length);

    const startTime = Date.now();

    const imageRequest: any = {
      model: MODELS.IMAGE,
      prompt: filteredPrompt,
      n: 1,
      size: size,
      quality: quality,
      background: 'auto',
      output_format: 'png',
      moderation: 'auto'
    };

    // Add previous generation ID if provided for consistency
    if (request.previous_generation_id) {
      imageRequest.previous_generation_id = request.previous_generation_id;
      logger.info(
        'Using previous generation ID for consistency',
        LogCategory.IMAGE,
        requestId,
        { previous_generation_id: request.previous_generation_id }
      );
    }

    const response = await openai.createImage(imageRequest, requestId);

    const responseTime = Date.now() - startTime;
    logger.logOpenAIResponse(true, responseTime, requestId, response.usage);

    // Extract image data and metadata
    const imageResult = response.data[0];
    if (!imageResult.b64_json) {
      throw new Error('No image data received from OpenAI');
    }

    const imageData = new Uint8Array(
      atob(imageResult.b64_json)
        .split('')
        .map(char => char.charCodeAt(0))
    ).buffer;

    const generationId = imageResult.generation_id || `gen_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // Upload to storage
    const { url: avatarUrl, size: fileSize } = await uploadAvatarImage(
      imageData,
      request.hero_id,
      userId,
      requestId
    );

    // Update hero with avatar information
    await updateHeroWithAvatar(
      request.hero_id,
      avatarUrl,
      filteredPrompt,
      generationId,
      userId,
      requestId
    );

    // Store generation chain for future consistency
    await storeGenerationChain(
      request.hero_id,
      generationId,
      filteredPrompt,
      requestId
    );

    // Prepare response
    const avatarResponse: AvatarGenerationResponse = {
      avatar_url: avatarUrl,
      generation_id: generationId,
      revised_prompt: imageResult.revised_prompt,
      file_size_bytes: fileSize,
      image_size: size,
      quality: quality
    };

    // Cache the response
    await cache.set(cacheKey, avatarResponse, CACHE_CONFIG.avatar_images.ttl, requestId);

    logger.logImageGeneration('avatar_completed', requestId, {
      hero_id: request.hero_id,
      generation_id: generationId,
      file_size_mb: Math.round(fileSize / 1024 / 1024 * 100) / 100,
      avatar_url: avatarUrl
    });

    return avatarResponse;
  });
});