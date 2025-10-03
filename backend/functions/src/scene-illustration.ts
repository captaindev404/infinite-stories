/**
 * Scene Illustration Cloud Function
 *
 * Generates scene illustrations for stories using DALL-E-3,
 * maintaining visual consistency through hero avatar prompts.
 *
 * Features:
 * - Batch processing with rate limiting (1-second delays)
 * - Hero visual consistency using avatarPrompt
 * - Children's book illustration style
 * - Enhanced content safety and sanitization
 * - Firebase Storage integration
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';
import { getConfig, validateSecrets } from './config/secrets';
import { uploadFile, STORAGE_PATHS, generateUniqueFilename } from './utils/storage';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();

// Scene illustration request interface
interface SceneIllustrationRequest {
  storyId: string;
  scenes: Array<{
    sceneId: string;
    sceneNumber: number;
    textSegment: string;
    illustrationPrompt: string;
    timestampSeconds: number;
    emotion?: string;
    importance?: string;
  }>;
  heroId: string;
  processAsync?: boolean;
}

// Scene illustration response interface
interface SceneIllustrationResponse {
  jobId?: string;
  illustrations?: Array<{
    sceneId: string;
    sceneNumber: number;
    imageUrl?: string;
    status: 'completed' | 'failed';
    errorMessage?: string;
  }>;
  status: 'processing' | 'completed' | 'partial';
  totalScenes: number;
  completedScenes: number;
  estimatedCompletion?: string;
}

// Hero interface
interface Hero {
  id: string;
  name: string;
  appearance: string;
  primaryTrait: string;
  secondaryTrait: string;
  specialAbility?: string;
  avatarPrompt?: string;
}

/**
 * Enhanced basic sanitization for child-friendly content
 */
function enhancedBasicSanitization(prompt: string): string {
  // Remove any potentially inappropriate content
  const replacements: Record<string, string> = {
    'alone': 'with friends',
    'lonely': 'with companions',
    'isolated': 'surrounded by friends',
    'scary': 'magical',
    'frightening': 'wonderful',
    'terrifying': 'amazing',
    'horror': 'adventure',
    'violent': 'peaceful',
    'fighting': 'playing',
    'blood': 'sparkles',
    'death': 'adventure',
    'die': 'rest',
    'dead': 'sleeping',
    'kill': 'help',
    'hurt': 'comfort',
    'pain': 'joy',
    'crying': 'laughing',
    'tears': 'smiles',
    'sad': 'happy',
    'angry': 'excited',
    'fear': 'courage',
    'afraid': 'brave',
    'dark': 'bright',
    'darkness': 'light',
    'night': 'twilight with stars',
    'storm': 'rainbow',
    'weapon': 'magic wand',
    'sword': 'magic staff',
    'gun': 'bubble blower',
    'knife': 'paintbrush',
  };

  let sanitized = prompt.toLowerCase();

  for (const [term, replacement] of Object.entries(replacements)) {
    const regex = new RegExp(`\\b${term}\\b`, 'gi');
    sanitized = sanitized.replace(regex, replacement);
  }

  return sanitized;
}

/**
 * Build scene illustration prompt with hero consistency
 */
