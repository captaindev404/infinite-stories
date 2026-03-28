import { NextRequest, NextResponse } from 'next/server';
import type { SceneExtractionRequest, StoryScene } from '@/types/openai';
import type { StoryTokenizer } from '@/app/utils/tokenizer';
import { withAuthAndValidation } from '@/lib/api/with-auth';
import { ExtractScenesSchema, type ExtractScenesInput } from '@/lib/api/schemas';

interface SceneJSON {
  sceneNumber: number;
  textSegment: string;
  timestamp: number;
  illustrationPrompt: string;
  emotion: string;
  importance: string;
}

interface SceneExtractionResponse {
  scenes: SceneJSON[];
  sceneCount: number;
  reasoning: string;
}

interface ChunkExtractionParams {
  chunkText: string;
  chunkIndex: number;
  totalChunks: number;
  chunkDuration: number;
  hero: {
    name: string;
    primaryTrait: string;
    secondaryTrait: string;
    appearance: string;
    specialAbility: string;
  };
  eventContext: string;
}

// Constants for chunk sizing
const MAX_INPUT_TOKENS = 6000;  // Conservative limit for input
const PROMPT_OVERHEAD = 1000;     // Tokens for system/user prompts
const CHUNK_SIZE = MAX_INPUT_TOKENS - PROMPT_OVERHEAD;
const MAX_RETRIES = 3;            // Maximum retry attempts per chunk

export async function POST(request: NextRequest) {
  return withAuthAndValidation(request, ExtractScenesSchema, 'story_generation', async (_user, body: ExtractScenesInput) => {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return NextResponse.json(
        { error: 'API key not configured' },
        { status: 500 }
      );
    }

    const { storyContent, storyDuration, hero, eventContext } = body;

    // Dynamically import tokenizer to avoid WASM issues at build time
    const { StoryTokenizer } = await import('@/app/utils/tokenizer');
    const tokenizer = new StoryTokenizer();

    try {
      // Count tokens in story content using the tokenizer class
      const storyTokens = tokenizer.countTokens(storyContent);
      console.log(`Story contains ${storyTokens} tokens`);

      const sceneRequest: SceneExtractionRequest = { storyContent, storyDuration, hero, eventContext };

      if (storyTokens <= CHUNK_SIZE) {
        // Story fits in one request - use existing logic
        console.log('Story fits in single request - using standard extraction');
        return await extractScenesFromFullStory(sceneRequest, apiKey);
      } else {
        // Story needs chunking - use new chunked approach
        console.log('Story requires chunking - using chunked extraction');
        return await extractScenesFromChunkedStory(sceneRequest, apiKey, tokenizer);
      }
    } finally {
      // Always free the encoder when done (important for memory management)
      tokenizer.free();
    }
  });
}

/**
 * Extract scenes from a story that fits in a single API call.
 * This is the original implementation for shorter stories.
 */
