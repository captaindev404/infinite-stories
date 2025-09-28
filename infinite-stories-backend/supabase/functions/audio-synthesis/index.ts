/**
 * Audio Synthesis Edge Function
 *
 * This function handles text-to-speech generation using OpenAI's TTS models,
 * providing the same voice configurations as the iOS app. Features:
 * - Multiple voice options with specialized instructions
 * - Multi-language support
 * - File storage in Supabase Storage
 * - Usage tracking and caching
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  withEdgeFunctionWrapper,
  parseAndValidateJSON,
  AudioSynthesisSchema,
  openai,
  MODELS,
  logger,
  LogCategory,
  cache,
  CacheKeyGenerator,
  CACHE_CONFIG,
  createSupabaseServiceClient
} from '../_shared/index.ts';

/**
 * Audio synthesis request interface
 */
interface AudioSynthesisRequest {
  story_id: string;
  text: string;
  voice: string;
  language: string;
}

/**
 * Audio synthesis response interface
 */
interface AudioSynthesisResponse {
  audio_url: string;
  duration_seconds: number;
  file_size_bytes: number;
  voice_used: string;
  language: string;
}

/**
 * Voice configurations with specialized instructions for each voice
 */
const VOICE_INSTRUCTIONS = {
  coral: {
    base: 'Speak with a warm, gentle, and nurturing tone perfect for bedtime stories. Use a calm and soothing pace with clear pronunciation. Add subtle emotional expressions to bring characters to life while maintaining a peaceful atmosphere that helps children relax and drift off to sleep.',
    languages: {
      en: 'Speak in clear, gentle English with a soothing bedtime story pace.',
      es: 'Habla en español claro y suave con un ritmo tranquilizador de cuento antes de dormir.',
      fr: 'Parlez en français clair et doux avec un rythme apaisant d\'histoire du coucher.',
      de: 'Sprechen Sie in klarem, sanftem Deutsch mit einem beruhigenden Gute-Nacht-Geschichten-Rhythmus.',
      it: 'Parla in italiano chiaro e dolce con un ritmo rilassante da storia della buonanotte.'
    }
  },
  nova: {
    base: 'Use a friendly, cheerful, and engaging storyteller voice that captivates young listeners. Speak clearly at a moderate pace with gentle enthusiasm. Create distinct character voices while keeping the overall tone calming and suitable for bedtime. Emphasize wonder and magic in the narrative.',
    languages: {
      en: 'Use an engaging English storyteller voice with gentle enthusiasm and wonder.',
      es: 'Usa una voz de narrador en español atractiva con suave entusiasmo y asombro.',
      fr: 'Utilisez une voix de conteur français engageante avec un enthousiasme doux et de l\'émerveillement.',
      de: 'Verwenden Sie eine ansprechende deutsche Erzählerstimme mit sanfter Begeisterung und Staunen.',
      it: 'Usa una voce narrante italiana coinvolgente con dolce entusiasmo e meraviglia.'
    }
  },
  fable: {
    base: 'Adopt a wise, comforting grandfather-like tone that makes children feel safe and loved. Use a slower, deliberate pace with warm inflections. Add gentle dramatic pauses for effect and speak as if sharing a treasured tale. Keep the voice soft and reassuring throughout.',
    languages: {
      en: 'Speak in English with a wise, grandfatherly tone that is comforting and reassuring.',
      es: 'Habla en español con un tono sabio y paternal que sea consolador y tranquilizador.',
      fr: 'Parlez en français avec un ton sage et paternel qui soit réconfortant et rassurant.',
      de: 'Sprechen Sie auf Deutsch mit einem weisen, väterlichen Ton, der tröstend und beruhigend ist.',
      it: 'Parla in italiano con un tono saggio e paterno che sia confortante e rassicurante.'
    }
  },
  alloy: {
    base: 'Speak with a clear, pleasant, and neutral tone that\'s easy for children to understand. Use moderate pacing with good articulation. Add subtle warmth and friendliness while maintaining consistency. Perfect for educational elements in the story.',
    languages: {
      en: 'Speak in clear, pleasant English that is easy for children to understand.',
      es: 'Habla en español claro y agradable que sea fácil de entender para los niños.',
      fr: 'Parlez en français clair et agréable qui soit facile à comprendre pour les enfants.',
      de: 'Sprechen Sie in klarem, angenehmem Deutsch, das für Kinder leicht verständlich ist.',
      it: 'Parla in italiano chiaro e piacevole che sia facile da capire per i bambini.'
    }
  },
  echo: {
    base: 'Use a soft, dreamy, and ethereal voice that creates a magical atmosphere. Speak gently with a flowing rhythm that mimics the natural cadence of bedtime stories. Add whisper-like qualities for mysterious moments while keeping the overall tone comforting.',
    languages: {
      en: 'Use a soft, dreamy English voice that creates a magical bedtime atmosphere.',
      es: 'Usa una voz española suave y soñadora que cree una atmósfera mágica para dormir.',
      fr: 'Utilisez une voix française douce et rêveuse qui crée une atmosphère magique du coucher.',
      de: 'Verwenden Sie eine sanfte, träumerische deutsche Stimme, die eine magische Schlafenszeit-Atmosphäre schafft.',
      it: 'Usa una voce italiana morbida e sognante che crei un\'atmosfera magica della buonanotte.'
    }
  },
  onyx: {
    base: 'Deliver the story with a deep, warm, and reassuring voice like a protective parent. Use a slow, steady pace that helps children feel secure. Add gravitas to important moments while maintaining gentleness. Perfect for adventure stories that need to stay calming.',
    languages: {
      en: 'Use a deep, warm English voice that is reassuring and protective like a caring parent.',
      es: 'Usa una voz española profunda y cálida que sea tranquilizadora y protectora como un padre cariñoso.',
      fr: 'Utilisez une voix française profonde et chaleureuse qui soit rassurante et protectrice comme un parent bienveillant.',
      de: 'Verwenden Sie eine tiefe, warme deutsche Stimme, die beruhigend und beschützend wie ein fürsorglicher Elternteil ist.',
      it: 'Usa una voce italiana profonda e calda che sia rassicurante e protettiva come un genitore premuroso.'
    }
  },
  shimmer: {
    base: 'Speak with a bright, melodic, and enchanting voice that sparkles with imagination. Use varied intonation to paint vivid pictures while keeping the energy level appropriate for bedtime. Add musical qualities to dialogue and maintain a soothing undertone throughout.',
    languages: {
      en: 'Use a bright, melodic English voice that sparkles with imagination and wonder.',
      es: 'Usa una voz española brillante y melódica que brille con imaginación y asombro.',
      fr: 'Utilisez une voix française brillante et mélodieuse qui scintille d\'imagination et d\'émerveillement.',
      de: 'Verwenden Sie eine helle, melodische deutsche Stimme, die vor Fantasie und Staunen funkelt.',
      it: 'Usa una voce italiana brillante e melodica che scintilli di immaginazione e meraviglia.'
    }
  }
};