function buildScenePrompt(
  scene: any,
  hero: Hero,
  storyTitle: string
): string {
  const baseStyle = `Create a beautiful children's book scene illustration in a warm, whimsical style.
Use soft watercolor or digital painting techniques with gentle lighting and magical atmosphere.
The art style should match modern children's picture books.
Ensure the image is appropriate for children aged 4-10.
Focus on creating wonder, joy, and visual storytelling.`;

  // Build hero consistency requirements
  let heroConsistency = `
HERO CHARACTER (MUST APPEAR CONSISTENTLY):
Name: ${hero.name}
Appearance: ${hero.appearance || 'friendly and lovable'}
Traits: ${hero.primaryTrait}, ${hero.secondaryTrait}
Special ability: ${hero.specialAbility || 'kindness and courage'}`;

  // Include avatar prompt for maximum consistency if available
  if (hero.avatarPrompt) {
    heroConsistency += `

VISUAL REFERENCE (MUST MATCH EXACTLY): ${hero.avatarPrompt}`;
  }

  heroConsistency += `

CRITICAL: The character ${hero.name} MUST look IDENTICAL to their established appearance.
Same hair color, clothing style, features, and overall design as in previous illustrations.`;

  const sceneDetails = `
SCENE CONTEXT:
Story: ${storyTitle}
Scene text: "${scene.textSegment}"
Emotion: ${scene.emotion || 'peaceful'}
Importance: ${scene.importance || 'major'}
Timestamp: ${Math.round(scene.timestampSeconds)}s into story`;

  const safetyRequirements = `
MANDATORY SAFETY REQUIREMENTS:
- ${hero.name} MUST be shown with friends, companions, or helpful creatures
- NO isolation, loneliness, or characters appearing alone
- Bright, colorful, cheerful atmosphere with warm lighting
- All characters show positive emotions (happy, curious, excited, peaceful)
- Safe, magical environment with no scary or dark elements
- Include magical creatures, animal friends, or other positive characters
- Peaceful interactions and cooperation between characters`;

  const specificPrompt = scene.illustrationPrompt;

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
  hero: Hero,
  storyTitle: string,
  storyId: string,
  userId: string,
  openai: OpenAI
): Promise<{
  success: boolean;
  imageUrl?: string;
  error?: string;
}> {
  try {
    // Build prompt
    const fullPrompt = buildScenePrompt(scene, hero, storyTitle);

    // Apply enhanced basic sanitization
    const sanitizedPrompt = enhancedBasicSanitization(fullPrompt);

    console.log(`Generating illustration for scene ${scene.sceneNumber}`, {
      sceneId: scene.sceneId,
      promptLength: sanitizedPrompt.length,
      hasAvatarPrompt: !!hero.avatarPrompt
    });

    // Generate image with DALL-E-3
    const response = await openai.images.generate({
      model: 'dall-e-3',
      prompt: sanitizedPrompt,
      n: 1,
      size: '1024x1024',
      quality: 'standard',
      response_format: 'b64_json'
    });

    if (!response.data || response.data.length === 0) {
      throw new Error('No image data received from DALL-E-3');
    }

    const imageResult = response.data[0];
    if (!imageResult.b64_json) {
      throw new Error('No image data received from DALL-E-3');
    }

    // Convert base64 to buffer
    const imageBuffer = Buffer.from(imageResult.b64_json, 'base64');

    // Generate filename and storage path
    const filename = generateUniqueFilename('illustration.png', `scene_${scene.sceneNumber}`);
    const storagePath = STORAGE_PATHS.SCENE_ILLUSTRATION(storyId, scene.sceneId, filename);

    // Upload to Firebase Storage
    const imageUrl = await uploadFile(
      storagePath,
      imageBuffer,
      'image/png',
      {
        storyId,
        sceneId: scene.sceneId,
        sceneNumber: scene.sceneNumber.toString(),
        userId,
        generatedAt: new Date().toISOString()
      }
    );

    console.log(`Successfully generated illustration for scene ${scene.sceneNumber}`, {
      sceneId: scene.sceneId,
      imageUrl,
      imageSize: imageBuffer.length
    });

    // Store illustration metadata in Firestore
    await firestore
      .collection('stories')
      .doc(storyId)
      .collection('illustrations')
      .doc(scene.sceneId)
      .set({
        sceneId: scene.sceneId,
        sceneNumber: scene.sceneNumber,
        imageUrl,
        storagePath,
        prompt: scene.illustrationPrompt,
        revisedPrompt: imageResult.revised_prompt,
        status: 'completed',
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          timestampSeconds: scene.timestampSeconds,
          emotion: scene.emotion,
          importance: scene.importance
        }
      });

    return {
      success: true,
      imageUrl
    };
  } catch (error: any) {
    console.error(`Failed to generate illustration for scene ${scene.sceneNumber}:`, error);

    // Store failure in Firestore
    await firestore
      .collection('stories')
      .doc(storyId)
      .collection('illustrations')
      .doc(scene.sceneId)
      .set({
        sceneId: scene.sceneId,
        sceneNumber: scene.sceneNumber,
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          timestampSeconds: scene.timestampSeconds,
          emotion: scene.emotion,
          importance: scene.importance
        }
      });

    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Process illustrations synchronously with batch processing
 */
