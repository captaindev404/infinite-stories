/**
 * Scene Extraction Cloud Function
 *
 * Extracts scenes from story content for illustration generation.
 * Uses GPT-4o with JSON response format for detailed scene analysis.
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { OpenAI } from 'openai';
import { getConfig } from './config/secrets';

// Initialize OpenAI client
const config = getConfig();
const openai = new OpenAI({
  apiKey: config.openai.apiKey,
});

/**
 * Scene extraction request interface
 */
interface SceneExtractionRequest {
  storyContent: string;
  storyDuration: number; // seconds
  hero: {
    id: string;
    name: string;
    appearance?: string;
    avatarPrompt?: string;
    userId?: string;
  };
  eventContext: string;
}

/**
 * Scene JSON structure matching Swift implementation
 */
interface SceneJSON {
  sceneNumber: number;
  textSegment: string;
  timestamp: number;
  illustrationPrompt: string;
  emotion: string;
  importance: string;
}

/**
 * Scene extraction JSON response interface
 */
interface SceneExtractionJSONResponse {
  scenes: SceneJSON[];
  sceneCount: number;
  reasoning: string;
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
async function extractScenesFromStory(
  storyContent: string,
  storyDuration: number,
  hero: any,
  eventContext: string,
  requestId: string
): Promise<SceneExtractionResponse['scenes']> {
  // Build detailed hero visual description for consistency
  let heroVisualDescription = hero.name;
  if (hero.appearance && hero.appearance.trim()) {
    heroVisualDescription += ` - ${hero.appearance}`;
  }

  // Add avatar prompt details if available for maximum consistency
  if (hero.avatarPrompt) {
    heroVisualDescription += `. IMPORTANT VISUAL REFERENCE: ${hero.avatarPrompt}`;
  }

  const prompt = `You are an expert at analyzing children's bedtime stories and identifying key visual moments for illustration.

Analyze the following story and identify the most important scenes for illustration. Consider:
- Natural narrative breaks and transitions
- Key emotional moments
- Visual variety (different settings, actions, moods)
- Story pacing (distribute scenes evenly throughout)

Story Context: ${eventContext}
Story Duration: ${Math.round(storyDuration)} seconds

HERO VISUAL CONSISTENCY REQUIREMENTS:
Main Character: ${heroVisualDescription}

CRITICAL: Every illustration prompt MUST include the EXACT hero appearance described above.
The character must look IDENTICAL in every scene - same colors, features, clothing, and style.

STORY TEXT:
${storyContent}

INSTRUCTIONS:
1. Identify the optimal number of scenes for this story (typically 1 scene per 15-20 seconds of narration)
2. Choose scenes that best represent the story arc
3. For each scene, provide:
   - The exact text segment from the story
   - A detailed illustration prompt for DALL-E
   - Estimated timestamp when this scene would occur during audio playback
   - The emotional tone and importance

The illustration prompts should:
- ALWAYS start with the hero description: "${heroVisualDescription}"
- Maintain EXACT visual consistency across all scenes
- Be child-friendly and magical
- Use warm, watercolor or soft digital art style
- Be specific about colors, composition, and atmosphere
- Include the hero in every scene with consistent appearance
- Be under 150 words each

Return your analysis as a JSON object matching this structure:
{
  "scenes": [
    {
      "sceneNumber": 1,
      "textSegment": "exact text from story",
      "timestamp": 0.0,
      "illustrationPrompt": "detailed DALL-E prompt",
      "emotion": "joyful|peaceful|exciting|mysterious|heartwarming|adventurous|contemplative",
      "importance": "key|major|minor"
    }
  ],
  "sceneCount": total_number,
  "reasoning": "brief explanation of scene selection"
}`;

  logger.info(`[${requestId}] Starting scene extraction`, {
    storyLength: storyContent.length,
    duration: storyDuration,
    heroName: hero.name,
    eventContext: eventContext,
  });

  try {
    const startTime = Date.now();

    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
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
      max_tokens: 2000,
      temperature: 0.7,
      response_format: { type: 'json_object' },
      user: hero.userId,
    });

    const responseTime = Date.now() - startTime;

    const content = response.choices[0]?.message?.content?.trim();
    if (!content) {
      throw new Error('No scene extraction content generated');
    }

    const sceneData = JSON.parse(content) as SceneExtractionJSONResponse;

    logger.info(`[${requestId}] Scene extraction completed`, {
      sceneCount: sceneData.scenes.length,
      reasoning: sceneData.reasoning,
      responseTime: responseTime,
      usage: response.usage,
    });

    // Transform to expected response format
    const scenes = sceneData.scenes.map((scene, index) => ({
      scene_number: scene.sceneNumber || index + 1,
      text_segment: scene.textSegment,
      illustration_prompt: scene.illustrationPrompt,
      timestamp_seconds: scene.timestamp || (index * (storyDuration / sceneData.scenes.length)),
      emotion: scene.emotion || 'peaceful',
      importance: scene.importance || 'major'
    }));

    return scenes;

  } catch (error) {
    logger.error(`[${requestId}] Scene extraction failed`, error);
    throw error;
  }
}

/**
 * Main scene extraction Cloud Function
 */
export const extractScenes = onCall(
  {
    timeoutSeconds: 60,
    memory: '512MiB',
    maxInstances: 10,
  },
  async (request) => {
    const data = request.data as SceneExtractionRequest;
    const requestIdHeader = request.rawRequest.headers['x-request-id'];
    const requestId = (typeof requestIdHeader === 'string' ? requestIdHeader : requestIdHeader?.[0]) || `req_${Date.now()}`;

    // Validate authentication
    if (!request.auth) {
      logger.error(`[${requestId}] Unauthorized request`);
      throw new HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    // Validate required fields
    if (!data.storyContent || !data.storyDuration || !data.hero || !data.eventContext) {
      logger.error(`[${requestId}] Missing required fields`, { data });
      throw new HttpsError(
        'invalid-argument',
        'Missing required fields: storyContent, storyDuration, hero, eventContext'
      );
    }

    // Validate story content is not empty
    if (!data.storyContent.trim()) {
      logger.error(`[${requestId}] Empty story content received`);
      throw new HttpsError(
        'invalid-argument',
        'Story content cannot be empty'
      );
    }

    // Set user_id if not provided
    if (!data.hero.userId) {
      data.hero.userId = request.auth.uid;
    }

    try {
      // Extract scenes
      const scenes = await extractScenesFromStory(
        data.storyContent,
        data.storyDuration,
        data.hero,
        data.eventContext,
        requestId
      );

      const response: SceneExtractionResponse = {
        scenes,
        scene_count: scenes.length,
        cached: false // Caching can be implemented later
      };

      logger.info(`[${requestId}] Scene extraction response sent`, {
        sceneCount: response.scene_count
      });

      return response;

    } catch (error) {
      logger.error(`[${requestId}] Function execution failed`, error);

      // Re-throw as HttpsError for proper client handling
      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        'internal',
        'Scene extraction failed'
      );
    }
  }
);