/**
 * Get voice instructions for TTS
 */
function getVoiceInstructions(voice: string, language: string): string {
  const voiceConfig = VOICE_INSTRUCTIONS[voice as keyof typeof VOICE_INSTRUCTIONS];
  if (!voiceConfig) {
    return VOICE_INSTRUCTIONS.coral.base + ' ' + VOICE_INSTRUCTIONS.coral.languages.en;
  }

  const languageInstruction = voiceConfig.languages[language as keyof typeof voiceConfig.languages] ||
                              voiceConfig.languages.en;

  return voiceConfig.base + ' ' + languageInstruction;
}

/**
 * Estimate audio duration based on text length and voice
 */
function estimateAudioDuration(text: string, voice: string): number {
  const wordCount = text.split(/\s+/).filter(word => word.length > 0).length;

  // Different voices have different speaking rates
  const wordsPerMinute = {
    coral: 180,    // Slower, more soothing
    nova: 200,     // Moderate pace
    fable: 160,    // Slower, grandfather-like
    alloy: 200,    // Standard pace
    echo: 170,     // Dreamy, slower
    onyx: 180,     // Deep, steady
    shimmer: 190   // Melodic, varied
  };

  const wpm = wordsPerMinute[voice as keyof typeof wordsPerMinute] || 200;
  return Math.round((wordCount / wpm) * 60); // Convert to seconds
}

/**
 * Upload audio file to Supabase Storage
 */
async function uploadAudioFile(
  audioData: ArrayBuffer,
  storyId: string,
  voice: string,
  language: string,
  userId: string,
  requestId: string
): Promise<{ url: string; size: number }> {
  const supabase = createSupabaseServiceClient();

  // Create filename
  const timestamp = Date.now();
  const fileName = `${userId}/${storyId}_${voice}_${language}_${timestamp}.mp3`;

  logger.debug(
    'Uploading audio file to storage',
    LogCategory.STORAGE,
    requestId,
    {
      file_name: fileName,
      size_bytes: audioData.byteLength,
      voice,
      language
    }
  );

  // Upload to storage
  const { data, error } = await supabase.storage
    .from('story-audio')
    .upload(fileName, audioData, {
      contentType: 'audio/mpeg',
      cacheControl: '3600'
    });

  if (error) {
    logger.error(
      'Failed to upload audio file',
      LogCategory.STORAGE,
      requestId,
      error as Error,
      { file_name: fileName }
    );
    throw new Error(`Failed to upload audio file: ${error.message}`);
  }

  // Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from('story-audio')
    .getPublicUrl(fileName);

  logger.info(
    'Audio file uploaded successfully',
    LogCategory.STORAGE,
    requestId,
    {
      file_name: fileName,
      size_bytes: audioData.byteLength,
      url: publicUrl
    }
  );

  return {
    url: publicUrl,
    size: audioData.byteLength
  };
}