async function processSyncIllustrations(
  request: SceneIllustrationRequest,
  hero: Hero,
  storyTitle: string,
  userId: string,
  openai: OpenAI
): Promise<SceneIllustrationResponse> {
  const results: Array<{
    sceneId: string;
    sceneNumber: number;
    imageUrl?: string;
    status: 'completed' | 'failed';
    errorMessage?: string;
  }> = [];

  // Sort scenes by scene number for sequential processing
  const sortedScenes = [...request.scenes].sort((a, b) => a.sceneNumber - b.sceneNumber);

  for (const [index, scene] of sortedScenes.entries()) {
    console.log(`Processing scene ${scene.sceneNumber} (${index + 1}/${sortedScenes.length})`);

    // Generate illustration
    const result = await generateSceneIllustration(
      scene,
      hero,
      storyTitle,
      request.storyId,
      userId,
      openai
    );

    if (result.success) {
      results.push({
        sceneId: scene.sceneId,
        sceneNumber: scene.sceneNumber,
        imageUrl: result.imageUrl!,
        status: 'completed'
      });
    } else {
      results.push({
        sceneId: scene.sceneId,
        sceneNumber: scene.sceneNumber,
        status: 'failed',
        errorMessage: result.error
      });
    }

    // Add 1-second delay between requests to avoid rate limits
    if (index < sortedScenes.length - 1) {
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }

  const completedCount = results.filter(r => r.status === 'completed').length;
  const status = completedCount === results.length ? 'completed' : 'partial';

  return {
    illustrations: results,
    status,
    totalScenes: sortedScenes.length,
    completedScenes: completedCount
  };
}

/**
 * Queue illustrations for async processing
 */
async function queueAsyncIllustrations(
  request: SceneIllustrationRequest,
  userId: string
): Promise<SceneIllustrationResponse> {
  // Create job in Firestore queue
  const jobRef = await firestore.collection('illustrationJobs').add({
    userId,
    storyId: request.storyId,
    heroId: request.heroId,
    scenes: request.scenes,
    status: 'pending',
    priority: 5,
    maxAttempts: 3,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    scheduledFor: admin.firestore.FieldValue.serverTimestamp()
  });

  // Estimate completion time (1 minute per scene + queue time)
  const estimatedMinutes = request.scenes.length + 2;
  const estimatedCompletion = new Date(Date.now() + estimatedMinutes * 60 * 1000).toISOString();

  console.log('Queued async illustration job', {
    jobId: jobRef.id,
    sceneCount: request.scenes.length,
    estimatedCompletion
  });

  return {
    jobId: jobRef.id,
    status: 'processing',
    totalScenes: request.scenes.length,
    completedScenes: 0,
    estimatedCompletion
  };
}

/**
 * Main scene illustration Cloud Function
 */
export const sceneIllustration = onCall(
  {
    timeoutSeconds: 540, // 9 minutes timeout
    memory: '2GiB',
    maxInstances: 10
  },
  async (request) => {
    const data = request.data as SceneIllustrationRequest;
    const context = request.auth;

    // Validate authentication
    if (!context) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated to generate illustrations'
      );
    }

    const userId = context.uid;

    // Validate secrets
    const secretValidation = validateSecrets();
    if (!secretValidation.valid) {
      console.error('Secret validation failed:', secretValidation.errors);
      throw new HttpsError(
        'failed-precondition',
        'Service configuration error'
      );
    }

    // Get OpenAI configuration
    const config = getConfig();
    const openai = new OpenAI({
      apiKey: config.openai.apiKey
    });

    // Validate request
    if (!data.storyId || !data.heroId || !data.scenes || data.scenes.length === 0) {
      throw new HttpsError(
        'invalid-argument',
        'Missing required fields: storyId, heroId, and scenes'
      );
    }

    if (data.scenes.length > 10) {
      throw new HttpsError(
        'invalid-argument',
        'Too many scenes (maximum 10)'
      );
    }

    try {
      // Verify access to story
      const storyDoc = await firestore
        .collection('stories')
        .doc(data.storyId)
        .get();

      if (!storyDoc.exists) {
        throw new HttpsError(
          'not-found',
          'Story not found'
        );
      }

      const story = storyDoc.data()!;
      if (story.userId !== userId) {
        throw new HttpsError(
          'permission-denied',
          'Access denied to this story'
        );
      }

      // Get hero data
      const heroDoc = await firestore
        .collection('heroes')
        .doc(data.heroId)
        .get();

      if (!heroDoc.exists) {
        throw new HttpsError(
          'not-found',
          'Hero not found'
        );
      }

      const heroData = heroDoc.data()!;
      if (heroData.userId !== userId) {
        throw new HttpsError(
          'permission-denied',
          'Access denied to this hero'
        );
      }

      const hero: Hero = {
        id: data.heroId,
        name: heroData.name,
        appearance: heroData.appearance,
        primaryTrait: heroData.primaryTrait,
        secondaryTrait: heroData.secondaryTrait,
        specialAbility: heroData.specialAbility,
        avatarPrompt: heroData.avatarPrompt
      };

      // Process based on sync/async preference
      if (data.processAsync && data.scenes.length > 3) {
        // Queue for async processing if more than 3 scenes
        return await queueAsyncIllustrations(data, userId);
      } else {
        // Process synchronously
        return await processSyncIllustrations(
          data,
          hero,
          story.title,
          userId,
          openai
        );
      }
    } catch (error: any) {
      console.error('Scene illustration error:', error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        'internal',
        error.message || 'Failed to generate illustrations'
      );
    }
  });