async function extractScenesFromFullStory(
  request: SceneExtractionRequest,
  apiKey: string
): Promise<NextResponse> {
  const { storyContent, storyDuration, hero, eventContext } = request;

  const prompt = `You are an expert at analyzing children's bedtime stories and identifying key visual moments for illustration.

Analyze the following story and identify ALL important scenes for illustration. Consider:
- Natural narrative breaks and transitions
- Key emotional moments
- Visual variety (different settings, actions, moods)
- Story pacing (distribute scenes evenly throughout)
- Generate as many illustrations as needed to fully capture the story

Story Context: ${eventContext}
Story Duration: ${Math.floor(storyDuration)} seconds

STORY TEXT:
${storyContent}

INSTRUCTIONS:
1. Identify ALL key scenes in this story - there is no limit on the number of scenes
2. Generate illustrations for every significant moment, action, or scene change
3. For each scene, provide:
   - The exact text segment from the story
   - A detailed illustration prompt for GPT-Image-1
   - Estimated timestamp when this scene would occur during audio playback
   - The emotional tone and importance

The illustration prompts should:
- Be child-friendly, bright, and magical
- Use warm, watercolor or soft digital art style
- Be specific about colors, composition, and atmosphere
- Include the hero character in the scene
- Be under 150 words each
- CRITICAL SAFETY RULES:
  * NEVER show characters alone - always include friends or magical companions
  * NEVER use dark, scary, or negative terms
  * ALWAYS make scenes bright, cheerful, and safe
  * Replace problematic terms: gargoyle→friendly guardian, bat→butterfly, ghost→friendly spirit
  * End each prompt with "child-friendly, warm bedtime illustration"

Return your analysis as a JSON object matching this structure:
{
    "scenes": [
        {
            "sceneNumber": 1,
            "textSegment": "exact text from story",
            "timestamp": 0.0,
            "illustrationPrompt": "detailed GPT-Image-1 prompt",
            "emotion": "joyful|peaceful|exciting|mysterious|heartwarming|adventurous|contemplative",
            "importance": "key|major|minor"
        }
    ],
    "sceneCount": total_number,
    "reasoning": "brief explanation of scene selection"
}`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are an expert at visual storytelling and scene analysis for children\'s books.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      max_tokens: 16000,
      temperature: 0.7,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const error = await response.json();
    return NextResponse.json(error, { status: response.status });
  }

  const data = await response.json();
  const content = data.choices[0].message.content;
  const sceneResponse: SceneExtractionResponse = JSON.parse(content);

  // Convert to StoryScene format
  const scenes: StoryScene[] = sceneResponse.scenes
    .sort((a, b) => a.sceneNumber - b.sceneNumber)
    .map((jsonScene) => ({
      sceneNumber: jsonScene.sceneNumber,
      textSegment: jsonScene.textSegment,
      illustrationPrompt: jsonScene.illustrationPrompt,
      timestamp: jsonScene.timestamp,
      emotion: jsonScene.emotion as any,
      importance: jsonScene.importance as any,
    }));

  return NextResponse.json({
    scenes,
    sceneCount: sceneResponse.sceneCount,
    reasoning: sceneResponse.reasoning,
  });
}

/**
 * Extract scenes from a long story by chunking it into smaller pieces.
 * Each chunk is processed separately and results are merged.
 */
async function extractScenesFromChunkedStory(
  request: SceneExtractionRequest,
  apiKey: string,
  tokenizer: StoryTokenizer
): Promise<NextResponse> {
  const { storyContent, storyDuration, hero, eventContext } = request;

  // Split story into chunks
  const chunks = tokenizer.chunkText(storyContent, CHUNK_SIZE);
  const chunkDuration = storyDuration / chunks.length;

  console.log(`Story split into ${chunks.length} chunks for processing`);
  console.log(`Each chunk represents approximately ${Math.floor(chunkDuration)} seconds`);

  // Process each chunk and collect scenes
  let allScenes: SceneJSON[] = [];
  let sceneNumberOffset = 0;

  for (let i = 0; i < chunks.length; i++) {
    const chunk = chunks[i];
    const chunkStartTime = i * chunkDuration;

    console.log(`Processing chunk ${i + 1}/${chunks.length} (${tokenizer.countTokens(chunk)} tokens)`);

    try {
      // Extract scenes from this chunk with retry logic
      const chunkScenes = await extractScenesFromChunkWithRetry({
        chunkText: chunk,
        chunkIndex: i,
        totalChunks: chunks.length,
        chunkDuration,
        hero: {
          name: hero.name,
          primaryTrait: hero.primaryTrait,
          secondaryTrait: hero.secondaryTrait,
          appearance: hero.appearance,
          specialAbility: hero.specialAbility,
        },
        eventContext,
      }, apiKey);

      // Adjust scene numbers and timestamps
      const adjustedScenes = chunkScenes.map(scene => ({
        ...scene,
        sceneNumber: scene.sceneNumber + sceneNumberOffset,
        timestamp: scene.timestamp + chunkStartTime,
      }));

      console.log(`Chunk ${i + 1} yielded ${chunkScenes.length} scenes`);
      allScenes = allScenes.concat(adjustedScenes);
      sceneNumberOffset += chunkScenes.length;

      // Rate limiting: wait between chunks (except last)
      if (i < chunks.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    } catch (error) {
      console.error(`Failed to process chunk ${i + 1} after ${MAX_RETRIES} retries:`, error);
      // Continue processing other chunks
    }
  }

  // Sort scenes by scene number to ensure correct order
  allScenes.sort((a, b) => a.sceneNumber - b.sceneNumber);

  // Convert to StoryScene format
  const scenes: StoryScene[] = allScenes.map(jsonScene => ({
    sceneNumber: jsonScene.sceneNumber,
    textSegment: jsonScene.textSegment,
    illustrationPrompt: jsonScene.illustrationPrompt,
    timestamp: jsonScene.timestamp,
    emotion: jsonScene.emotion as any,
    importance: jsonScene.importance as any,
  }));

  console.log(`Total scenes extracted: ${scenes.length} from ${chunks.length} chunks`);

  return NextResponse.json({
    scenes,
    sceneCount: scenes.length,
    reasoning: `Extracted ${scenes.length} scenes from ${chunks.length} chunks`,
  });
}

/**
 * Extract scenes from a single chunk with retry logic.
 */
async function extractScenesFromChunkWithRetry(
  params: ChunkExtractionParams,
  apiKey: string,
  retries = 0
): Promise<SceneJSON[]> {
  try {
    return await extractScenesFromChunk(params, apiKey);
  } catch (error) {
    if (retries < MAX_RETRIES) {
      console.log(`Retrying chunk ${params.chunkIndex} (attempt ${retries + 1}/${MAX_RETRIES})`);
      // Exponential backoff: 1s, 2s, 4s
      await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, retries)));
      return extractScenesFromChunkWithRetry(params, apiKey, retries + 1);
    }
    throw error;
  }
}

