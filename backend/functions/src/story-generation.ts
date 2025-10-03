/**
 * Story Generation Cloud Function
 *
 * Migrated from Supabase Edge Function to Firebase Cloud Function
 * Handles story generation requests from iOS app with GPT-4o integration
 *
 * Features:
 * - Story generation using GPT-4o model (matching AIService.swift)
 * - Multi-language support (en, es, fr, de, it)
 * - Content safety filtering for child-appropriate content
 * - Hero traits and event-based story generation
 * - Compatible with iOS app's expected request/response format
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import { getConfig } from "./config";

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Story generation request interface (matches iOS)
interface StoryGenerationRequest {
  hero_id: string;
  event: {
    type: "built_in" | "custom";
    data: any;
  };
  target_duration: number; // seconds
  language: string;
}

// Story generation response interface (matches iOS)
interface StoryGenerationResponse {
  story_id: string;
  title: string;
  content: string;
  estimated_duration: number;
  word_count: number;
}

// Built-in story events (matches iOS StoryEvent enum)
const BUILT_IN_EVENTS: Record<string, string> = {
  "Bedtime Adventure": "a calm bedtime adventure that helps prepare for sleep",
  "School Day Fun": "an exciting day at school with learning and fun",
  "Birthday Celebration": "a magical birthday celebration with surprises",
  "Weekend Explorer": "a fun weekend adventure exploring new places",
  "Rainy Day Magic": "a creative indoor adventure on a rainy day",
  "Family Time": "a heartwarming adventure with family",
  "Making Friends": "a story about making new friends and friendship",
  "Learning Something New": "an adventure while learning something exciting and new",
  "Helping Others": "a story about helping others and being kind",
  "Holiday Adventure": "a festive holiday adventure full of joy",
};

// Prompt templates by language
const PROMPT_TEMPLATES: Record<string, (hero: any, traits: string, event: string, duration: number) => string> = {
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

Scrivi la storia in prosa naturale e fluida adatta per la narrazione audio.`,
};

/**
 * Content safety filter for child-appropriate content
 */
async function filterContent(content: string): Promise<string> {
  // Basic content filtering - can be enhanced with more sophisticated checks
  const inappropriateTerms = [
    "death", "die", "kill", "murder", "blood", "weapon", "gun", "knife",
    "scary", "horror", "nightmare", "monster", "demon", "evil",
    "alone", "isolated", "abandoned", "lost",
  ];

  let filteredContent = content;
  for (const term of inappropriateTerms) {
    const regex = new RegExp(`\\b${term}\\b`, "gi");
    filteredContent = filteredContent.replace(regex, "***");
  }

  return filteredContent;
}

/**
 * Generate story using OpenAI GPT-4o
 */
async function generateStoryContent(
  hero: any,
  event: string,
  targetDuration: number,
  language: string,
  requestId: string
): Promise<{ title: string; content: string; wordCount: number; estimatedDuration: number }> {
  const config = getConfig();
  const openai = new OpenAI({
    apiKey: config.openai.apiKey,
  });

  // Build hero traits description
  const traits = `${hero.primary_trait || "brave"}, ${hero.secondary_trait || "kind"}, ${
    hero.appearance || "lovable appearance"
  }, ${hero.special_ability || "warm heart"}`;

  // Get prompt template for language
  const getPrompt = PROMPT_TEMPLATES[language];
  if (!getPrompt) {
    throw new Error(`Unsupported language: ${language}`);
  }

  const prompt = getPrompt(hero, traits, event, targetDuration);

  console.log(`[${requestId}] Generating story with GPT-4o for hero: ${hero.name}`);

  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4o", // Using GPT-4o as specified in AIService.swift
      messages: [
        {
          role: "system",
          content: "You are a master storyteller specializing in magical bedtime stories for children. Create engaging, safe, and wonderful stories that help children fall asleep peacefully.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
      max_tokens: 2000,
      temperature: 0.8,
    });

    const storyContent = response.choices[0].message?.content?.trim() || "";

    if (!storyContent) {
      throw new Error("No story content generated");
    }

    // Apply content filtering
    const filteredContent = await filterContent(storyContent);

    // Generate title
    const title = `${hero.name} and the ${event.split(" ").slice(0, 3).join(" ")}`;

    // Calculate word count and duration
    const wordCount = filteredContent.split(/\s+/).filter((word) => word.length > 0).length;
    const estimatedDuration = (wordCount / 200) * 60; // 200 words per minute

    console.log(`[${requestId}] Story generated successfully: ${wordCount} words, ${estimatedDuration}s duration`);

    return {
      title,
      content: filteredContent,
      wordCount,
      estimatedDuration,
    };
  } catch (error) {
    console.error(`[${requestId}] Error generating story:`, error);
    throw new Error(`Failed to generate story: ${error}`);
  }
}

