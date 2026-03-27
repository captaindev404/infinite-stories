import { betterAuth } from "better-auth";
import { bearer } from "better-auth/plugins";
import { prismaAdapter } from "better-auth/adapters/prisma";
import { prisma } from "@/lib/prisma/client";

const appleCredentialsConfigured = !!(
  process.env.APPLE_CLIENT_ID &&
  process.env.APPLE_CLIENT_SECRET
);

if (!appleCredentialsConfigured) {
  console.warn("⚠️ Apple Sign-In credentials not configured. Apple authentication will be unavailable.");
}

if (!process.env.BETTER_AUTH_SECRET) {
  throw new Error('Missing BETTER_AUTH_SECRET environment variable');
}

export const auth = betterAuth({
  database: prismaAdapter(prisma, {
    provider: "postgresql",
  }),

  baseURL: process.env.BETTER_AUTH_URL || "http://localhost:3000",
  secret: process.env.BETTER_AUTH_SECRET,

  emailAndPassword: {
    enabled: true,
    requireEmailVerification: false, // Set to true in production with email service
    minPasswordLength: 8,
    maxPasswordLength: 128,
  },

  socialProviders: appleCredentialsConfigured ? {
    apple: {
      clientId: process.env.APPLE_CLIENT_ID!,
      clientSecret: process.env.APPLE_CLIENT_SECRET!,
      appBundleIdentifier: process.env.APPLE_APP_BUNDLE_IDENTIFIER || "com.captaindev.InfiniteStories",
    },
  } : undefined,

  session: {
    expiresIn: 60 * 60 * 24 * 30, // 30 days
    updateAge: 60 * 60 * 24, // Update every 24 hours
    cookieCache: {
      enabled: true,
      maxAge: 5 * 60, // 5 minutes
    },
  },

  // Enable Bearer token authentication for mobile apps
  plugins: [bearer()],

  account: {
    accountLinking: {
      enabled: true,
      trustedProviders: ["email", "apple"],
    },
  },

  user: {
    additionalFields: {
      totalStoriesGenerated: {
        type: "number",
        defaultValue: 0,
      },
      totalAudioGenerated: {
        type: "number",
        defaultValue: 0,
      },
      totalIllustrationsGenerated: {
        type: "number",
        defaultValue: 0,
      },
      lastStoryGeneratedAt: {
        type: "date",
        required: false,
      },
    },
  },

  advanced: {
    cookiePrefix: "infinite-stories",
    crossSubDomainCookies: {
      enabled: false,
    },
    // Allow requests without Origin header (for mobile apps)
    useSecureCookies: process.env.NODE_ENV === "production",
    generateSessionToken: true,
  },

  // Trust proxy for local development
  trustedOrigins: [
    "http://localhost:3000",
    "capacitor://localhost", // For Capacitor apps
    "ionic://localhost", // For Ionic apps
    "https://appleid.apple.com", // Sign in with Apple
    process.env.BETTER_AUTH_URL || "",
  ],
});

export type Session = typeof auth.$Infer.Session.session;
export type User = typeof auth.$Infer.Session.user;
