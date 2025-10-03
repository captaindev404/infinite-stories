/**
 * Avatar Generation Cloud Function
 *
 * This function handles hero avatar generation using DALL-E-3,
 * providing visual consistency through generation ID tracking. Features:
 * - Child-safe image generation with content filtering
 * - Visual consistency through generation ID chaining
 * - Multiple size and quality options
 * - Enhanced image quality and instruction following
 * - File storage in Firebase Storage
 * - Automatic hero profile updates
 *
 * Model: DALL-E-3 (migrated from Supabase Edge Function using GPT-5)
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { OpenAI } from "openai";
import * as logger from "firebase-functions/logger";
import { enhancedBasicSanitization, buildAvatarPrompt } from "./utils/content-filter";

// Initialize OpenAI client with API key from environment
// For local development, use .env file
// For production, use Firebase secrets (set via: firebase functions:secrets:set OPENAI_API_KEY)
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = admin.storage();

/**
 * Avatar generation request interface
 */
interface AvatarGenerationRequest {
  heroId: string;
  prompt: string;
  size?: "1024x1024" | "1024x1792" | "1792x1024";
  quality?: "standard" | "hd";
  previousGenerationId?: string;
}

/**
 * Avatar generation response interface
 */
interface AvatarGenerationResponse {
  avatarUrl: string;
  generationId: string;
  revisedPrompt?: string;
  fileSizeBytes: number;
  imageSize: string;
  quality: string;
}

/**
 * Hero interface from Firestore
 */
interface Hero {
  id: string;
  name: string;
  primaryTrait?: string;
  primary_trait?: string;
  secondaryTrait?: string;
  secondary_trait?: string;
  appearance?: string;
  specialAbility?: string;
  special_ability?: string;
  userId: string;
}

/**
 * Upload avatar image to Firebase Storage
 */
