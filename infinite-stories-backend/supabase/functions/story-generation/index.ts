/**
 * Story Generation Edge Function
 *
 * This function handles story generation requests from the iOS app, replacing
 * direct OpenAI API calls with server-side processing. It includes:
 * - Story generation using GPT-5-mini with fallback to GPT-4o
 * - Official OpenAI Node.js SDK integration
 * - Automatic scene extraction with enhanced reasoning
 * - Content filtering for child safety
 * - Caching for performance
 * - Usage tracking and rate limiting
 * - Migration support with feature flags
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  withEdgeFunctionWrapper,
  parseAndValidateJSON,
  StoryGenerationSchema,
  openai,
  MODELS,
  logger,
  LogCategory,
  cache,
  CacheKeyGenerator,
  CACHE_CONFIG,
  contentFilter,
  createSupabaseServiceClient,
  calculateCost,
  getOptimalParams
} from '../_shared/index.ts';

/**
 * Story generation request interface (matches iOS expectations)
 */
interface StoryGenerationRequest {
  hero_id: string;
  event: {
    type: 'built_in' | 'custom';
    data: any;
  };
  target_duration: number; // seconds
  language: string;
}

/**
 * Story generation response interface (matches iOS expectations)
 */
interface StoryGenerationResponse {
  story_id: string;
  title: string;
  content: string;
  estimated_duration: number;
  word_count: number;
  scenes: Array<{
    scene_number: number;
    text_segment: string;
    illustration_prompt: string;
    timestamp_seconds: number;
    emotion: string;
    importance: string;
  }>;
}

/**
 * Built-in story events (matches iOS StoryEvent enum)
 */
const BUILT_IN_EVENTS = {
  'magical_forest_adventure': 'discovers a hidden magical forest where talking animals need help solving a puzzle',
  'friendly_dragon_encounter': 'meets a shy, friendly dragon who has lost their way home',
  'underwater_treasure_hunt': 'dives into a magical underwater world to find a treasure that helps sea creatures',
  'cloud_castle_journey': 'climbs a rainbow to visit a castle in the clouds where they help cloud creatures',
  'time_travel_mission': 'travels back in time to help historical figures solve a fun problem',
  'space_exploration': 'blasts off to space to help alien friends fix their broken spaceship',
  'miniature_world_discovery': 'shrinks down to explore a tiny world where they help miniature creatures',
  'weather_wizard_training': 'learns to control weather magic to help their town during a gentle storm',
  'animal_language_learning': 'gains the ability to talk to animals and helps them organize a forest festival',
  'dream_world_adventure': 'enters the dream world to help other children have better dreams'
} as const;

/**
 * Prompt templates by language
 */
