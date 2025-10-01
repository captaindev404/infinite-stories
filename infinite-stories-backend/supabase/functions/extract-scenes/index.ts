/**
 * Scene Extraction Edge Function
 *
 * Extracts scenes from story content for illustration generation.
 * Uses GPT-5 Mini with high reasoning effort for detailed scene analysis.
 */

// Validate environment variables at startup
import { validateEnvironmentVariables } from '../_shared/env-validation.ts';
validateEnvironmentVariables();
import {
  withEdgeFunctionWrapper,
  parseAndValidateJSON,
  openai,
  MODELS,
  logger,
  LogCategory,
  cache,
  CacheKeyGenerator,
  CACHE_CONFIG,
  contentFilter,
  getOptimalParams
} from '../_shared/index.ts';

/**
 * Scene extraction request interface
 */
interface SceneExtractionRequest {
  story_content: string;
  story_duration: number; // seconds
  hero: {
    id: string;
    name: string;
    user_id?: string;
  };
  event_context: string;
}

/**
 * Scene extraction response interface
 */
interface SceneExtractionResponse {
  scenes: Array<{
    scene_number: number;
    text_segment: string;
    illustration_prompt: string;
    timestamp_seconds: number;
    emotion: string;
    importance: string;
  }>;
  scene_count: number;
  cached?: boolean;
}

/**
 * Extract scenes from story using OpenAI
 */
async function extractScenes(
  storyContent: string,
  storyDuration: number,
  hero: any,
  eventContext: string,
  requestId: string
): Promise<Array<{
  scene_number: number;
  text_segment: string;
  illustration_prompt: string;
  timestamp_seconds: number;
  emotion: string;
  importance: string;
}>> {
  const prompt = `You are an expert at analyzing children's bedtime stories and identifying key visual moments for illustration.

Analyze the following story and identify the most important scenes for illustration. Consider:
- Natural narrative breaks and transitions
- Key emotional moments
- Visual variety (different settings, actions, moods)
- Story pacing (distribute scenes evenly throughout)

Story Duration: ${Math.round(storyDuration)} seconds
Hero: ${hero.name}
Context: ${eventContext}

STORY TEXT:
${storyContent}

INSTRUCTIONS:
1. Identify 3-6 optimal scenes for this story (1 scene per 15-30 seconds of narration)
2. Choose scenes that best represent the story arc
3. For each scene, provide:
   - The exact text segment from the story
   - A detailed illustration prompt for DALL-E 3
   - Estimated timestamp when this scene would occur during audio playback
   - The emotional tone and importance

The illustration prompts should:
- Be child-friendly and magical
- Use warm, watercolor or soft digital art style
- Be specific about colors, composition, and atmosphere
- Include ${hero.name} in the scene with companions
- Be under 150 words each

Return your analysis as a JSON object matching this structure:
{
  "scenes": [
    {
      "sceneNumber": 1,
      "textSegment": "exact text from story",
      "timestamp": 0.0,
      "illustrationPrompt": "detailed DALL-E 3 prompt",
      "emotion": "joyful|peaceful|exciting|mysterious|heartwarming|adventurous|contemplative",
      "importance": "key|major|minor"
    }
  ],
  "sceneCount": total_number,
  "reasoning": "brief explanation of scene selection"
}`;

  // Use high reasoning effort for detailed scene extraction
  const extractionParams = getOptimalParams('scene_extraction');

  logger.logOpenAIRequest(MODELS.CHAT, 'scene_extraction', requestId, prompt.length);

  const startTime = Date.now();
  const response = await openai.createChatCompletion({
    messages: [
      {
        role: 'system',
        content: 'You are an expert at visual storytelling and scene analysis for children\'s books.'
      },
      {
        role: 'user',
        content: prompt
      }
    ],
    max_tokens: extractionParams.max_tokens,
    temperature: extractionParams.temperature,
    reasoning_effort: extractionParams.reasoning_effort,  // High reasoning for scene analysis
    text_verbosity: extractionParams.text_verbosity,      // Medium verbosity for scene details
    response_format: { type: 'json_object' },
    user_id: hero.user_id
  }, requestId);

  const responseTime = Date.now() - startTime;
  logger.logOpenAIResponse(true, responseTime, requestId, response.usage);

  const contentToProcess = response.choices[0].message.content?.trim();
  if (!contentToProcess) {
    throw new Error('No scene extraction content generated');
  }

  const sceneData = JSON.parse(contentToProcess);

  // Note: Scene prompt filtering is optional for performance
  // AI-generated prompts from GPT-5 are already safe and child-friendly
  const shouldFilterScenes = Deno.env.get('FILTER_SCENE_PROMPTS') === 'true';

  let scenes: Array<{
    scene_number: number;
    text_segment: string;
    illustration_prompt: string;
    timestamp_seconds: number;
    emotion: string;
    importance: string;
  }>;

  if (shouldFilterScenes) {
    // Filter all scenes in parallel for performance
    logger.info(
      `Filtering ${sceneData.scenes.length} scene prompts in parallel`,
      LogCategory.IMAGE,
      requestId
    );

    scenes = await Promise.all(
      sceneData.scenes.map(async (scene: any, index: number) => {
        // Filter illustration prompt for safety (with fail-safe)
        const filteredPrompt = await contentFilter.filterImagePrompt(scene.illustrationPrompt, requestId);

        return {
          scene_number: scene.sceneNumber || index + 1,
          text_segment: scene.textSegment,
          illustration_prompt: filteredPrompt,
          timestamp_seconds: scene.timestamp || (index * (storyDuration / sceneData.scenes.length)),
          emotion: scene.emotion || 'peaceful',
          importance: scene.importance || 'major'
        };
      })
    );
  } else {
    // Skip filtering for better performance - AI prompts are already safe
    logger.info(
      `Skipping scene prompt filtering (FILTER_SCENE_PROMPTS not enabled)`,
      LogCategory.IMAGE,
      requestId
    );

    scenes = sceneData.scenes.map((scene: any, index: number) => ({
      scene_number: scene.sceneNumber || index + 1,
      text_segment: scene.textSegment,
      illustration_prompt: scene.illustrationPrompt,
      timestamp_seconds: scene.timestamp || (index * (storyDuration / sceneData.scenes.length)),
      emotion: scene.emotion || 'peaceful',
      importance: scene.importance || 'major'
    }));
  }

  logger.logStoryGeneration('scenes_extracted', requestId, {
    scene_count: scenes.length,
    reasoning: sceneData.reasoning,
    reasoning_tokens: response.usage?.reasoning_tokens
  });

  return scenes;
}