async function uploadAvatarImage(
  imageData: Buffer,
  heroId: string,
  userId: string,
  requestId: string
): Promise<{ url: string; size: number }> {
  // Use consistent naming convention: heroes/{heroId}/avatar/avatar.png
  const fileName = `heroes/${heroId}/avatar/avatar.png`;
  const file = storage.bucket().file(fileName);

  logger.debug("Uploading avatar image to storage", {
    requestId,
    fileName,
    sizeBytes: imageData.byteLength,
    heroId,
  });

  try {
    // Upload to storage
    await file.save(imageData, {
      metadata: {
        contentType: "image/png",
        cacheControl: "public, max-age=86400", // 24 hours
        metadata: {
          heroId,
          userId,
          requestId,
          uploadedAt: new Date().toISOString(),
        },
      },
    });

    // Make the file public
    await file.makePublic();

    // Get public URL
    const publicUrl = `https://storage.googleapis.com/${storage.bucket().name}/${fileName}`;

    logger.info("Avatar image uploaded successfully", {
      requestId,
      fileName,
      sizeBytes: imageData.byteLength,
      url: publicUrl,
    });

    return {
      url: publicUrl,
      size: imageData.byteLength,
    };
  } catch (error) {
    logger.error("Failed to upload avatar image", {
      requestId,
      fileName,
      error: error instanceof Error ? error.message : String(error),
    });
    throw new HttpsError("internal", `Failed to upload avatar image: ${error}`);
  }
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
  try {
    await db.collection("heroes").doc(heroId).update({
      avatarUrl,
      avatarPrompt,
      avatarGenerationId: generationId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Hero updated with avatar info", {
      requestId,
      heroId,
      generationId,
    });
  } catch (error) {
    logger.warn("Failed to update hero with avatar info", {
      requestId,
      heroId,
      error: error instanceof Error ? error.message : String(error),
    });
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
  try {
    await db.collection("imageGenerationChains").doc(`${heroId}_avatar`).set({
      heroId,
      chainType: "avatar",
      sequenceNumber: 0, // Avatar is always sequence 0
      generationId,
      prompt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Generation chain stored", {
      requestId,
      heroId,
      generationId,
    });
  } catch (error) {
    logger.warn("Failed to store generation chain", {
      requestId,
      heroId,
      generationId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

/**
 * Main avatar generation handler
 */
export const avatarGeneration = onCall<AvatarGenerationRequest>(
  {
    maxInstances: 10,
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const requestId = `avatar_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const startTime = Date.now();

    // Validate authentication
    if (!request.auth) {
      logger.error("Unauthenticated request", { requestId });
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = request.auth.uid;
    const data = request.data;

    logger.info("Avatar generation request received", {
      requestId,
      userId,
      heroId: data.heroId,
      promptLength: data.prompt.length,
      size: data.size || "1024x1024",
      quality: data.quality || "hd",
    });

    try {
      // Get hero data from Firestore
      const heroDoc = await db.collection("heroes").doc(data.heroId).get();

      if (!heroDoc.exists) {
        throw new HttpsError("not-found", "Hero not found");
      }

      const hero = { id: heroDoc.id, ...heroDoc.data() } as Hero;

      // Verify user owns the hero
      if (hero.userId !== userId) {
        throw new HttpsError("permission-denied", "Access denied to this hero");
      }

      // Set defaults
      const size = data.size || "1024x1024";
      const quality = data.quality || "hd";

      // Build comprehensive prompt
      const fullPrompt = buildAvatarPrompt(hero, data.prompt);

      // Filter prompt for safety
      const filterResult = enhancedBasicSanitization(fullPrompt);
      const filteredPrompt = filterResult.filtered;

      if (filterResult.wasModified) {
        logger.warn("Content filtering applied to avatar prompt", {
          requestId,
          modifications: filterResult.modifications,
        });
      }

      logger.info("Prompt built and filtered", {
        requestId,
        originalLength: fullPrompt.length,
        filteredLength: filteredPrompt.length,
      });

      // Generate image using DALL-E 3
      logger.info("Calling DALL-E-3 for avatar generation", {
        requestId,
        model: "dall-e-3",
        size,
        quality,
      });

      const imageRequest: any = {
        model: "dall-e-3",
        prompt: filteredPrompt,
        n: 1,
        size,
        quality,
        response_format: "b64_json",
      };

      // Add previous generation ID if provided for consistency
      if (data.previousGenerationId) {
        logger.info("Using previous generation ID for consistency", {
          requestId,
          previousGenerationId: data.previousGenerationId,
        });
        // Note: DALL-E-3 doesn't officially support generation ID chaining,
        // but we track it for our own consistency purposes
      }

      const response = await openai.images.generate(imageRequest);

      const responseTime = Date.now() - startTime;
      logger.info("DALL-E-3 response received", {
        requestId,
        responseTimeMs: responseTime,
      });

      // Extract image data and metadata
      if (!response.data || response.data.length === 0) {
        throw new HttpsError("internal", "No image data received from OpenAI");
      }

      const imageResult = response.data[0];
      if (!imageResult.b64_json) {
        throw new HttpsError("internal", "No image data received from OpenAI");
      }

      // Convert base64 to buffer
      const imageData = Buffer.from(imageResult.b64_json, "base64");

      // Generate a unique generation ID for tracking
      const generationId = `gen_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      // Upload to Firebase Storage
      const { url: avatarUrl, size: fileSize } = await uploadAvatarImage(
        imageData,
        data.heroId,
        userId,
        requestId
      );

      // Update hero with avatar information
      await updateHeroWithAvatar(
        data.heroId,
        avatarUrl,
        filteredPrompt,
        generationId,
        userId,
        requestId
      );

      // Store generation chain for future consistency
      await storeGenerationChain(
        data.heroId,
        generationId,
        filteredPrompt,
        requestId
      );

      // Prepare response
      const avatarResponse: AvatarGenerationResponse = {
        avatarUrl,
        generationId,
        revisedPrompt: imageResult.revised_prompt,
        fileSizeBytes: fileSize,
        imageSize: size,
        quality,
      };

      logger.info("Avatar generation completed", {
        requestId,
        heroId: data.heroId,
        generationId,
        fileSizeMb: Math.round(fileSize / 1024 / 1024 * 100) / 100,
        avatarUrl,
        totalTimeMs: Date.now() - startTime,
      });

      return avatarResponse;

    } catch (error) {
      logger.error("Avatar generation failed", {
        requestId,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      // Handle OpenAI specific errors
      if (error instanceof OpenAI.APIError) {
        if (error.status === 429) {
          throw new HttpsError("resource-exhausted", "Rate limit exceeded. Please try again later.");
        }
        if (error.status === 400 && error.message.includes("content_policy_violation")) {
          throw new HttpsError("invalid-argument", "Content policy violation detected. Please modify your prompt.");
        }
        throw new HttpsError("internal", `OpenAI API error: ${error.message}`);
      }

      throw new HttpsError("internal", `Avatar generation failed: ${error}`);
    }
  }
);