const PROMPT_TEMPLATES = {
  en: (hero: any, traits: string, event: string, duration: number) => `
Create a magical bedtime story for children aged 4-10. The story should be exactly ${duration} seconds long when read aloud (approximately ${Math.round(duration / 60)} minutes).

HERO: ${hero.name}
TRAITS: ${traits}
ADVENTURE: ${event}

STORY REQUIREMENTS:
- Write a complete, flowing narrative perfect for bedtime
- Include dialogue and gentle sound effects naturally in the text
- Make the story calming and peaceful, ending with a restful resolution
- Include moral lessons about friendship, kindness, and cooperation
- Ensure ${hero.name} is ALWAYS accompanied by friends or helpful companions
- Create magical, wonder-filled moments that spark imagination
- Use gentle, soothing language throughout
- End with ${hero.name} feeling safe, happy, and ready for sleep

IMPORTANT SAFETY RULES:
- NEVER show ${hero.name} alone or isolated
- NO scary, dark, or frightening elements
- NO violence, fighting, or conflict
- Keep everything bright, positive, and magical
- All problems are solved through friendship and creativity

Write the story in natural, flowing prose suitable for audio narration.`,

  es: (hero: any, traits: string, event: string, duration: number) => `
Crea un cuento mágico para la hora de dormir para niños de 4 a 10 años. La historia debe durar exactamente ${duration} segundos cuando se lea en voz alta (aproximadamente ${Math.round(duration / 60)} minutos).

HÉROE: ${hero.name}
RASGOS: ${traits}
AVENTURA: ${event}

REQUISITOS DE LA HISTORIA:
- Escribe una narrativa completa y fluida perfecta para la hora de dormir
- Incluye diálogo y efectos de sonido suaves naturalmente en el texto
- Haz que la historia sea calmante y pacífica, terminando con una resolución tranquila
- Incluye lecciones morales sobre amistad, bondad y cooperación
- Asegúrate de que ${hero.name} SIEMPRE esté acompañado por amigos o compañeros útiles
- Crea momentos mágicos y llenos de maravilla que despierten la imaginación
- Usa un lenguaje suave y tranquilizador en toda la historia
- Termina con ${hero.name} sintiéndose seguro, feliz y listo para dormir

REGLAS DE SEGURIDAD IMPORTANTES:
- NUNCA muestres a ${hero.name} solo o aislado
- NO elementos aterradores, oscuros o espantosos
- NO violencia, peleas o conflictos
- Mantén todo brillante, positivo y mágico
- Todos los problemas se resuelven a través de la amistad y creatividad

Escribe la historia en prosa natural y fluida adecuada para narración de audio.`,

  fr: (hero: any, traits: string, event: string, duration: number) => `
Créez une histoire magique pour l'heure du coucher pour les enfants de 4 à 10 ans. L'histoire doit durer exactement ${duration} secondes lorsqu'elle est lue à haute voix (environ ${Math.round(duration / 60)} minutes).

HÉROS: ${hero.name}
TRAITS: ${traits}
AVENTURE: ${event}

EXIGENCES DE L'HISTOIRE:
- Écrivez un récit complet et fluide parfait pour l'heure du coucher
- Incluez des dialogues et des effets sonores doux naturellement dans le texte
- Rendez l'histoire apaisante et paisible, se terminant par une résolution reposante
- Incluez des leçons morales sur l'amitié, la gentillesse et la coopération
- Assurez-vous que ${hero.name} soit TOUJOURS accompagné d'amis ou de compagnons utiles
- Créez des moments magiques et merveilleux qui stimulent l'imagination
- Utilisez un langage doux et apaisant tout au long
- Terminez avec ${hero.name} se sentant en sécurité, heureux et prêt à dormir

RÈGLES DE SÉCURITÉ IMPORTANTES:
- Ne montrez JAMAIS ${hero.name} seul ou isolé
- PAS d'éléments effrayants, sombres ou frightening
- PAS de violence, de combats ou de conflits
- Gardez tout lumineux, positif et magique
- Tous les problèmes sont résolus par l'amitié et la créativité

Écrivez l'histoire en prose naturelle et fluide adaptée à la narration audio.`,

  de: (hero: any, traits: string, event: string, duration: number) => `
Erstelle eine magische Gute-Nacht-Geschichte für Kinder von 4 bis 10 Jahren. Die Geschichte sollte genau ${duration} Sekunden dauern, wenn sie laut vorgelesen wird (etwa ${Math.round(duration / 60)} Minuten).

HELD: ${hero.name}
EIGENSCHAFTEN: ${traits}
ABENTEUER: ${event}

GESCHICHTENANFORDERUNGEN:
- Schreibe eine vollständige, fließende Erzählung, die perfekt für die Schlafenszeit ist
- Füge Dialog und sanfte Soundeffekte natürlich in den Text ein
- Mache die Geschichte beruhigend und friedlich, endend mit einer ruhigen Auflösung
- Füge moralische Lektionen über Freundschaft, Freundlichkeit und Zusammenarbeit hinzu
- Stelle sicher, dass ${hero.name} IMMER von Freunden oder hilfreichen Begleitern begleitet wird
- Erschaffe magische, wundervolle Momente, die die Fantasie anregen
- Verwende sanfte, beruhigende Sprache durchgehend
- Ende damit, dass ${hero.name} sich sicher, glücklich und bereit zum Schlafen fühlt

WICHTIGE SICHERHEITSREGELN:
- Zeige ${hero.name} NIEMALS allein oder isoliert
- KEINE gruseligen, dunklen oder erschreckenden Elemente
- KEINE Gewalt, Kämpfe oder Konflikte
- Halte alles hell, positiv und magisch
- Alle Probleme werden durch Freundschaft und Kreativität gelöst

Schreibe die Geschichte in natürlicher, fließender Prosa, die für Audio-Erzählung geeignet ist.`,

  it: (hero: any, traits: string, event: string, duration: number) => `
Crea una storia magica della buonanotte per bambini dai 4 ai 10 anni. La storia dovrebbe durare esattamente ${duration} secondi quando viene letta ad alta voce (circa ${Math.round(duration / 60)} minuti).

EROE: ${hero.name}
TRATTI: ${traits}
AVVENTURA: ${event}

REQUISITI DELLA STORIA:
- Scrivi una narrativa completa e fluida perfetta per l'ora di andare a letto
- Includi dialoghi ed effetti sonori dolci naturalmente nel testo
- Rendi la storia calmante e pacifica, finendo con una risoluzione riposante
- Includi lezioni morali su amicizia, gentilezza e cooperazione
- Assicurati che ${hero.name} sia SEMPRE accompagnato da amici o compagni utili
- Crea momenti magici e pieni di meraviglia che accendano l'immaginazione
- Usa un linguaggio dolce e calmante per tutto il tempo
- Finisci con ${hero.name} che si sente sicuro, felice e pronto per dormire

REGOLE DI SICUREZZA IMPORTANTI:
- NON mostrare MAI ${hero.name} da solo o isolato
- NESSUN elemento spaventoso, scuro o terrifico
- NESSUNA violenza, lotta o conflitto
- Mantieni tutto luminoso, positivo e magico
- Tutti i problemi sono risolti attraverso amicizia e creatività

Scrivi la storia in prosa naturale e fluida adatta per la narrazione audio.`
};

