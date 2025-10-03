/**
 * Audio Synthesis Cloud Function
 *
 * This function handles text-to-speech generation using OpenAI's GPT-4o Mini TTS model,
 * providing the same voice configurations as the iOS app. Features:
 * - Multiple voice options with specialized instructions
 * - Multi-language support with enhanced quality
 * - File storage in Firebase Storage
 * - Usage tracking
 *
 * Model: gpt-4o-mini-tts
 */

import * as functions from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import { getConfig } from "./config";

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Types and Interfaces
interface AudioSynthesisRequest {
  story_id: string;
  text: string;
  voice: string;
  language: string;
}

interface AudioSynthesisResponse {
  audio_url: string;
  duration_seconds: number;
  file_size_bytes: number;
  voice_used: string;
  language: string;
}

/**
 * Voice configurations with specialized instructions for each voice
 * These match the configurations in AIService.swift (lines 769-805)
 */
const VOICE_INSTRUCTIONS: Record<string, {
  base: string;
  languages: Record<string, string>;
}> = {
  coral: {
    base: "Speak with a warm, gentle, and nurturing tone perfect for bedtime stories. Use a calm and soothing pace with clear pronunciation. Add subtle emotional expressions to bring characters to life while maintaining a peaceful atmosphere that helps children relax and drift off to sleep.",
    languages: {
      en: "Speak in clear, gentle English with a soothing bedtime story pace.",
      es: "Habla en español claro y suave con un ritmo tranquilizador de cuento antes de dormir.",
      fr: "Parlez en français clair et doux avec un rythme apaisant d'histoire du coucher.",
      de: "Sprechen Sie in klarem, sanftem Deutsch mit einem beruhigenden Gute-Nacht-Geschichten-Rhythmus.",
      it: "Parla in italiano chiaro e dolce con un ritmo rilassante da storia della buonanotte.",
    },
  },
  nova: {
    base: "Use a friendly, cheerful, and engaging storyteller voice that captivates young listeners. Speak clearly at a moderate pace with gentle enthusiasm. Create distinct character voices while keeping the overall tone calming and suitable for bedtime. Emphasize wonder and magic in the narrative.",
    languages: {
      en: "Use an engaging English storyteller voice with gentle enthusiasm and wonder.",
      es: "Usa una voz de narrador en español atractiva con suave entusiasmo y asombro.",
      fr: "Utilisez une voix de conteur français engageante avec un enthousiasme doux et de l'émerveillement.",
      de: "Verwenden Sie eine ansprechende deutsche Erzählerstimme mit sanfter Begeisterung und Staunen.",
      it: "Usa una voce narrante italiana coinvolgente con dolce entusiasmo e meraviglia.",
    },
  },
  fable: {
    base: "Adopt a wise, comforting grandfather-like tone that makes children feel safe and loved. Use a slower, deliberate pace with warm inflections. Add gentle dramatic pauses for effect and speak as if sharing a treasured tale. Keep the voice soft and reassuring throughout.",
    languages: {
      en: "Speak in English with a wise, grandfatherly tone that is comforting and reassuring.",
      es: "Habla en español con un tono sabio y paternal que sea consolador y tranquilizador.",
      fr: "Parlez en français avec un ton sage et paternel qui soit réconfortant et rassurant.",
      de: "Sprechen Sie auf Deutsch mit einem weisen, väterlichen Ton, der tröstend und beruhigend ist.",
      it: "Parla in italiano con un tono saggio e paterno che sia confortante e rassicurante.",
    },
  },
  alloy: {
    base: "Speak with a clear, pleasant, and neutral tone that's easy for children to understand. Use moderate pacing with good articulation. Add subtle warmth and friendliness while maintaining consistency. Perfect for educational elements in the story.",
    languages: {
      en: "Speak in clear, pleasant English that is easy for children to understand.",
      es: "Habla en español claro y agradable que sea fácil de entender para los niños.",
      fr: "Parlez en français clair et agréable qui soit facile à comprendre pour les enfants.",
      de: "Sprechen Sie in klarem, angenehmem Deutsch, das für Kinder leicht verständlich ist.",
      it: "Parla in italiano chiaro e piacevole che sia facile da capire per i bambini.",
    },
  },
  echo: {
    base: "Use a soft, dreamy, and ethereal voice that creates a magical atmosphere. Speak gently with a flowing rhythm that mimics the natural cadence of bedtime stories. Add whisper-like qualities for mysterious moments while keeping the overall tone comforting.",
    languages: {
      en: "Use a soft, dreamy English voice that creates a magical bedtime atmosphere.",
      es: "Usa una voz española suave y soñadora que cree una atmósfera mágica para dormir.",
      fr: "Utilisez une voix française douce et rêveuse qui crée une atmosphère magique du coucher.",
      de: "Verwenden Sie eine sanfte, träumerische deutsche Stimme, die eine magische Schlafenszeit-Atmosphäre schafft.",
      it: "Usa una voce italiana morbida e sognante che crei un'atmosfera magica della buonanotte.",
    },
  },
  onyx: {
    base: "Deliver the story with a deep, warm, and reassuring voice like a protective parent. Use a slow, steady pace that helps children feel secure. Add gravitas to important moments while maintaining gentleness. Perfect for adventure stories that need to stay calming.",
    languages: {
      en: "Use a deep, warm English voice that is reassuring and protective like a caring parent.",
      es: "Usa una voz española profunda y cálida que sea tranquilizadora y protectora como un padre cariñoso.",
      fr: "Utilisez une voix française profonde et chaleureuse qui soit rassurante et protectrice comme un parent bienveillant.",
      de: "Verwenden Sie eine tiefe, warme deutsche Stimme, die beruhigend und beschützend wie ein fürsorglicher Elternteil ist.",
      it: "Usa una voce italiana profonda e calda che sia rassicurante e protettiva come un genitore premuroso.",
    },
  },
  shimmer: {
    base: "Speak with a bright, melodic, and enchanting voice that sparkles with imagination. Use varied intonation to paint vivid pictures while keeping the energy level appropriate for bedtime. Add musical qualities to dialogue and maintain a soothing undertone throughout.",
    languages: {
      en: "Use a bright, melodic English voice that sparkles with imagination and wonder.",
      es: "Usa una voz española brillante y melódica que brille con imaginación y asombro.",
      fr: "Utilisez une voix française brillante et mélodieuse qui scintille d'imagination et d'émerveillement.",
      de: "Verwenden Sie eine helle, melodische deutsche Stimme, die vor Fantasie und Staunen funkelt.",
      it: "Usa una voce italiana brillante e melodica che scintilli di immaginazione e meraviglia.",
    },
  },
};