/**
 * Validation schema for scene extraction requests
 */
const SceneExtractionSchema = {
  story_content: { type: 'string', required: true },
  story_duration: { type: 'number', required: true },
  hero: {
    type: 'object',
    required: true,
    properties: {
      id: { type: 'string', required: true },
      name: { type: 'string', required: true },
      user_id: { type: 'string', required: false }
    }
  },
  event_context: { type: 'string', required: true }
};

/**
 * Main scene extraction handler
 */
Deno.serve(async (req) => {
  return withEdgeFunctionWrapper(req, 'scene_extraction', async ({ userId, supabase, requestId }) => {
    const request = await parseAndValidateJSON<SceneExtractionRequest>(req, SceneExtractionSchema);

    // Add debug logging to understand what we're receiving
    logger.logStoryGeneration('scene_extraction_request', requestId, {
      story_length: request.story_content.length,
      duration: request.story_duration,
      hero_name: request.hero.name,
      event_context: request.event_context,
      story_preview: request.story_content.substring(0, 100) // First 100 chars for debug
    });

    // Validate story content is not empty
    if (!request.story_content || request.story_content.trim().length === 0) {
      logger.error('Empty story content received', LogCategory.STORY_GENERATION, requestId, new Error('Story content is empty'));
      throw new Error('Story content cannot be empty for scene extraction');
    }

    // Set user_id if not provided
    if (!request.hero.user_id) {
      request.hero.user_id = userId;
    }

    // Check cache
    const cacheKey = CacheKeyGenerator.sceneExtraction(
      request.story_content,
      request.story_duration
    );

    // Cache disabled for development/debugging
    // const cached = await cache.get<SceneExtractionResponse>(cacheKey, requestId);
    // if (cached) {
    //   logger.logStoryGeneration('cache_hit', requestId, { cache_key: cacheKey });
    //   return { ...cached, cached: true };
    // }

    // Extract scenes
    const scenes = await extractScenes(
      request.story_content,
      request.story_duration,
      request.hero,
      request.event_context,
      requestId
    );

    const response: SceneExtractionResponse = {
      scenes,
      scene_count: scenes.length
    };

    // Cache disabled for development/debugging
    // await cache.set(cacheKey, response, CACHE_CONFIG.scene_extraction.ttl, requestId);

    logger.logStoryGeneration('scene_extraction_complete', requestId, {
      scene_count: scenes.length,
      cached: false
    });

    return response;
  });
});