/**
 * Update story with audio information
 */
async function updateStoryWithAudio(
  storyId: string,
  audioUrl: string,
  duration: number,
  voice: string,
  userId: string,
  requestId: string
): Promise<void> {
  const supabase = createSupabaseServiceClient();

  const { error } = await supabase
    .from('stories')
    .update({
      audio_url: audioUrl,
      audio_duration: `${duration} seconds`,
      audio_voice: voice,
      updated_at: new Date().toISOString()
    })
    .eq('id', storyId)
    .eq('user_id', userId);

  if (error) {
    logger.warn(
      'Failed to update story with audio info',
      LogCategory.DATABASE,
      requestId,
      error as Error,
      { story_id: storyId }
    );
  }
}

/**
 * Main audio synthesis handler
 */
serve(async (req) => {
  return withEdgeFunctionWrapper(req, 'audio_synthesis', async ({ userId, supabase, requestId }) => {
    const request = await parseAndValidateJSON<AudioSynthesisRequest>(req, AudioSynthesisSchema);

    logger.logAudioSynthesis('request_received', requestId, {
      story_id: request.story_id,
      voice: request.voice,
      language: request.language,
      text_length: request.text.length
    });

    // Verify story access
    const { data: story, error: storyError } = await supabase
      .from('stories')
      .select('id, title')
      .eq('id', request.story_id)
      .eq('user_id', userId)
      .single();

    if (storyError || !story) {
      throw new Error('Story not found or access denied');
    }

    // Check cache first
    const cacheKey = CacheKeyGenerator.audioSynthesis(request.text, request.voice, request.language);
    const cached = await cache.get<AudioSynthesisResponse>(cacheKey, requestId);

    if (cached) {
      logger.logAudioSynthesis('cache_hit', requestId, { story_id: request.story_id });
      return { ...cached, cached: true };
    }

    // Validate voice
    if (!VOICE_INSTRUCTIONS[request.voice as keyof typeof VOICE_INSTRUCTIONS]) {
      throw new Error(`Unsupported voice: ${request.voice}`);
    }

    // Get voice instructions
    const instructions = getVoiceInstructions(request.voice, request.language);

    // Estimate duration
    const estimatedDuration = estimateAudioDuration(request.text, request.voice);

    logger.logAudioSynthesis('generating', requestId, {
      estimated_duration: estimatedDuration,
      instructions_length: instructions.length
    });

    // Generate audio using OpenAI TTS with official client
    logger.logOpenAIRequest(MODELS.TTS, 'audio_synthesis', requestId, request.text.length);

    const startTime = Date.now();
    const audioBuffer = await openai.createSpeech({
      model: MODELS.TTS,
      input: request.text,
      voice: request.voice,
      instructions: instructions,
      response_format: 'mp3',
      speed: 0.95
    }, requestId);

    const responseTime = Date.now() - startTime;
    logger.logOpenAIResponse(true, responseTime, requestId, undefined);

    // Upload to storage
    const { url: audioUrl, size: fileSize } = await uploadAudioFile(
      audioBuffer,
      request.story_id,
      request.voice,
      request.language,
      userId,
      requestId
    );

    // Update story record
    await updateStoryWithAudio(
      request.story_id,
      audioUrl,
      estimatedDuration,
      request.voice,
      userId,
      requestId
    );

    // Prepare response
    const response: AudioSynthesisResponse = {
      audio_url: audioUrl,
      duration_seconds: estimatedDuration,
      file_size_bytes: fileSize,
      voice_used: request.voice,
      language: request.language
    };

    // Cache the response
    await cache.set(cacheKey, response, CACHE_CONFIG.audio_files.ttl, requestId);

    logger.logAudioSynthesis('completed', requestId, {
      story_id: request.story_id,
      duration_seconds: estimatedDuration,
      file_size_mb: Math.round(fileSize / 1024 / 1024 * 100) / 100,
      audio_url: audioUrl
    });

    return response;
  });
});