/**
 * Generate story using OpenAI
 */
async function generateStoryContent(
  hero: any,
  event: string,
  targetDuration: number,
  language: string,
  requestId: string
): Promise<{ title: string; content: string; wordCount: number; estimatedDuration: number }> {
  // Build hero traits description
  const traits = `${hero.primary_trait}, ${hero.secondary_trait}, ${hero.appearance || 'lovable appearance'}, ${hero.special_ability || 'warm heart'}`;

  // Get prompt template for language
  const getPrompt = PROMPT_TEMPLATES[language as keyof typeof PROMPT_TEMPLATES];
  if (!getPrompt) {
    throw new Error(`Unsupported language: ${language}`);
  }

  const prompt = getPrompt(hero, traits, event, targetDuration);

  // Filter the prompt for safety
  const filteredPrompt = await contentFilter.filterStoryPrompt(prompt, requestId);

  // Get optimal parameters for GPT-5-mini story generation
  const modelParams = getOptimalParams('story_generation');

  logger.logOpenAIRequest(MODELS.CHAT, 'story_generation', requestId, filteredPrompt.length);

  const startTime = Date.now();
  const response = await openai.createChatCompletion({
    messages: [
      {
        role: 'system',
        content: 'You are a master storyteller specializing in magical bedtime stories for children. Create engaging, safe, and wonderful stories that help children fall asleep peacefully.'
      },
      {
        role: 'user',
        content: filteredPrompt
      }
    ],
    max_tokens: modelParams.max_tokens,
    temperature: modelParams.temperature,
    reasoning_effort: modelParams.reasoning_effort,
    text_verbosity: modelParams.text_verbosity,
    user_id: hero.user_id
  }, requestId);

  const responseTime = Date.now() - startTime;
  logger.logOpenAIResponse(true, responseTime, requestId, response.usage);

  const storyContent = response.choices[0].message.content?.trim() || '';

  if (!storyContent) {
    throw new Error('No story content generated');
  }

  // Filter the generated content
  const filterResult = await contentFilter.filterContent(storyContent, true, requestId);

  // Generate title
  const title = `${hero.name} and the ${event.split(' ').slice(0, 3).join(' ')}`;

  // Calculate word count and duration
  const wordCount = filterResult.filteredContent.split(/\s+/).filter(word => word.length > 0).length;
  const estimatedDuration = (wordCount / 200) * 60; // 200 words per minute

  logger.logStoryGeneration('content_generated', requestId, {
    word_count: wordCount,
    estimated_duration: estimatedDuration,
    target_duration: targetDuration,
    filter_changes: filterResult.changesApplied.length,
    model_used: MODELS.CHAT,
    reasoning_tokens: response.usage?.reasoning_tokens
  });

  return {
    title,
    content: filterResult.filteredContent,
    wordCount,
    estimatedDuration
  };
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
   - A detailed illustration prompt for GPT-Image-1
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
      "illustrationPrompt": "detailed GPT-Image-1 prompt",
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
    reasoning_effort: extractionParams.reasoning_effort,
    text_verbosity: extractionParams.text_verbosity,
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

  // Process and filter scenes
  const scenes = await Promise.all(
    sceneData.scenes.map(async (scene: any, index: number) => {
      // Filter illustration prompt for safety
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

  logger.logStoryGeneration('scenes_extracted', requestId, {
    scene_count: scenes.length,
    reasoning: sceneData.reasoning
  });

  return scenes;
}

/**
 * Main story generation handler
 */
serve(async (req) => {
  return withEdgeFunctionWrapper(req, 'story_generation', async ({ userId, supabase, requestId }) => {
    const request = await parseAndValidateJSON<StoryGenerationRequest>(req, StoryGenerationSchema);

    logger.logStoryGeneration('request_received', requestId, {
      hero_id: request.hero_id,
      event_type: request.event.type,
      target_duration: request.target_duration,
      language: request.language
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

    // Determine event details
    let eventPrompt: string;
    let eventContext: string;

    if (request.event.type === 'built_in') {
      const eventKey = request.event.data.event as keyof typeof BUILT_IN_EVENTS;
      eventPrompt = BUILT_IN_EVENTS[eventKey];
      eventContext = `Built-in event: ${eventKey}`;

      if (!eventPrompt) {
        throw new Error(`Unknown built-in event: ${eventKey}`);
      }
    } else {
      // Custom event
      const { data: customEvent, error: eventError } = await supabase
        .from('custom_events')
        .select('*')
        .eq('id', request.event.data.custom_event_id)
        .eq('user_id', userId)
        .single();

      if (eventError || !customEvent) {
        throw new Error('Custom event not found or access denied');
      }

      eventPrompt = customEvent.prompt_seed;
      eventContext = `Custom event: ${customEvent.title}`;
    }

    // Check cache
    const cacheKey = CacheKeyGenerator.storyGeneration(
      request.hero_id,
      request.event,
      request.language,
      request.target_duration
    );

    const cached = await cache.get<StoryGenerationResponse>(cacheKey, requestId);
    if (cached) {
      logger.logStoryGeneration('cache_hit', requestId, { story_id: cached.story_id });
      return { ...cached, cached: true };
    }

    // Generate story
    const storyResult = await generateStoryContent(
      hero,
      eventPrompt,
      request.target_duration,
      request.language,
      requestId
    );

    // Extract scenes
    const scenes = await extractScenes(
      storyResult.content,
      storyResult.estimatedDuration,
      hero,
      eventContext,
      requestId
    );

    // Save story to database
    const { data: savedStory, error: saveError } = await supabase
      .from('stories')
      .insert({
        user_id: userId,
        hero_id: request.hero_id,
        custom_event_id: request.event.type === 'custom' ? request.event.data.custom_event_id : null,
        title: storyResult.title,
        content: storyResult.content,
        event_type: request.event.type,
        event_data: request.event.data,
        language: request.language,
        estimated_duration: `${Math.round(storyResult.estimatedDuration)} seconds`,
        word_count: storyResult.wordCount,
        generation_metadata: {
          target_duration: request.target_duration,
          actual_duration: storyResult.estimatedDuration,
          scene_count: scenes.length,
          event_context: eventContext
        }
      })
      .select()
      .single();

    if (saveError) {
      logger.error('Failed to save story', LogCategory.DATABASE, requestId, saveError as Error);
      throw new Error('Failed to save story');
    }

    // Save scenes to database
    if (scenes.length > 0) {
      const { error: scenesError } = await supabase
        .from('story_scenes')
        .insert(
          scenes.map(scene => ({
            story_id: savedStory.id,
            scene_number: scene.scene_number,
            text_segment: scene.text_segment,
            illustration_prompt: scene.illustration_prompt,
            sanitized_prompt: scene.illustration_prompt, // Already filtered
            timestamp_seconds: scene.timestamp_seconds,
            emotion: scene.emotion,
            importance: scene.importance
          }))
        );

      if (scenesError) {
        logger.warn('Failed to save scenes', LogCategory.DATABASE, requestId, scenesError as Error);
      }
    }

    // Prepare response
    const response: StoryGenerationResponse = {
      story_id: savedStory.id,
      title: storyResult.title,
      content: storyResult.content,
      estimated_duration: storyResult.estimatedDuration,
      word_count: storyResult.wordCount,
      scenes
    };

    // Cache the response
    await cache.set(cacheKey, response, CACHE_CONFIG.story_content.ttl, requestId);

    logger.logStoryGeneration('completed', requestId, {
      story_id: savedStory.id,
      duration: storyResult.estimatedDuration,
      scenes: scenes.length
    });

    return response;
  });
});