/**
 * Get voice instructions for TTS based on voice and language
 */
function getVoiceInstructions(voice: string, language: string): string {
  const voiceConfig = VOICE_INSTRUCTIONS[voice];
  if (!voiceConfig) {
    // Fallback to coral voice if invalid voice provided
    const fallbackConfig = VOICE_INSTRUCTIONS.coral;
    return fallbackConfig.base + " " + (fallbackConfig.languages[language] || fallbackConfig.languages.en);
  }

  const languageInstruction = voiceConfig.languages[language] || voiceConfig.languages.en;
  return voiceConfig.base + " " + languageInstruction;
}

/**
 * Estimate audio duration based on text length and voice
 */
function estimateAudioDuration(text: string, voice: string): number {
  const wordCount = text.split(/\s+/).filter((word) => word.length > 0).length;

  // Different voices have different speaking rates (words per minute)
  const wordsPerMinute: Record<string, number> = {
    coral: 180, // Slower, more soothing
    nova: 200, // Moderate pace
    fable: 160, // Slower, grandfather-like
    alloy: 200, // Standard pace
    echo: 170, // Dreamy, slower
    onyx: 180, // Deep, steady
    shimmer: 190, // Melodic, varied
  };

  const wpm = wordsPerMinute[voice] || 200;
  return Math.round((wordCount / wpm) * 60); // Convert to seconds
}