/**
 * Main story generation Cloud Function
 */
export const storyGeneration = functions.https.onCall(
  async (request) => {
    const data = request.data as StoryGenerationRequest;
    const requestId = request.auth?.uid ? `${request.auth.uid}_${Date.now()}` : `req_${Date.now()}`;

    // Verify authentication
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to generate stories"
      );
    }

    const userId = request.auth.uid;

    console.log(`[${requestId}] Story generation request from user: ${userId}`);

    try {
      // Validate request
      if (!data.hero_id || !data.event || !data.target_duration || !data.language) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required parameters"
        );
      }

      // Get hero data from Firestore
      const heroDoc = await db
        .collection("heroes")
        .doc(data.hero_id)
        .get();

      if (!heroDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Hero not found"
        );
      }

      const hero = heroDoc.data();

      // Verify hero belongs to user
      if (hero?.user_id !== userId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Access denied to this hero"
        );
      }

      // Determine event details
      let eventPrompt: string;
      let eventContext: string;

      if (data.event.type === "built_in") {
        // iOS app sends "name" field with the event key
        const eventKey = (data.event.data.name || data.event.data.event) as string;
        eventPrompt = BUILT_IN_EVENTS[eventKey];
        eventContext = `Built-in event: ${eventKey}`;

        if (!eventPrompt) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            `Unknown built-in event: ${eventKey}`
          );
        }
      } else {
        // Custom event
        const customEventDoc = await db
          .collection("custom_events")
          .doc(data.event.data.custom_event_id)
          .get();

        if (!customEventDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Custom event not found"
          );
        }

        const customEvent = customEventDoc.data();

        // Verify custom event belongs to user
        if (customEvent?.user_id !== userId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "Access denied to this custom event"
          );
        }

        eventPrompt = customEvent?.prompt_seed || "";
        eventContext = `Custom event: ${customEvent?.title || "Unknown"}`;
      }

      // Generate story
      const storyResult = await generateStoryContent(
        hero,
        eventPrompt,
        data.target_duration,
        data.language,
        requestId
      );

      // Save story to Firestore
      const storyRef = db.collection("stories").doc();
      await storyRef.set({
        id: storyRef.id,
        user_id: userId,
        hero_id: data.hero_id,
        custom_event_id: data.event.type === "custom" ? data.event.data.custom_event_id : null,
        title: storyResult.title,
        content: storyResult.content,
        event_type: data.event.type,
        event_data: data.event.data,
        language: data.language,
        estimated_duration: `${Math.round(storyResult.estimatedDuration)} seconds`,
        word_count: storyResult.wordCount,
        generation_metadata: {
          target_duration: data.target_duration,
          actual_duration: storyResult.estimatedDuration,
          event_context: eventContext,
          model: "gpt-4o",
          request_id: requestId,
        },
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Prepare response matching iOS expectations
      const response: StoryGenerationResponse = {
        story_id: storyRef.id,
        title: storyResult.title,
        content: storyResult.content,
        estimated_duration: storyResult.estimatedDuration,
        word_count: storyResult.wordCount,
      };

      console.log(`[${requestId}] Story generation completed successfully`);

      return response;
    } catch (error) {
      console.error(`[${requestId}] Error in story generation:`, error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        `Failed to generate story: ${error}`
      );
    }
  }
);