/**
 * Extract scenes from a single chunk of the story.
 */
async function extractScenesFromChunk(
  params: ChunkExtractionParams,
  apiKey: string
): Promise<SceneJSON[]> {
  const {
    chunkText,
    chunkIndex,
    totalChunks,
    chunkDuration,
    hero,
    eventContext
  } = params;

  // Modified prompt for chunk processing
  const prompt = `You are analyzing part ${chunkIndex + 1} of ${totalChunks} of a children's bedtime story.

Story Context: ${eventContext}
Chunk Duration: ${Math.floor(chunkDuration)} seconds

STORY CHUNK:
${chunkText}

INSTRUCTIONS:
1. Identify key scenes in THIS SECTION ONLY
2. ${chunkIndex === 0 ? 'Start scene numbering from 1' : 'Continue scene numbering (numbering will be adjusted automatically)'}
3. For each scene, provide:
   - The exact text segment from the story chunk
   - A detailed illustration prompt for GPT-Image-1
   - Estimated timestamp RELATIVE TO THIS CHUNK (0 to ${Math.floor(chunkDuration)} seconds)
   - The emotional tone and importance

${chunkIndex > 0 ? 'IMPORTANT: You are analyzing a continuation of the story. Focus on scenes in this section, but be aware this is part of a larger narrative.' : ''}
${chunkIndex === totalChunks - 1 ? 'IMPORTANT: This is the final section of the story. Include the conclusion scenes.' : ''}

The illustration prompts should:
- Be child-friendly, bright, and magical
- Use warm, watercolor or soft digital art style
- Be specific about colors, composition, and atmosphere
- Include the hero character ${hero.name}
- Be under 150 words each
- CRITICAL SAFETY RULES:
  * NEVER show characters alone - always include friends or magical companions
  * NEVER use dark, scary, or negative terms
  * ALWAYS make scenes bright, cheerful, and safe
  * Replace problematic terms: gargoyle→friendly guardian, bat→butterfly, ghost→friendly spirit
  * End each prompt with "child-friendly, warm bedtime illustration"

Return your analysis as a JSON object matching this structure:
{
    "scenes": [
        {
            "sceneNumber": 1,
            "textSegment": "exact text from story chunk",
            "timestamp": 0.0,
            "illustrationPrompt": "detailed GPT-Image-1 prompt",
            "emotion": "joyful|peaceful|exciting|mysterious|heartwarming|adventurous|contemplative",
            "importance": "key|major|minor"
        }
    ],
    "sceneCount": total_number,
    "reasoning": "brief explanation of scene selection"
}`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are an expert at visual storytelling and scene analysis for children\'s books.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      max_tokens: 8000,  // Reduced for chunk processing
      temperature: 0.7,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(`Chunk ${chunkIndex} extraction failed: ${response.status} - ${JSON.stringify(errorData)}`);
  }

  const data = await response.json();
  const content = data.choices[0].message.content;
  const sceneResponse: SceneExtractionResponse = JSON.parse(content);

  return sceneResponse.scenes;
}