/**
 * Upload audio file to Firebase Storage
 */
async function uploadAudioFile(
  audioBuffer: Buffer,
  storyId: string,
  userId: string,
  voice: string,
  language: string
): Promise<{ url: string; size: number }> {
  const config = getConfig();
  const bucket = admin.storage().bucket(config.firebase.storageBucket);

  // Use consistent naming convention: {userId}/{storyId}/audio.mp3
  const fileName = `story-audio/${userId}/${storyId}/audio.mp3`;
  const file = bucket.file(fileName);

  // Upload the audio buffer
  await file.save(audioBuffer, {
    metadata: {
      contentType: "audio/mpeg",
      cacheControl: "public, max-age=3600",
      metadata: {
        voice: voice,
        language: language,
        generatedAt: new Date().toISOString(),
      },
    },
  });

  // Make the file publicly accessible
  await file.makePublic();

  // Get the public URL
  const publicUrl = `https://storage.googleapis.com/${config.firebase.storageBucket}/${fileName}`;

  return {
    url: publicUrl,
    size: audioBuffer.length,
  };
}

/**
 * Update story document with audio information
 */
async function updateStoryWithAudio(
  storyId: string,
  audioUrl: string,
  duration: number,
  voice: string,
  userId: string
): Promise<void> {
  const db = admin.firestore();

  try {
    await db.collection("stories").doc(storyId).update({
      audioUrl: audioUrl,
      audioDuration: `${duration} seconds`,
      audioVoice: voice,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.warn("Failed to update story with audio info:", error);
    // Non-critical error, don't throw
  }
}

/**
 * Main audio synthesis handler
 */
export const audioSynthesis = onCall(
  async (request) => {
    const data = request.data as AudioSynthesisRequest;

    // Verify authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to generate audio"
      );
    }

    const userId = request.auth.uid;
    const requestId = Date.now().toString();

    console.log("Audio synthesis request received:", {
      requestId,
      userId,
      storyId: data.story_id,
      voice: data.voice,
      language: data.language,
      textLength: data.text?.length || 0,
    });

    // Validate request data
    if (!data.text || data.text.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Text content is required for audio synthesis"
      );
    }

    if (!data.voice || !VOICE_INSTRUCTIONS[data.voice]) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid voice: ${data.voice}. Supported voices: ${Object.keys(VOICE_INSTRUCTIONS).join(", ")}`
      );
    }

    if (!data.language) {
      data.language = "en"; // Default to English
    }

    try {
      // Verify story access if story_id is provided
      if (data.story_id) {
        const db = admin.firestore();
        const storyDoc = await db.collection("stories").doc(data.story_id).get();

        if (!storyDoc.exists) {
          throw new HttpsError(
            "not-found",
            "Story not found"
          );
        }

        const storyData = storyDoc.data();
        if (storyData?.userId !== userId) {
          throw new HttpsError(
            "permission-denied",
            "Access denied to this story"
          );
        }

        // Use story content as fallback if text is too short
        if (data.text.trim().length < 10 && storyData?.content) {
          console.log("Using story content as fallback for audio synthesis");
          data.text = storyData.content;
        }
      }

      // Get voice instructions
      const instructions = getVoiceInstructions(data.voice, data.language);

      // Estimate duration
      const estimatedDuration = estimateAudioDuration(data.text, data.voice);

      console.log("Generating audio with gpt-4o-mini-tts:", {
        requestId,
        voice: data.voice,
        language: data.language,
        estimatedDuration,
      });

      // Initialize OpenAI client
      const config = getConfig();
      const openai = new OpenAI({
        apiKey: config.openai.apiKey,
      });

      // Generate audio using gpt-4o-mini-tts model
      const startTime = Date.now();

      // Create the TTS request with gpt-4o-mini-tts model and instructions
      const mp3Response = await openai.audio.speech.create({
        model: "gpt-4o-mini-tts", // Using the gpt-4o-mini-tts model as specified
        input: data.text,
        voice: data.voice as any, // Cast to any to bypass TypeScript voice type checking
        response_format: "mp3",
        speed: 0.95, // Slightly slower for bedtime stories
        // Note: The instructions parameter is passed as part of the request
        // The OpenAI SDK may not have explicit typing for this, but it's supported by the API
        ...{ instructions }, // Add instructions as additional parameter
      } as any);

      const audioBuffer = Buffer.from(await mp3Response.arrayBuffer());
      const responseTime = Date.now() - startTime;

      console.log("Audio generated successfully:", {
        requestId,
        responseTimeMs: responseTime,
        sizeBytes: audioBuffer.length,
      });

      // Upload to Firebase Storage
      const storageId = data.story_id || `standalone_${Date.now()}_${requestId}`;
      const { url: audioUrl, size: fileSize } = await uploadAudioFile(
        audioBuffer,
        storageId,
        userId,
        data.voice,
        data.language
      );

      // Update story record if story_id was provided
      if (data.story_id) {
        await updateStoryWithAudio(
          data.story_id,
          audioUrl,
          estimatedDuration,
          data.voice,
          userId
        );
      }

      // Prepare response
      const response: AudioSynthesisResponse = {
        audio_url: audioUrl,
        duration_seconds: estimatedDuration,
        file_size_bytes: fileSize,
        voice_used: data.voice,
        language: data.language,
      };

      console.log("Audio synthesis completed:", {
        requestId,
        audioUrl,
        durationSeconds: estimatedDuration,
        fileSizeMB: Math.round(fileSize / 1024 / 1024 * 100) / 100,
      });

      return response;
    } catch (error: any) {
      console.error("Audio synthesis error:", {
        requestId,
        error: error.message,
        stack: error.stack,
      });

      // Handle OpenAI API errors
      if (error.response?.status === 429) {
        throw new HttpsError(
          "resource-exhausted",
          "Rate limit exceeded. Please try again later."
        );
      }

      if (error.response?.status === 401) {
        throw new HttpsError(
          "failed-precondition",
          "OpenAI API key is invalid or not configured"
        );
      }

      // Generic error
      throw new HttpsError(
        "internal",
        `Failed to generate audio: ${error.message}`
      );
    }
  }
);

/**
 * HTTP endpoint version of audio synthesis (for compatibility)
 */
export const audioSynthesisHttp = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    // Extract auth token
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const idToken = authHeader.split("Bearer ")[1];

    // Verify the token
    const decodedToken = await admin.auth().verifyIdToken(idToken);

    // Validate that token is valid
    if (!decodedToken.uid) {
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    // Since we can't directly call the onCall function, we need to duplicate the logic
    // or restructure the code to share the logic between both endpoints
    // For now, let's send a message that this endpoint is for compatibility only
    res.status(501).json({
      error: "HTTP endpoint not fully implemented. Please use the callable function 'audioSynthesis' instead.",
      info: "Request was authenticated but function is not available via HTTP"
    });
  } catch (error: any) {
    console.error("HTTP audio synthesis error:", error);

    if (error.code === "auth/argument-error") {
      res.status(401).json({ error: "Invalid authentication token" });
    } else if (error instanceof HttpsError) {
      const statusCode = error.code === "unauthenticated" ? 401 :
                        error.code === "permission-denied" ? 403 :
                        error.code === "not-found" ? 404 :
                        error.code === "invalid-argument" ? 400 :
                        error.code === "resource-exhausted" ? 429 :
                        500;
      res.status(statusCode).json({ error: error.message });
    } else {
      res.status(500).json({ error: "Internal server error" });
    }
  }
});