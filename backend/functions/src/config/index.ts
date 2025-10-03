/**
 * Configuration module for Firebase Cloud Functions
 * Manages API keys and environment configuration
 */

import * as functions from "firebase-functions";

interface Config {
  openai: {
    apiKey: string;
  };
  firebase: {
    projectId: string;
    storageBucket: string;
  };
  environment: string;
}

/**
 * Get configuration from Firebase Functions config
 * In production, set with: firebase functions:config:set openai.key="your-api-key"
 * For local development, use .env file with OPENAI_API_KEY
 */
export function getConfig(): Config {
  // Check for local development environment variable first
  if (process.env.OPENAI_API_KEY) {
    return {
      openai: {
        apiKey: process.env.OPENAI_API_KEY,
      },
      firebase: {
        projectId: process.env.GCLOUD_PROJECT || "infinite-stories-8861a",
        storageBucket: process.env.STORAGE_BUCKET || "infinite-stories-8861a.appspot.com",
      },
      environment: process.env.NODE_ENV || "development",
    };
  }

  // Production: use Firebase Functions config
  const config = functions.config();

  if (!config.openai?.key) {
    throw new Error(
      "OpenAI API key not configured. Set it with: firebase functions:config:set openai.key='your-api-key'"
    );
  }

  return {
    openai: {
      apiKey: config.openai.key,
    },
    firebase: {
      projectId: process.env.GCLOUD_PROJECT || "",
      storageBucket: process.env.STORAGE_BUCKET || `${process.env.GCLOUD_PROJECT}.appspot.com`,
    },
    environment: "production",
  };
}